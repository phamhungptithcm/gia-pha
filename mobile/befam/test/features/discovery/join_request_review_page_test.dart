import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/discovery/models/genealogy_discovery_result.dart';
import 'package:befam/features/discovery/models/join_request_draft.dart';
import 'package:befam/features/discovery/models/join_request_review_item.dart';
import 'package:befam/features/discovery/models/my_join_request_item.dart';
import 'package:befam/features/discovery/presentation/join_request_review_page.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_analytics_service.dart';
import 'package:befam/features/discovery/services/genealogy_discovery_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'reviewer:+84901230000',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901230000',
      displayName: 'Clan reviewer',
      memberId: 'member_reviewer_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
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
        home: JoinRequestReviewPage(
          session: buildSession(),
          repository: repository,
          analyticsService: analyticsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tracks approve review decisions', (tester) async {
    final repository = _ReviewRepository();
    final analytics = _ReviewAnalyticsService();

    await pumpPage(tester, repository: repository, analyticsService: analytics);

    expect(find.text('Nguyễn An'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(repository.decisions.single, 'approve');
    expect(analytics.reviewSubmitted.single['clan_id'], 'clan_demo_001');
    expect(analytics.reviewSubmitted.single['decision'], 'approve');
  });
}

class _ReviewAnalyticsService implements GenealogyDiscoveryAnalyticsService {
  final List<Map<String, Object>> reviewSubmitted = <Map<String, Object>>[];

  @override
  Future<void> trackJoinRequestCancelFailed({
    required String clanId,
    required String source,
  }) async {}

  @override
  Future<void> trackJoinRequestCanceled({
    required String clanId,
    required String source,
  }) async {}

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
  }) async {
    reviewSubmitted.add(<String, Object>{
      'clan_id': clanId,
      'decision': decision,
    });
  }

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
  }) async {}

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

class _ReviewRepository implements GenealogyDiscoveryRepository {
  final List<String> decisions = <String>[];

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
    return const <MyJoinRequestItem>[];
  }

  @override
  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  }) async {
    return const <JoinRequestReviewItem>[
      JoinRequestReviewItem(
        id: 'request_demo_001',
        clanId: 'clan_demo_001',
        status: 'pending',
        applicantName: 'Nguyễn An',
        relationshipToFamily: 'Descendant',
        contactInfo: '+84901112233',
        message: 'Please help me join the verified tree.',
      ),
    ];
  }

  @override
  Future<void> reviewJoinRequest({
    required AuthSession session,
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    decisions.add(approve ? 'approve' : 'reject');
  }

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
