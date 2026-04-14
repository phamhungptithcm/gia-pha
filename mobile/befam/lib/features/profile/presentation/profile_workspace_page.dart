import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_locale_controller.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../core/widgets/address_action_tools.dart';
import '../../../core/widgets/member_phone_action.dart';
import '../../../core/widgets/social_link_actions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../ads/services/ad_consent_service.dart';
import '../../ai/services/ai_product_analytics_service.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/services/auth_session_store.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../../auth/widgets/phone_country_selector_field.dart';
import '../../billing/models/billing_workspace_snapshot.dart';
import '../../billing/presentation/billing_workspace_page.dart';
import '../../billing/services/billing_repository.dart';
import '../../member/models/member_profile.dart';
import '../../member/models/member_social_links.dart';
import '../../member/services/member_avatar_picker.dart';
import '../../member/services/member_repository.dart';
import '../../notifications/services/notification_test_service.dart';
import '../../ai/services/ai_assist_service.dart';
import '../../ai/presentation/ai_usage_quota_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_draft.dart';
import '../services/profile_quality_check_actions.dart';
import '../services/account_deletion_request_service.dart';
import '../services/profile_notification_preferences_repository.dart';
import 'profile_controller.dart';

class ProfileWorkspacePage extends StatefulWidget {
  const ProfileWorkspacePage({
    super.key,
    required this.session,
    required this.memberRepository,
    this.avatarPicker,
    this.notificationPreferencesRepository,
    this.localeController,
    this.billingRepository,
    this.onBillingStateChanged,
    this.onLogoutRequested,
    this.onSessionUpdated,
    this.accountDeletionRequestService,
    this.adConsentService,
    this.aiAssistService,
    this.showAppBar = false,
  });

  final AuthSession session;
  final MemberRepository memberRepository;
  final MemberAvatarPicker? avatarPicker;
  final ProfileNotificationPreferencesRepository?
  notificationPreferencesRepository;
  final AppLocaleController? localeController;
  final BillingRepository? billingRepository;
  final VoidCallback? onBillingStateChanged;
  final Future<void> Function()? onLogoutRequested;
  final ValueChanged<AuthSession>? onSessionUpdated;
  final AccountDeletionRequestService? accountDeletionRequestService;
  final AdConsentService? adConsentService;
  final AiAssistService? aiAssistService;
  final bool showAppBar;

  @override
  State<ProfileWorkspacePage> createState() => _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends State<ProfileWorkspacePage> {
  late final ProfileController _controller;
  late final MemberAvatarPicker _avatarPicker;
  late final AppLocaleController _localeController;
  late final SharedPrefsAuthSessionStore _sessionStore;
  late final _UnlinkedProfileDraftStore _unlinkedProfileStore;
  late final NotificationTestService _notificationTestService;
  late final AccountDeletionRequestService _accountDeletionRequestService;
  late final AdConsentService _adConsentService;
  late final AiAssistService _aiAssistService;
  late final bool _ownsLocaleController;
  ProfileDraft? _unlinkedDraft;
  bool _isSavingUnlinkedProfile = false;
  bool _isSendingTestNotification = false;
  bool _isSendingEventReminderTest = false;
  bool _isLoadingAccountDeletionStatus = false;
  bool _isSubmittingAccountDeletionRequest = false;
  bool _isOpeningPrivacyChoices = false;
  AccountDeletionRequestState _accountDeletionRequestState =
      const AccountDeletionRequestState.notRequested();

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      memberRepository: widget.memberRepository,
      session: widget.session,
      notificationPreferencesRepository:
          widget.notificationPreferencesRepository,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    _localeController = widget.localeController ?? AppLocaleController();
    _sessionStore = SharedPrefsAuthSessionStore();
    _unlinkedProfileStore = const _UnlinkedProfileDraftStore();
    _notificationTestService = createDefaultNotificationTestService(
      session: widget.session,
    );
    _accountDeletionRequestService =
        widget.accountDeletionRequestService ??
        createDefaultAccountDeletionRequestService(session: widget.session);
    _adConsentService =
        widget.adConsentService ?? createDefaultAdConsentService();
    _aiAssistService = widget.aiAssistService ?? createDefaultAiAssistService();
    _ownsLocaleController = widget.localeController == null;
    unawaited(_localeController.load());
    unawaited(_controller.initialize());
    unawaited(_loadUnlinkedDraft());
    unawaited(_loadAccountDeletionRequestStatus());
  }

  @override
  void didUpdateWidget(covariant ProfileWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid) {
      _accountDeletionRequestState =
          const AccountDeletionRequestState.notRequested();
      unawaited(_loadUnlinkedDraft());
      unawaited(_loadAccountDeletionRequestStatus());
    }
  }

  @override
  void dispose() {
    if (_ownsLocaleController) {
      _localeController.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor(MemberProfile profile) async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileEditorSheet(
          session: widget.session,
          initialDraft: ProfileDraft.fromMember(profile),
          isSaving: _controller.isSavingProfile,
          onSubmit: _controller.saveProfile,
          aiAssistService: _aiAssistService,
          billingRepository: widget.billingRepository,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdateSuccess)));
    }
  }

  ProfileDraft _fallbackUnlinkedDraft(AuthSession session) {
    return ProfileDraft(
      fullName: session.displayName.trim(),
      nickName: '',
      phoneInput: session.phoneE164.trim(),
      email: '',
      addressText: '',
      jobTitle: '',
      bio: '',
      facebook: '',
      zalo: '',
      linkedin: '',
    );
  }

  Future<void> _loadUnlinkedDraft() async {
    final draft = await _unlinkedProfileStore.read(
      sessionUid: widget.session.uid,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _unlinkedDraft = draft;
    });
  }

  Future<void> _openUnlinkedEditor() async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileEditorSheet(
          session: widget.session,
          initialDraft:
              _unlinkedDraft ?? _fallbackUnlinkedDraft(widget.session),
          isSaving: _isSavingUnlinkedProfile,
          onSubmit: _saveUnlinkedProfileDraft,
          aiAssistService: _aiAssistService,
          billingRepository: widget.billingRepository,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdateSuccess)));
    }
  }

  Future<void> _sendTestNotification() async {
    if (_isSendingTestNotification) {
      return;
    }

    final l10n = context.l10n;
    setState(() {
      _isSendingTestNotification = true;
    });

    try {
      final result = await _notificationTestService.sendSelfTest(
        session: widget.session,
        delaySeconds: 8,
        title: l10n.pick(
          vi: 'Thông báo thử từ BeFam',
          en: 'Test notification from BeFam',
        ),
        body: l10n.pick(
          vi: 'Chạm để mở BeFam và kiểm tra luồng thông báo trên máy này.',
          en: 'Tap to open BeFam and verify the notification flow on this device.',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'BeFam sẽ gửi thông báo thử sau ${result.delaySeconds} giây. Hãy đưa app ra nền để kiểm tra.',
              en: 'BeFam will send a test notification in ${result.delaySeconds} seconds. Put the app in the background to verify it.',
            ),
          ),
        ),
      );
    } on NotificationTestServiceException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notificationTestErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTestNotification = false;
        });
      } else {
        _isSendingTestNotification = false;
      }
    }
  }

  Future<void> _sendEventReminderTest() async {
    if (_isSendingEventReminderTest) {
      return;
    }

    final l10n = context.l10n;
    setState(() {
      _isSendingEventReminderTest = true;
    });

    try {
      final result = await _notificationTestService.sendEventReminderSelfTest(
        session: widget.session,
        delaySeconds: 8,
        title: l10n.pick(vi: 'Sự kiện thử từ BeFam', en: 'BeFam test event'),
        body: l10n.pick(
          vi: 'BeFam sẽ nhắc bạn mở lại app để kiểm tra event reminder trên máy thật.',
          en: 'BeFam will remind you to reopen the app so you can verify event reminders on a real device.',
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'BeFam đã tạo một sự kiện thử và sẽ nhắc sau ${result.delaySeconds} giây. Hãy đưa app ra nền để kiểm tra.',
              en: 'BeFam created a test event and will remind you in ${result.delaySeconds} seconds. Put the app in the background to verify it.',
            ),
          ),
        ),
      );
    } on NotificationTestServiceException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notificationTestErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEventReminderTest = false;
        });
      } else {
        _isSendingEventReminderTest = false;
      }
    }
  }

  Future<void> _loadAccountDeletionRequestStatus() async {
    if (_isLoadingAccountDeletionStatus) {
      return;
    }

    setState(() {
      _isLoadingAccountDeletionStatus = true;
    });

    try {
      final status = await _accountDeletionRequestService.loadStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _accountDeletionRequestState = status;
      });
    } on AccountDeletionRequestServiceException {
      // Keep the section usable even if the status endpoint is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAccountDeletionStatus = false;
        });
      } else {
        _isLoadingAccountDeletionStatus = false;
      }
    }
  }

  Future<void> _openPrivacyChoices() async {
    if (_isOpeningPrivacyChoices) {
      return;
    }

    final l10n = context.l10n;
    setState(() {
      _isOpeningPrivacyChoices = true;
    });

    try {
      final result = await _adConsentService.showPrivacyOptions();
      if (!mounted) {
        return;
      }
      final message =
          result.privacyOptionsRequirementStatus ==
              PrivacyOptionsRequirementStatus.required
          ? l10n.pick(
              vi: 'BeFam đã mở lại phần lựa chọn quyền riêng tư trên thiết bị này.',
              en: 'BeFam reopened the privacy choices form on this device.',
            )
          : l10n.pick(
              vi: 'Hiện chưa có lựa chọn quyền riêng tư nào cần cập nhật trên thiết bị này.',
              en: 'There are no privacy choices to update on this device right now.',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Chưa thể mở phần lựa chọn quyền riêng tư lúc này.',
              en: 'Unable to open privacy choices right now.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningPrivacyChoices = false;
        });
      } else {
        _isOpeningPrivacyChoices = false;
      }
    }
  }

  Future<void> _confirmAccountDeletionRequest() async {
    if (_isSubmittingAccountDeletionRequest ||
        _accountDeletionRequestState.hasPendingRequest) {
      return;
    }

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.pick(
              vi: 'Gửi yêu cầu xóa tài khoản?',
              en: 'Send an account deletion request?',
            ),
          ),
          content: Text(
            l10n.pick(
              vi: 'BeFam sẽ ghi nhận yêu cầu, xác minh thông tin cần thiết và xử lý việc xóa tài khoản của bạn theo chính sách hiện hành.',
              en: 'BeFam will record the request, verify the necessary details, and process your account deletion under the current policy.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.pick(vi: 'Để sau', en: 'Not now')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.pick(vi: 'Gửi yêu cầu xóa', en: 'Send deletion request'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSubmittingAccountDeletionRequest = true;
    });

    try {
      final status = await _accountDeletionRequestService.submitRequest();
      if (!mounted) {
        return;
      }
      setState(() {
        _accountDeletionRequestState = status;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'BeFam đã nhận yêu cầu xóa tài khoản của bạn.',
              en: 'BeFam received your account deletion request.',
            ),
          ),
        ),
      );
    } on AccountDeletionRequestServiceException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_accountDeletionRequestErrorMessage(l10n, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingAccountDeletionRequest = false;
        });
      } else {
        _isSubmittingAccountDeletionRequest = false;
      }
    }
  }

  String _accountDeletionRequestErrorMessage(
    AppLocalizations l10n,
    AccountDeletionRequestServiceException error,
  ) {
    return switch (error.code) {
      AccountDeletionRequestServiceErrorCode.unauthenticated => l10n.pick(
        vi: 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.',
        en: 'This session expired. Sign in again and try once more.',
      ),
      AccountDeletionRequestServiceErrorCode.permissionDenied => l10n.pick(
        vi: 'Phiên này chưa được phép gửi yêu cầu xóa tài khoản.',
        en: 'This session is not allowed to request account deletion.',
      ),
      AccountDeletionRequestServiceErrorCode.failedPrecondition => l10n.pick(
        vi: 'Tài khoản này chưa sẵn sàng cho thao tác xóa. Hãy thử lại sau ít phút.',
        en: 'This account is not ready for deletion yet. Please try again shortly.',
      ),
      AccountDeletionRequestServiceErrorCode.unavailable => l10n.pick(
        vi: 'Máy chủ tạm thời chưa phản hồi. Hãy thử lại sau ít phút.',
        en: 'The server is temporarily unavailable. Please try again shortly.',
      ),
      AccountDeletionRequestServiceErrorCode.unknown => l10n.pick(
        vi: 'Chưa thể gửi yêu cầu xóa tài khoản lúc này.',
        en: 'Unable to submit the account deletion request right now.',
      ),
    };
  }

  String _formatInlineTimestamp(String isoString) {
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) {
      return isoString;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _notificationTestErrorMessage(
    AppLocalizations l10n,
    NotificationTestServiceException error,
  ) {
    return switch (error.code) {
      NotificationTestServiceErrorCode.unauthenticated => l10n.pick(
        vi: 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.',
        en: 'This session expired. Sign in again and try once more.',
      ),
      NotificationTestServiceErrorCode.permissionDenied => l10n.pick(
        vi: 'Phiên này chưa được phép gửi thông báo thử.',
        en: 'This session is not allowed to send a test notification.',
      ),
      NotificationTestServiceErrorCode.failedPrecondition => l10n.pick(
        vi: 'Máy này chưa sẵn sàng cho bài test này. Hãy mở app vài giây, cấp quyền thông báo và bật nhắc sự kiện rồi thử lại.',
        en: 'This device is not ready for this test yet. Keep the app open briefly, allow notifications, enable event reminders, then try again.',
      ),
      NotificationTestServiceErrorCode.unavailable => l10n.pick(
        vi: 'Máy chủ tạm thời chưa phản hồi. Hãy thử lại sau ít phút.',
        en: 'The server is temporarily unavailable. Please try again shortly.',
      ),
      NotificationTestServiceErrorCode.unknown => l10n.pick(
        vi: 'Chưa thể chạy bài test lúc này.',
        en: 'Unable to run this test right now.',
      ),
    };
  }

  Future<MemberRepositoryErrorCode?> _saveUnlinkedProfileDraft(
    ProfileDraft draft,
  ) async {
    if (_isSavingUnlinkedProfile) {
      return MemberRepositoryErrorCode.permissionDenied;
    }
    setState(() {
      _isSavingUnlinkedProfile = true;
    });

    try {
      final fullName = _trimOrFallback(
        draft.fullName,
        widget.session.displayName,
      );
      final phoneInput = _trimOrFallback(
        draft.phoneInput,
        widget.session.phoneE164,
      );
      final normalizedPhoneInput =
          PhoneNumberFormatter.tryParseE164(
            phoneInput,
            defaultCountryIso: PhoneNumberFormatter.inferCountryOption(
              widget.session.phoneE164,
            ).isoCode,
          ) ??
          phoneInput;
      final normalizedDraft = ProfileDraft(
        fullName: fullName,
        nickName: draft.nickName.trim(),
        phoneInput: normalizedPhoneInput,
        email: draft.email.trim(),
        addressText: draft.addressText.trim(),
        jobTitle: draft.jobTitle.trim(),
        bio: draft.bio.trim(),
        facebook: draft.facebook.trim(),
        zalo: draft.zalo.trim(),
        linkedin: draft.linkedin.trim(),
      );
      await _unlinkedProfileStore.write(
        sessionUid: widget.session.uid,
        draft: normalizedDraft,
      );
      final updatedSession = widget.session.copyWith(
        displayName: fullName,
        phoneE164: normalizedPhoneInput,
      );
      await _sessionStore.write(updatedSession);
      widget.onSessionUpdated?.call(updatedSession);
      if (!mounted) {
        return null;
      }
      setState(() {
        _unlinkedDraft = normalizedDraft;
      });
      return null;
    } catch (_) {
      return MemberRepositoryErrorCode.permissionDenied;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUnlinkedProfile = false;
        });
      } else {
        _isSavingUnlinkedProfile = false;
      }
    }
  }

  MemberProfile _buildUnlinkedFallbackProfile({
    required AuthSession session,
    required ProfileDraft draft,
    required AppLocalizations l10n,
  }) {
    final fullName = _normalizeUnlinkedFullName(
      draftValue: draft.fullName,
      fallbackValue: session.displayName,
      l10n: l10n,
    );
    final phone = _displayOrFallback(
      draft.phoneInput,
      fallback: session.phoneE164,
    );
    final normalizedRole = (session.primaryRole ?? '').trim().toUpperCase();
    return MemberProfile(
      id: 'unlinked_${session.uid}',
      clanId: '',
      branchId: '',
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase().trim(),
      nickName: draft.nickName.trim(),
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneE164: phone.isEmpty ? null : phone,
      email: _blankToNull(draft.email),
      addressText: _blankToNull(draft.addressText),
      jobTitle: _blankToNull(draft.jobTitle),
      avatarUrl: null,
      bio: _blankToNull(draft.bio),
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      siblingOrder: null,
      generation: 1,
      primaryRole: normalizedRole.isEmpty ? 'MEMBER' : normalizedRole,
      status: 'active',
      isMinor: false,
      authUid: session.uid,
    );
  }

  Future<void> _handleAvatarUpload() async {
    final l10n = context.l10n;
    final picked = await _avatarPicker.pickAvatar();
    if (picked == null || !mounted) {
      return;
    }

    final error = await _controller.uploadAvatar(
      bytes: picked.bytes,
      fileName: picked.fileName,
      contentType: picked.contentType,
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.memberAvatarUploadSuccess)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_memberErrorMessage(l10n, error))));
  }

  Future<void> _openAvatarActions(MemberProfile profile) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppWorkspaceSurface(
              padding: const EdgeInsets.all(18),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
                bottom: Radius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.pick(vi: 'Ảnh đại diện', en: 'Profile photo'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.pick(
                      vi: 'Giữ các thao tác với ảnh ở một nơi ngắn gọn để chỉnh nhanh.',
                      en: 'Keep photo actions in one compact place for quick updates.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  _AvatarActionTile(
                    icon: Icons.image_outlined,
                    title: l10n.pick(
                      vi: 'Xem ảnh hiện tại',
                      en: 'View current photo',
                    ),
                    onTap: () => Navigator.of(context).pop(_AvatarAction.view),
                  ),
                  const SizedBox(height: 10),
                  _AvatarActionTile(
                    icon: Icons.file_upload_outlined,
                    title: l10n.pick(vi: 'Tải ảnh mới', en: 'Upload new photo'),
                    onTap: () =>
                        Navigator.of(context).pop(_AvatarAction.upload),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _AvatarAction.upload) {
      await _handleAvatarUpload();
      return;
    }

    if (!profile.hasAvatar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Hiện chưa có ảnh đại diện.',
              en: 'No current profile photo yet.',
            ),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(profile.avatarUrl!, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _SettingsScreenShell(
            controller: _controller,
            session: widget.session,
            localeController: _localeController,
            billingRepository: widget.billingRepository,
            onBillingStateChanged: widget.onBillingStateChanged,
            onLogoutRequested: widget.onLogoutRequested,
            showTestAction:
                !kReleaseMode && !_notificationTestService.isSandbox,
            isSendingTestNotification: _isSendingTestNotification,
            isSendingEventReminderTest: _isSendingEventReminderTest,
            accountDeletionRequestState: _accountDeletionRequestState,
            isLoadingAccountDeletionStatus: _isLoadingAccountDeletionStatus,
            isSubmittingAccountDeletionRequest:
                _isSubmittingAccountDeletionRequest,
            isOpeningPrivacyChoices: _isOpeningPrivacyChoices,
            onSendTestNotification: _sendTestNotification,
            onSendEventReminderTest: _sendEventReminderTest,
            onOpenPrivacyChoices: _openPrivacyChoices,
            onRequestAccountDeletion: _confirmAccountDeletionRequest,
            formatInlineTimestamp: _formatInlineTimestamp,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _localeController]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final selectedLanguageCode = _localeController.locale.languageCode;
        final unlinkedDraft =
            _unlinkedDraft ?? _fallbackUnlinkedDraft(widget.session);
        final usesFallbackProfile =
            !_controller.hasMemberContext && _controller.profile == null;
        final displayProfile =
            _controller.profile ??
            (usesFallbackProfile
                ? _buildUnlinkedFallbackProfile(
                    session: widget.session,
                    draft: unlinkedDraft,
                    l10n: l10n,
                  )
                : null);
        final languageLabel = selectedLanguageCode == 'vi'
            ? l10n.profileLanguageVietnamese
            : l10n.profileLanguageEnglish;

        return Scaffold(
          appBar: widget.showAppBar
              ? AppBar(
                  title: Text(l10n.shellProfileTitle),
                  actions: [
                    IconButton(
                      tooltip: l10n.profileRefreshAction,
                      onPressed: _controller.isLoading
                          ? null
                          : _controller.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: l10n.profileOpenSettingsAction,
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải hồ sơ...',
                      en: 'Loading profile...',
                    ),
                  )
                : displayProfile == null
                ? _ProfileEmptyState(
                    icon: Icons.person_search_outlined,
                    title: l10n.memberNotFoundTitle,
                    description: l10n.memberNotFoundDescription,
                    actionLabel: l10n.notificationInboxRetryAction,
                    onAction: _controller.refresh,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: AppWorkspaceViewport(
                      child: ListView(
                        padding: appWorkspacePagePadding(
                          context,
                          top: 16,
                          bottom: 32,
                        ),
                        children: [
                          _ProfileHeroCard(
                            profile: displayProfile,
                            onEditProfile: usesFallbackProfile
                                ? _openUnlinkedEditor
                                : () => _openEditor(displayProfile),
                            onAvatarTap:
                                usesFallbackProfile ||
                                    _controller.isUploadingAvatar
                                ? null
                                : () => _openAvatarActions(displayProfile),
                            isUploadingAvatar: usesFallbackProfile
                                ? _isSavingUnlinkedProfile
                                : _controller.isUploadingAvatar,
                            showAvatarActionBadge: !usesFallbackProfile,
                          ),
                          const SizedBox(height: 16),
                          if (_controller.errorMessage != null) ...[
                            _ProfileInfoCard(
                              icon: Icons.error_outline,
                              title: l10n.profileUpdateErrorTitle,
                              description: _friendlyProfileErrorMessage(
                                _controller.errorMessage!,
                                l10n,
                              ),
                              tone: colorScheme.errorContainer,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _controller.refresh,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.profileRefreshAction),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _ProfileSectionCard(
                            title: l10n.pick(
                              vi: 'Thông tin chính',
                              en: 'Main info',
                            ),
                            child: Column(
                              children: [
                                _ProfileDetailRow(
                                  label: l10n.memberNicknameLabel,
                                  value: _blankIfMissing(
                                    displayProfile.nickName,
                                  ),
                                ),
                                _ProfileDetailRow(
                                  label: l10n.memberPhoneLabel,
                                  value: _blankIfMissing(
                                    displayProfile.phoneE164,
                                  ),
                                  trailing: MemberPhoneActionIconButton(
                                    phoneNumber: displayProfile.phoneE164 ?? '',
                                    contactName: displayProfile.displayName,
                                  ),
                                ),
                                _ProfileDetailRow(
                                  label: l10n.memberEmailLabel,
                                  value: _blankIfMissing(displayProfile.email),
                                ),
                                _ProfileDetailRow(
                                  label: l10n.memberJobTitleLabel,
                                  value: _blankIfMissing(
                                    displayProfile.jobTitle,
                                  ),
                                ),
                                _ProfileDetailRow(
                                  label: l10n.memberAddressLabel,
                                  value: _blankIfMissing(
                                    displayProfile.addressText,
                                  ),
                                  trailing: AddressDirectionIconButton(
                                    address: displayProfile.addressText ?? '',
                                    label: displayProfile.displayName,
                                  ),
                                ),
                                _ProfileDetailRow(
                                  label: l10n.memberBioLabel,
                                  value: _blankIfMissing(displayProfile.bio),
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ProfileSectionCard(
                            title: l10n.pick(
                              vi: 'Liên hệ & mạng xã hội',
                              en: 'Contacts & social links',
                            ),
                            child: displayProfile.socialLinks.isEmpty
                                ? Text(
                                    l10n.memberSocialLinksEmptyDescription,
                                    style: theme.textTheme.bodyMedium,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (displayProfile
                                                  .socialLinks
                                                  .facebook !=
                                              null)
                                            SocialLinkActionIconButton(
                                              platform: SocialPlatform.facebook,
                                              rawValue: displayProfile
                                                  .socialLinks
                                                  .facebook!,
                                            ),
                                          if (displayProfile.socialLinks.zalo !=
                                              null)
                                            SocialLinkActionIconButton(
                                              platform: SocialPlatform.zalo,
                                              rawValue: displayProfile
                                                  .socialLinks
                                                  .zalo!,
                                            ),
                                          if (displayProfile
                                                  .socialLinks
                                                  .linkedin !=
                                              null)
                                            SocialLinkActionIconButton(
                                              platform: SocialPlatform.linkedin,
                                              rawValue: displayProfile
                                                  .socialLinks
                                                  .linkedin!,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _ProfileSectionCard(
                            title: l10n.pick(vi: 'Tùy chọn', en: 'Preferences'),
                            child: _ProfileCompactMenuTile(
                              icon: Icons.tune_rounded,
                              title: l10n.pick(
                                vi: 'Mở cài đặt',
                                en: 'Open settings',
                              ),
                              subtitle: l10n.pick(
                                vi: 'Ngôn ngữ: $languageLabel',
                                en: 'Language: $languageLabel',
                              ),
                              onTap: _openSettings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _SettingsScreenShell extends StatelessWidget {
  const _SettingsScreenShell({
    required this.controller,
    required this.session,
    required this.localeController,
    required this.showTestAction,
    required this.isSendingTestNotification,
    required this.isSendingEventReminderTest,
    required this.accountDeletionRequestState,
    required this.isLoadingAccountDeletionStatus,
    required this.isSubmittingAccountDeletionRequest,
    required this.isOpeningPrivacyChoices,
    this.billingRepository,
    this.onBillingStateChanged,
    required this.onLogoutRequested,
    this.onSendTestNotification,
    this.onSendEventReminderTest,
    this.onOpenPrivacyChoices,
    this.onRequestAccountDeletion,
    required this.formatInlineTimestamp,
  });

  final ProfileController controller;
  final AuthSession session;
  final AppLocaleController localeController;
  final bool showTestAction;
  final bool isSendingTestNotification;
  final bool isSendingEventReminderTest;
  final AccountDeletionRequestState accountDeletionRequestState;
  final bool isLoadingAccountDeletionStatus;
  final bool isSubmittingAccountDeletionRequest;
  final bool isOpeningPrivacyChoices;
  final BillingRepository? billingRepository;
  final VoidCallback? onBillingStateChanged;
  final Future<void> Function()? onLogoutRequested;
  final Future<void> Function()? onSendTestNotification;
  final Future<void> Function()? onSendEventReminderTest;
  final Future<void> Function()? onOpenPrivacyChoices;
  final Future<void> Function()? onRequestAccountDeletion;
  final String Function(String isoString) formatInlineTimestamp;

  Future<void> _confirmLogout(BuildContext context) async {
    if (onLogoutRequested == null) {
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.profileLogoutDialogTitle),
          content: Text(l10n.profileSettingsLogoutDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shellLogout),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await onLogoutRequested?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: Listenable.merge([controller, localeController]),
      builder: (context, _) {
        final selectedLanguageCode = localeController.locale.languageCode;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.profileSettingsTitle)),
          body: SafeArea(
            child: AppWorkspaceViewport(
              child: ListView(
                padding: appWorkspacePagePadding(context, top: 16, bottom: 32),
                children: [
                  _NotificationSettingsHeroCard(
                    controller: controller,
                    showTestAction: showTestAction,
                    isSendingTestNotification: isSendingTestNotification,
                    isSendingEventReminderTest: isSendingEventReminderTest,
                    onSendTestNotification: onSendTestNotification,
                    onSendEventReminderTest: onSendEventReminderTest,
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionCard(
                    title: l10n.notificationSettingsTitle,
                    child: _NotificationSettingsPanel(controller: controller),
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionCard(
                    title: l10n.profileLanguageSectionTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          showSelectedIcon: true,
                          segments: [
                            ButtonSegment<String>(
                              value: 'vi',
                              label: Text(
                                l10n.profileLanguageVietnamese,
                                key: const Key('profile-language-option-vi'),
                              ),
                            ),
                            ButtonSegment<String>(
                              value: 'en',
                              label: Text(
                                l10n.profileLanguageEnglish,
                                key: const Key('profile-language-option-en'),
                              ),
                            ),
                          ],
                          selected: {selectedLanguageCode},
                          onSelectionChanged: (selected) {
                            if (selected.isEmpty) {
                              return;
                            }
                            unawaited(
                              localeController.updateLanguageCode(
                                selected.first,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionCard(
                    title: l10n.pick(vi: 'Gói của bạn', en: 'Your plan'),
                    child: _BillingSettingsHub(
                      session: session,
                      billingRepository: billingRepository,
                      onBillingStateChanged: onBillingStateChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProfileSectionCard(
                    title: l10n.pick(
                      vi: 'Quyền riêng tư và dữ liệu',
                      en: 'Privacy & data',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (accountDeletionRequestState.hasPendingRequest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _InlineStatusBadge(
                              icon: Icons.verified_user_outlined,
                              label: l10n.pick(
                                vi: 'Đã nhận yêu cầu xóa tài khoản',
                                en: 'Account deletion request received',
                              ),
                            ),
                          )
                        else if (isLoadingAccountDeletionStatus)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _InlineStatusBadge(
                              icon: Icons.sync_rounded,
                              label: l10n.pick(
                                vi: 'Đang kiểm tra trạng thái tài khoản',
                                en: 'Checking account status',
                              ),
                            ),
                          ),
                        Text(
                          l10n.pick(
                            vi: 'Bạn có thể xem lại lựa chọn quyền riêng tư cho quảng cáo và gửi yêu cầu xóa tài khoản ngay trong app.',
                            en: 'You can revisit ad privacy choices and request account deletion directly in the app.',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (accountDeletionRequestState.requestedAtIso != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.pick(
                                vi: 'Yêu cầu gần nhất: ${formatInlineTimestamp(accountDeletionRequestState.requestedAtIso!)}',
                                en: 'Latest request: ${formatInlineTimestamp(accountDeletionRequestState.requestedAtIso!)}',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isOpeningPrivacyChoices
                                ? null
                                : onOpenPrivacyChoices,
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: AppStableLoadingChild(
                              isLoading: isOpeningPrivacyChoices,
                              child: Text(
                                l10n.pick(
                                  vi: 'Cập nhật lựa chọn quyền riêng tư',
                                  en: 'Update privacy choices',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                accountDeletionRequestState.hasPendingRequest ||
                                    isSubmittingAccountDeletionRequest
                                ? null
                                : onRequestAccountDeletion,
                            icon: const Icon(Icons.delete_outline_rounded),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            label: AppStableLoadingChild(
                              isLoading: isSubmittingAccountDeletionRequest,
                              child: Text(
                                accountDeletionRequestState.hasPendingRequest
                                    ? l10n.pick(
                                        vi: 'Đã gửi yêu cầu xóa',
                                        en: 'Deletion request sent',
                                      )
                                    : l10n.pick(
                                        vi: 'Yêu cầu xóa tài khoản',
                                        en: 'Request account deletion',
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onLogoutRequested != null) ...[
                    const SizedBox(height: 16),
                    _ProfileSectionCard(
                      title: l10n.profileAccountSectionTitle,
                      child: AppWorkspaceSurface(
                        padding: const EdgeInsets.all(16),
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.38,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _confirmLogout(context),
                                icon: const Icon(Icons.logout),
                                label: Text(l10n.shellLogout),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BillingSettingsHub extends StatefulWidget {
  const _BillingSettingsHub({
    required this.session,
    this.billingRepository,
    this.onBillingStateChanged,
  });

  final AuthSession session;
  final BillingRepository? billingRepository;
  final VoidCallback? onBillingStateChanged;

  @override
  State<_BillingSettingsHub> createState() => _BillingSettingsHubState();
}

class _BillingSettingsHubState extends State<_BillingSettingsHub> {
  late final BillingRepository _billingRepository;
  late Future<_BillingSettingsSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _billingRepository =
        widget.billingRepository ??
        createDefaultBillingRepository(session: widget.session);
    _snapshotFuture = _loadSnapshot();
  }

  Future<_BillingSettingsSnapshot> _loadSnapshot() async {
    try {
      final workspace = await _billingRepository.loadWorkspace(
        session: widget.session,
      );
      return _BillingSettingsSnapshot.fromWorkspace(workspace);
    } on BillingRepositoryException catch (error) {
      if (_shouldFallbackToViewer(error)) {
        final summary = await _billingRepository.loadViewerSummary(
          session: widget.session,
        );
        return _BillingSettingsSnapshot.fromViewerSummary(summary);
      }
      rethrow;
    }
  }

  bool _shouldFallbackToViewer(BillingRepositoryException error) {
    if (error.code == BillingRepositoryErrorCode.permissionDenied) {
      return true;
    }
    if (error.code == BillingRepositoryErrorCode.failedPrecondition) {
      final lower = (error.message ?? '').toLowerCase();
      if (lower.contains('owner') ||
          lower.contains('billing scope') ||
          lower.contains('clan billing')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _openBillingWorkspace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BillingWorkspacePage(
          session: widget.session,
          repository: _billingRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    widget.onBillingStateChanged?.call();
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _openBillingDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BillingDetailsPage(
          session: widget.session,
          repository: _billingRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    widget.onBillingStateChanged?.call();
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  String _planLabel(_BillingSettingsSnapshot snapshot, AppLocalizations l10n) {
    return switch (snapshot.planCode.trim().toUpperCase()) {
      'BASE' => l10n.pick(vi: 'Gói Cơ bản', en: 'Base plan'),
      'PLUS' => l10n.pick(vi: 'Gói Plus', en: 'Plus plan'),
      'PRO' => l10n.pick(vi: 'Gói Pro', en: 'Pro plan'),
      _ => l10n.pick(vi: 'Gói Miễn phí', en: 'Free plan'),
    };
  }

  String _statusLabel(
    _BillingSettingsSnapshot snapshot,
    AppLocalizations l10n,
  ) {
    return switch (snapshot.status.trim().toLowerCase()) {
      'active' => l10n.pick(vi: 'Đang hoạt động', en: 'Active'),
      'grace_period' => l10n.pick(vi: 'Ân hạn', en: 'Grace period'),
      'pending_payment' => l10n.pick(vi: 'Chờ thanh toán', en: 'Pending'),
      'expired' => l10n.pick(vi: 'Hết hạn', en: 'Expired'),
      _ => snapshot.status,
    };
  }

  String _expiresLabel(
    _BillingSettingsSnapshot snapshot,
    AppLocalizations l10n,
  ) {
    final iso = snapshot.expiresAtIso;
    if (iso == null || iso.trim().isEmpty) {
      return l10n.pick(vi: 'Chưa có mốc', en: 'No date yet');
    }
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) {
      return iso;
    }
    final day = '${parsed.day}'.padLeft(2, '0');
    final month = '${parsed.month}'.padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<_BillingSettingsSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final hasResolvedQuota = data?.aiUsageSummary.hasResolvedQuota ?? false;
        final progress = hasResolvedQuota
            ? (data?.aiUsageSummary.usageProgress ?? 0.0)
            : 0.0;
        final remainingCredits = hasResolvedQuota
            ? data?.aiUsageSummary.remainingCredits
            : null;
        final quotaCredits = hasResolvedQuota
            ? data?.aiUsageSummary.quotaCredits
            : null;
        final isNearLimit =
            data != null &&
            data.aiUsageSummary.hasResolvedQuota &&
            data.aiUsageSummary.remainingCredits > 0 &&
            data.aiUsageSummary.usageProgress >= 0.8;
        final isExhausted =
            data != null && data.aiUsageSummary.isExhausted;
        final statusLabel = data == null ? null : _statusLabel(data, l10n);
        final nextCycleLabel = data == null ? null : _expiresLabel(data, l10n);

        return AppWorkspaceSurface(
          padding: const EdgeInsets.all(14),
          color: Colors.white.withValues(alpha: 0.82),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _planLabel(data, l10n),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.canManage
                                ? l10n.pick(
                                    vi: 'Đang áp dụng cho tài khoản này.',
                                    en: 'Currently applied to this account.',
                                  )
                                : l10n.pick(
                                    vi: 'Thông tin gói hiện tại.',
                                    en: 'Current plan information.',
                                  ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(data, l10n),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BillingSettingsMiniStat(
                        label: l10n.pick(vi: 'AI còn lại', en: 'AI left'),
                        value: hasResolvedQuota
                            ? l10n.pick(
                                vi: '${remainingCredits ?? 0} lượt',
                                en: '${remainingCredits ?? 0} left',
                              )
                            : l10n.pick(
                                vi: 'Đang cập nhật',
                                en: 'Updating',
                              ),
                        hint: hasResolvedQuota
                            ? l10n.pick(
                                vi: '/ ${quotaCredits ?? 0} trong tháng',
                                en: '/ ${quotaCredits ?? 0} this month',
                              )
                            : l10n.pick(
                                vi: 'Lượt AI sẽ hiện sau khi đồng bộ',
                                en: 'AI usage will appear after sync',
                              ),
                        accentColor: isExhausted
                            ? colorScheme.error
                            : isNearLimit
                            ? colorScheme.tertiary
                            : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BillingSettingsMiniStat(
                        label: l10n.pick(vi: 'Kỳ tiếp theo', en: 'Next cycle'),
                        value: nextCycleLabel ?? '',
                        hint: statusLabel ?? '',
                        accentColor: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (hasResolvedQuota) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isExhausted
                            ? colorScheme.error
                            : isNearLimit
                            ? colorScheme.tertiary
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                if (isExhausted || isNearLimit) ...[
                  const SizedBox(height: 8),
                  Text(
                    isExhausted
                        ? l10n.pick(
                            vi: 'Bạn đã dùng hết lượt AI tháng này. Nâng gói để dùng tiếp ngay.',
                            en: 'You have used up this month’s AI help. Upgrade to continue right away.',
                          )
                        : l10n.pick(
                            vi: 'Bạn sắp chạm giới hạn tháng này.',
                            en: 'You are getting close to this month’s limit.',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else if (snapshot.hasError) ...[
                Text(
                  l10n.pick(
                    vi: 'Không tải được tóm tắt gói lúc này.',
                    en: 'Unable to load the plan summary right now.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.pick(
                          vi: 'Đang tải gói của bạn...',
                          en: 'Loading your plan...',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openBillingWorkspace,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    data?.canManage == false
                        ? l10n.pick(
                            vi: 'Xem gói hiện tại',
                            en: 'View current plan',
                          )
                        : l10n.pick(
                            vi: 'Đổi hoặc nâng cấp',
                            en: 'Change or upgrade',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openBillingDetails,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(
                    l10n.pick(vi: 'AI và thanh toán', en: 'AI and billing'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BillingSettingsSnapshot {
  const _BillingSettingsSnapshot({
    required this.planCode,
    required this.status,
    required this.expiresAtIso,
    required this.aiUsageSummary,
    required this.canManage,
  });

  factory _BillingSettingsSnapshot.fromWorkspace(
    BillingWorkspaceSnapshot workspace,
  ) {
    return _BillingSettingsSnapshot(
      planCode: workspace.entitlement.planCode,
      status: workspace.entitlement.status,
      expiresAtIso:
          workspace.entitlement.expiresAtIso ??
          workspace.subscription.expiresAtIso,
      aiUsageSummary: workspace.aiUsageSummary,
      canManage: true,
    );
  }

  factory _BillingSettingsSnapshot.fromViewerSummary(
    BillingViewerSummary summary,
  ) {
    return _BillingSettingsSnapshot(
      planCode: summary.entitlement.planCode,
      status: summary.entitlement.status,
      expiresAtIso:
          summary.entitlement.expiresAtIso ?? summary.subscription.expiresAtIso,
      aiUsageSummary: summary.aiUsageSummary,
      canManage: false,
    );
  }

  final String planCode;
  final String status;
  final String? expiresAtIso;
  final BillingAiUsageSummary aiUsageSummary;
  final bool canManage;
}

class _BillingSettingsMiniStat extends StatelessWidget {
  const _BillingSettingsMiniStat({
    required this.label,
    required this.value,
    required this.hint,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String hint;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsPanel extends StatelessWidget {
  const _NotificationSettingsPanel({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final prefs = controller.notificationPreferences;
    final l10n = context.l10n;
    final isSaving = controller.isSavingNotificationPreferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSaving)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineStatusBadge(
              icon: Icons.sync_rounded,
              label: l10n.notificationSettingsSavingBadge,
            ),
          ),
        _NotificationPreferenceGroup(
          title: l10n.notificationSettingsChannelsSectionTitle,
          child: Column(
            children: [
              _NotificationPreferenceTile(
                icon: Icons.mark_email_unread_outlined,
                title: l10n.notificationSettingsEmailChannel,
                subtitle: l10n.notificationSettingsEmailChannelHint,
                value: prefs.emailEnabled,
                isLast: false,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(
                          controller.updateEmailEnabledPreference(value),
                        );
                      },
              ),
              _NotificationPreferenceTile(
                icon: Icons.bedtime_outlined,
                title: l10n.notificationSettingsQuietHours,
                subtitle: l10n.notificationSettingsQuietHoursHint,
                value: prefs.quietHoursEnabled,
                isLast: true,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(controller.updateQuietHoursPreference(value));
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _NotificationPreferenceGroup(
          title: l10n.notificationSettingsTopicsSectionTitle,
          child: Column(
            children: [
              _NotificationPreferenceTile(
                icon: Icons.event_note_outlined,
                title: l10n.notificationSettingsEventUpdates,
                subtitle: l10n.notificationSettingsEventUpdatesHint,
                value: prefs.eventReminders,
                isLast: false,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(
                          controller.updateEventRemindersPreference(value),
                        );
                      },
              ),
              _NotificationPreferenceTile(
                icon: Icons.school_outlined,
                title: l10n.notificationSettingsScholarshipUpdates,
                subtitle: l10n.notificationSettingsScholarshipUpdatesHint,
                value: prefs.scholarshipUpdates,
                isLast: false,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(
                          controller.updateScholarshipUpdatesPreference(value),
                        );
                      },
              ),
              _NotificationPreferenceTile(
                icon: Icons.account_balance_wallet_outlined,
                title: l10n.profileNotificationFundAlerts,
                subtitle: l10n.profileNotificationFundAlertsHint,
                value: prefs.fundTransactions,
                isLast: false,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(
                          controller.updateFundTransactionsPreference(value),
                        );
                      },
              ),
              _NotificationPreferenceTile(
                icon: Icons.groups_2_outlined,
                title: l10n.notificationSettingsGeneralUpdates,
                subtitle: l10n.notificationSettingsGeneralUpdatesHint,
                value: prefs.systemNotices,
                isLast: true,
                onChanged: isSaving
                    ? null
                    : (value) {
                        unawaited(
                          controller.updateSystemNoticesPreference(value),
                        );
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationSettingsHeroCard extends StatelessWidget {
  const _NotificationSettingsHeroCard({
    required this.controller,
    required this.showTestAction,
    required this.isSendingTestNotification,
    required this.isSendingEventReminderTest,
    this.onSendTestNotification,
    this.onSendEventReminderTest,
  });

  final ProfileController controller;
  final bool showTestAction;
  final bool isSendingTestNotification;
  final bool isSendingEventReminderTest;
  final Future<void> Function()? onSendTestNotification;
  final Future<void> Function()? onSendEventReminderTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = controller.notificationPreferences;
    final l10n = context.l10n;

    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(20),
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Thông báo gia đình', en: 'Family notifications'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          AppWorkspaceSurface(
            color: Colors.white.withValues(alpha: 0.82),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.92,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    prefs.pushEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notificationSettingsPushChannel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pick(
                          vi: 'Nhận nhắc việc và cập nhật ngay trên điện thoại.',
                          en: 'Receive reminders and key updates on this phone.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch.adaptive(
                  value: prefs.pushEnabled,
                  onChanged: controller.isSavingNotificationPreferences
                      ? null
                      : (value) {
                          unawaited(
                            controller.updatePushEnabledPreference(value),
                          );
                        },
                ),
              ],
            ),
          ),
          if (showTestAction) ...[
            const SizedBox(height: 12),
            AppWorkspaceSurface(
              color: Colors.white.withValues(alpha: 0.76),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.pick(
                      vi: 'Kiểm tra trên máy này',
                      en: 'Test on this device',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.pick(
                      vi: 'BeFam có thể gửi một push nhanh hoặc một nhắc sự kiện để bạn kiểm tra notification thật trên máy này.',
                      en: 'BeFam can send a quick push or an event reminder so you can verify notifications on a real device.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: isSendingTestNotification
                            ? null
                            : onSendTestNotification,
                        icon: const Icon(Icons.send_to_mobile_rounded),
                        label: AppStableLoadingChild(
                          isLoading: isSendingTestNotification,
                          child: Text(
                            context.l10n.pick(
                              vi: 'Push ngay',
                              en: 'Quick push',
                            ),
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: isSendingEventReminderTest
                            ? null
                            : onSendEventReminderTest,
                        icon: const Icon(Icons.event_available_rounded),
                        label: AppStableLoadingChild(
                          isLoading: isSendingEventReminderTest,
                          child: Text(
                            context.l10n.pick(
                              vi: 'Nhắc sự kiện',
                              en: 'Event reminder',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationPreferenceGroup extends StatelessWidget {
  const _NotificationPreferenceGroup({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppWorkspaceSurface(
      color: Colors.white.withValues(alpha: 0.74),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _NotificationPreferenceTile extends StatelessWidget {
  const _NotificationPreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

class _InlineStatusBadge extends StatelessWidget {
  const _InlineStatusBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCompactMenuTile extends StatelessWidget {
  const _ProfileCompactMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AppWorkspaceSurface(
          color: Colors.white.withValues(alpha: 0.76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.onEditProfile,
    this.onAvatarTap,
    this.isUploadingAvatar = false,
    this.showAvatarActionBadge = true,
  });

  final MemberProfile profile;
  final VoidCallback onEditProfile;
  final VoidCallback? onAvatarTap;
  final bool isUploadingAvatar;
  final bool showAvatarActionBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final bio = (profile.bio ?? '').trim();
    final jobTitle = (profile.jobTitle ?? '').trim();
    final resolvedSubtitle = bio.isNotEmpty
        ? bio
        : jobTitle.isNotEmpty
        ? jobTitle
        : '';

    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(24),
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onAvatarTap,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  backgroundImage: profile.hasAvatar
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.hasAvatar
                      ? null
                      : Text(
                          profile.initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (showAvatarActionBadge)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (isUploadingAvatar)
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        profile.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.memberEditAction,
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit_outlined),
                      color: colorScheme.onSurface,
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (resolvedSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    resolvedSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AvatarAction { view, upload }

class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({
    required this.session,
    required this.initialDraft,
    required this.isSaving,
    required this.onSubmit,
    required this.aiAssistService,
    this.billingRepository,
  });

  final AuthSession session;
  final ProfileDraft initialDraft;
  final bool isSaving;
  final Future<MemberRepositoryErrorCode?> Function(ProfileDraft draft)
  onSubmit;
  final AiAssistService aiAssistService;
  final BillingRepository? billingRepository;

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _nickNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _bioController;
  late final TextEditingController _facebookController;
  late final TextEditingController _zaloController;
  late final TextEditingController _linkedinController;
  late final FocusNode _nickNameFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _addressFocusNode;
  late final FocusNode _jobTitleFocusNode;
  late final FocusNode _bioFocusNode;
  late final FocusNode _facebookFocusNode;
  late final AiProductAnalyticsService _aiAnalyticsService;
  late String _phoneCountryIsoCode;
  bool _resolvedAutoPhoneCountry = false;

  MemberRepositoryErrorCode? _submitError;
  ProfileAiReview? _aiReview;
  bool _isSubmitting = false;
  bool _isReviewingWithAi = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.initialDraft.fullName,
    );
    _nickNameController = TextEditingController(
      text: widget.initialDraft.nickName,
    );
    _phoneCountryIsoCode = PhoneNumberFormatter.inferCountryOption(
      widget.initialDraft.phoneInput,
    ).isoCode;
    _phoneController = TextEditingController(
      text: PhoneNumberFormatter.toNationalInput(
        widget.initialDraft.phoneInput,
        defaultCountryIso: _phoneCountryIsoCode,
      ),
    );
    _emailController = TextEditingController(text: widget.initialDraft.email);
    _addressController = TextEditingController(
      text: widget.initialDraft.addressText,
    );
    _jobTitleController = TextEditingController(
      text: widget.initialDraft.jobTitle,
    );
    _bioController = TextEditingController(text: widget.initialDraft.bio);
    _facebookController = TextEditingController(
      text: widget.initialDraft.facebook,
    );
    _zaloController = TextEditingController(text: widget.initialDraft.zalo);
    _linkedinController = TextEditingController(
      text: widget.initialDraft.linkedin,
    );
    _nickNameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _addressFocusNode = FocusNode();
    _jobTitleFocusNode = FocusNode();
    _bioFocusNode = FocusNode();
    _facebookFocusNode = FocusNode();
    _aiAnalyticsService = createDefaultAiProductAnalyticsService();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nickNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    _facebookController.dispose();
    _zaloController.dispose();
    _linkedinController.dispose();
    _nickNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _addressFocusNode.dispose();
    _jobTitleFocusNode.dispose();
    _bioFocusNode.dispose();
    _facebookFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedAutoPhoneCountry || _phoneController.text.trim().isNotEmpty) {
      return;
    }
    final locale = Localizations.localeOf(context);
    _phoneCountryIsoCode = PhoneNumberFormatter.autoCountryIsoFromRegion(
      locale.countryCode,
    );
    _resolvedAutoPhoneCountry = true;
  }

  void _normalizePhoneInputForCountry() {
    final normalized = PhoneNumberFormatter.toNationalInput(
      _phoneController.text,
      defaultCountryIso: _phoneCountryIsoCode,
    );
    if (normalized == _phoneController.text.trim()) {
      return;
    }
    _phoneController
      ..text = normalized
      ..selection = TextSelection.collapsed(offset: normalized.length);
  }

  ProfileDraft _currentDraft() {
    final trimmedPhone = _phoneController.text.trim();
    final normalizedPhone = trimmedPhone.isEmpty
        ? ''
        : PhoneNumberFormatter.tryParseE164(
                trimmedPhone,
                defaultCountryIso: _phoneCountryIsoCode,
              ) ??
              trimmedPhone;
    return ProfileDraft(
      fullName: _fullNameController.text.trim(),
      nickName: _nickNameController.text.trim(),
      phoneInput: normalizedPhone,
      email: _emailController.text.trim(),
      addressText: _addressController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      bio: _bioController.text.trim(),
      facebook: _facebookController.text.trim(),
      zalo: _zaloController.text.trim(),
      linkedin: _linkedinController.text.trim(),
    );
  }

  List<ProfileQualityCheckActionTarget> _qualityCheckActions() {
    return buildProfileQualityCheckActions(_currentDraft());
  }

  String _quickFixLabel(
    BuildContext context,
    ProfileQualityCheckActionTarget target,
  ) {
    final l10n = context.l10n;
    return switch (target) {
      ProfileQualityCheckActionTarget.nickname => l10n.pick(
        vi: 'Thêm tên thường gọi',
        en: 'Add a familiar nickname',
      ),
      ProfileQualityCheckActionTarget.jobTitle => l10n.pick(
        vi: 'Thêm nghề nghiệp hiện tại',
        en: 'Add your current role',
      ),
      ProfileQualityCheckActionTarget.bio => l10n.pick(
        vi: 'Thêm vài dòng giới thiệu',
        en: 'Add a short intro',
      ),
      ProfileQualityCheckActionTarget.contact => l10n.pick(
        vi: 'Thêm cách liên hệ',
        en: 'Add a contact method',
      ),
      ProfileQualityCheckActionTarget.address => l10n.pick(
        vi: 'Thêm khu vực đang sống',
        en: 'Add your area',
      ),
      ProfileQualityCheckActionTarget.social => l10n.pick(
        vi: 'Thêm một mạng xã hội',
        en: 'Add one social link',
      ),
    };
  }

  String _quickFixTargetId(ProfileQualityCheckActionTarget target) {
    return switch (target) {
      ProfileQualityCheckActionTarget.nickname => 'nickname',
      ProfileQualityCheckActionTarget.jobTitle => 'job_title',
      ProfileQualityCheckActionTarget.bio => 'bio',
      ProfileQualityCheckActionTarget.contact => 'contact',
      ProfileQualityCheckActionTarget.address => 'address',
      ProfileQualityCheckActionTarget.social => 'social',
    };
  }

  void _applyQuickFix(ProfileQualityCheckActionTarget target) {
    final focusNode = switch (target) {
      ProfileQualityCheckActionTarget.nickname => _nickNameFocusNode,
      ProfileQualityCheckActionTarget.jobTitle => _jobTitleFocusNode,
      ProfileQualityCheckActionTarget.bio => _bioFocusNode,
      ProfileQualityCheckActionTarget.contact =>
        _phoneController.text.trim().isEmpty
            ? _phoneFocusNode
            : _emailFocusNode,
      ProfileQualityCheckActionTarget.address => _addressFocusNode,
      ProfileQualityCheckActionTarget.social => _facebookFocusNode,
    };
    unawaited(
      _aiAnalyticsService.trackProfileQuickFixSelected(
        target: _quickFixTargetId(target),
      ),
    );
    FocusScope.of(context).requestFocus(focusNode);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    _normalizePhoneInputForCountry();
    final trimmedPhone = _phoneController.text.trim();
    final normalizedPhone = trimmedPhone.isEmpty
        ? ''
        : PhoneNumberFormatter.parse(
            trimmedPhone,
            defaultCountryIso: _phoneCountryIsoCode,
          ).e164;

    final error = await widget.onSubmit(
      ProfileDraft(
        fullName: _fullNameController.text.trim(),
        nickName: _nickNameController.text.trim(),
        phoneInput: normalizedPhone,
        email: _emailController.text.trim(),
        addressText: _addressController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        bio: _bioController.text.trim(),
        facebook:
            normalizeSocialLinkForStorage(
              SocialPlatform.facebook,
              _facebookController.text,
            ) ??
            '',
        zalo:
            normalizeSocialLinkForStorage(
              SocialPlatform.zalo,
              _zaloController.text,
            ) ??
            '',
        linkedin:
            normalizeSocialLinkForStorage(
              SocialPlatform.linkedin,
              _linkedinController.text,
            ) ??
            '',
      ),
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submitError = error;
    });
  }

  Future<void> _reviewWithAi() async {
    if (_isSubmitting || widget.isSaving || _isReviewingWithAi) {
      return;
    }

    final locale = Localizations.localeOf(context).languageCode;
    final l10n = context.l10n;
    final draft = _currentDraft();
    final aiStopwatch = Stopwatch()..start();
    unawaited(
      _aiAnalyticsService.trackProfileCheckRequested(
        hasPhone: draft.phoneInput.trim().isNotEmpty,
        hasEmail: draft.email.trim().isNotEmpty,
        hasBio: draft.bio.trim().isNotEmpty,
        socialLinkCount: [
          draft.facebook,
          draft.zalo,
          draft.linkedin,
        ].where((value) => value.trim().isNotEmpty).length,
      ),
    );
    setState(() {
      _isReviewingWithAi = true;
    });

    try {
      final review = await widget.aiAssistService.reviewProfileDraft(
        session: widget.session,
        locale: locale,
        draft: ProfileDraft(
          fullName: draft.fullName.trim().isEmpty
              ? l10n.pick(vi: 'Hồ sơ chưa có tên', en: 'Unnamed profile')
              : draft.fullName.trim(),
          nickName: draft.nickName,
          phoneInput: draft.phoneInput,
          email: draft.email,
          addressText: draft.addressText,
          jobTitle: draft.jobTitle,
          bio: draft.bio,
          facebook: draft.facebook,
          zalo: draft.zalo,
          linkedin: draft.linkedin,
        ),
      );
      aiStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        _aiAnalyticsService.trackProfileCheckCompleted(
          usedFallback: review.usedFallback,
          missingCount: review.missingImportant.length,
          riskCount: review.risks.length,
          nextActionCount: review.nextActions.length,
          elapsedMs: aiStopwatch.elapsedMilliseconds,
        ),
      );
      setState(() {
        _aiReview = review;
      });
    } on AiAssistServiceException catch (error) {
      aiStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        _aiAnalyticsService.trackProfileCheckFailed(
          reason: error.code ?? 'unknown',
          elapsedMs: aiStopwatch.elapsedMilliseconds,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isReviewingWithAi = false;
        });
      } else {
        _isReviewingWithAi = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final phoneHint = PhoneNumberFormatter.nationalNumberHint(
      _phoneCountryIsoCode,
    );
    final socialLinkCount = [
      _facebookController.text,
      _zaloController.text,
      _linkedinController.text,
    ].where((value) => value.trim().isNotEmpty).length;
    final quickFixActions = _qualityCheckActions();

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 32,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: AppWorkspaceSurface(
                    padding: const EdgeInsets.all(20),
                    gradient: appWorkspaceHeroGradient(context),
                    showAccentOrbs: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.profileEditSheetTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _EditorBadge(
                              icon: Icons.badge_outlined,
                              label: l10n.pick(
                                vi: 'Thông tin chính',
                                en: 'Core info',
                              ),
                            ),
                            _EditorBadge(
                              icon: Icons.call_outlined,
                              label: l10n.pick(vi: 'Liên hệ', en: 'Contact'),
                            ),
                            _EditorBadge(
                              icon: Icons.share_outlined,
                              label: l10n.pick(
                                vi: '$socialLinkCount mạng xã hội',
                                en: '$socialLinkCount socials',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _EditorSectionCard(
                  title: l10n.pick(
                    vi: 'Kiểm tra nhanh hồ sơ',
                    en: 'Quick profile check',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          vi: 'Rà nhanh các chi tiết còn thiếu để người thân nhận ra bạn dễ hơn và hồ sơ đáng tin hơn.',
                          en: 'Run a quick check for the details that make your profile easier to recognize and trust.',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.pick(
                          vi: 'AI chỉ dùng các tín hiệu cần thiết của hồ sơ nháp để kiểm tra, không dùng toàn bộ dữ liệu liên hệ thô.',
                          en: 'AI only uses the draft signals needed for this check, not the full raw contact details.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AiUsageQuotaNotice(
                        session: widget.session,
                        billingRepository: widget.billingRepository,
                        requestCost: 1,
                        compact: true,
                        usageHint: l10n.pick(
                          vi: 'Lượt kiểm tra này dùng 1 credit AI.',
                          en: 'This profile check uses 1 AI credit.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          key: const Key('profile-quality-check-button'),
                          onPressed:
                              (_isSubmitting ||
                                  widget.isSaving ||
                                  _isReviewingWithAi)
                              ? null
                              : _reviewWithAi,
                          icon: _isReviewingWithAi
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            _isReviewingWithAi
                                ? l10n.pick(
                                    vi: 'Đang phân tích...',
                                    en: 'Checking...',
                                  )
                                : l10n.pick(
                                    vi: 'Kiểm tra hồ sơ này',
                                    en: 'Check this profile',
                                  ),
                          ),
                        ),
                      ),
                      if (_isReviewingWithAi) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.pick(
                            vi: 'Đang tạo gợi ý, thường mất vài giây.',
                            en: 'Checking the draft now. This usually takes a few seconds.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_aiReview != null) ...[
                        const SizedBox(height: 14),
                        AppWorkspaceSurface(
                          padding: const EdgeInsets.all(14),
                          color: Colors.white.withValues(alpha: 0.76),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _aiReview!.summary,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_aiReview!.usedFallback) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.pick(
                                    vi: 'Hôm nay đang dùng chế độ kiểm tra nội bộ để giữ kết quả ổn định.',
                                    en: 'Using the built-in quality check mode to keep the guidance stable today.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (quickFixActions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.pick(
                                    vi: 'Sửa nhanh các chỗ dễ thiếu',
                                    en: 'Quick fixes',
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final action in quickFixActions)
                                      OutlinedButton.icon(
                                        key: Key(
                                          'profile-quick-fix-${_quickFixTargetId(action)}',
                                        ),
                                        onPressed: () => _applyQuickFix(action),
                                        icon: const Icon(
                                          Icons.edit_note_outlined,
                                        ),
                                        label: Text(
                                          _quickFixLabel(context, action),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (_aiReview!.strengths.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _AiAdviceGroup(
                                  title: l10n.pick(
                                    vi: 'Điểm đã ổn',
                                    en: 'What already works',
                                  ),
                                  items: _aiReview!.strengths,
                                ),
                              ],
                              if (_aiReview!.missingImportant.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _AiAdviceGroup(
                                  title: l10n.pick(
                                    vi: 'Nên bổ sung',
                                    en: 'Worth adding',
                                  ),
                                  items: _aiReview!.missingImportant,
                                ),
                              ],
                              if (_aiReview!.risks.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _AiAdviceGroup(
                                  title: l10n.pick(
                                    vi: 'Chỗ cần lưu ý',
                                    en: 'Watchouts',
                                  ),
                                  items: _aiReview!.risks,
                                ),
                              ],
                              if (_aiReview!.nextActions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _AiAdviceGroup(
                                  title: l10n.pick(
                                    vi: 'Bước tiếp theo',
                                    en: 'Next steps',
                                  ),
                                  items: _aiReview!.nextActions,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _ProfileInfoCard(
                    icon: Icons.error_outline,
                    title: l10n.profileSaveErrorTitle,
                    description: _memberErrorMessage(l10n, _submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 16),
                _EditorSectionCard(
                  title: l10n.pick(vi: 'Thông tin chính', en: 'Core details'),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('profile-full-name-field'),
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: l10n.memberFullNameLabel,
                        ),
                        validator: (value) {
                          return value == null || value.trim().isEmpty
                              ? l10n.memberValidationNameRequired
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-nickname-field'),
                        focusNode: _nickNameFocusNode,
                        controller: _nickNameController,
                        decoration: InputDecoration(
                          labelText: l10n.memberNicknameLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-job-title-field'),
                        focusNode: _jobTitleFocusNode,
                        controller: _jobTitleController,
                        decoration: InputDecoration(
                          labelText: l10n.memberJobTitleLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-bio-field'),
                        focusNode: _bioFocusNode,
                        controller: _bioController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: l10n.memberBioLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _EditorSectionCard(
                  title: l10n.pick(vi: 'Liên hệ', en: 'Contact'),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhoneCountrySelectorField(
                            selectedIsoCode: _phoneCountryIsoCode,
                            enabled: !_isSubmitting,
                            onChanged: (value) {
                              setState(() {
                                _phoneCountryIsoCode = value;
                                _normalizePhoneInputForCountry();
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              key: const Key('profile-phone-field'),
                              focusNode: _phoneFocusNode,
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: l10n.memberPhoneLabel,
                                hintText: phoneHint,
                              ),
                              keyboardType: TextInputType.phone,
                              onEditingComplete: _normalizePhoneInputForCountry,
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return null;
                                }
                                try {
                                  PhoneNumberFormatter.parse(
                                    trimmed,
                                    defaultCountryIso: _phoneCountryIsoCode,
                                  );
                                  return null;
                                } catch (_) {
                                  return l10n.memberValidationPhoneInvalid;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-email-field'),
                        focusNode: _emailFocusNode,
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: l10n.memberEmailLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AddressAutocompleteField(
                        key: const Key('profile-address-field'),
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        maxLines: 2,
                        labelText: l10n.memberAddressLabel,
                        hintText: l10n.pick(
                          vi: 'Số nhà, đường, phường/xã, quận/huyện...',
                          en: 'Street, ward, district...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _EditorSectionCard(
                  title: l10n.memberSocialLinksTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const Key('profile-facebook-field'),
                        focusNode: _facebookFocusNode,
                        controller: _facebookController,
                        decoration: InputDecoration(
                          labelText: l10n.profileFacebookUrlLabel,
                          hintText: l10n.pick(
                            vi: 'Tên tài khoản hoặc URL',
                            en: 'Username or profile URL',
                          ),
                          prefixIcon: const Icon(Icons.facebook),
                          suffixIcon: SocialLinkFieldConnectButton(
                            platform: SocialPlatform.facebook,
                            controller: _facebookController,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-zalo-field'),
                        controller: _zaloController,
                        decoration: InputDecoration(
                          labelText: l10n.profileZaloUrlLabel,
                          hintText: l10n.pick(
                            vi: 'Tên tài khoản hoặc URL',
                            en: 'Username or profile URL',
                          ),
                          prefixIcon: const Icon(Icons.forum_outlined),
                          suffixIcon: SocialLinkFieldConnectButton(
                            platform: SocialPlatform.zalo,
                            controller: _zaloController,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('profile-linkedin-field'),
                        controller: _linkedinController,
                        decoration: InputDecoration(
                          labelText: l10n.profileLinkedinUrlLabel,
                          hintText: l10n.pick(
                            vi: 'Tên tài khoản hoặc URL',
                            en: 'Username or profile URL',
                          ),
                          prefixIcon: const Icon(Icons.work_outline),
                          suffixIcon: SocialLinkFieldConnectButton(
                            platform: SocialPlatform.linkedin,
                            controller: _linkedinController,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                AppWorkspaceSurface(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isSubmitting || widget.isSaving)
                          ? null
                          : _submit,
                      icon: (_isSubmitting || widget.isSaving)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        (_isSubmitting || widget.isSaving)
                            ? l10n.profileSavingAction
                            : l10n.memberSaveAction,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AiAdviceGroup extends StatelessWidget {
  const _AiAdviceGroup({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.trailing,
  });

  final String label;
  final String value;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Align(alignment: Alignment.centerRight, child: trailing!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceSurface(
      color: tone,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSectionCard extends StatelessWidget {
  const _EditorSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EditorBadge extends StatelessWidget {
  const _EditorBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  const _AvatarActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppWorkspaceSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: Colors.white.withValues(alpha: 0.76),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String _displayOrFallback(String value, {String? fallback}) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  final fallbackTrimmed = (fallback ?? '').trim();
  if (fallbackTrimmed.isNotEmpty) {
    return fallbackTrimmed;
  }
  return '';
}

String _blankIfMissing(String? value) {
  return (value ?? '').trim();
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _normalizeUnlinkedFullName({
  required String draftValue,
  required String fallbackValue,
  required AppLocalizations l10n,
}) {
  final draft = draftValue.trim();
  if (draft.isNotEmpty && !_looksLikeUnlinkedPlaceholder(draft)) {
    return draft;
  }
  final fallback = fallbackValue.trim();
  if (fallback.isNotEmpty && !_looksLikeUnlinkedPlaceholder(fallback)) {
    return fallback;
  }
  return l10n.pick(vi: 'Chưa cập nhật tên', en: 'Name not added yet');
}

bool _looksLikeUnlinkedPlaceholder(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('chưa vào gia phả') ||
      normalized.contains('chưa liên kết') ||
      normalized.contains('not linked') ||
      normalized.contains('unlinked');
}

class _UnlinkedProfileDraftStore {
  const _UnlinkedProfileDraftStore();

  static const String _draftKeyPrefix = 'befam.profile.unlinkedDraft';

  Future<ProfileDraft?> read({required String sessionUid}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_keyForUid(sessionUid));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return ProfileDraft(
        fullName: _asText(payload['fullName']),
        nickName: _asText(payload['nickName']),
        phoneInput: _asText(payload['phoneInput']),
        email: _asText(payload['email']),
        addressText: _asText(payload['addressText']),
        jobTitle: _asText(payload['jobTitle']),
        bio: _asText(payload['bio']),
        facebook: _asText(payload['facebook']),
        zalo: _asText(payload['zalo']),
        linkedin: _asText(payload['linkedin']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String sessionUid,
    required ProfileDraft draft,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _keyForUid(sessionUid),
      jsonEncode({
        'fullName': draft.fullName,
        'nickName': draft.nickName,
        'phoneInput': draft.phoneInput,
        'email': draft.email,
        'addressText': draft.addressText,
        'jobTitle': draft.jobTitle,
        'bio': draft.bio,
        'facebook': draft.facebook,
        'zalo': draft.zalo,
        'linkedin': draft.linkedin,
      }),
    );
  }

  String _keyForUid(String sessionUid) {
    final normalized = sessionUid.trim();
    return '$_draftKeyPrefix.${normalized.isEmpty ? 'unknown' : normalized}';
  }
}

String _asText(Object? value) {
  return value is String ? value : '';
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceViewport(
      child: Padding(
        padding: appWorkspacePagePadding(context, top: 20),
        child: AppWorkspaceSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyProfileErrorMessage(String raw, AppLocalizations l10n) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return l10n.pick(
      vi: 'Không thể tải hồ sơ lúc này. Vui lòng thử lại.',
      en: 'Could not load profile right now. Please try again.',
    );
  }
  if (normalized.contains('permission_denied') ||
      normalized.contains('permission denied')) {
    return l10n.pick(
      vi: 'Bạn chưa có quyền cập nhật hồ sơ này.',
      en: 'You do not have permission to update this profile.',
    );
  }
  if (normalized.contains('network') ||
      normalized.contains('unavailable') ||
      normalized.contains('timeout') ||
      normalized.contains('deadline')) {
    return l10n.pick(
      vi: 'Kết nối đang gián đoạn. Vui lòng kiểm tra mạng rồi thử lại.',
      en: 'Connection is unstable. Please check your network and try again.',
    );
  }
  return l10n.pick(
    vi: 'Cập nhật hồ sơ chưa thành công. Vui lòng thử lại sau.',
    en: 'Profile update failed. Please try again later.',
  );
}

String _memberErrorMessage(
  AppLocalizations l10n,
  MemberRepositoryErrorCode code,
) {
  return switch (code) {
    MemberRepositoryErrorCode.duplicatePhone => l10n.memberDuplicatePhoneError,
    MemberRepositoryErrorCode.planLimitExceeded =>
      l10n.memberPlanLimitExceededError,
    MemberRepositoryErrorCode.permissionDenied =>
      l10n.memberPermissionDeniedError,
    MemberRepositoryErrorCode.memberNotFound => l10n.memberNotFoundDescription,
    MemberRepositoryErrorCode.avatarUploadFailed =>
      l10n.memberAvatarUploadError,
  };
}

String _trimOrFallback(String value, String fallback) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return fallback.trim();
}
