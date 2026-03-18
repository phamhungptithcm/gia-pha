import 'package:flutter/widgets.dart';

import '../app/models/app_shortcut.dart';
import '../features/auth/models/auth_entry_method.dart';
import '../features/auth/models/auth_issue.dart';
import '../features/auth/models/auth_member_access_mode.dart';
import '../features/calendar/models/calendar_date_mode.dart';
import '../features/calendar/models/calendar_display_mode.dart';
import '../features/calendar/models/calendar_region.dart';
import '../features/calendar/models/lunar_recurrence_policy.dart';
import '../features/events/models/event_type.dart';
import 'generated/app_localizations.dart';

extension BuildContextL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppLocalizationsX on AppLocalizations {
  String pick({required String vi, required String en}) {
    return localeName.toLowerCase().startsWith('vi') ? vi : en;
  }

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
      AuthIssueKey.privacyPolicyRequired => pick(
        vi: 'Vui lòng đồng ý Chính sách quyền riêng tư trước khi đăng nhập.',
        en: 'Please accept the Privacy Policy before signing in.',
      ),
      AuthIssueKey.operationNotAllowed => authIssueOperationNotAllowed,
      AuthIssueKey.webDomainNotAuthorized => authIssueWebDomainNotAuthorized,
      AuthIssueKey.recaptchaVerificationFailed =>
        authIssueRecaptchaVerificationFailed,
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
    final label = switch (id) {
      'home' => shellHomeLabel,
      'tree' => shellTreeLabel,
      'events' => shellEventsLabel,
      'billing' => pick(vi: 'Gói', en: 'Billing'),
      'profile' => shellProfileLabel,
      _ => shellHomeLabel,
    };
    return label.replaceAll(' ', '\u00A0');
  }

  String shellDestinationTitle(String id) {
    return switch (id) {
      'home' => shellHomeTitle,
      'tree' => shellTreeTitle,
      'events' => shellEventsTitle,
      'billing' => pick(vi: 'Gói dịch vụ', en: 'Billing'),
      'profile' => shellProfileTitle,
      _ => shellHomeTitle,
    };
  }

  String roleLabel(String? role) {
    return switch (role?.trim().toUpperCase()) {
      'SUPER_ADMIN' => roleSuperAdmin,
      'CLAN_ADMIN' => roleClanAdmin,
      'CLAN_OWNER' => pick(vi: 'Chủ tộc', en: 'Clan owner'),
      'CLAN_LEADER' => pick(vi: 'Trưởng tộc', en: 'Clan leader'),
      'BRANCH_ADMIN' => roleBranchAdmin,
      'TREASURER' => pick(vi: 'Thủ quỹ', en: 'Treasurer'),
      'SCHOLARSHIP_COUNCIL_HEAD' => pick(
        vi: 'Trưởng hội đồng học bổng',
        en: 'Scholarship Council Head',
      ),
      'ADMIN_SUPPORT' => pick(vi: 'Hỗ trợ quản trị', en: 'Admin/Support Staff'),
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

  String calendarDisplayModeLabel(CalendarDisplayMode mode) {
    return switch (mode) {
      CalendarDisplayMode.dual => pick(vi: 'Lịch Dương', en: 'Solar calendar'),
      CalendarDisplayMode.solarOnly => pick(
        vi: 'Chỉ dương lịch',
        en: 'Solar only',
      ),
      CalendarDisplayMode.lunarOnly => pick(
        vi: 'Lịch Âm',
        en: 'Lunar calendar',
      ),
    };
  }

  String calendarDateModeLabel(CalendarDateMode mode) {
    return switch (mode) {
      CalendarDateMode.solar => pick(vi: 'Ngày dương', en: 'Solar date'),
      CalendarDateMode.lunar => pick(vi: 'Ngày âm', en: 'Lunar date'),
    };
  }

  String calendarRegionLabel(CalendarRegion region) {
    return switch (region) {
      CalendarRegion.vietnam => pick(vi: 'Việt Nam', en: 'Vietnam'),
      CalendarRegion.china => pick(vi: 'Trung Quốc', en: 'China'),
      CalendarRegion.korea => pick(vi: 'Hàn Quốc', en: 'Korea'),
    };
  }

  String lunarRecurrencePolicyLabel(LunarRecurrencePolicy policy) {
    return switch (policy) {
      LunarRecurrencePolicy.skip => pick(
        vi: 'Bỏ qua năm không phù hợp',
        en: 'Skip year',
      ),
      LunarRecurrencePolicy.firstOccurrence => pick(
        vi: 'Lần xuất hiện đầu tiên',
        en: 'First occurrence',
      ),
      LunarRecurrencePolicy.leapOccurrence => pick(
        vi: 'Ưu tiên tháng nhuận',
        en: 'Leap occurrence',
      ),
    };
  }
}
