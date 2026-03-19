import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/relationship/presentation/relationship_inspector_panel.dart';
import '../../support/features/relationship/services/debug_relationship_repository.dart';
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
      displayName: 'Nguyễn Minh',
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

  testWidgets('renders relationship inspector in read-only mode', (
    tester,
  ) async {
    final store = DebugGenealogyStore.seeded();
    final relationshipRepository = DebugRelationshipRepository(store: store);
    final member = store.members['member_demo_parent_001']!;

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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RelationshipInspectorPanel(
              session: buildClanAdminSession(),
              member: member,
              members: store.members.values.toList(growable: false),
              repository: relationshipRepository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quan hệ gia đình'), findsOneWidget);
    expect(find.text('Cha/mẹ'), findsOneWidget);
    expect(find.text('Con'), findsOneWidget);
    expect(find.text('Vợ/chồng'), findsOneWidget);
    expect(find.text('Bé Minh'), findsWidgets);
    expect(
      find.byKey(const Key('relationship-add-parent-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('relationship-add-child-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('relationship-add-spouse-button')),
      findsNothing,
    );
  });

  testWidgets(
    'opens linked member detail callback when tapping relation chip',
    (tester) async {
      final store = DebugGenealogyStore.seeded();
      final relationshipRepository = DebugRelationshipRepository(store: store);
      final member = store.members['member_demo_parent_001']!;
      final linkedMember = store.members.values.firstWhere(
        (entry) => entry.fullName == 'Bé Minh',
      );
      String? openedMemberId;

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
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RelationshipInspectorPanel(
                session: buildClanAdminSession(),
                member: member,
                members: store.members.values.toList(growable: false),
                repository: relationshipRepository,
                onOpenMemberDetail: (selected) {
                  openedMemberId = selected.id;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Bé Minh').first);
      await tester.pump();

      expect(openedMemberId, linkedMember.id);
    },
  );
}
