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
  static const webMarketingCtaClick = 'web_marketing_cta_click';

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
    webMarketingCtaClick,
  ];
}

abstract final class AnalyticsUserPropertyNames {
  static const authMethod = 'auth_method';
  static const memberAccessMode = 'member_access_mode';

  static const values = <String>[authMethod, memberAccessMode];
}
