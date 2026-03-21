import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/notifications/models/notification_inbox_item.dart';
import 'package:befam/features/notifications/presentation/notification_inbox_page.dart';
import 'package:befam/features/notifications/presentation/notification_target_page.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test/support/features/notifications/services/debug_notification_inbox_repository.dart';
import '../e2e_test_harness.dart';

class NotificationPageObject {
  const NotificationPageObject(this.tester);

  final WidgetTester tester;

  Future<void> openInbox(AuthSession session) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) {
          return NotificationInboxPage(
            session: session,
            repository: DebugNotificationInboxRepository(),
            onOpenTarget: (item) {
              final targetType = switch (item.target) {
                NotificationInboxTarget.event => NotificationTargetType.event,
                NotificationInboxTarget.scholarship =>
                  NotificationTargetType.scholarship,
                NotificationInboxTarget.billing => NotificationTargetType.billing,
                NotificationInboxTarget.generic => NotificationTargetType.unknown,
                NotificationInboxTarget.unknown => NotificationTargetType.unknown,
              };
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => NotificationTargetPage(
                    targetType: targetType,
                    referenceId: item.targetId,
                    sourceTitle: item.title,
                    sourceBody: item.body,
                  ),
                ),
              );
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
      await tester.tap(find.byKey(const Key('notification-row-notif_demo_event_001')));
      await safePumpAndSettle(tester);
      return;
    }
    await tester.tap(firstOpenButton.first);
    await safePumpAndSettle(tester);
  }

  Future<void> expectEventDeepLinkTargetVisible() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('notification-target-event')),
      reason: 'Không mở đúng deep-link target cho notification event.',
    );
  }
}
