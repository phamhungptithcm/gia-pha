import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/discovery/models/join_request_draft.dart';
import '../../support/features/discovery/services/debug_genealogy_discovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugGenealogyDiscoveryRepository', () {
    test('searches genealogy by leader and location', () async {
      final repository = DebugGenealogyDiscoveryRepository.seeded();

      final byLeader = await repository.search(leaderQuery: 'Nguyễn Minh');
      final byLocation = await repository.search(locationQuery: 'Quảng Nam');

      expect(byLeader.isNotEmpty, isTrue);
      expect(byLeader.first.leaderName, contains('Nguyễn Minh'));
      expect(byLocation.isNotEmpty, isTrue);
      expect(byLocation.first.provinceCity, contains('Quảng Nam'));
    });

    test('submits and reviews a join request lifecycle', () async {
      final repository = DebugGenealogyDiscoveryRepository.seeded();
      final session = _claimedClanAdminSession();

      await repository.submitJoinRequest(
        draft: const JoinRequestDraft(
          clanId: 'clan_demo_001',
          applicantName: 'Nguyen An',
          relationshipToFamily: 'Hậu duệ đời 5',
          contactInfo: '+84901230000',
          message: 'Xin được tham gia gia phả.',
        ),
      );

      final pending = await repository.loadPendingJoinRequests(
        session: session,
      );
      expect(pending, hasLength(1));
      expect(pending.first.status, 'pending');

      await repository.reviewJoinRequest(
        session: session,
        requestId: pending.first.id,
        approve: true,
      );

      final afterReview = await repository.loadPendingJoinRequests(
        session: session,
      );
      expect(afterReview, isEmpty);
    });
  });
}

AuthSession _claimedClanAdminSession() {
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
    signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
  );
}
