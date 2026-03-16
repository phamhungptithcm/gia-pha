import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/presentation/billing_workspace_page.dart';
import 'package:befam/features/billing/services/debug_billing_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({
    String uid = 'debug:+84901234567',
    String primaryRole = 'CLAN_ADMIN',
  }) {
    return AuthSession(
      uid: uid,
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: primaryRole,
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  AuthSession buildNoClanSession({String uid = 'debug:no-clan-billing'}) {
    return AuthSession(
      uid: uid,
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84900000000',
      displayName: 'No Clan User',
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  Future<void> pumpBillingPage(
    WidgetTester tester, {
    AuthSession? session,
    DebugBillingRepository? repository,
    Locale locale = const Locale('vi'),
    Future<bool> Function(Uri uri)? externalUrlLauncher,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BillingWorkspacePage(
          session: session ?? buildSession(),
          repository: repository ?? DebugBillingRepository.shared(),
          externalUrlLauncher: externalUrlLauncher ?? ((_) async => true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void seedPaidTier() {
    final store = DebugGenealogyStore.sharedSeeded();
    for (var index = 0; index < 20; index += 1) {
      store.members['member_billing_widget_$index'] = store
          .members['member_demo_parent_001']!
          .copyWith(
            id: 'member_billing_widget_$index',
            fullName: 'Billing Widget Member $index',
            normalizedFullName: 'billing widget member $index',
            authUid: null,
            primaryRole: 'MEMBER',
          );
    }
  }

  void seedPlusTier() {
    final store = DebugGenealogyStore.sharedSeeded();
    for (var index = 0; index < 260; index += 1) {
      store.members['member_billing_widget_plus_$index'] = store
          .members['member_demo_parent_001']!
          .copyWith(
            id: 'member_billing_widget_plus_$index',
            fullName: 'Billing Plus Member $index',
            normalizedFullName: 'billing plus member $index',
            authUid: null,
            primaryRole: 'MEMBER',
          );
    }
  }

  testWidgets('renders billing workspace summary', (tester) async {
    await pumpBillingPage(tester);

    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(find.textContaining('Số thành viên hiện tại'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lịch sử thanh toán'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lịch sử thanh toán'), findsOneWidget);
  });

  testWidgets('no-clan user can load personal billing workspace and checkout', (
    tester,
  ) async {
    await pumpBillingPage(tester, session: buildNoClanSession());

    expect(find.text('Gói cá nhân của bạn'), findsNothing);
    expect(find.text('Thanh toán & gia hạn'), findsOneWidget);
    final vnpayButton = find.byKey(const Key('billing-open-vnpay-form-button'));
    await tester.scrollUntilVisible(
      vnpayButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(vnpayButton, findsOneWidget);
  });

  testWidgets('creates VNPay checkout and opens pending transaction detail', (
    tester,
  ) async {
    seedPaidTier();
    await pumpBillingPage(
      tester,
      session: buildSession(uid: 'debug:billing-vnpay-checkout'),
    );

    final vnpayButton = find.byKey(const Key('billing-open-vnpay-form-button'));
    expect(vnpayButton, findsOneWidget);

    await tester.scrollUntilVisible(
      vnpayButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(vnpayButton);
    await tester.pumpAndSettle();
    await tester.tap(vnpayButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('billing-vnpay-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán chưa hoàn tất'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('billing-payment-failed-back-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phiên thanh toán mới nhất'), findsNothing);
    expect(find.text('Giao dịch đang chờ xử lý'), findsOneWidget);
    final firstPendingCard = find.byKey(
      const Key('billing-pending-transaction-item-0'),
    );
    await tester.scrollUntilVisible(
      firstPendingCard,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(firstPendingCard);
    await tester.pumpAndSettle();
    await tester.tap(firstPendingCard);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết giao dịch chờ'), findsOneWidget);
    expect(find.text('Mã giao dịch'), findsOneWidget);
    expect(find.textContaining('Đánh dấu VNPay'), findsNothing);
  });

  testWidgets('saves billing preference changes', (tester) async {
    seedPaidTier();
    await pumpBillingPage(tester);

    final saveButton = find.byKey(const Key('billing-save-preferences-button'));
    await tester.scrollUntilVisible(
      saveButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    final saveBeforeChange = tester.widget<FilledButton>(saveButton);
    expect(saveBeforeChange.onPressed, isNull);

    final reminderChip = find.byKey(const Key('billing-reminder-chip-30'));
    await tester.scrollUntilVisible(
      reminderChip,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(reminderChip);
    await tester.pumpAndSettle();
    await tester.tap(reminderChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    final saveAfterChange = tester.widget<FilledButton>(saveButton);
    expect(saveAfterChange.onPressed, isNotNull);

    await tester.scrollUntilVisible(
      saveButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final saveAfterPersist = tester.widget<FilledButton>(saveButton);
    expect(saveAfterPersist.onPressed, isNull);
  });

  testWidgets('viewer mode shows summary only and hides manager actions', (
    tester,
  ) async {
    final repository = DebugBillingRepository.shared();
    await pumpBillingPage(
      tester,
      session: buildSession(primaryRole: 'MEMBER'),
      repository: repository,
    );

    expect(find.text('Chế độ xem'), findsOneWidget);
    expect(
      find.byKey(const Key('billing-open-vnpay-form-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('billing-save-preferences-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('billing-payment-history-section')),
      findsNothing,
    );
  });

  testWidgets(
    'manager can select upgrade-only plans and checkout selected plan',
    (tester) async {
      seedPlusTier();
      final repository = DebugBillingRepository.shared();
      final session = buildSession(
        uid: 'debug:billing-upgrade-only',
        primaryRole: 'CLAN_ADMIN',
      );

      await pumpBillingPage(tester, session: session, repository: repository);

      final selector = find.byKey(const Key('billing-plan-selector'));
      expect(selector, findsOneWidget);

      final vnpayButton = find.byKey(
        const Key('billing-open-vnpay-form-button'),
      );
      await tester.scrollUntilVisible(
        vnpayButton,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(vnpayButton);
      await tester.pumpAndSettle();
      await tester.tap(vnpayButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('billing-vnpay-submit-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('billing-payment-failed-back-button')),
      );
      await tester.pumpAndSettle();

      final snapshot = await tester.runAsync(
        () => repository.loadWorkspace(session: session),
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.subscription.planCode, 'PLUS');
      expect(snapshot.subscription.status, 'expired');
    },
  );

  testWidgets(
    'shows downgrade warning when selected tier is below current member minimum',
    (tester) async {
      seedPlusTier(); // member count >= 201, minimum tier PLUS
      await pumpBillingPage(
        tester,
        session: buildSession(uid: 'debug:billing-downgrade-guard'),
      );

      final selector = find.byKey(const Key('billing-plan-selector'));
      expect(selector, findsOneWidget);
      await tester.scrollUntilVisible(
        selector,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      final baseOption = find.byKey(const Key('billing-plan-option-base'));
      expect(baseOption, findsOneWidget);
      expect(find.byKey(const Key('billing-plan-option-plus')), findsOneWidget);
      expect(find.byKey(const Key('billing-plan-option-pro')), findsOneWidget);

      await tester.tap(baseOption);
      await tester.pumpAndSettle();

      expect(find.text('Không thể hạ xuống gói này'), findsOneWidget);
      expect(
        find.byKey(const Key('billing-open-vnpay-form-button')),
        findsNothing,
      );
    },
  );

  testWidgets('localizes statuses and audit labels in English', (tester) async {
    seedPaidTier();
    await pumpBillingPage(
      tester,
      locale: const Locale('en'),
      session: buildSession(uid: 'debug:billing-en-localization'),
    );

    final vnpayButton = find.byKey(const Key('billing-open-vnpay-form-button'));
    await tester.scrollUntilVisible(
      vnpayButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(vnpayButton);
    await tester.pumpAndSettle();
    await tester.tap(vnpayButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('billing-vnpay-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('billing-payment-failed-back-button')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Payment history'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.textContaining('• Pending'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Invoices'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Status: Issued'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Audit logs'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Checkout created'), findsWidgets);
    expect(find.textContaining('Payment transaction •'), findsWidgets);
    expect(find.text('checkout_created'), findsNothing);
    expect(find.text('paymentTransaction'), findsNothing);
  });
}
