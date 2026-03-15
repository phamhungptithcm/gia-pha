import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/scholarship/presentation/scholarship_workspace_page.dart';
import 'package:befam/features/scholarship/services/debug_scholarship_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  AuthSession buildCouncilHeadSession() {
    return AuthSession(
      uid: 'debug:+84901111001',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901111001',
      displayName: 'Council Head',
      memberId: 'member_council_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'SCHOLARSHIP_COUNCIL_HEAD',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  Future<void> pumpScholarshipWorkspace(
    WidgetTester tester, {
    AuthSession? session,
    DebugScholarshipRepository? repository,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ScholarshipWorkspacePage(
          session: session ?? buildClanAdminSession(),
          repository: repository ?? DebugScholarshipRepository.seeded(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders program list and opens detail screen', (tester) async {
    await pumpScholarshipWorkspace(tester);

    expect(find.text('Scholarship programs'), findsOneWidget);
    expect(
      find.byKey(const Key('scholarship-program-card-sp_demo_2026')),
      findsOneWidget,
    );

    final openDetailFinder = find.byKey(
      const Key('scholarship-open-program-detail-sp_demo_2026'),
    );
    final openDetailButton = tester.widget<IconButton>(openDetailFinder);
    expect(openDetailButton.onPressed, isNotNull);
    openDetailButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Program detail'), findsOneWidget);
    expect(find.text('2026 Scholarship Program'), findsWidgets);
  });

  testWidgets('supports create forms and evidence upload', (
    tester,
  ) async {
    await pumpScholarshipWorkspace(tester);

    await tester.tap(
      find.byKey(const Key('scholarship-open-program-form-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('scholarship-program-title-input')),
      '2030 Scholarship Program',
    );
    await tester.enterText(
      find.byKey(const Key('scholarship-program-year-input')),
      '2030',
    );
    await tester.ensureVisible(
      find.byKey(const Key('scholarship-program-save-button')),
    );
    await tester.tap(find.byKey(const Key('scholarship-program-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('2030 Scholarship Program'), findsWidgets);

    final openDetailFinder = find.byKey(
      const Key('scholarship-open-program-detail-sp_demo_2026'),
    );
    final openDetailButton = tester.widget<IconButton>(openDetailFinder);
    expect(openDetailButton.onPressed, isNotNull);
    openDetailButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('scholarship-detail-open-award-form-button')),
    );
    await tester.tap(
      find.byKey(const Key('scholarship-detail-open-award-form-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('scholarship-award-name-input')),
      'Merit Award',
    );
    await tester.enterText(
      find.byKey(const Key('scholarship-award-amount-input')),
      '500000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('scholarship-award-save-button')),
    );
    await tester.tap(find.byKey(const Key('scholarship-award-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Merit Award'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('scholarship-detail-open-submission-form-button')),
    );
    await tester.tap(
      find.byKey(const Key('scholarship-detail-open-submission-form-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('scholarship-submission-student-input')),
      'Pham Gia Hung',
    );
    await tester.enterText(
      find.byKey(const Key('scholarship-submission-title-input')),
      'Math Talent Prize',
    );
    await tester.enterText(
      find.byKey(const Key('scholarship-evidence-file-input')),
      'talent-proof.txt',
    );

    await tester.tap(
      find.byKey(const Key('scholarship-upload-evidence-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scholarship-evidence-url-0')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('scholarship-submission-save-button')),
    );
    await tester.tap(
      find.byKey(const Key('scholarship-submission-save-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('scholarship-submission-save-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('scholarship-detail-submission-sub_demo_1000')),
      findsOneWidget,
    );
  });

  testWidgets('shows council review controls for pending submissions', (
    tester,
  ) async {
    await pumpScholarshipWorkspace(
      tester,
      session: buildCouncilHeadSession(),
    );

    final openDetailFinder = find.byKey(
      const Key('scholarship-open-program-detail-sp_demo_2026'),
    );
    final openDetailButton = tester.widget<IconButton>(openDetailFinder);
    expect(openDetailButton.onPressed, isNotNull);
    openDetailButton.onPressed!.call();
    await tester.pumpAndSettle();

    final approveFinder = find.byKey(
      const Key('scholarship-detail-approve-sub_demo_001'),
    );
    final approveActionButton = tester.widget<OutlinedButton>(approveFinder);
    expect(approveActionButton.onPressed, isNotNull);

    final rejectFinder = find.byKey(
      const Key('scholarship-detail-reject-sub_demo_001'),
    );
    expect(rejectFinder, findsOneWidget);
  });
}
