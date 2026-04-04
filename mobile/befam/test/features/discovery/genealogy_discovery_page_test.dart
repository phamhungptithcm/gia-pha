import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/ads/services/rewarded_discovery_attempt_service.dart';
import 'package:befam/features/discovery/presentation/genealogy_discovery_page.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_analytics_service.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_repository.dart';
import 'package:befam/features/discovery/models/genealogy_discovery_result.dart';
import 'package:befam/features/discovery/models/join_request_draft.dart';
import 'package:befam/features/discovery/models/join_request_review_item.dart';
import 'package:befam/features/discovery/models/my_join_request_item.dart';
import 'package:befam/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/features/discovery/services/debug_genealogy_discovery_repository.dart';

void main() {
  void setDiscoveryViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
  }

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
    GenealogyDiscoveryRepository? repository,
    RewardedDiscoveryAttemptService? rewardedDiscoveryAttemptService,
  }) async {
    setDiscoveryViewport(tester);
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
          repository: repository ?? DebugGenealogyDiscoveryRepository.seeded(),
          onAddGenealogyRequested: () async {},
          analyticsService: analyticsService,
          onboardingCoordinator: createDisabledOnboardingCoordinator(
            session: session,
          ),
          rewardedDiscoveryAttemptService: rewardedDiscoveryAttemptService,
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
    expect(find.text('Create a new genealogy'), findsOneWidget);
    expect(find.text('Nguyễn tộc miền Trung'), findsOneWidget);
  });

  testWidgets('tracks join request submit flow', (tester) async {
    final analytics = _RecordingGenealogyDiscoveryAnalyticsService();

    await pumpPage(tester, analyticsService: analytics);

    expect(analytics.searchSubmitted.single['source'], 'initial');

    final requestToJoinButton = find.widgetWithText(
      FilledButton,
      'Request to join',
    );
    await _tapVisibleButton(tester, requestToJoinButton);
    await _pumpInteraction(tester);

    expect(analytics.sheetOpened.single['clan_id'], 'clan_demo_001');

    final submitRequestButton = find.widgetWithText(
      FilledButton,
      'Submit request',
    );
    await _tapVisibleButton(tester, submitRequestButton);
    await _pumpInteraction(tester);

    expect(analytics.submitted.single['clan_id'], 'clan_demo_001');
    expect(analytics.submitted.single['has_member_link'], 0);
  });

  testWidgets('tracks join request sheet dismissals', (tester) async {
    final analytics = _RecordingGenealogyDiscoveryAnalyticsService();

    await pumpPage(tester, analyticsService: analytics);

    final requestToJoinButton = find.widgetWithText(
      FilledButton,
      'Request to join',
    );
    await _tapVisibleButton(tester, requestToJoinButton);
    await _pumpInteraction(tester);
    final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel');
    await _tapVisibleButton(
      tester,
      cancelButton,
      scrollable: find.byType(Scrollable).last,
    );
    await _pumpInteraction(tester);

    expect(analytics.sheetDismissed.single['clan_id'], 'clan_demo_001');
    expect(analytics.sheetDismissed.single['dismissal_reason'], 'cta_cancel');
  });

  testWidgets('rewarded ad unlocks one extra discovery search attempt', (
    tester,
  ) async {
    final analytics = _RecordingGenealogyDiscoveryAnalyticsService();
    final repository = _CountingDiscoveryRepository();
    final rewardedService = _FakeRewardedDiscoveryAttemptService();

    await pumpPage(
      tester,
      analyticsService: analytics,
      repository: repository,
      rewardedDiscoveryAttemptService: rewardedService,
    );

    expect(repository.searchCallCount, 1);

    await tester.tap(find.byKey(const Key('discovery-search-button')));
    await _pumpInteraction(tester);
    expect(repository.searchCallCount, 2);

    await tester.tap(find.byKey(const Key('discovery-search-button')));
    await _pumpInteraction(tester);
    expect(find.text('Unlock an extra discovery attempt?'), findsOneWidget);

    await tester.tap(find.text('Watch ad'));
    await _pumpInteraction(tester);
    await tester.pumpAndSettle();

    expect(rewardedService.showCallCount, 1);
    expect(repository.searchCallCount, 3);
    expect(analytics.rewardUnlocked.single['extra_searches_granted'], 1);
  });
}

Future<void> _pumpInteraction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapVisibleButton(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  final target = finder.first;
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: scrollable ?? find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.tap(target, warnIfMissed: false);
}

class _RecordingGenealogyDiscoveryAnalyticsService
    implements GenealogyDiscoveryAnalyticsService {
  final List<Map<String, Object>> attemptLimitReached = <Map<String, Object>>[];
  final List<Map<String, Object>> canceled = <Map<String, Object>>[];
  final List<Map<String, Object>> rewardPromptOpened = <Map<String, Object>>[];
  final List<Map<String, Object>> rewardPromptDismissed =
      <Map<String, Object>>[];
  final List<Map<String, Object>> rewardUnlocked = <Map<String, Object>>[];
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
  Future<void> trackAttemptLimitReached({
    required int freeSearchesPerSession,
    required int manualSearchesUsed,
    required int rewardedUnlocksUsed,
    required bool canOfferReward,
  }) async {
    attemptLimitReached.add(<String, Object>{
      'free_searches_per_session': freeSearchesPerSession,
      'manual_searches_used': manualSearchesUsed,
      'rewarded_unlocks_used': rewardedUnlocksUsed,
      'can_offer_reward': canOfferReward ? 1 : 0,
    });
  }

  @override
  Future<void> trackRewardPromptOpened({
    required int freeSearchesPerSession,
    required int rewardedUnlocksUsed,
  }) async {
    rewardPromptOpened.add(<String, Object>{
      'free_searches_per_session': freeSearchesPerSession,
      'rewarded_unlocks_used': rewardedUnlocksUsed,
    });
  }

  @override
  Future<void> trackRewardPromptDismissed({required String reason}) async {
    rewardPromptDismissed.add(<String, Object>{'reason': reason});
  }

  @override
  Future<void> trackRewardUnlocked({
    required int rewardedUnlocksUsed,
    required int extraSearchesGranted,
  }) async {
    rewardUnlocked.add(<String, Object>{
      'rewarded_unlocks_used': rewardedUnlocksUsed,
      'extra_searches_granted': extraSearchesGranted,
    });
  }

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

class _FakeRewardedDiscoveryAttemptService
    implements RewardedDiscoveryAttemptService {
  int showCallCount = 0;

  @override
  int get extraSearchesPerReward => 1;

  @override
  int get freeSearchesPerSession => 1;

  @override
  bool get isRewardedDiscoveryEnabled => true;

  @override
  int get maxUnlocksPerSession => 1;

  @override
  Future<void> primeRewardedDiscoveryAttempt() async {}

  @override
  Future<RewardedDiscoveryAttemptResult> unlockExtraDiscoveryAttempt({
    required String screenId,
    required String placementId,
  }) async {
    showCallCount += 1;
    return RewardedDiscoveryAttemptResult.granted;
  }
}

class _CountingDiscoveryRepository implements GenealogyDiscoveryRepository {
  int searchCallCount = 0;

  @override
  bool get isSandbox => true;

  @override
  Future<void> cancelJoinRequest({
    required AuthSession session,
    required String requestId,
  }) async {}

  @override
  Future<List<MyJoinRequestItem>> loadMyJoinRequests({
    required AuthSession session,
  }) async {
    return const [];
  }

  @override
  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  }) async {
    return const [];
  }

  @override
  Future<void> reviewJoinRequest({
    required AuthSession session,
    required String requestId,
    required bool approve,
    String? note,
  }) async {}

  @override
  Future<List<GenealogyDiscoveryResult>> search({
    String? query,
    String? leaderQuery,
    String? locationQuery,
    int limit = 20,
  }) async {
    searchCallCount += 1;
    return const [
      GenealogyDiscoveryResult(
        id: 'clan_demo_001',
        clanId: 'clan_demo_001',
        genealogyName: 'Nguyễn tộc miền Trung',
        leaderName: 'Nguyễn Minh',
        provinceCity: 'Đà Nẵng',
        summary: 'Gia phả mẫu với dữ liệu nhiều thế hệ để kiểm thử UI.',
        memberCount: 34,
        branchCount: 6,
      ),
    ];
  }

  @override
  Future<void> submitJoinRequest({required JoinRequestDraft draft}) async {}
}
