import 'package:flutter/foundation.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/firebase_services.dart';

abstract interface class MemberSearchAnalyticsService {
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
    required int resultCount,
  });

  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  });

  Future<void> trackFiltersUpdated({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  });

  Future<void> trackRetryRequested({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  });

  Future<void> trackResultOpened({
    required String memberId,
    required String branchId,
    required int generation,
  });
}

class FirebaseMemberSearchAnalyticsService
    implements MemberSearchAnalyticsService {
  const FirebaseMemberSearchAnalyticsService();

  @override
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
    required int resultCount,
  }) {
    return FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.memberSearchSubmitted,
      parameters: {
        'query_length': queryLength,
        'has_branch_filter': hasBranchFilter ? 1 : 0,
        'has_generation_filter': hasGenerationFilter ? 1 : 0,
        'result_count': resultCount,
      },
    );
  }

  @override
  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) {
    return FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.memberSearchFailed,
      parameters: {
        'query_length': queryLength,
        'has_branch_filter': hasBranchFilter ? 1 : 0,
        'has_generation_filter': hasGenerationFilter ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackFiltersUpdated({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) {
    return FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.memberSearchFiltersUpdated,
      parameters: {
        'query_length': queryLength,
        'has_branch_filter': hasBranchFilter ? 1 : 0,
        'has_generation_filter': hasGenerationFilter ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackRetryRequested({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) {
    return FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.memberSearchRetryRequested,
      parameters: {
        'query_length': queryLength,
        'has_branch_filter': hasBranchFilter ? 1 : 0,
        'has_generation_filter': hasGenerationFilter ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackResultOpened({
    required String memberId,
    required String branchId,
    required int generation,
  }) {
    return FirebaseServices.analytics.logEvent(
      name: AnalyticsEventNames.memberSearchResultOpened,
      parameters: {
        'member_id': memberId,
        'branch_id': branchId,
        'generation': generation,
      },
    );
  }
}

class NoopMemberSearchAnalyticsService implements MemberSearchAnalyticsService {
  const NoopMemberSearchAnalyticsService();

  @override
  Future<void> trackFiltersUpdated({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {}

  @override
  Future<void> trackResultOpened({
    required String memberId,
    required String branchId,
    required int generation,
  }) async {}

  @override
  Future<void> trackRetryRequested({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {}

  @override
  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {}

  @override
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
    required int resultCount,
  }) async {}
}

MemberSearchAnalyticsService createDefaultMemberSearchAnalyticsService() {
  if (kDebugMode) {
    return const NoopMemberSearchAnalyticsService();
  }
  return const FirebaseMemberSearchAnalyticsService();
}
