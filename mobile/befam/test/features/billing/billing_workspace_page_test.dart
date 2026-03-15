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
  AuthSession buildSession({String primaryRole = 'CLAN_ADMIN'}) {
    return AuthSession(
      uid: 'debug:+84901234567',
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

  Future<void> pumpBillingPage(
    WidgetTester tester, {
    AuthSession? session,
    DebugBillingRepository? repository,
    Locale locale = const Locale('vi'),
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

  testWidgets('creates card checkout and displays latest checkout card', (
    tester,
  ) async {
    seedPaidTier();
    await pumpBillingPage(tester);

    final cardButton = find.byKey(const Key('billing-checkout-card-button'));
    expect(cardButton, findsOneWidget);

    await tester.tap(cardButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Phiên thanh toán mới nhất'), findsOneWidget);
    expect(find.textContaining('Mã giao dịch'), findsOneWidget);
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
    await tester.tap(find.text('Tự động').first, warnIfMissed: false);
    await tester.pump();

    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Đã lưu cài đặt thanh toán.'), findsOneWidget);
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
    expect(find.byKey(const Key('billing-checkout-card-button')), findsNothing);
    expect(
      find.byKey(const Key('billing-checkout-vnpay-button')),
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
      final session = buildSession(primaryRole: 'CLAN_ADMIN');

      await pumpBillingPage(tester, session: session, repository: repository);

      final selector = find.byKey(const Key('billing-plan-selector'));
      expect(selector, findsOneWidget);

      await tester.tap(selector);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('FREE •'), findsNothing);
      expect(find.textContaining('BASE •'), findsNothing);
      expect(find.textContaining('PLUS •'), findsWidgets);
      expect(find.textContaining('PRO •'), findsWidgets);

      await tester.tap(find.textContaining('PRO •').last);
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byKey(const Key('billing-checkout-card-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final snapshot = await tester.runAsync(
        () => repository.loadWorkspace(session: session),
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.subscription.planCode, 'PRO');
      expect(snapshot.subscription.status, 'pending_payment');
    },
  );

  testWidgets('localizes statuses and audit labels in English', (tester) async {
    seedPaidTier();
    await pumpBillingPage(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(const Key('billing-checkout-card-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

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
