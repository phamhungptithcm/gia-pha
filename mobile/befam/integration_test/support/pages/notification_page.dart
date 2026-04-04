import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/presentation/billing_workspace_page.dart';
import 'package:befam/features/events/presentation/event_workspace_page.dart';
import 'package:befam/features/notifications/models/notification_inbox_item.dart';
import 'package:befam/features/notifications/presentation/notification_inbox_page.dart';
import 'package:befam/features/scholarship/presentation/scholarship_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test/support/features/billing/services/debug_billing_repository.dart';
import '../../../test/support/features/events/services/debug_event_repository.dart';
import '../../../test/support/features/notifications/services/debug_notification_inbox_repository.dart';
import '../../../test/support/features/scholarship/services/debug_scholarship_repository.dart';
import '../e2e_test_harness.dart';

class NotificationPageObject {
  const NotificationPageObject(this.tester);

  final WidgetTester tester;

  Future<void> openInbox(AuthSession session) async {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) {
          return NotificationInboxPage(
            session: session,
            repository: DebugNotificationInboxRepository(),
            onOpenTarget: (item) {
              switch (item.target) {
                case NotificationInboxTarget.event:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => EventWorkspacePage(
                        session: session,
                        repository: DebugEventRepository.shared(),
                        initialEventId: item.targetId,
                      ),
                    ),
                  );
                case NotificationInboxTarget.scholarship:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => ScholarshipWorkspacePage(
                        session: session,
                        repository: DebugScholarshipRepository.shared(),
                        initialProgramId: item.targetId,
                        initialSubmissionId: item.targetId,
                      ),
                    ),
                  );
                case NotificationInboxTarget.billing:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => BillingWorkspacePage(
                        session: session,
                        repository: DebugBillingRepository.shared(),
                      ),
                    ),
                  );
                case NotificationInboxTarget.generic:
                case NotificationInboxTarget.unknown:
                  break;
              }
            },
          );
        },
      ),
    );
    await safePumpAndSettle(tester);
  }

  Future<void> openFirstNotification() async {
    final firstOpenButton = find.byKey(
      const Key('notification-open-notif_demo_event_001'),
    );
    if (firstOpenButton.evaluate().isEmpty) {
      await waitForFinder(
        tester,
        find.byKey(const Key('notification-row-notif_demo_event_001')),
        reason: 'Không thấy item đầu tiên trong notification inbox.',
      );
      await tapFinderSafely(
        tester,
        find.byKey(const Key('notification-row-notif_demo_event_001')),
        reason: 'Không thể mở notification item đầu tiên.',
        dismissKeyboardBeforeTap: false,
      );
      return;
    }
    await tapFinderSafely(
      tester,
      firstOpenButton,
      reason: 'Không thể bấm nút mở notification đầu tiên.',
      dismissKeyboardBeforeTap: false,
    );
  }

  Future<void> expectEventDeepLinkTargetVisible() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('event-detail-page-event_demo_memorial_001')),
      reason: 'Không mở đúng deep-link target cho notification event.',
    );
  }
}
