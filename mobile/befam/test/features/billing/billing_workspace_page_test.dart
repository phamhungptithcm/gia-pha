import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/models/billing_workspace_snapshot.dart';
import 'package:befam/features/billing/presentation/billing_workspace_page.dart';
import 'package:befam/features/billing/services/billing_repository.dart';
import '../../support/features/billing/services/debug_billing_repository.dart';
import 'package:befam/features/billing/services/vnpay_mobile_sdk_gateway.dart';
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
      displayName: 'Nguyễn Minh',
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
      displayName: 'Người dùng chưa có gia phả',
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
    BillingRepository? repository,
    Locale locale = const Locale('vi'),
    Future<bool> Function(Uri uri)? externalUrlLauncher,
    VnpayMobileSdkGateway? vnpayGateway,
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
          vnpayGateway: vnpayGateway ?? const _TestVnpayGateway(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<Finder> waitForPaymentReturnButton(WidgetTester tester) async {
    final failedBackButton = find.byKey(
      const Key('billing-payment-failed-back-button'),
    );
    final pendingBackButton = find.byKey(
      const Key('billing-payment-back-button'),
    );
    final successBackButton = find.byKey(
      const Key('billing-payment-success-back-button'),
    );

    for (var index = 0; index < 80; index += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (failedBackButton.evaluate().isNotEmpty) {
        return failedBackButton;
      }
      if (pendingBackButton.evaluate().isNotEmpty) {
        return pendingBackButton;
      }
      if (successBackButton.evaluate().isNotEmpty) {
        return successBackButton;
      }
    }

    throw TestFailure('Timed out waiting for a payment return action button.');
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
    expect(find.text('Gói dịch vụ & thanh toán'), findsOneWidget);
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
    final returnButton = await waitForPaymentReturnButton(tester);
    final hasFailedLabel = find
        .text('Thanh toán chưa hoàn tất')
        .evaluate()
        .isNotEmpty;
    final hasPendingLabel = find
        .text('Đang chờ thanh toán')
        .evaluate()
        .isNotEmpty;
    expect(hasFailedLabel || hasPendingLabel, isTrue);
    await tester.tap(returnButton);
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
    expect(find.text('Phương thức'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
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
      final returnButton = await waitForPaymentReturnButton(tester);
      await tester.tap(returnButton);
      await tester.pumpAndSettle();

      final snapshot = await tester.runAsync(
        () => repository.loadWorkspace(session: session),
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.subscription.planCode, 'PLUS');
      expect(snapshot.subscription.status, 'expired');
    },
  );

  testWidgets('uses QR fallback checkout when runtime config enables it', (
    tester,
  ) async {
    seedPaidTier();
    final repository = _QrEnabledBillingRepository(
      DebugBillingRepository.shared(),
    );
    var didOpenQrImage = false;
    await pumpBillingPage(
      tester,
      session: buildSession(uid: 'debug:billing-qr-fallback'),
      repository: repository,
      externalUrlLauncher: (uri) async {
        didOpenQrImage = true;
        return true;
      },
    );

    final checkoutButton = find.byKey(
      const Key('billing-open-vnpay-form-button'),
    );
    await tester.scrollUntilVisible(
      checkoutButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(checkoutButton);
    await tester.pumpAndSettle();
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('billing-qr-payment-screen')), findsOneWidget);
    expect(find.byKey(const Key('billing-vnpay-submit-button')), findsNothing);
    await tester.tap(
      find.byKey(const Key('billing-qr-payment-download-button')),
    );
    await tester.pumpAndSettle();
    expect(didOpenQrImage, isTrue);
  });

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
    final returnButton = await waitForPaymentReturnButton(tester);
    await tester.tap(returnButton);
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
    expect(find.text('Payment transaction'), findsWidgets);
    expect(find.text('checkout_created'), findsNothing);
    expect(find.text('paymentTransaction'), findsNothing);
  });
}

class _QrEnabledBillingRepository implements BillingRepository {
  _QrEnabledBillingRepository(this._delegate);

  final BillingRepository _delegate;

  @override
  bool get isSandbox => _delegate.isSandbox;

  @override
  Future<BillingWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    final workspace = await _delegate.loadWorkspace(session: session);
    return BillingWorkspaceSnapshot(
      clanId: workspace.clanId,
      scope: workspace.scope,
      subscription: workspace.subscription,
      entitlement: workspace.entitlement,
      settings: workspace.settings,
      checkoutFlow: const BillingCheckoutFlowConfig(
        qrCheckoutEnabled: true,
        qrImageUrlsByPlan: <String, String>{
          'BASE': 'https://example.com/base-qr.png',
          'PLUS': 'https://example.com/plus-qr.png',
          'PRO': 'https://example.com/pro-qr.png',
        },
      ),
      pricingTiers: workspace.pricingTiers,
      memberCount: workspace.memberCount,
      transactions: workspace.transactions,
      invoices: workspace.invoices,
      auditLogs: workspace.auditLogs,
    );
  }

  @override
  Future<BillingViewerSummary> loadViewerSummary({
    required AuthSession session,
  }) {
    return _delegate.loadViewerSummary(session: session);
  }

  @override
  Future<BillingEntitlement> resolveEntitlement({
    required AuthSession session,
  }) {
    return _delegate.resolveEntitlement(session: session);
  }

  @override
  Future<BillingSettings> updatePreferences({
    required AuthSession session,
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) {
    return _delegate.updatePreferences(
      session: session,
      paymentMode: paymentMode,
      autoRenew: autoRenew,
      reminderDaysBefore: reminderDaysBefore,
    );
  }

  @override
  Future<BillingCheckoutResult> createCheckout({
    required AuthSession session,
    required String paymentMethod,
    String? requestedPlanCode,
    String? returnUrl,
    String? locale,
    String? orderNote,
    String? bankCode,
    String? contactPhone,
  }) {
    return _delegate.createCheckout(
      session: session,
      paymentMethod: paymentMethod,
      requestedPlanCode: requestedPlanCode,
      returnUrl: returnUrl,
      locale: locale,
      orderNote: orderNote,
      bankCode: bankCode,
      contactPhone: contactPhone,
    );
  }

  @override
  Future<void> completeCardCheckout({
    required AuthSession session,
    required String transactionId,
  }) {
    return _delegate.completeCardCheckout(
      session: session,
      transactionId: transactionId,
    );
  }

  @override
  Future<void> settleVnpayCheckout({
    required AuthSession session,
    required String transactionId,
  }) {
    return _delegate.settleVnpayCheckout(
      session: session,
      transactionId: transactionId,
    );
  }

  @override
  Future<BillingEntitlement> verifyInAppPurchase({
    required AuthSession session,
    required String platform,
    required String productId,
    required Map<String, dynamic> payload,
  }) {
    return _delegate.verifyInAppPurchase(
      session: session,
      platform: platform,
      productId: productId,
      payload: payload,
    );
  }
}

class _TestVnpayGateway implements VnpayMobileSdkGateway {
  const _TestVnpayGateway();

  @override
  Future<VnpayCheckoutOpenResult> openCheckout({
    required Uri checkoutUri,
  }) async {
    return const VnpayCheckoutOpenResult(
      status: VnpayCheckoutOpenStatus.externalBrowser,
    );
  }
}
