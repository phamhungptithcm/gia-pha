import 'dart:async';
import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/auth/services/phone_number_formatter.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_workspace_snapshot.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:collection/collection.dart';
import '../../../core/services/debug_genealogy_store.dart';

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
    _ensureUniquePhone(
      clanId: clanId,
      phoneE164: normalizedPhone,
      memberId: memberId,
    );

    final resolvedMemberId =
        memberId ?? 'member_demo_${_store.memberSequence++}';
    final existing = _store.members[resolvedMemberId];
    var parentIds = _normalizeParentIds(
      draft.parentIds,
    ).where((id) => id != resolvedMemberId).toList(growable: false);
    var branchId =
        draft.branchId ?? existing?.branchId ?? session.branchId ?? '';
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
      siblingOrder: parentIds.isEmpty
          ? null
          : existing?.siblingOrder ?? draft.siblingOrder,
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
    _syncSiblingOrder(
      clanId: clanId,
      parentIds: {...previousParentIds, ...parentIds},
    );
    if (parentIds.isEmpty) {
      final current = _store.members[resolvedMemberId];
      if (current != null && current.siblingOrder != null) {
        _store.members[resolvedMemberId] = current.copyWith(siblingOrder: null);
      }
    }
    _store.recountBranchMembers(clanId);
    return _store.members[resolvedMemberId] ?? payload;
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

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final existing = _store.members[memberId];
    if (existing == null) {
      return;
    }
    final validCoordinates =
        latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    final shouldShare = sharingEnabled && validCoordinates;
    _store.members[memberId] = existing.copyWith(
      locationSharingEnabled: shouldShare,
      locationLatitude: shouldShare ? latitude : null,
      locationLongitude: shouldShare ? longitude : null,
      locationAccuracyMeters: shouldShare ? accuracyMeters : null,
      locationUpdatedAt: shouldShare
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    );
  }

  void _ensureUniquePhone({
    required String clanId,
    required String? phoneE164,
    required String? memberId,
  }) {
    if (phoneE164 == null) {
      return;
    }

    final duplicate = _store.members.values.firstWhereOrNull(
      (member) =>
          member.clanId == clanId &&
          PhoneNumberFormatter.areEquivalent(member.phoneE164, phoneE164) &&
          member.id != memberId,
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
      final mergedChildren = {
        ...parent.childrenIds,
        memberId,
      }.toList(growable: false);
      _store.members[parentId] = parent.copyWith(childrenIds: mergedChildren);
    }
  }

  void _syncSiblingOrder({
    required String clanId,
    required Set<String> parentIds,
  }) {
    for (final parentId in parentIds) {
      if (parentId.trim().isEmpty) {
        continue;
      }
      final parent = _store.members[parentId];
      if (parent == null || parent.clanId != clanId) {
        continue;
      }
      final rankedChildren =
          parent.childrenIds
              .map((childId) => _store.members[childId])
              .whereType<MemberProfile>()
              .where((child) => child.clanId == clanId)
              .toList(growable: false)
            ..sort(_compareMemberBySiblingOrderRules);
      for (var index = 0; index < rankedChildren.length; index++) {
        final member = rankedChildren[index];
        final nextOrder = index + 1;
        if (member.siblingOrder == nextOrder) {
          continue;
        }
        _store.members[member.id] = member.copyWith(siblingOrder: nextOrder);
      }
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

DateTime? _tryParseIsoDate(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

int _compareMemberBySiblingOrderRules(MemberProfile left, MemberProfile right) {
  final leftBirthDate = _tryParseIsoDate(left.birthDate);
  final rightBirthDate = _tryParseIsoDate(right.birthDate);
  final byBirthDate = _compareNullableDate(leftBirthDate, rightBirthDate);
  if (byBirthDate != 0) {
    return byBirthDate;
  }
  final byGeneration = left.generation.compareTo(right.generation);
  if (byGeneration != 0) {
    return byGeneration;
  }
  final byName = left.fullName.toLowerCase().compareTo(
    right.fullName.toLowerCase(),
  );
  if (byName != 0) {
    return byName;
  }
  return left.id.compareTo(right.id);
}

int _compareNullableDate(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}
