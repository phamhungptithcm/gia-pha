import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../core/services/debug_genealogy_store.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../models/member_draft.dart';
import '../models/member_profile.dart';
import '../models/member_workspace_snapshot.dart';
import 'member_repository.dart';

class DebugMemberRepository implements MemberRepository {
  DebugMemberRepository({required DebugGenealogyStore store}) : _store = store;

  factory DebugMemberRepository.seeded() {
    return DebugMemberRepository(store: DebugGenealogyStore.seeded());
  }

  factory DebugMemberRepository.shared() {
    return DebugMemberRepository(store: DebugGenealogyStore.sharedSeeded());
  }

  final DebugGenealogyStore _store;

  @override
  bool get isSandbox => true;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const MemberWorkspaceSnapshot(members: [], branches: []);
    }

    final members = _store.members.values
        .where((member) => member.clanId == clanId)
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final branches = _store.branches.values
        .where((branch) => branch.clanId == clanId)
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);

    return MemberWorkspaceSnapshot(members: members, branches: branches);
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final normalizedPhone = _normalizePhoneOrNull(draft.phoneInput);
    _ensureUniquePhone(normalizedPhone, memberId);

    final resolvedMemberId =
        memberId ?? 'member_demo_${_store.memberSequence++}';
    final existing = _store.members[resolvedMemberId];
    var parentIds = _normalizeParentIds(draft.parentIds)
        .where((id) => id != resolvedMemberId)
        .toList(growable: false);
    var branchId = draft.branchId ?? existing?.branchId ?? session.branchId ?? '';
    var generation = draft.generation;
    if (parentIds.isNotEmpty) {
      final primaryParent = _store.members[parentIds.first];
      if (primaryParent != null) {
        branchId = primaryParent.branchId;
        generation = primaryParent.generation + 1;
      }
    }
    final previousParentIds = existing?.parentIds ?? const <String>[];
    final payload = MemberProfile(
      id: resolvedMemberId,
      clanId: clanId,
      branchId: branchId,
      fullName: draft.fullName.trim(),
      normalizedFullName: draft.fullName.trim().toLowerCase(),
      nickName: draft.nickName.trim(),
      gender: _nullableTrim(draft.gender),
      birthDate: draft.birthDate,
      deathDate: draft.deathDate,
      phoneE164: normalizedPhone,
      email: _nullableTrim(draft.email),
      addressText: _nullableTrim(draft.addressText),
      jobTitle: _nullableTrim(draft.jobTitle),
      avatarUrl: existing?.avatarUrl,
      bio: _nullableTrim(draft.bio),
      socialLinks: draft.socialLinks,
      parentIds: parentIds,
      childrenIds: existing?.childrenIds ?? const [],
      spouseIds: existing?.spouseIds ?? const [],
      generation: generation <= 0 ? 1 : generation,
      primaryRole: existing?.primaryRole ?? draft.primaryRole,
      status: existing?.status ?? draft.status,
      isMinor: draft.isMinor,
      authUid: existing?.authUid,
    );

    _store.members[resolvedMemberId] = payload;
    _syncParentLinks(
      memberId: resolvedMemberId,
      previousParentIds: previousParentIds,
      nextParentIds: parentIds,
    );
    _store.recountBranchMembers(clanId);
    return payload;
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final existing = _store.members[memberId];
    if (existing == null) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.memberNotFound,
      );
    }

    final updated = existing.copyWith(
      avatarUrl:
          'debug://avatar/$memberId/${DateTime.now().millisecondsSinceEpoch}-$fileName',
    );
    _store.members[memberId] = updated;
    return updated;
  }

  void _ensureUniquePhone(String? phoneE164, String? memberId) {
    if (phoneE164 == null) {
      return;
    }

    final duplicate = _store.members.values.firstWhereOrNull(
      (member) => member.phoneE164 == phoneE164 && member.id != memberId,
    );
    if (duplicate != null) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.duplicatePhone,
      );
    }
  }

  void _syncParentLinks({
    required String memberId,
    required List<String> previousParentIds,
    required List<String> nextParentIds,
  }) {
    final previous = previousParentIds.toSet();
    final next = nextParentIds.toSet();
    for (final parentId in previous.difference(next)) {
      final parent = _store.members[parentId];
      if (parent == null) {
        continue;
      }
      _store.members[parentId] = parent.copyWith(
        childrenIds: parent.childrenIds
            .where((childId) => childId != memberId)
            .toList(growable: false),
      );
    }
    for (final parentId in next.difference(previous)) {
      final parent = _store.members[parentId];
      if (parent == null) {
        continue;
      }
      final mergedChildren = {...parent.childrenIds, memberId}.toList(
        growable: false,
      );
      _store.members[parentId] = parent.copyWith(childrenIds: mergedChildren);
    }
  }
}

String? _normalizePhoneOrNull(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return PhoneNumberFormatter.parse(trimmed).e164;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<String> _normalizeParentIds(List<String> parentIds) {
  return parentIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
