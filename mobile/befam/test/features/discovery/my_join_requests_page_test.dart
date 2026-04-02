import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/discovery/models/genealogy_discovery_result.dart';
import 'package:befam/features/discovery/models/join_request_draft.dart';
import 'package:befam/features/discovery/models/join_request_review_item.dart';
import 'package:befam/features/discovery/models/my_join_request_item.dart';
import 'package:befam/features/discovery/presentation/my_join_requests_page.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_analytics_service.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'member:+84901230000',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901230000',
      displayName: 'Nguyen An',
      memberId: 'member_demo_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 4, 2).toIso8601String(),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required GenealogyDiscoveryRepository repository,
    GenealogyDiscoveryAnalyticsService? analyticsService,
  }) async {
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
        home: MyJoinRequestsPage(
          session: buildSession(),
          repository: repository,
          analyticsService: analyticsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tracks my requests open and cancel flow', (tester) async {
    final repository = _MyJoinRequestsRepository();
    final analytics = _MyJoinRequestsAnalyticsService();

    await pumpPage(tester, repository: repository, analyticsService: analytics);

    expect(find.text('Requested genealogy'), findsOneWidget);
    expect(analytics.opened.single['pending_count'], 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
    await tester.pumpAndSettle();

    expect(repository.canceledRequestIds.single, 'request_demo_001');
    expect(analytics.canceled.single['clan_id'], 'clan_demo_001');
    expect(analytics.canceled.single['source'], 'my_requests_page');
  });
}

class _MyJoinRequestsAnalyticsService
    implements GenealogyDiscoveryAnalyticsService {
  final List<Map<String, Object>> canceled = <Map<String, Object>>[];
  final List<Map<String, Object>> opened = <Map<String, Object>>[];

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
  }) async {}

  @override
  Future<void> trackJoinRequestSheetOpened({
    required String clanId,
    required bool hasMemberLink,
  }) async {}

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
  }) async {}

  @override
  Future<void> trackMyJoinRequestsOpened({
    required int totalCount,
    required int pendingCount,
  }) async {
    opened.add(<String, Object>{
      'total_count': totalCount,
      'pending_count': pendingCount,
    });
  }

  @override
  Future<void> trackAttemptLimitReached({
    required int freeSearchesPerSession,
    required int manualSearchesUsed,
    required int rewardedUnlocksUsed,
    required bool canOfferReward,
  }) async {}

  @override
  Future<void> trackRewardPromptOpened({
    required int freeSearchesPerSession,
    required int rewardedUnlocksUsed,
  }) async {}

  @override
  Future<void> trackRewardPromptDismissed({required String reason}) async {}

  @override
  Future<void> trackRewardUnlocked({
    required int rewardedUnlocksUsed,
    required int extraSearchesGranted,
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
  }) async {}
}

class _MyJoinRequestsRepository implements GenealogyDiscoveryRepository {
  final List<String> canceledRequestIds = <String>[];

  @override
  bool get isSandbox => true;

  @override
  Future<void> cancelJoinRequest({
    required AuthSession session,
    required String requestId,
  }) async {
    canceledRequestIds.add(requestId);
  }

  @override
  Future<List<MyJoinRequestItem>> loadMyJoinRequests({
    required AuthSession session,
  }) async {
    return const <MyJoinRequestItem>[
      MyJoinRequestItem(
        id: 'request_demo_001',
        clanId: 'clan_demo_001',
        genealogyName: 'Requested genealogy',
        status: 'pending',
        submittedAtEpochMs: 1712012345000,
        canCancel: true,
      ),
    ];
  }

  @override
  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  }) async {
    return const <JoinRequestReviewItem>[];
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
    return const <GenealogyDiscoveryResult>[];
  }

  @override
  Future<void> submitJoinRequest({required JoinRequestDraft draft}) async {}
}
