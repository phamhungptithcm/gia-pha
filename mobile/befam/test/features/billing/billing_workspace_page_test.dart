import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/presentation/billing_workspace_page.dart';
import 'package:befam/features/billing/services/billing_repository.dart';
import '../../support/features/billing/services/debug_billing_repository.dart';
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

  Future<void> pumpBillingDetailsPage(
    WidgetTester tester, {
    AuthSession? session,
    BillingRepository? repository,
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
        home: BillingDetailsPage(
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

  testWidgets('renders billing workspace summary', (tester) async {
    await pumpBillingPage(tester);

    expect(find.text('Gói của bạn'), findsOneWidget);
    expect(find.byKey(const Key('billing-ai-usage-section')), findsNothing);
    expect(
      find.byKey(const Key('billing-payment-history-section')),
      findsNothing,
    );
    expect(find.text('Chọn gói tiếp theo'), findsOneWidget);
  });

  testWidgets('no-clan user can load personal billing workspace and checkout', (
    tester,
  ) async {
    await pumpBillingPage(tester, session: buildNoClanSession());

    expect(find.text('Gói của bạn'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chọn gói tiếp theo'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chọn gói tiếp theo'), findsOneWidget);
    final selector = find.byKey(const Key('billing-plan-selector'));
    expect(selector, findsOneWidget);
    final baseOption = find.byKey(const Key('billing-plan-option-base'));
    expect(baseOption, findsOneWidget);
    await tester.tap(baseOption);
    await tester.pumpAndSettle();

    final checkoutButton = find.byKey(
      const Key('billing-open-checkout-button'),
    );
    await tester.ensureVisible(checkoutButton);
    await tester.pumpAndSettle();
    expect(checkoutButton, findsOneWidget);
  });

  testWidgets('creates checkout action without crashing', (tester) async {
    seedPaidTier();
    await pumpBillingPage(
      tester,
      session: buildSession(uid: 'debug:billing-checkout'),
    );

    final checkoutButton = find.byKey(
      const Key('billing-open-checkout-button'),
    );
    await tester.scrollUntilVisible(
      checkoutButton,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(checkoutButton);
    await tester.pumpAndSettle();
    expect(checkoutButton, findsOneWidget);
    await tester.tap(checkoutButton);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('billing-open-checkout-button')),
      findsOneWidget,
    );
  });

  testWidgets('saves billing preference changes from billing details', (
    tester,
  ) async {
    seedPaidTier();
    await pumpBillingDetailsPage(tester);

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

    final reminderSwitch = find.byType(Switch);
    expect(reminderSwitch, findsOneWidget);
    await tester.scrollUntilVisible(
      reminderSwitch,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(reminderSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
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
    expect(
      find.byKey(const Key('billing-save-success-indicator')),
      findsOneWidget,
    );
  });

  testWidgets('member role can still manage personal billing', (tester) async {
    final repository = DebugBillingRepository.shared();
    await pumpBillingPage(
      tester,
      session: buildSession(primaryRole: 'MEMBER'),
      repository: repository,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('billing-open-checkout-button')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('billing-open-checkout-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('billing-ai-usage-section')), findsNothing);
    expect(
      find.byKey(const Key('billing-payment-history-section')),
      findsNothing,
    );
  });

  testWidgets('pricing quick view uses concise plan guidance', (tester) async {
    await pumpBillingPage(tester);

    await tester.tap(find.byKey(const Key('billing-pricing-quick-action')));
    await tester.pumpAndSettle();

    expect(find.text('Các gói hiện có'), findsOneWidget);
    expect(find.textContaining('Gọn nhẹ cho nhu cầu hằng ngày'), findsWidgets);
    expect(find.textContaining('thành viên'), findsNothing);
  });

  testWidgets('localizes billing details in English', (tester) async {
    seedPaidTier();
    await pumpBillingDetailsPage(
      tester,
      locale: const Locale('en'),
      session: buildSession(uid: 'debug:billing-en-localization'),
    );

    await tester.scrollUntilVisible(
      find.text('Payment history'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Your AI help this month'), findsOneWidget);
  });
}
