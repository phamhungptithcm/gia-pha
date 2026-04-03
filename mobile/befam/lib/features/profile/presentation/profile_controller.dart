import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../../member/models/member_draft.dart';
import '../../member/models/member_profile.dart';
import '../../member/models/member_social_links.dart';
import '../../member/services/member_repository.dart';
import '../models/profile_draft.dart';
import '../models/profile_notification_preferences.dart';
import '../services/profile_notification_preferences_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required MemberRepository memberRepository,
    required AuthSession session,
    ProfileNotificationPreferencesRepository? notificationPreferencesRepository,
  }) : _memberRepository = memberRepository,
       _session = session,
       _notificationPreferencesRepository =
           notificationPreferencesRepository ??
           createDefaultProfileNotificationPreferencesRepository(
             session: session,
           );

  final MemberRepository _memberRepository;
  final AuthSession _session;
  final ProfileNotificationPreferencesRepository
  _notificationPreferencesRepository;

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isSavingNotificationPreferences = false;
  String? _errorMessage;
  MemberProfile? _profile;
  ProfileNotificationPreferences _notificationPreferences =
      const ProfileNotificationPreferences();

  bool get isLoading => _isLoading;
  bool get isSavingProfile => _isSavingProfile;
  bool get isUploadingAvatar => _isUploadingAvatar;
  bool get isSavingNotificationPreferences => _isSavingNotificationPreferences;
  String? get errorMessage => _errorMessage;
  MemberProfile? get profile => _profile;
  ProfileNotificationPreferences get notificationPreferences =>
      _notificationPreferences;

  bool get hasMemberContext {
    final clanId = (_session.clanId ?? '').trim();
    final memberId = (_session.memberId ?? '').trim();
    return clanId.isNotEmpty && memberId.isNotEmpty;
  }

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!hasMemberContext) {
      _notificationPreferences = const ProfileNotificationPreferences();
      _profile = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    String? failureMessage;
    final preferencesFuture = _notificationPreferencesRepository.load(
      session: _session,
    );
    final workspaceFuture = _memberRepository.loadWorkspace(session: _session);

    try {
      _notificationPreferences = await preferencesFuture;
    } catch (error) {
      failureMessage = error.toString();
    }

    try {
      final snapshot = await workspaceFuture;
      final memberId = _session.memberId!.trim();
      final uid = _session.uid.trim();
      _profile =
          snapshot.members.firstWhereOrNull(
            (member) => member.id == memberId,
          ) ??
          snapshot.members.firstWhereOrNull((member) => member.authUid == uid);
    } catch (error) {
      failureMessage = error.toString();
      _profile = null;
    } finally {
      _errorMessage = failureMessage;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MemberRepositoryErrorCode?> saveProfile(ProfileDraft draft) async {
    final existing = _profile;
    if (existing == null) {
      return MemberRepositoryErrorCode.memberNotFound;
    }

    _isSavingProfile = true;
    _errorMessage = null;
    notifyListeners();

    final payload = MemberDraft.fromProfile(existing).copyWith(
      fullName: draft.fullName.trim(),
      nickName: draft.nickName.trim(),
      phoneInput: draft.phoneInput.trim(),
      email: draft.email.trim(),
      addressText: draft.addressText.trim(),
      jobTitle: draft.jobTitle.trim(),
      bio: draft.bio.trim(),
      socialLinks: MemberSocialLinks(
        facebook: _nullableTrim(draft.facebook),
        zalo: _nullableTrim(draft.zalo),
        linkedin: _nullableTrim(draft.linkedin),
      ),
    );

    try {
      final updated = await _memberRepository.saveMember(
        session: _session,
        memberId: existing.id,
        draft: payload,
      );
      _profile = updated;
      return null;
    } on MemberRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }

  Future<MemberRepositoryErrorCode?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final existing = _profile;
    if (existing == null) {
      return MemberRepositoryErrorCode.memberNotFound;
    }

    _isUploadingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _memberRepository.uploadAvatar(
        session: _session,
        memberId: existing.id,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      _profile = updated;
      return null;
    } on MemberRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> updateEventRemindersPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(eventReminders: enabled),
    );
  }

  Future<void> updatePushEnabledPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(pushEnabled: enabled),
    );
  }

  Future<void> updateEmailEnabledPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(emailEnabled: enabled),
    );
  }

  Future<void> updateScholarshipUpdatesPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(scholarshipUpdates: enabled),
    );
  }

  Future<void> updateFundTransactionsPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(fundTransactions: enabled),
    );
  }

  Future<void> updateSystemNoticesPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(systemNotices: enabled),
    );
  }

  Future<void> updateQuietHoursPreference(bool enabled) {
    return _updateNotificationPreference(
      _notificationPreferences.copyWith(quietHoursEnabled: enabled),
    );
  }

  Future<void> _updateNotificationPreference(
    ProfileNotificationPreferences next,
  ) async {
    if (_isSavingNotificationPreferences) {
      return;
    }

    final previous = _notificationPreferences;
    _notificationPreferences = next;
    _isSavingNotificationPreferences = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notificationPreferences = await _notificationPreferencesRepository.save(
        session: _session,
        preferences: next,
      );
    } catch (error) {
      _notificationPreferences = previous;
      _errorMessage = error.toString();
    } finally {
      _isSavingNotificationPreferences = false;
      notifyListeners();
    }
  }
}

String? _nullableTrim(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
