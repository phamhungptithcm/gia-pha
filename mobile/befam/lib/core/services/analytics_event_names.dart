abstract final class AnalyticsEventNames {
  static const authMethodSelected = 'auth_method_selected';
  static const authOtpRequested = 'auth_otp_requested';
  static const authChildContextResolved = 'auth_child_context_resolved';
  static const authSessionEstablished = 'auth_session_established';
  static const authFailure = 'auth_failure';
  static const authLogout = 'auth_logout';

  static const memberSearchSubmitted = 'member_search_submit';
  static const memberSearchFailed = 'member_search_failed';
  static const memberSearchFiltersUpdated = 'member_search_filters_updated';
  static const memberSearchRetryRequested = 'member_search_retry';
  static const memberSearchResultOpened = 'member_search_open_result';
  static const genealogyDiscoverySearchSubmitted =
      'genealogy_discovery_search_submitted';
  static const genealogyDiscoverySearchFailed =
      'genealogy_discovery_search_failed';
  static const genealogyMyJoinRequestsOpened =
      'genealogy_my_join_requests_opened';
  static const genealogyJoinRequestSheetOpened =
      'genealogy_join_request_sheet_opened';
  static const genealogyJoinRequestSheetDismissed =
      'genealogy_join_request_sheet_dismissed';
  static const genealogyJoinRequestDuplicateBlocked =
      'genealogy_join_request_duplicate_blocked';
  static const genealogyJoinRequestSubmitted =
      'genealogy_join_request_submitted';
  static const genealogyJoinRequestSubmitFailed =
      'genealogy_join_request_submit_failed';
  static const genealogyJoinRequestCanceled = 'genealogy_join_request_canceled';
  static const genealogyJoinRequestCancelFailed =
      'genealogy_join_request_cancel_failed';
  static const genealogyJoinRequestReviewSubmitted =
      'genealogy_join_request_review_submitted';
  static const genealogyJoinRequestReviewFailed =
      'genealogy_join_request_review_failed';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';
  static const onboardingInterrupted = 'onboarding_interrupted';
  static const onboardingAnchorMissing = 'onboarding_anchor_missing';
  static const webMarketingCtaClick = 'web_marketing_cta_click';
  static const adOpportunity = 'ad_opportunity';
  static const adRequested = 'ad_requested';
  static const adLoaded = 'ad_loaded';
  static const adFailed = 'ad_failed';
  static const adShown = 'ad_shown';
  static const adDismissed = 'ad_dismissed';
  static const adPaidEvent = 'ad_paid_event';
  static const adRewardEarned = 'ad_reward_earned';
  static const screenAfterAd = 'screen_after_ad';
  static const sessionExitAfterAd = 'session_exit_after_ad';
  static const premiumIntentMarked = 'premium_intent_marked';
  static const premiumPurchaseAfterAdExposure =
      'premium_purchase_after_ad_exposure';
  static const genealogyDiscoveryAttemptLimitReached =
      'genealogy_discovery_attempt_limit_reached';
  static const genealogyDiscoveryRewardPromptOpened =
      'genealogy_discovery_reward_prompt_opened';
  static const genealogyDiscoveryRewardPromptDismissed =
      'genealogy_discovery_reward_prompt_dismissed';
  static const genealogyDiscoveryRewardUnlocked =
      'genealogy_discovery_reward_unlocked';
  static const aiProfileCheckRequested = 'ai_profile_check_requested';
  static const aiProfileCheckCompleted = 'ai_profile_check_completed';
  static const aiProfileCheckFailed = 'ai_profile_check_failed';
  static const aiProfileQuickFixSelected = 'ai_profile_quick_fix_selected';
  static const aiEventSuggestionRequested = 'ai_event_suggestion_requested';
  static const aiEventSuggestionCompleted = 'ai_event_suggestion_completed';
  static const aiEventSuggestionFailed = 'ai_event_suggestion_failed';
  static const aiEventSuggestionApplied = 'ai_event_suggestion_applied';
  static const aiDuplicateReviewOpened = 'ai_duplicate_review_opened';
  static const aiDuplicateReviewDecision = 'ai_duplicate_review_decision';
  static const aiAssistantOpened = 'ai_assistant_opened';
  static const aiAssistantQuerySubmitted = 'ai_assistant_query_submitted';
  static const aiAssistantQueryCompleted = 'ai_assistant_query_completed';
  static const aiAssistantQueryFailed = 'ai_assistant_query_failed';
  static const aiAssistantDestinationOpened = 'ai_assistant_destination_opened';

  static const values = <String>[
    authMethodSelected,
    authOtpRequested,
    authChildContextResolved,
    authSessionEstablished,
    authFailure,
    authLogout,
    memberSearchSubmitted,
    memberSearchFailed,
    memberSearchFiltersUpdated,
    memberSearchRetryRequested,
    memberSearchResultOpened,
    genealogyDiscoverySearchSubmitted,
    genealogyDiscoverySearchFailed,
    genealogyMyJoinRequestsOpened,
    genealogyJoinRequestSheetOpened,
    genealogyJoinRequestSheetDismissed,
    genealogyJoinRequestDuplicateBlocked,
    genealogyJoinRequestSubmitted,
    genealogyJoinRequestSubmitFailed,
    genealogyJoinRequestCanceled,
    genealogyJoinRequestCancelFailed,
    genealogyJoinRequestReviewSubmitted,
    genealogyJoinRequestReviewFailed,
    onboardingStarted,
    onboardingStepViewed,
    onboardingCompleted,
    onboardingSkipped,
    onboardingInterrupted,
    onboardingAnchorMissing,
    webMarketingCtaClick,
    adOpportunity,
    adRequested,
    adLoaded,
    adFailed,
    adShown,
    adDismissed,
    adPaidEvent,
    adRewardEarned,
    screenAfterAd,
    sessionExitAfterAd,
    premiumIntentMarked,
    premiumPurchaseAfterAdExposure,
    genealogyDiscoveryAttemptLimitReached,
    genealogyDiscoveryRewardPromptOpened,
    genealogyDiscoveryRewardPromptDismissed,
    genealogyDiscoveryRewardUnlocked,
    aiProfileCheckRequested,
    aiProfileCheckCompleted,
    aiProfileCheckFailed,
    aiProfileQuickFixSelected,
    aiEventSuggestionRequested,
    aiEventSuggestionCompleted,
    aiEventSuggestionFailed,
    aiEventSuggestionApplied,
    aiDuplicateReviewOpened,
    aiDuplicateReviewDecision,
    aiAssistantOpened,
    aiAssistantQuerySubmitted,
    aiAssistantQueryCompleted,
    aiAssistantQueryFailed,
    aiAssistantDestinationOpened,
  ];
}

abstract final class AnalyticsUserPropertyNames {
  static const authMethod = 'auth_method';
  static const memberAccessMode = 'member_access_mode';
  static const adSegment = 'ad_segment';
  static const subscriptionTier = 'subscription_tier';
  static const adsPolicyVersion = 'ads_policy_version';

  static const values = <String>[
    authMethod,
    memberAccessMode,
    adSegment,
    subscriptionTier,
    adsPolicyVersion,
  ];
}
