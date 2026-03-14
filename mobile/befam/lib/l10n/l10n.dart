import 'package:flutter/widgets.dart';

import '../app/models/app_shortcut.dart';
import '../features/auth/models/auth_entry_method.dart';
import '../features/auth/models/auth_issue.dart';
import '../features/auth/models/auth_member_access_mode.dart';
import '../features/events/models/event_type.dart';
import 'generated/app_localizations.dart';

extension BuildContextL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppLocalizationsX on AppLocalizations {
  String authEntryMethodSummary(AuthEntryMethod method) {
    return switch (method) {
      AuthEntryMethod.phone => authEntryMethodPhoneSummary,
      AuthEntryMethod.child => authEntryMethodChildSummary,
    };
  }

  String authEntryMethodInline(AuthEntryMethod method) {
    return switch (method) {
      AuthEntryMethod.phone => authEntryMethodPhoneInline,
      AuthEntryMethod.child => authEntryMethodChildInline,
    };
  }

  String authIssueMessage(AuthIssue issue) {
    return switch (issue.key) {
      AuthIssueKey.restoreSessionFailed => authIssueRestoreSessionFailed,
      AuthIssueKey.requestOtpBeforeVerify => authIssueRequestOtpBeforeVerify,
      AuthIssueKey.otpMustBeSixDigits => authIssueOtpMustBeSixDigits,
      AuthIssueKey.phoneRequired => authIssuePhoneRequired,
      AuthIssueKey.phoneInvalidFormat => authIssuePhoneInvalidFormat,
      AuthIssueKey.childIdentifierRequired => authIssueChildIdentifierRequired,
      AuthIssueKey.childIdentifierInvalid => authIssueChildIdentifierInvalid,
      AuthIssueKey.invalidPhoneNumber => authIssueInvalidPhoneNumber,
      AuthIssueKey.invalidVerificationCode => authIssueInvalidVerificationCode,
      AuthIssueKey.sessionExpired => authIssueSessionExpired,
      AuthIssueKey.networkRequestFailed => authIssueNetworkRequestFailed,
      AuthIssueKey.tooManyRequests => authIssueTooManyRequests,
      AuthIssueKey.quotaExceeded => authIssueQuotaExceeded,
      AuthIssueKey.userNotFound => authIssueUserNotFound,
      AuthIssueKey.childAccessNotReady => authIssueChildAccessNotReady,
      AuthIssueKey.memberAlreadyLinked => authIssueMemberAlreadyLinked,
      AuthIssueKey.memberClaimConflict => authIssueMemberClaimConflict,
      AuthIssueKey.parentVerificationMismatch =>
        authIssueParentVerificationMismatch,
      AuthIssueKey.operationNotAllowed => authIssueOperationNotAllowed,
      AuthIssueKey.authUnavailable => authIssueAuthUnavailable,
      AuthIssueKey.preparationFailed => authIssuePreparationFailed,
    };
  }

  String authMemberAccessModeLabel(AuthMemberAccessMode mode) {
    return switch (mode) {
      AuthMemberAccessMode.unlinked => shellAccessModeUnlinked,
      AuthMemberAccessMode.claimed => shellAccessModeClaimed,
      AuthMemberAccessMode.child => shellAccessModeChild,
    };
  }

  String shellDestinationLabel(String id) {
    return switch (id) {
      'home' => shellHomeLabel,
      'tree' => shellTreeLabel,
      'events' => shellEventsLabel,
      'profile' => shellProfileLabel,
      _ => shellHomeLabel,
    };
  }

  String shellDestinationTitle(String id) {
    return switch (id) {
      'home' => shellHomeTitle,
      'tree' => shellTreeTitle,
      'events' => shellEventsTitle,
      'profile' => shellProfileTitle,
      _ => shellHomeTitle,
    };
  }

  String roleLabel(String? role) {
    return switch (role?.trim().toUpperCase()) {
      'SUPER_ADMIN' => roleSuperAdmin,
      'CLAN_ADMIN' => roleClanAdmin,
      'BRANCH_ADMIN' => roleBranchAdmin,
      'MEMBER' => roleMember,
      null || '' => roleUnknown,
      _ => roleUnknown,
    };
  }

  String shortcutTitle(String id) {
    return switch (id) {
      'clan' => shortcutTitleClan,
      'tree' => shortcutTitleTree,
      'members' => shortcutTitleMembers,
      'events' => shortcutTitleEvents,
      'funds' => shortcutTitleFunds,
      'scholarship' => shortcutTitleScholarship,
      'profile' => shortcutTitleProfile,
      _ => id,
    };
  }

  String shortcutDescription(String id) {
    return switch (id) {
      'clan' => shortcutDescriptionClan,
      'tree' => shortcutDescriptionTree,
      'members' => shortcutDescriptionMembers,
      'events' => shortcutDescriptionEvents,
      'funds' => shortcutDescriptionFunds,
      'scholarship' => shortcutDescriptionScholarship,
      'profile' => shortcutDescriptionProfile,
      _ => id,
    };
  }

  String shortcutStatusLabel(AppShortcutStatus status) {
    return switch (status) {
      AppShortcutStatus.live => shellShortcutStatusLive,
      AppShortcutStatus.bootstrap => shellShortcutStatusBootstrap,
      AppShortcutStatus.planned => shellShortcutStatusPlanned,
    };
  }

  String eventTypeLabel(EventType type) {
    return switch (type) {
      EventType.clanGathering => eventTypeClanGathering,
      EventType.meeting => eventTypeMeeting,
      EventType.birthday => eventTypeBirthday,
      EventType.deathAnniversary => eventTypeDeathAnniversary,
      EventType.other => eventTypeOther,
    };
  }
}
