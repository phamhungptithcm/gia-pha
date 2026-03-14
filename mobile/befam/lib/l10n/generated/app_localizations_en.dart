// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BeFam';

  @override
  String get authSignInNeedsAttention => 'Sign-in needs attention';

  @override
  String get authLoadingTitle => 'Preparing your BeFam session';

  @override
  String get authLoadingReadyDescription =>
      'Firebase is ready. BeFam is restoring the last signed-in session now.';

  @override
  String get authLoadingPendingDescription =>
      'BeFam is still checking Firebase readiness on this device.';

  @override
  String get authFirebaseReadyChip => 'Firebase ready';

  @override
  String get authBootstrapPendingChip => 'Bootstrap pending';

  @override
  String get authSandboxChip => 'Debug auth sandbox';

  @override
  String get authLiveFirebaseChip => 'Live Firebase auth';

  @override
  String get authHeroTitle => 'Authentication is the next BeFam milestone.';

  @override
  String get authHeroSandboxDescription =>
      'Local builds use a safe OTP sandbox so we can test phone and child access flows without waiting on real SMS infrastructure. Use OTP 123456 for the demo flow.';

  @override
  String get authHeroLiveDescription =>
      'This build uses the live Firebase authentication path for phone verification and session restore.';

  @override
  String get authMethodPhoneTitle => 'Continue with phone';

  @override
  String get authMethodPhoneDescription =>
      'Use your own phone number to request an OTP and restore your BeFam identity.';

  @override
  String get authMethodPhoneButton => 'Use phone number';

  @override
  String get authMethodChildTitle => 'Continue with child ID';

  @override
  String get authMethodChildDescription =>
      'Start from a child identifier, resolve the linked parent phone, and verify access with OTP.';

  @override
  String get authMethodChildButton => 'Use child identifier';

  @override
  String get authBootstrapNoteTitle => 'Current bootstrap note';

  @override
  String get authBootstrapNoteReadySandbox =>
      'Firebase is ready and the debug auth sandbox is active for local UI testing.';

  @override
  String get authBootstrapNoteReadyLive =>
      'Firebase is ready and the app will attempt live phone authentication.';

  @override
  String get authBootstrapNotePending =>
      'Firebase startup still needs attention, so sign-in should stay in the sandbox until cloud setup is stable.';

  @override
  String get authPhoneHelperSandbox =>
      'Use the demo number below for quick local testing. BeFam can auto-fill the sandbox OTP on the next step.';

  @override
  String get authPhoneHelperLive =>
      'Use a Vietnamese local number or full international format. BeFam only uses it for secure sign-in.';

  @override
  String get authPhoneTitle => 'Phone verification';

  @override
  String get authPhoneDescription =>
      'Enter a phone number in local Vietnamese format or full E.164 format. BeFam will request an OTP from this number.';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authPhoneHint => '0901234567 or +84901234567';

  @override
  String get authPhoneDemoButton => 'Use demo number 0901234567';

  @override
  String get authSendOtp => 'Send OTP';

  @override
  String get authSendingOtp => 'Sending OTP...';

  @override
  String get authChildTitle => 'Child access';

  @override
  String get authChildDescription =>
      'Enter the family child identifier. BeFam will resolve the linked parent phone and request OTP verification there.';

  @override
  String get authChildLabel => 'Child identifier';

  @override
  String get authChildHint => 'BEFAM-CHILD-001';

  @override
  String get authChildHelper =>
      'Use the child access code shared by the family administrator.';

  @override
  String get authChildQuickTesting => 'Quick local testing identifiers';

  @override
  String get authContinue => 'Continue';

  @override
  String get authResolvingParentPhone => 'Resolving parent phone...';

  @override
  String get authOtpMissingTitle => 'OTP verification';

  @override
  String get authOtpMissingDescription =>
      'Request a new code before trying to verify access.';

  @override
  String get authOtpTitle => 'Verify the OTP';

  @override
  String authOtpDescription(Object maskedDestination) {
    return 'Enter the 6-digit code sent to $maskedDestination.';
  }

  @override
  String authOtpDebugCode(Object hint) {
    return 'Debug sandbox OTP: $hint';
  }

  @override
  String get authOtpAutofillDemo => 'Auto-fill demo code';

  @override
  String authOtpChildIdentifier(Object childIdentifier) {
    return 'Child identifier: $childIdentifier';
  }

  @override
  String get authContinueNow => 'Continue now';

  @override
  String get authVerifyingOtp => 'Verifying OTP...';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authResendOtp => 'Resend OTP';

  @override
  String get authOtpHelpText =>
      'Enter or paste the code. BeFam continues automatically after the sixth digit.';

  @override
  String get authQuickBenefitsTitle => 'Choose the easiest way to enter BeFam';

  @override
  String get authQuickBenefitsDescription =>
      'BeFam keeps sign-in short, guides users step by step, and automatically continues once the OTP is complete.';

  @override
  String get authQuickBenefitAutoContinue => '6-digit OTP auto-continues';

  @override
  String get authQuickBenefitMultipleAccess =>
      'Phone or child access supported';

  @override
  String get authQuickBenefitSandbox => 'Safe local sandbox testing';

  @override
  String get authQuickBenefitLive => 'Live Firebase verification';

  @override
  String get authBack => 'Back';

  @override
  String get authEntryMethodPhoneSummary => 'Phone login';

  @override
  String get authEntryMethodChildSummary => 'Child access';

  @override
  String get authEntryMethodPhoneInline => 'phone login';

  @override
  String get authEntryMethodChildInline => 'child access';

  @override
  String get shellHomeLabel => 'Home';

  @override
  String get shellHomeTitle => 'Bootstrap dashboard';

  @override
  String get shellTreeLabel => 'Tree';

  @override
  String get shellTreeTitle => 'Family tree';

  @override
  String get shellEventsLabel => 'Events';

  @override
  String get shellEventsTitle => 'Events';

  @override
  String get shellProfileLabel => 'Profile';

  @override
  String get shellProfileTitle => 'Profile';

  @override
  String get shellTreeWorkspaceTitle => 'Family tree workspace';

  @override
  String get shellTreeWorkspaceDescription =>
      'The shell is ready for the branch-first genealogy experience and large tree rendering work.';

  @override
  String get shellEventsWorkspaceTitle => 'Events workspace';

  @override
  String get shellEventsWorkspaceDescription =>
      'Calendar, memorial rituals, and reminder flows will land here next.';

  @override
  String get shellProfileWorkspaceTitle => 'Profile workspace';

  @override
  String get shellProfileWorkspaceDescription =>
      'Member identity, settings, and household context will grow from this placeholder.';

  @override
  String get shellMoreActions => 'More actions';

  @override
  String get shellLogout => 'Log out';

  @override
  String shellWelcomeBack(Object displayName) {
    return 'Welcome back, $displayName.';
  }

  @override
  String get shellBootstrapNeedsCloud =>
      'Bootstrap is wired, but Firebase still needs cloud setup.';

  @override
  String shellSignedInMethod(Object method) {
    return 'You are signed in through $method, and the BeFam shell is ready for the next feature teams.';
  }

  @override
  String get shellCloudSetupNeeded =>
      'The mobile foundation is ready locally. Cloud Firestore still needs to be enabled before backend deployment can finish.';

  @override
  String get shellTagFreezedJson => 'Freezed + JSON';

  @override
  String get shellTagFirebaseCore => 'Firebase core';

  @override
  String get shellTagAuthSessionLive => 'Auth session live';

  @override
  String get shellTagCrashlyticsEnabled => 'Crashlytics enabled';

  @override
  String get shellTagLocalLoggerActive => 'Local logger active';

  @override
  String get shellTagShellPlaceholders => 'Shell placeholders';

  @override
  String get shellPriorityWorkspaces => 'Priority workspaces';

  @override
  String get shellPriorityWorkspacesDescription =>
      'These placeholders match the first product surfaces described in the implementation plan.';

  @override
  String get shellSignedInContext => 'Signed-in context';

  @override
  String get shellFieldDisplayName => 'Display name';

  @override
  String get shellFieldLoginMethod => 'Login method';

  @override
  String get shellFieldPhone => 'Phone';

  @override
  String get shellFieldChildId => 'Child ID';

  @override
  String get shellFieldMemberId => 'Member ID';

  @override
  String get shellFieldSessionType => 'Session type';

  @override
  String get shellSessionTypeSandbox => 'Debug sandbox session';

  @override
  String get shellSessionTypeFirebase => 'Firebase auth session';

  @override
  String get shellFieldFirebaseProject => 'Firebase project';

  @override
  String get shellFieldStorageBucket => 'Storage bucket';

  @override
  String get shellFieldCrashHandling => 'Crash handling';

  @override
  String get shellCrashHandlingRelease =>
      'Crashlytics captures release crashes.';

  @override
  String get shellCrashHandlingLocal =>
      'Logger is active locally and Crashlytics stays off outside release mode.';

  @override
  String get shellFieldCoreServices => 'Core services';

  @override
  String get shellCoreServicesWaiting =>
      'Firebase core wiring is waiting on initialization.';

  @override
  String get shellFieldStartupNote => 'Startup note';

  @override
  String get shellShortcutStatusLive => 'Live';

  @override
  String get shellShortcutStatusBootstrap => 'Bootstrap';

  @override
  String get shellShortcutStatusPlanned => 'Planned';

  @override
  String get shellReadinessReady => 'Firebase ready';

  @override
  String get shellReadinessPending => 'Cloud setup pending';

  @override
  String get shortcutTitleTree => 'Family Tree';

  @override
  String get shortcutDescriptionTree =>
      'Start the genealogy experience with branch-aware tree navigation.';

  @override
  String get shortcutTitleMembers => 'Members';

  @override
  String get shortcutDescriptionMembers =>
      'View member profiles, claim records, and prepare the first data flows.';

  @override
  String get shortcutTitleEvents => 'Events';

  @override
  String get shortcutDescriptionEvents =>
      'Plan clan events, memorial days, and reminders from a shared calendar.';

  @override
  String get shortcutTitleFunds => 'Funds';

  @override
  String get shortcutDescriptionFunds =>
      'Track contribution funds, transaction history, and transparent balances.';

  @override
  String get shortcutTitleScholarship => 'Scholarships';

  @override
  String get shortcutDescriptionScholarship =>
      'Capture student achievements and later connect awards to family branches.';

  @override
  String get shortcutTitleProfile => 'Profile';

  @override
  String get shortcutDescriptionProfile =>
      'Reserve a personal space for member settings, guardianship, and context.';

  @override
  String get authIssueRestoreSessionFailed =>
      'We could not restore the last sign-in session.';

  @override
  String get authIssueRequestOtpBeforeVerify =>
      'Request an OTP before trying to verify it.';

  @override
  String get authIssueOtpMustBeSixDigits =>
      'Enter the 6-digit OTP to continue.';

  @override
  String get authIssuePhoneRequired => 'Enter your phone number to continue.';

  @override
  String get authIssuePhoneInvalidFormat =>
      'Enter a valid phone number with country code or local Vietnamese format.';

  @override
  String get authIssueChildIdentifierRequired =>
      'Enter a child identifier to continue.';

  @override
  String get authIssueChildIdentifierInvalid =>
      'Enter a valid child identifier with at least 4 characters.';

  @override
  String get authIssueInvalidPhoneNumber =>
      'Enter a valid phone number, including the country code if needed.';

  @override
  String get authIssueInvalidVerificationCode =>
      'That code does not match. Check the OTP and try again.';

  @override
  String get authIssueSessionExpired =>
      'The verification session expired. Request a new OTP to continue.';

  @override
  String get authIssueNetworkRequestFailed =>
      'Network connection failed. Check your internet connection and try again.';

  @override
  String get authIssueTooManyRequests =>
      'Too many authentication attempts were made. Please wait a moment and try again.';

  @override
  String get authIssueQuotaExceeded =>
      'OTP quota has been reached for now. Please try again later.';

  @override
  String get authIssueUserNotFound =>
      'We could not find a matching family record for that information yet.';

  @override
  String get authIssueOperationNotAllowed =>
      'This sign-in method is not enabled for the current Firebase project.';

  @override
  String get authIssueAuthUnavailable =>
      'Authentication could not be completed right now.';

  @override
  String get authIssuePreparationFailed =>
      'Something went wrong while preparing sign-in. Please try again.';
}
