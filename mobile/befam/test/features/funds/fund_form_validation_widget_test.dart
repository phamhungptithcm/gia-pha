import 'package:befam/app/theme/app_theme.dart';
import 'package:befam/core/widgets/app_form_controls.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/funds/presentation/fund_workspace_page.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/features/funds/services/debug_fund_repository.dart';
import '../../support/features/funds/services/debug_treasurer_dashboard_repository.dart';
import '../../support/features/member/services/debug_member_repository.dart';
import '../../support/features/scholarship/services/debug_scholarship_repository.dart';

void main() {
  Future<void> tapByKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  AuthSession buildClanAdminSession() {
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
      signedInAtIso: DateTime(2026, 4, 2).toIso8601String(),
    );
  }

  Future<void> pumpFunds(WidgetTester tester) async {
    final fundRepository = DebugFundRepository.seeded();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: FundWorkspacePage(
          session: buildClanAdminSession(),
          repository: fundRepository,
          treasurerDashboardRepository: DebugTreasurerDashboardRepository(
            fundRepository: fundRepository,
            scholarshipRepository: DebugScholarshipRepository.seeded(),
          ),
          memberRepository: DebugMemberRepository.seeded(),
        ),
      ),
    );
    for (var i = 0; i < 40; i += 1) {
      if (find.byKey(const Key('fund-add-fab')).evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('fund-add-fab')), findsOneWidget);
  }

  Future<void> openScholarshipFund(WidgetTester tester) async {
    for (var i = 0; i < 40; i += 1) {
      if (find
          .byKey(const Key('fund-row-fund_demo_scholarship'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tapByKey(tester, const Key('fund-row-fund_demo_scholarship'));
  }

  testWidgets('fund editor shows required name before member assignment', (
    tester,
  ) async {
    await pumpFunds(tester);

    await tapByKey(tester, const Key('fund-add-fab'));
    await tapByKey(tester, const Key('fund-editor-next-step-button'));

    expect(find.text('Tên quỹ là bắt buộc.'), findsOneWidget);
    expect(find.byKey(const Key('fund-save-button')), findsNothing);
    expect(find.byKey(AppRequiredFieldLabel.markerKey), findsWidgets);
  });

  testWidgets('transaction editor requires amount before saving', (
    tester,
  ) async {
    await pumpFunds(tester);
    await openScholarshipFund(tester);
    await tapByKey(tester, const Key('fund-add-donation-button'));
    await tapByKey(tester, const Key('fund-transaction-save-button'));

    expect(find.text('Số tiền là bắt buộc.'), findsOneWidget);
    expect(find.byKey(AppRequiredFieldLabel.markerKey), findsWidgets);
  });

  testWidgets('transaction editor validates bad amount, zero, and long note', (
    tester,
  ) async {
    await pumpFunds(tester);
    await openScholarshipFund(tester);
    await tapByKey(tester, const Key('fund-add-donation-button'));

    await tester.enterText(
      find.byKey(const Key('fund-transaction-amount-input')),
      'abc',
    );
    await tapByKey(tester, const Key('fund-transaction-save-button'));
    expect(find.text('Nhập số tiền hợp lệ.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fund-transaction-amount-input')),
      '0',
    );
    await tapByKey(tester, const Key('fund-transaction-save-button'));
    expect(find.text('Số tiền phải lớn hơn 0.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fund-transaction-amount-input')),
      '100000',
    );
    await tester.enterText(
      find.byKey(const Key('fund-transaction-note-input')),
      List.filled(281, 'a').join(),
    );
    await tapByKey(tester, const Key('fund-transaction-save-button'));
    expect(find.text('Ghi chú tối đa 280 ký tự.'), findsOneWidget);
  });

  testWidgets('expense editor blocks amount above current balance', (
    tester,
  ) async {
    await pumpFunds(tester);
    await openScholarshipFund(tester);
    await tapByKey(tester, const Key('fund-add-expense-button'));

    await tester.enterText(
      find.byKey(const Key('fund-transaction-amount-input')),
      '999999999',
    );
    await tapByKey(tester, const Key('fund-transaction-save-button'));

    expect(
      find.text('Khoản chi không được vượt số dư hiện tại.'),
      findsOneWidget,
    );
  });
}
