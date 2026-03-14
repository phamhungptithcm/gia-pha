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
  String get genealogyWorkspaceTitle => 'Genealogy read model';

  @override
  String get genealogyWorkspaceDescription =>
      'Load the current clan or branch scope, inspect the root entry points, and verify ancestry, descendants, siblings, and cached tree data before the visual tree canvas arrives.';

  @override
  String get genealogyScopeClan => 'Clan scope';

  @override
  String get genealogyScopeBranch => 'Current branch';

  @override
  String get genealogyRefreshAction => 'Refresh tree data';

  @override
  String get genealogyLoadFailed =>
      'The genealogy workspace could not load yet.';

  @override
  String get genealogyFromCache => 'Loaded from cache';

  @override
  String get genealogyLiveData => 'Fresh local snapshot';

  @override
  String get genealogySummaryMembers => 'Members';

  @override
  String get genealogySummaryRelationships => 'Relationships';

  @override
  String get genealogySummaryRoots => 'Root entries';

  @override
  String get genealogySummaryScope => 'Scope';

  @override
  String get genealogyFocusMemberTitle => 'Focus member';

  @override
  String get genealogyAncestryPathTitle => 'Ancestry path';

  @override
  String get genealogyRootEntriesTitle => 'Tree root entry points';

  @override
  String get genealogyNoRootEntries =>
      'No root entry points are available for this scope yet.';

  @override
  String get genealogyMemberStructureTitle => 'Structure preview';

  @override
  String get genealogyEmptyStateTitle =>
      'No members are available in this scope yet.';

  @override
  String get genealogyEmptyStateDescription =>
      'Create the first member profiles or switch scopes to start building the family graph.';

  @override
  String get genealogyGenerationLabel => 'Generation';

  @override
  String get genealogyParentCountLabel => 'Parents';

  @override
  String get genealogyChildCountLabel => 'Children';

  @override
  String get genealogySpouseCountLabel => 'Spouses';

  @override
  String get genealogySiblingCountLabel => 'Siblings';

  @override
  String get genealogyDescendantCountLabel => 'Descendants';

  @override
  String get genealogyMemberStatusLabel => 'Status';

  @override
  String get genealogyMemberAliveStatus => 'Alive';

  @override
  String get genealogyMemberDeceasedStatus => 'Deceased';

  @override
  String get genealogyViewMemberInfoAction => 'View member details';

  @override
  String genealogyMetricNodes(int count) {
    return 'Nodes: $count';
  }

  @override
  String genealogyMetricEdges(int count) {
    return 'Edges: $count';
  }

  @override
  String genealogyMetricLayout(int millis) {
    return 'Layout: ${millis}ms';
  }

  @override
  String genealogyMetricAverage(int millis) {
    return 'Avg: ${millis}ms';
  }

  @override
  String genealogyMetricPeak(int millis) {
    return 'Peak: ${millis}ms';
  }

  @override
  String get genealogyRootReasonCurrentMember => 'Current member';

  @override
  String get genealogyRootReasonClanRoot => 'Clan root';

  @override
  String get genealogyRootReasonScopeRoot => 'Scope root';

  @override
  String get genealogyRootReasonBranchLeader => 'Branch leader';

  @override
  String get genealogyRootReasonBranchViceLeader => 'Vice leader';

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
  String get profileRefreshAction => 'Refresh profile';

  @override
  String get profileOpenSettingsAction => 'Open settings';

  @override
  String get profileNoContextTitle => 'Missing member context';

  @override
  String get profileNoContextDescription =>
      'Link this account to a member profile before managing personal settings.';

  @override
  String get profileUpdateSuccess => 'Profile updated successfully.';

  @override
  String get profileUpdateErrorTitle => 'Could not update profile';

  @override
  String get profileDetailsSectionTitle => 'Profile details';

  @override
  String get profileAccountSectionTitle => 'Account';

  @override
  String get profileLogoutDialogTitle => 'Log out?';

  @override
  String get profileLogoutDialogDescription =>
      'You can sign back in at any time with your linked account.';

  @override
  String get profileSettingsLogoutDescription =>
      'This confirmation helps prevent accidental sign-out while managing settings.';

  @override
  String get profileCancelAction => 'Cancel';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSettingsOverviewTitle => 'Settings overview';

  @override
  String get profileSettingsOverviewDescription =>
      'Manage your app language, notification preferences, and session settings in one place.';

  @override
  String get profileLanguageSectionTitle => 'Language';

  @override
  String get profileLanguageSectionDescription =>
      'Choose the display language used across the app.';

  @override
  String get profileLanguageVietnamese => 'Tiếng Việt';

  @override
  String get profileLanguageVietnameseSubtitle =>
      'Use Vietnamese across all screens';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileLanguageEnglishSubtitle => 'Use English across all screens';

  @override
  String get profileSecuritySectionTitle => 'Privacy and security';

  @override
  String get profileSecurityPlaceholderTitle => 'Security settings coming soon';

  @override
  String get profileSecurityPlaceholderDescription =>
      'Advanced sign-in and session protection controls will be added in a later release.';

  @override
  String get profileSessionSectionTitle => 'Session';

  @override
  String get profileNotificationFundAlerts => 'Fund transaction alerts';

  @override
  String get profileEditSheetTitle => 'Edit profile';

  @override
  String get profileEditSheetDescription =>
      'Update member details and contact links so your profile stays complete and easy to use.';

  @override
  String get profileSaveErrorTitle => 'Could not save profile';

  @override
  String get profileFacebookUrlLabel => 'Facebook URL';

  @override
  String get profileZaloUrlLabel => 'Zalo URL';

  @override
  String get profileLinkedinUrlLabel => 'LinkedIn URL';

  @override
  String get profileSavingAction => 'Saving...';

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
  String get shellFieldClanId => 'Clan ID';

  @override
  String get shellFieldBranchId => 'Branch ID';

  @override
  String get shellFieldPrimaryRole => 'Primary role';

  @override
  String get shellFieldAccessMode => 'Access mode';

  @override
  String get shellFieldSessionType => 'Session type';

  @override
  String get shellAccessModeUnlinked => 'Signed in without member link';

  @override
  String get shellAccessModeClaimed => 'Linked member session';

  @override
  String get shellAccessModeChild => 'Child access session';

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
  String get shellMemberAccessClaimedTitle => 'Your member profile is linked';

  @override
  String get shellMemberAccessClaimedDescription =>
      'This session is attached to a BeFam member profile, and the auth UID is linked for direct member access.';

  @override
  String get shellMemberAccessChildTitle =>
      'Parent-verified child access is active';

  @override
  String get shellMemberAccessChildDescription =>
      'This session is using a parent OTP to open a child member context. The child profile is available without permanently linking the auth UID.';

  @override
  String get shellMemberAccessUnlinkedTitle =>
      'Signed in, but not linked to a member profile yet';

  @override
  String get shellMemberAccessUnlinkedDescription =>
      'The verified phone session is active, but BeFam could not match it to a claimable member record yet. Clan-scoped access stays limited until a profile is linked.';

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
  String get shortcutTitleClan => 'Clan';

  @override
  String get shortcutDescriptionClan =>
      'Set up clan identity, branch leadership, and the first administration workspace.';

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
  String get roleSuperAdmin => 'Super admin';

  @override
  String get roleClanAdmin => 'Clan admin';

  @override
  String get roleBranchAdmin => 'Branch admin';

  @override
  String get roleMember => 'Member';

  @override
  String get roleUnknown => 'Unknown';

  @override
  String get clanDetailTitle => 'Clan Management';

  @override
  String get clanRefreshAction => 'Refresh';

  @override
  String get clanSaveSuccess => 'Clan profile saved.';

  @override
  String get clanBranchSaveSuccess => 'Branch details saved.';

  @override
  String get clanNoContextTitle =>
      'This account does not have clan context yet';

  @override
  String get clanNoContextDescription =>
      'Link this account to a member profile or finish the claim flow before managing clan settings.';

  @override
  String get clanCreateFirstTitle => 'Create the clan profile';

  @override
  String get clanCreateFirstDescription =>
      'Set up the core clan record so the team has a home for branches, leadership assignments, and the first administration flows.';

  @override
  String get clanPermissionEditor => 'Can manage settings';

  @override
  String get clanPermissionViewer => 'Read-only access';

  @override
  String get clanSandboxSourceChip => 'Local sandbox data';

  @override
  String get clanLiveSourceChip => 'Live Firestore data';

  @override
  String get clanLoadErrorTitle => 'The clan workspace could not be loaded';

  @override
  String get clanPermissionDeniedDescription =>
      'The current session does not have permission to save clan settings or branch updates.';

  @override
  String get clanLoadErrorDescription =>
      'Something went wrong while loading clan data. Try again or check the Firebase configuration.';

  @override
  String get clanReadOnlyTitle => 'This session is read-only';

  @override
  String get clanReadOnlyDescription =>
      'The workspace is visible, but only linked clan or branch administrators can change settings here.';

  @override
  String get clanStatBranches => 'Branches';

  @override
  String get clanStatMembers => 'Members';

  @override
  String get clanStatYourRole => 'Your role';

  @override
  String get clanProfileSectionTitle => 'Clan profile';

  @override
  String get clanCreateAction => 'Create profile';

  @override
  String get clanEditAction => 'Edit profile';

  @override
  String get clanProfileEmptyTitle => 'The clan profile is not created yet';

  @override
  String get clanProfileEmptyDescription =>
      'Start with the clan name, founder, and a short description so the rest of the workspace has the right context.';

  @override
  String get clanFieldName => 'Clan name';

  @override
  String get clanFieldSlug => 'Slug';

  @override
  String get clanFieldCountry => 'Country';

  @override
  String get clanFieldFounder => 'Founder';

  @override
  String get clanFieldDescription => 'Description';

  @override
  String get clanFieldLogoUrl => 'Logo URL';

  @override
  String get clanFieldUnset => 'Not set';

  @override
  String get clanBranchSectionTitle => 'Branches';

  @override
  String get clanAddBranchAction => 'Add branch';

  @override
  String get clanOpenBranchListAction => 'Open branch list';

  @override
  String get clanBranchEmptyTitle => 'No branches yet';

  @override
  String get clanBranchEmptyDescription =>
      'Create the first branch to assign leaders, operational scope, and future member flows.';

  @override
  String get clanBranchCodeLabel => 'Branch code';

  @override
  String get clanLeaderLabel => 'Branch leader';

  @override
  String get clanViceLeaderLabel => 'Vice leader';

  @override
  String get clanGenerationHintLabel => 'Generation hint';

  @override
  String get clanEditBranchAction => 'Edit branch';

  @override
  String get clanEditorTitle => 'Edit clan profile';

  @override
  String get clanEditorDescription =>
      'This information becomes the shared identity layer for the app and keeps naming, country, founder, and governance notes aligned.';

  @override
  String get clanFieldNameHint => 'Example: Nguyen Van Clan';

  @override
  String get clanFieldSlugHint => 'example: nguyen-van-clan';

  @override
  String get clanFieldSlugHelper =>
      'If left empty, BeFam will create a slug from the clan name.';

  @override
  String get clanValidationNameRequired => 'Enter the clan name.';

  @override
  String get clanValidationCountryRequired => 'Enter a valid country code.';

  @override
  String get clanFieldFounderHint => 'Example: Nguyen Van Founder';

  @override
  String get clanFieldDescriptionHint =>
      'Summarize the clan background, scope, or important governance notes.';

  @override
  String get clanSaveAction => 'Save changes';

  @override
  String get clanBranchEditorTitle => 'Edit branch';

  @override
  String get clanBranchEditorDescription =>
      'Create or update a branch so the leadership, identifier, and generation hint are ready for later genealogy flows.';

  @override
  String get clanBranchNameLabel => 'Branch name';

  @override
  String get clanBranchNameHint => 'Example: Main branch';

  @override
  String get clanBranchCodeHint => 'Example: MB01';

  @override
  String get clanValidationBranchNameRequired => 'Enter the branch name.';

  @override
  String get clanValidationBranchCodeRequired => 'Enter the branch code.';

  @override
  String get clanValidationGenerationRequired =>
      'Enter a generation hint greater than 0.';

  @override
  String get clanNoLeaderOption => 'No leader assigned';

  @override
  String get clanNoViceLeaderOption => 'No vice leader assigned';

  @override
  String get clanValidationViceDistinct =>
      'The branch leader and vice leader must be different people.';

  @override
  String get clanBranchListTitle => 'Branch List';

  @override
  String get memberWorkspaceTitle => 'Member Profiles';

  @override
  String get memberRefreshAction => 'Refresh';

  @override
  String get memberNoContextTitle =>
      'This account does not have member context yet';

  @override
  String get memberNoContextDescription =>
      'Link this account to a member profile before managing the member directory in BeFam.';

  @override
  String get memberWorkspaceHeroTitle => 'Manage the clan member directory';

  @override
  String get memberWorkspaceHeroDescription =>
      'Create new profiles, update linked profiles, manage avatars, and prepare member data for the family tree, events, and permissions.';

  @override
  String get memberReadOnlyTitle => 'This session is read-only';

  @override
  String get memberReadOnlyDescription =>
      'This session can only review its own profile or linked member context. Only clan or branch administrators can add new members.';

  @override
  String get memberLoadErrorTitle => 'The member workspace could not be loaded';

  @override
  String get memberLoadErrorDescription =>
      'Something went wrong while loading member profiles. Try again or check the Firebase configuration.';

  @override
  String get memberStatCount => 'Total profiles';

  @override
  String get memberStatVisible => 'Visible now';

  @override
  String get memberStatRole => 'Your role';

  @override
  String get memberOwnProfileTitle => 'Your profile';

  @override
  String get memberEditOwnProfileAction => 'Edit my profile';

  @override
  String get memberFilterSectionTitle => 'Search and filter';

  @override
  String get memberListSectionTitle => 'Member directory';

  @override
  String get memberAddAction => 'Add member';

  @override
  String get memberListEmptyTitle => 'No matching profiles yet';

  @override
  String get memberListEmptyDescription =>
      'Create the first member or adjust the filters to reveal more profiles.';

  @override
  String get memberSaveSuccess => 'Member profile saved.';

  @override
  String get memberAvatarUploadSuccess => 'Avatar uploaded successfully.';

  @override
  String get memberDetailTitle => 'Member detail';

  @override
  String get memberUploadAvatarAction => 'Upload avatar';

  @override
  String get memberEditAction => 'Edit';

  @override
  String get memberNotFoundTitle => 'Member not found';

  @override
  String get memberNotFoundDescription =>
      'This member profile is no longer available in the current context.';

  @override
  String get memberDetailNoNickname => 'No nickname yet';

  @override
  String get memberGenerationLabel => 'Generation';

  @override
  String get memberDetailSummaryTitle => 'Profile summary';

  @override
  String get memberFullNameLabel => 'Full name';

  @override
  String get memberNicknameLabel => 'Nickname';

  @override
  String get memberFieldUnset => 'Not set';

  @override
  String get memberPhoneLabel => 'Phone number';

  @override
  String get memberEmailLabel => 'Email';

  @override
  String get memberGenderLabel => 'Gender';

  @override
  String get memberBirthDateLabel => 'Birth date';

  @override
  String get memberDeathDateLabel => 'Death date';

  @override
  String get memberJobTitleLabel => 'Job title';

  @override
  String get memberAddressLabel => 'Address';

  @override
  String get memberBioLabel => 'Short bio';

  @override
  String get memberSocialLinksTitle => 'Social links';

  @override
  String get memberSocialLinksEmptyTitle => 'No social links yet';

  @override
  String get memberSocialLinksEmptyDescription =>
      'Add Facebook, Zalo, or LinkedIn so the profile is easier to contact.';

  @override
  String get memberAvatarHint =>
      'Avatar files are stored in Firebase Storage and will be reused across profile surfaces later.';

  @override
  String get memberAddSheetTitle => 'Add member';

  @override
  String get memberEditSheetTitle => 'Edit member';

  @override
  String get memberEditorDescription =>
      'Capture the core details BeFam needs to search, verify, and present member profiles accurately across branches and generations.';

  @override
  String get memberSaveErrorTitle => 'The member profile could not be saved';

  @override
  String get memberFullNameHint => 'Example: Nguyen Van Minh';

  @override
  String get memberValidationNameRequired => 'Enter the member full name.';

  @override
  String get memberNicknameHint => 'Example: Minh';

  @override
  String get memberBranchLabel => 'Branch';

  @override
  String get memberValidationBranchRequired =>
      'Choose a branch for this member.';

  @override
  String get memberGenderUnspecified => 'Unspecified';

  @override
  String get memberGenderMale => 'Male';

  @override
  String get memberGenderFemale => 'Female';

  @override
  String get memberGenderOther => 'Other';

  @override
  String get memberValidationGenerationRequired =>
      'Enter a generation greater than 0.';

  @override
  String get memberValidationDateInvalid =>
      'Enter a valid date in YYYY-MM-DD format.';

  @override
  String get memberPhoneHint => '0901234567 or +84901234567';

  @override
  String get memberValidationPhoneInvalid => 'Enter a valid phone number.';

  @override
  String get memberJobTitleHint => 'Example: Engineer, teacher, operator';

  @override
  String get memberAddressHint => 'Example: Da Nang, Viet Nam';

  @override
  String get memberSaveAction => 'Save profile';

  @override
  String get memberSearchLabel => 'Search members';

  @override
  String get memberSearchHint => 'Enter a name, nickname, or phone number';

  @override
  String get memberFilterBranchLabel => 'Filter by branch';

  @override
  String get memberFilterAllBranches => 'All branches';

  @override
  String get memberFilterGenerationLabel => 'Filter by generation';

  @override
  String get memberFilterAllGenerations => 'All generations';

  @override
  String get memberClearFiltersAction => 'Clear filters';

  @override
  String get memberPhoneMissing => 'No phone number yet';

  @override
  String get memberPermissionEditor => 'Can edit';

  @override
  String get memberPermissionViewer => 'Read-only';

  @override
  String get memberSandboxChip => 'Local sandbox data';

  @override
  String get memberLiveChip => 'Live Firestore data';

  @override
  String get memberDuplicatePhoneError =>
      'That phone number already belongs to another member profile.';

  @override
  String get memberPermissionDeniedError =>
      'The current session does not have permission to change this member profile.';

  @override
  String get memberAvatarUploadError =>
      'BeFam could not upload the avatar right now.';

  @override
  String get relationshipInspectorTitle => 'Family relationships';

  @override
  String get relationshipInspectorDescription =>
      'Inspect this profile\'s parent, child, and spouse links. Sensitive changes are limited to linked administrators.';

  @override
  String get relationshipRefreshAction => 'Refresh relationships';

  @override
  String get relationshipAddParentAction => 'Add parent';

  @override
  String get relationshipAddChildAction => 'Add child';

  @override
  String get relationshipAddSpouseAction => 'Add spouse';

  @override
  String get relationshipParentsTitle => 'Parents';

  @override
  String get relationshipChildrenTitle => 'Children';

  @override
  String get relationshipSpousesTitle => 'Spouses';

  @override
  String get relationshipNoParents => 'No parent links yet.';

  @override
  String get relationshipNoChildren => 'No child links yet.';

  @override
  String get relationshipNoSpouses => 'No spouse links yet.';

  @override
  String get relationshipCanonicalEdgeTitle => 'Canonical relationship edges';

  @override
  String get relationshipNoEdges =>
      'There are no relationship edges for this profile yet.';

  @override
  String get relationshipEdgeParentChild => 'Parent -> child';

  @override
  String get relationshipEdgeSpouse => 'Spouse';

  @override
  String get relationshipSourceLabel => 'Source';

  @override
  String get relationshipErrorTitle => 'The relationship could not be updated';

  @override
  String get relationshipErrorDuplicateSpouse =>
      'Those two members are already linked as spouses.';

  @override
  String get relationshipErrorDuplicateParentChild =>
      'That parent-child relationship already exists.';

  @override
  String get relationshipErrorCycle =>
      'That parent-child link would create an invalid cycle.';

  @override
  String get relationshipErrorPermissionDenied =>
      'The current session cannot change this sensitive relationship.';

  @override
  String get relationshipErrorMemberNotFound =>
      'We could not find a valid member profile for this relationship change.';

  @override
  String get relationshipErrorSameMember =>
      'A relationship cannot target the same member.';

  @override
  String get relationshipPickParentTitle => 'Choose a parent';

  @override
  String get relationshipPickChildTitle => 'Choose a child';

  @override
  String get relationshipPickSpouseTitle => 'Choose a spouse';

  @override
  String get relationshipNoCandidates =>
      'No eligible candidates remain for this action.';

  @override
  String get relationshipParentAddedSuccess => 'Parent link added.';

  @override
  String get relationshipChildAddedSuccess => 'Child link added.';

  @override
  String get relationshipSpouseAddedSuccess => 'Spouse link added.';

  @override
  String get notificationForegroundEvent => 'A new event update arrived.';

  @override
  String get notificationForegroundScholarship =>
      'A scholarship update arrived.';

  @override
  String get notificationForegroundGeneral => 'A new notification arrived.';

  @override
  String get notificationOpenedEvent => 'Opened the event notification.';

  @override
  String get notificationOpenedScholarship =>
      'Opened the scholarship notification.';

  @override
  String get notificationOpenedGeneral => 'Opened a notification.';

  @override
  String get notificationInboxHeroTitle => 'Notification inbox';

  @override
  String get notificationInboxHeroDescription =>
      'Review the latest event and scholarship updates delivered to your member profile.';

  @override
  String notificationInboxUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String get notificationInboxAllRead => 'All caught up';

  @override
  String get notificationInboxSourceSandbox => 'Local sandbox data';

  @override
  String get notificationInboxSourceLive => 'Live Firestore data';

  @override
  String get notificationInboxNoContextTitle =>
      'Notification inbox unavailable';

  @override
  String get notificationInboxNoContextDescription =>
      'This session is not linked to a member profile yet, so there is no inbox to show.';

  @override
  String get notificationInboxLoadErrorTitle => 'Could not load notifications';

  @override
  String get notificationInboxLoadErrorDescription =>
      'Pull to refresh or retry now. If this keeps happening, check Firebase connectivity and permissions.';

  @override
  String get notificationInboxRetryAction => 'Retry';

  @override
  String get notificationInboxEmptyTitle => 'No notifications yet';

  @override
  String get notificationInboxEmptyDescription =>
      'When events and scholarship updates are sent, they will appear here.';

  @override
  String get notificationInboxUnreadChip => 'Unread';

  @override
  String get notificationInboxReadChip => 'Read';

  @override
  String get notificationInboxTargetEvent => 'Event';

  @override
  String get notificationInboxTargetScholarship => 'Scholarship';

  @override
  String get notificationInboxTargetGeneric => 'General';

  @override
  String get notificationInboxTargetUnknown => 'Update';

  @override
  String get notificationInboxFallbackTitle => 'Notification update';

  @override
  String get notificationInboxFallbackBody =>
      'Open this notification for more details.';

  @override
  String get notificationInboxOpenAction => 'Open';

  @override
  String get notificationInboxMarkReadAction => 'Mark as read';

  @override
  String get notificationInboxMarkReadFailed =>
      'Could not mark this notification as read right now.';

  @override
  String get notificationInboxLoadMoreAction => 'Load more notifications';

  @override
  String get notificationInboxPaginationDone => 'No more notifications.';

  @override
  String get notificationTargetEventTitle => 'Event notification';

  @override
  String get notificationTargetEventDescription =>
      'This confirms deep-link routing into the event destination placeholder.';

  @override
  String get notificationTargetScholarshipTitle => 'Scholarship notification';

  @override
  String get notificationTargetScholarshipDescription =>
      'This confirms deep-link routing into the scholarship result destination placeholder.';

  @override
  String get notificationTargetUnknownTitle => 'Notification destination';

  @override
  String get notificationTargetUnknownDescription =>
      'This notification does not contain a supported destination yet.';

  @override
  String get notificationTargetReferenceLabel => 'Reference ID';

  @override
  String get notificationTargetPayloadTitleLabel => 'Notification title';

  @override
  String get notificationTargetPayloadBodyLabel => 'Notification message';

  @override
  String get notificationTargetUnknownReference => 'Unavailable';

  @override
  String get notificationSettingsTitle => 'Notification settings';

  @override
  String get notificationSettingsDescription =>
      'These toggles are placeholders so profile-level notification controls can be finalized in later delivery slices.';

  @override
  String get notificationSettingsEventUpdates => 'Event reminders and updates';

  @override
  String get notificationSettingsScholarshipUpdates =>
      'Scholarship decisions and review updates';

  @override
  String get notificationSettingsGeneralUpdates =>
      'General family announcements';

  @override
  String get notificationSettingsQuietHours => 'Quiet hours mode';

  @override
  String get notificationSettingsPlaceholderNote =>
      'This is a UI placeholder. Toggle values are local-only and are not persisted to backend preferences yet.';

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
  String get authIssueChildAccessNotReady =>
      'That child identifier exists, but it is not fully linked to a parent OTP flow yet.';

  @override
  String get authIssueMemberAlreadyLinked =>
      'This member profile is already linked to another account.';

  @override
  String get authIssueMemberClaimConflict =>
      'More than one member profile uses this phone number. Please contact a clan administrator.';

  @override
  String get authIssueParentVerificationMismatch =>
      'The verified phone number does not match the parent phone linked to that child access code.';

  @override
  String get authIssueOperationNotAllowed =>
      'This sign-in method is not enabled for the current Firebase project.';

  @override
  String get authIssueAuthUnavailable =>
      'Authentication could not be completed right now.';

  @override
  String get authIssuePreparationFailed =>
      'Something went wrong while preparing sign-in. Please try again.';

  @override
  String get eventWorkspaceTitle => 'Events workspace';

  @override
  String get eventRefreshAction => 'Refresh events';

  @override
  String get eventCreateAction => 'Create event';

  @override
  String get eventSaveSuccess => 'Event saved successfully.';

  @override
  String get eventNoContextTitle => 'Clan context is required';

  @override
  String get eventNoContextDescription =>
      'Sign in with a linked clan profile to view and manage events.';

  @override
  String get eventHeroTitle => 'Shared clan schedule';

  @override
  String get eventHeroDescription =>
      'Track ceremonies, memorials, and reminders from one timeline for your clan.';

  @override
  String get eventReadOnlyTitle => 'Read-only access';

  @override
  String get eventReadOnlyDescription =>
      'This account can view events but cannot create or edit them yet.';

  @override
  String get eventLoadErrorTitle => 'Unable to load events';

  @override
  String get eventLoadErrorDescription =>
      'Try refreshing. If the issue continues, verify your network and permissions.';

  @override
  String get eventStatTotal => 'Total events';

  @override
  String get eventStatUpcoming => 'Upcoming';

  @override
  String get eventStatMemorial => 'Memorial events';

  @override
  String get eventFilterSectionTitle => 'Search and filters';

  @override
  String get eventSearchLabel => 'Search events';

  @override
  String get eventSearchHint => 'Title, location, member, or description';

  @override
  String get eventFilterTypeAll => 'All';

  @override
  String get eventFilterClearAction => 'Clear';

  @override
  String get eventListSectionTitle => 'Event list';

  @override
  String get eventListEmptyTitle => 'No events yet';

  @override
  String get eventListEmptyDescription =>
      'Create the first event for your clan schedule.';

  @override
  String get eventDetailTitle => 'Event details';

  @override
  String get eventEditAction => 'Edit';

  @override
  String get eventDetailNotFoundTitle => 'Event no longer available';

  @override
  String get eventDetailNotFoundDescription =>
      'The event may have been removed or is outside the current workspace scope.';

  @override
  String get eventDetailTimingSection => 'Timing and recurrence';

  @override
  String get eventDetailReminderSection => 'Reminder offsets';

  @override
  String get eventReminderEmptyTitle => 'No reminders configured';

  @override
  String get eventReminderEmptyDescription =>
      'Add reminder offsets to notify members before this event starts.';

  @override
  String get eventFieldType => 'Type';

  @override
  String get eventFieldBranch => 'Branch';

  @override
  String get eventFieldTargetMember => 'Target member';

  @override
  String get eventFieldLocationName => 'Location name';

  @override
  String get eventFieldLocationAddress => 'Location address';

  @override
  String get eventFieldDescription => 'Description';

  @override
  String get eventFieldStartsAt => 'Starts at';

  @override
  String get eventFieldEndsAt => 'Ends at';

  @override
  String get eventFieldTimezone => 'Timezone';

  @override
  String get eventFieldRecurring => 'Recurring';

  @override
  String get eventFieldRecurrenceRule => 'Recurrence rule';

  @override
  String get eventFieldVisibility => 'Visibility';

  @override
  String get eventFieldStatus => 'Status';

  @override
  String get eventFieldUnset => 'Not set';

  @override
  String get eventRecurringYes => 'Yes';

  @override
  String get eventRecurringNo => 'No';

  @override
  String get eventFormCreateTitle => 'Create event';

  @override
  String get eventFormEditTitle => 'Edit event';

  @override
  String get eventFormTitleLabel => 'Title';

  @override
  String get eventFormTitleHint => 'Example: Clan meeting, memorial ceremony';

  @override
  String get eventFormTypeLabel => 'Event type';

  @override
  String get eventFormBranchLabel => 'Branch scope';

  @override
  String get eventFormTargetMemberLabel => 'Memorial target member';

  @override
  String get eventFormRecurringMemorialLabel => 'Repeat yearly memorial';

  @override
  String get eventFormStartsAtLabel => 'Starts at';

  @override
  String get eventFormEndsAtLabel => 'Ends at';

  @override
  String get eventFormDateTimeHint => 'YYYY-MM-DD HH:mm';

  @override
  String get eventFormTimezoneLabel => 'Timezone';

  @override
  String get eventFormLocationNameLabel => 'Location name';

  @override
  String get eventFormLocationAddressLabel => 'Location address';

  @override
  String get eventFormDescriptionLabel => 'Description';

  @override
  String get eventFormReminderSectionTitle => 'Reminder offsets';

  @override
  String get eventFormReminderPresetWeek => '+7d';

  @override
  String get eventFormReminderPresetDay => '+1d';

  @override
  String get eventFormReminderPresetHours => '+2h';

  @override
  String get eventFormReminderCustomLabel => 'Custom offset (minutes)';

  @override
  String get eventFormReminderCustomHint => 'Example: 30';

  @override
  String get eventFormReminderAddAction => 'Add';

  @override
  String get eventFormSaveAction => 'Save event';

  @override
  String get eventValidationTitleRequired => 'Please enter an event title.';

  @override
  String get eventValidationTimeRange =>
      'Start and end times are invalid. End time must be after start time.';

  @override
  String get eventValidationReminderOffsets =>
      'Reminder offsets must be positive and unique.';

  @override
  String get eventValidationMemorialTarget =>
      'Recurring memorial events need a target member.';

  @override
  String get eventValidationMemorialRule =>
      'Recurring memorial events must use a yearly recurrence rule.';

  @override
  String get eventErrorPermission =>
      'This session does not have permission to manage events.';

  @override
  String get eventErrorNotFound => 'The event could not be found.';

  @override
  String get eventTypeClanGathering => 'Clan gathering';

  @override
  String get eventTypeMeeting => 'Meeting';

  @override
  String get eventTypeBirthday => 'Birthday';

  @override
  String get eventTypeDeathAnniversary => 'Death anniversary';

  @override
  String get eventTypeOther => 'Other';
}
