import 'package:flutter/widgets.dart';

import '../app/models/app_shortcut.dart';
import '../features/auth/models/auth_entry_method.dart';
import '../features/auth/models/auth_issue.dart';
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
      AuthIssueKey.operationNotAllowed => authIssueOperationNotAllowed,
      AuthIssueKey.authUnavailable => authIssueAuthUnavailable,
      AuthIssueKey.preparationFailed => authIssuePreparationFailed,
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

  String shortcutTitle(String id) {
    return switch (id) {
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
}
