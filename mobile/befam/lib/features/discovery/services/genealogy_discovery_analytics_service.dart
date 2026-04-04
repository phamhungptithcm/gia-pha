import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';

abstract interface class GenealogyDiscoveryAnalyticsService {
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required int resultCount,
    required String source,
  });

  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required String source,
  });

  Future<void> trackAttemptLimitReached({
    required int freeSearchesPerSession,
    required int manualSearchesUsed,
    required int rewardedUnlocksUsed,
    required bool canOfferReward,
  });

  Future<void> trackRewardPromptOpened({
    required int freeSearchesPerSession,
    required int rewardedUnlocksUsed,
  });

  Future<void> trackRewardPromptDismissed({required String reason});

  Future<void> trackRewardUnlocked({
    required int rewardedUnlocksUsed,
    required int extraSearchesGranted,
  });

  Future<void> trackMyJoinRequestsOpened({
    required int totalCount,
    required int pendingCount,
  });

  Future<void> trackJoinRequestSheetOpened({
    required String clanId,
    required bool hasMemberLink,
  });

  Future<void> trackJoinRequestSheetDismissed({
    required String clanId,
    required String dismissalReason,
  });

  Future<void> trackJoinRequestDuplicateBlocked({required String clanId});

  Future<void> trackJoinRequestSubmitted({
    required String clanId,
    required bool hasMessage,
    required bool hasMemberLink,
  });

  Future<void> trackJoinRequestSubmitFailed({
    required String clanId,
    required String reason,
  });

  Future<void> trackJoinRequestCanceled({
    required String clanId,
    required String source,
  });

  Future<void> trackJoinRequestCancelFailed({
    required String clanId,
    required String source,
  });

  Future<void> trackJoinRequestReviewSubmitted({
    required String clanId,
    required String decision,
  });

  Future<void> trackJoinRequestReviewFailed({
    required String clanId,
    required String decision,
  });
}

class NoopGenealogyDiscoveryAnalyticsService
    implements GenealogyDiscoveryAnalyticsService {
  const NoopGenealogyDiscoveryAnalyticsService();

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
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required int resultCount,
    required String source,
  }) async {}
}

class FirebaseGenealogyDiscoveryAnalyticsService
    implements GenealogyDiscoveryAnalyticsService {
  const FirebaseGenealogyDiscoveryAnalyticsService();

  @override
  Future<void> trackJoinRequestCancelFailed({
    required String clanId,
    required String source,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestCancelFailed,
      <String, Object>{'clan_id': clanId, 'source': source},
    );
  }

  @override
  Future<void> trackJoinRequestCanceled({
    required String clanId,
    required String source,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestCanceled,
      <String, Object>{'clan_id': clanId, 'source': source},
    );
  }

  @override
  Future<void> trackJoinRequestDuplicateBlocked({required String clanId}) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestDuplicateBlocked,
      <String, Object>{'clan_id': clanId},
    );
  }

  @override
  Future<void> trackJoinRequestReviewFailed({
    required String clanId,
    required String decision,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestReviewFailed,
      <String, Object>{'clan_id': clanId, 'decision': decision},
    );
  }

  @override
  Future<void> trackJoinRequestReviewSubmitted({
    required String clanId,
    required String decision,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestReviewSubmitted,
      <String, Object>{'clan_id': clanId, 'decision': decision},
    );
  }

  @override
  Future<void> trackJoinRequestSheetDismissed({
    required String clanId,
    required String dismissalReason,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestSheetDismissed,
      <String, Object>{'clan_id': clanId, 'dismissal_reason': dismissalReason},
    );
  }

  @override
  Future<void> trackJoinRequestSheetOpened({
    required String clanId,
    required bool hasMemberLink,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestSheetOpened,
      <String, Object>{
        'clan_id': clanId,
        'has_member_link': hasMemberLink ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackJoinRequestSubmitFailed({
    required String clanId,
    required String reason,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestSubmitFailed,
      <String, Object>{'clan_id': clanId, 'reason': reason},
    );
  }

  @override
  Future<void> trackJoinRequestSubmitted({
    required String clanId,
    required bool hasMessage,
    required bool hasMemberLink,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyJoinRequestSubmitted,
      <String, Object>{
        'clan_id': clanId,
        'has_message': hasMessage ? 1 : 0,
        'has_member_link': hasMemberLink ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackMyJoinRequestsOpened({
    required int totalCount,
    required int pendingCount,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyMyJoinRequestsOpened,
      <String, Object>{
        'total_count': totalCount,
        'pending_count': pendingCount,
      },
    );
  }

  @override
  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required String source,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoverySearchFailed,
      <String, Object>{
        'query_length': queryLength,
        'has_leader_filter': hasLeaderFilter ? 1 : 0,
        'has_location_filter': hasLocationFilter ? 1 : 0,
        'source': source,
      },
    );
  }

  @override
  Future<void> trackAttemptLimitReached({
    required int freeSearchesPerSession,
    required int manualSearchesUsed,
    required int rewardedUnlocksUsed,
    required bool canOfferReward,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoveryAttemptLimitReached,
      <String, Object>{
        'free_searches_per_session': freeSearchesPerSession,
        'manual_searches_used': manualSearchesUsed,
        'rewarded_unlocks_used': rewardedUnlocksUsed,
        'can_offer_reward': canOfferReward ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackRewardPromptOpened({
    required int freeSearchesPerSession,
    required int rewardedUnlocksUsed,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoveryRewardPromptOpened,
      <String, Object>{
        'free_searches_per_session': freeSearchesPerSession,
        'rewarded_unlocks_used': rewardedUnlocksUsed,
      },
    );
  }

  @override
  Future<void> trackRewardPromptDismissed({required String reason}) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoveryRewardPromptDismissed,
      <String, Object>{'reason': reason},
    );
  }

  @override
  Future<void> trackRewardUnlocked({
    required int rewardedUnlocksUsed,
    required int extraSearchesGranted,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoveryRewardUnlocked,
      <String, Object>{
        'rewarded_unlocks_used': rewardedUnlocksUsed,
        'extra_searches_granted': extraSearchesGranted,
      },
    );
  }

  @override
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasLeaderFilter,
    required bool hasLocationFilter,
    required int resultCount,
    required String source,
  }) {
    return _logEvent(
      AnalyticsEventNames.genealogyDiscoverySearchSubmitted,
      <String, Object>{
        'query_length': queryLength,
        'has_leader_filter': hasLeaderFilter ? 1 : 0,
        'has_location_filter': hasLocationFilter ? 1 : 0,
        'result_count': resultCount,
        'source': source,
      },
    );
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      await FirebaseServices.analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Discovery analytics event failed for $name.',
        error,
        stackTrace,
      );
    }
  }
}

GenealogyDiscoveryAnalyticsService
createDefaultGenealogyDiscoveryAnalyticsService() {
  if (Firebase.apps.isEmpty) {
    return const NoopGenealogyDiscoveryAnalyticsService();
  }
  return const FirebaseGenealogyDiscoveryAnalyticsService();
}
