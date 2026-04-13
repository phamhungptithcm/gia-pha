import 'dart:typed_data';

import 'package:befam/features/ai/services/app_assistant_context_service.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/auth/models/clan_context_option.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_workspace_snapshot.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/features/member/services/debug_member_repository.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 13).toIso8601String(),
    );
  }

  final availableClanContexts = <ClanContextOption>[
    const ClanContextOption(
      clanId: 'clan_demo_001',
      clanName: 'Gia phả họ Nguyễn',
      memberId: 'member_demo_parent_001',
      primaryRole: 'CLAN_ADMIN',
    ),
    const ClanContextOption(
      clanId: 'clan_demo_002',
      clanName: 'Gia phả họ Trần',
      memberId: 'member_demo_parent_001',
      primaryRole: 'MEMBER',
    ),
  ];

  test(
    'buildSearchContext returns grounded member matches for person lookups',
    () async {
      final service = MemberWorkspaceAssistantContextService(
        memberRepository: DebugMemberRepository.seeded(),
      );

      final context = await service.buildSearchContext(
        session: buildSession(),
        question: 'Nguyễn Minh ở chi nào và đời thứ mấy?',
        activeClanName: 'Gia phả họ Nguyễn',
        availableClanContexts: availableClanContexts,
      );

      expect(context.searchQueryHint, 'Nguyễn Minh');
      expect(context.activeClanName, 'Gia phả họ Nguyễn');
      expect(context.availableClanCount, 2);
      expect(context.availableClanNames, [
        'Gia phả họ Nguyễn',
        'Gia phả họ Trần',
      ]);
      expect(context.memberMatches, isNotEmpty);
      expect(context.memberMatches.first.fullName, 'Nguyễn Minh');
      expect(context.memberMatches.first.branchName, 'Chi Trưởng');
      expect(context.memberMatches.first.generation, greaterThan(0));
    },
  );

  test('buildSearchContext stays empty for pure app-help questions', () async {
    final service = MemberWorkspaceAssistantContextService(
      memberRepository: DebugMemberRepository.seeded(),
    );

    final context = await service.buildSearchContext(
      session: buildSession(),
      question: 'Đổi ngôn ngữ app ở đâu?',
      activeClanName: 'Gia phả họ Nguyễn',
      availableClanContexts: availableClanContexts,
    );

    expect(context.searchQueryHint, isEmpty);
    expect(context.memberMatches, isEmpty);
    expect(context.activeClanMemberCount, greaterThan(0));
  });

  test('buildSearchContext reuses cached workspace within the cache window', () async {
    final repository = _CountingMemberRepository(
      delegate: DebugMemberRepository.seeded(),
    );
    final service = MemberWorkspaceAssistantContextService(
      memberRepository: repository,
    );

    await service.buildSearchContext(
      session: buildSession(),
      question: 'Tìm Nguyễn Minh trong gia phả này',
      activeClanName: 'Gia phả họ Nguyễn',
      availableClanContexts: availableClanContexts,
    );
    await service.buildSearchContext(
      session: buildSession(),
      question: 'Nguyễn Minh thuộc chi nào?',
      activeClanName: 'Gia phả họ Nguyễn',
      availableClanContexts: availableClanContexts,
    );

    expect(repository.loadWorkspaceCallCount, 1);
  });

  test('buildSearchContext refreshes the cache after the cache window expires', () async {
    final repository = _CountingMemberRepository(
      delegate: DebugMemberRepository.seeded(),
    );
    var now = DateTime(2026, 4, 13, 8, 0);
    final service = MemberWorkspaceAssistantContextService(
      memberRepository: repository,
      snapshotCacheTtl: const Duration(minutes: 1),
      nowProvider: () => now,
    );

    await service.buildSearchContext(
      session: buildSession(),
      question: 'Tìm Nguyễn Minh trong gia phả này',
      activeClanName: 'Gia phả họ Nguyễn',
      availableClanContexts: availableClanContexts,
    );

    now = now.add(const Duration(minutes: 2));

    await service.buildSearchContext(
      session: buildSession(),
      question: 'Nguyễn Minh thuộc chi nào?',
      activeClanName: 'Gia phả họ Nguyễn',
      availableClanContexts: availableClanContexts,
    );

    expect(repository.loadWorkspaceCallCount, 2);
  });
}

class _CountingMemberRepository implements MemberRepository {
  _CountingMemberRepository({required MemberRepository delegate})
    : _delegate = delegate;

  final MemberRepository _delegate;
  int loadWorkspaceCallCount = 0;

  @override
  bool get isSandbox => _delegate.isSandbox;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) {
    loadWorkspaceCallCount += 1;
    return _delegate.loadWorkspace(session: session);
  }

  @override
  Future<void> notifyNearbyRelativesDetected({
    required AuthSession session,
    required String clanId,
    required String memberId,
    required List<String> relativeMemberIds,
    double? closestDistanceKm,
  }) {
    return _delegate.notifyNearbyRelativesDetected(
      session: session,
      clanId: clanId,
      memberId: memberId,
      relativeMemberIds: relativeMemberIds,
      closestDistanceKm: closestDistanceKm,
    );
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) {
    return _delegate.saveMember(
      session: session,
      memberId: memberId,
      draft: draft,
    );
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    return _delegate.uploadAvatar(
      session: session,
      memberId: memberId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    return _delegate.updateMemberLiveLocation(
      session: session,
      memberId: memberId,
      sharingEnabled: sharingEnabled,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
    );
  }
}
