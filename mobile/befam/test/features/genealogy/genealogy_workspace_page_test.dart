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

  Future<void> scrollToTreeWorkspace(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('genealogy-depth-parents-value')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

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

    expect(find.text('Không gian cây gia phả'), findsOneWidget);
    expect(find.byKey(const Key('tree-preset-focused')), findsOneWidget);
    expect(find.byKey(const Key('tree-status-all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('genealogy-scope-branch')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('genealogy-summary-members-3')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('genealogy-summary-members-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('genealogy-summary-scope-branch')),
      findsOneWidget,
    );
  });

  testWidgets('renders landing, node cards, and connectors', (tester) async {
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

    expect(find.byKey(const Key('genealogy-landing-card')), findsOneWidget);
    await scrollToTreeWorkspace(tester);

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Nguyễn Minh'), findsWidgets);
  });

  testWidgets('shows ancestor and descendant lazy depth controls', (
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

    await scrollToTreeWorkspace(tester);

    expect(
      find.byKey(const Key('genealogy-depth-parents-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('genealogy-depth-children-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('genealogy-depth-parents-increase')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('genealogy-depth-children-increase')),
      findsOneWidget,
    );

    final parentDepthText = tester.widget<Text>(
      find.byKey(const Key('genealogy-depth-parents-value')),
    );
    final childDepthText = tester.widget<Text>(
      find.byKey(const Key('genealogy-depth-children-value')),
    );
    expect(parentDepthText.data, contains('1'));
    expect(childDepthText.data, contains('1'));
  });

  testWidgets('opens member detail sheet from node tap', (tester) async {
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

    await scrollToTreeWorkspace(tester);
    await tester.tap(find.byKey(const Key('tree-node-member_demo_child_001')));
    await tester.pumpAndSettle();

    expect(find.text('Bé Minh'), findsWidgets);
    expect(
      find.byKey(const Key('genealogy-open-member-detail-action')),
      findsOneWidget,
    );
  });

  testWidgets('coverage preset renders all clan members across branches', (
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

    await tester.tap(find.byKey(const Key('tree-preset-coverage')));
    await tester.pumpAndSettle();
    await scrollToTreeWorkspace(tester);

    expect(
      find.byKey(const Key('tree-node-member_demo_parent_001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tree-node-member_demo_parent_002')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tree-node-member_demo_child_001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tree-node-member_demo_child_002')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tree-node-member_demo_elder_001')),
      findsOneWidget,
    );
  });

  testWidgets('opens member detail page from node info button', (tester) async {
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

    await scrollToTreeWorkspace(tester);
    await tester.tap(
      find.byKey(const Key('tree-node-info-member_demo_child_001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết thành viên'), findsOneWidget);
    expect(find.text('Bé Minh'), findsWidgets);
  });
}
