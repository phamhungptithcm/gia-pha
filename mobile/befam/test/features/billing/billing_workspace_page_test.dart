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

  Future<void> pumpBillingPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BillingWorkspacePage(
          session: buildSession(),
          repository: DebugBillingRepository.shared(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void seedPaidTier() {
    final store = DebugGenealogyStore.sharedSeeded();
    for (var index = 0; index < 20; index += 1) {
      store.members['member_billing_widget_$index'] =
          store.members['member_demo_parent_001']!.copyWith(
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

    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(find.textContaining('Số thành viên hiện tại'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lịch sử thanh toán'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lịch sử thanh toán'), findsOneWidget);
  });

  testWidgets('creates card checkout and displays latest checkout card', (tester) async {
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
}
