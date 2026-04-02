import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/discovery/presentation/genealogy_discovery_page.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_analytics_service.dart';
import 'package:befam/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/features/discovery/services/debug_genealogy_discovery_repository.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901230000',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901230000',
      displayName: 'Nguyen An',
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 2).toIso8601String(),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    GenealogyDiscoveryAnalyticsService? analyticsService,
  }) async {
    final session = buildSession();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: GenealogyDiscoveryPage(
          session: session,
          repository: DebugGenealogyDiscoveryRepository.seeded(),
          onAddGenealogyRequested: () async {},
          analyticsService: analyticsService,
          onboardingCoordinator: createDisabledOnboardingCoordinator(
            session: session,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders discovery search controls and add action', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('discovery-query-input')), findsOneWidget);
    expect(find.byKey(const Key('discovery-search-button')), findsOneWidget);
    expect(find.byKey(const Key('discovery-add-fab')), findsOneWidget);
    expect(find.text('Nguyễn tộc miền Trung'), findsOneWidget);
  });

  testWidgets('tracks join request submit flow', (tester) async {
    final analytics = _RecordingGenealogyDiscoveryAnalyticsService();

    await pumpPage(tester, analyticsService: analytics);

    expect(analytics.searchSubmitted.single['source'], 'initial');

    await tester.tap(find.text('Request to join').first);
    await _pumpInteraction(tester);

    expect(analytics.sheetOpened.single['clan_id'], 'clan_demo_001');

    await tester.tap(find.text('Submit request'));
    await _pumpInteraction(tester);

    expect(analytics.submitted.single['clan_id'], 'clan_demo_001');
    expect(analytics.submitted.single['has_member_link'], 0);
  });

  testWidgets('tracks join request sheet dismissals', (tester) async {
    final analytics = _RecordingGenealogyDiscoveryAnalyticsService();

    await pumpPage(tester, analyticsService: analytics);

    await tester.tap(find.text('Request to join').first);
    await _pumpInteraction(tester);
    await tester.tap(find.text('Cancel'));
    await _pumpInteraction(tester);

    expect(analytics.sheetDismissed.single['clan_id'], 'clan_demo_001');
    expect(analytics.sheetDismissed.single['dismissal_reason'], 'cta_cancel');
  });
}

Future<void> _pumpInteraction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _RecordingGenealogyDiscoveryAnalyticsService
    implements GenealogyDiscoveryAnalyticsService {
  final List<Map<String, Object>> canceled = <Map<String, Object>>[];
  final List<Map<String, Object>> searchSubmitted = <Map<String, Object>>[];
  final List<Map<String, Object>> sheetDismissed = <Map<String, Object>>[];
  final List<Map<String, Object>> sheetOpened = <Map<String, Object>>[];
  final List<Map<String, Object>> submitted = <Map<String, Object>>[];

  @override
  Future<void> trackJoinRequestCancelFailed({
    required String clanId,
    required String source,
  }) async {}

  @override
  Future<void> trackJoinRequestCanceled({
    required String clanId,
    required String source,
  }) async {
    canceled.add(<String, Object>{'clan_id': clanId, 'source': source});
  }

  @override
  Future<void> trackJoinRequestDuplicateBlocked({
    required String clanId,
  }) async {}

  @override
  Future<void> trackJoinRequestReviewFailed({
    required String clanId,
    required String decision,
  }) async {}

  @override
  Future<void> trackJoinRequestReviewSubmitted({
    required String clanId,
    required String decision,
  }) async {}

  @override
  Future<void> trackJoinRequestSheetDismissed({
    required String clanId,
    required String dismissalReason,
  }) async {
    sheetDismissed.add(<String, Object>{
      'clan_id': clanId,
      'dismissal_reason': dismissalReason,
    });
  }

  @override
  Future<void> trackJoinRequestSheetOpened({
    required String clanId,
    required bool hasMemberLink,
  }) async {
    sheetOpened.add(<String, Object>{
      'clan_id': clanId,
      'has_member_link': hasMemberLink ? 1 : 0,
    });
  }

  @override
  Future<void> trackJoinRequestSubmitFailed({
    required String clanId,
    required String reason,
  }) async {}

  @override
  Future<void> trackJoinRequestSubmitted({
    required String clanId,
    required bool hasMessage,
    required bool hasMemberLink,
  }) async {
    submitted.add(<String, Object>{
      'clan_id': clanId,
      'has_message': hasMessage ? 1 : 0,
      'has_member_link': hasMemberLink ? 1 : 0,
    });
  }

  @override
  Future<void> trackMyJoinRequestsOpened({
    required int totalCount,
    required int pendingCount,
  }) async {}

  @override
  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required String source,
  }) async {}

  @override
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required int resultCount,
    required String source,
  }) async {
    searchSubmitted.add(<String, Object>{
      'query_length': queryLength,
      'has_leader_filter': hasLeaderFilter ? 1 : 0,
      'has_location_filter': hasLocationFilter ? 1 : 0,
      'result_count': resultCount,
      'source': source,
    });
  }
}
