import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/onboarding/models/onboarding_models.dart';
import 'package:befam/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
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
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  test(
    'default onboarding coordinator degrades gracefully without Firebase bootstrap',
    () async {
      final coordinator = createDefaultOnboardingCoordinator(
        session: buildSession(),
      );
      addTearDown(coordinator.dispose);

      await coordinator.handleTrigger(
        const OnboardingTrigger(
          id: 'app_shell_home',
          routeId: 'app_shell_home',
        ),
      );

      expect(coordinator.activeFlow, isNull);
      expect(coordinator.isVisible, isFalse);
    },
  );
}
