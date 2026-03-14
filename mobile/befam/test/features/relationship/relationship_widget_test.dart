import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/relationship/presentation/relationship_inspector_panel.dart';
import 'package:befam/features/relationship/services/debug_relationship_repository.dart';
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

  testWidgets('adds a spouse relationship from the inspector panel', (
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
              onRelationshipsChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quan hệ gia đình'), findsOneWidget);
    expect(find.text('Bé Minh'), findsWidgets);

    await tester.tap(find.byKey(const Key('relationship-add-spouse-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('relationship-candidate-member_demo_parent_002')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đã thêm liên kết hôn phối.'), findsOneWidget);
    expect(find.text('Trần Lan'), findsWidgets);
    expect(
      find.byKey(
        const Key(
          'relationship-record-rel_spouse_member_demo_parent_001_member_demo_parent_002',
        ),
      ),
      findsOneWidget,
    );
  });
}
