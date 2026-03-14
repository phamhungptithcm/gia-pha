import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/genealogy/presentation/genealogy_workspace_page.dart';
import 'package:befam/features/genealogy/services/debug_genealogy_read_repository.dart';
import 'package:befam/features/genealogy/services/genealogy_segment_cache.dart';
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

  setUp(() {
    GenealogySegmentCache.shared().clear();
  });

  testWidgets('renders the genealogy workspace and switches scope', (
    tester,
  ) async {
    final repository = DebugGenealogyReadRepository(
      store: DebugGenealogyStore.seeded(),
    );

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
        home: Scaffold(
          body: GenealogyWorkspacePage(
            session: buildClanAdminSession(),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read model gia phả'), findsOneWidget);
    expect(find.byKey(const Key('genealogy-summary-members-5')), findsOneWidget);
    expect(find.byKey(const Key('genealogy-summary-scope-clan')), findsOneWidget);

    await tester.tap(find.byKey(const Key('genealogy-scope-branch')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('genealogy-summary-members-3')), findsOneWidget);
    expect(find.byKey(const Key('genealogy-summary-scope-branch')), findsOneWidget);
  });
}
