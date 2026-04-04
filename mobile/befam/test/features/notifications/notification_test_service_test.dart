import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/notifications/services/notification_test_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSandboxSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 4).toIso8601String(),
    );
  }

  test('uses sandbox notification service for sandbox sessions', () async {
    final service = createDefaultNotificationTestService(
      session: buildSandboxSession(),
    );

    expect(service.isSandbox, isTrue);
    await expectLater(
      service.sendSelfTest(
        session: buildSandboxSession(),
        title: 'Test notification',
        body: 'This should stay local.',
      ),
      throwsA(
        isA<NotificationTestServiceException>().having(
          (error) => error.code,
          'code',
          NotificationTestServiceErrorCode.failedPrecondition,
        ),
      ),
    );
    await expectLater(
      service.sendEventReminderSelfTest(
        session: buildSandboxSession(),
        title: 'Test event',
        body: 'This should stay local.',
      ),
      throwsA(
        isA<NotificationTestServiceException>().having(
          (error) => error.code,
          'code',
          NotificationTestServiceErrorCode.failedPrecondition,
        ),
      ),
    );
  });
}
