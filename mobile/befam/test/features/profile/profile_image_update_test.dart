import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/models/member_workspace_snapshot.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:befam/features/profile/models/profile_notification_preferences.dart';
import 'package:befam/features/profile/presentation/profile_controller.dart';
import 'package:befam/features/profile/services/profile_notification_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({
    String memberId = 'member_demo_001',
    String uid = 'debug:+84901234567',
    String clanId = 'clan_demo_001',
    String branchId = 'branch_demo_001',
    String primaryRole = 'MEMBER',
    AuthMemberAccessMode accessMode = AuthMemberAccessMode.claimed,
    bool linkedAuthUid = true,
  }) {
    return AuthSession(
      uid: uid,
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: memberId,
      clanId: clanId,
      branchId: branchId,
      primaryRole: primaryRole,
      accessMode: accessMode,
      linkedAuthUid: linkedAuthUid,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  MemberProfile buildProfile({String? avatarUrl}) {
    return MemberProfile(
      id: 'member_demo_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      fullName: 'Nguyễn Minh',
      normalizedFullName: 'nguyễn minh',
      nickName: 'Minh',
      gender: 'male',
      birthDate: '1988-02-14',
      deathDate: null,
      phoneE164: '+84901234567',
      email: 'minh@befam.vn',
      addressText: 'Đà Nẵng, Việt Nam',
      jobTitle: 'Điều phối viên',
      avatarUrl: avatarUrl,
      bio: 'Hồ sơ mẫu.',
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      generation: 4,
      primaryRole: 'MEMBER',
      status: 'active',
      isMinor: false,
      authUid: 'debug:+84901234567',
    );
  }

  test('uploads avatar and updates profile state', () async {
    final repository = _FakeMemberRepository(profile: buildProfile());
    final preferencesRepository =
        _FakeProfileNotificationPreferencesRepository();
    final controller = ProfileController(
      memberRepository: repository,
      session: buildSession(),
      notificationPreferencesRepository: preferencesRepository,
    );

    await controller.initialize();
    expect(controller.profile?.avatarUrl, isNull);

    final result = await controller.uploadAvatar(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'avatar.jpg',
      contentType: 'image/jpeg',
    );

    expect(result, isNull);
    expect(repository.uploadCalls, 1);
    expect(controller.profile?.avatarUrl, startsWith('debug://avatar/'));
  });

  test(
    'returns member_not_found when session member cannot be resolved',
    () async {
      final repository = _FakeMemberRepository(profile: buildProfile());
      final preferencesRepository =
          _FakeProfileNotificationPreferencesRepository();
      final controller = ProfileController(
        memberRepository: repository,
        session: buildSession(
          memberId: 'missing_member',
          uid: 'debug:+84000000000',
        ),
        notificationPreferencesRepository: preferencesRepository,
      );

      await controller.initialize();
      expect(controller.profile, isNull);

      final result = await controller.uploadAvatar(
        bytes: Uint8List.fromList(const [4, 5, 6]),
        fileName: 'avatar.jpg',
        contentType: 'image/jpeg',
      );

      expect(result, MemberRepositoryErrorCode.memberNotFound);
      expect(repository.uploadCalls, 0);
    },
  );

  test('maps repository upload failure to avatar_upload_failed', () async {
    final repository = _FakeMemberRepository(
      profile: buildProfile(),
      failUpload: true,
    );
    final preferencesRepository =
        _FakeProfileNotificationPreferencesRepository();
    final controller = ProfileController(
      memberRepository: repository,
      session: buildSession(),
      notificationPreferencesRepository: preferencesRepository,
    );

    await controller.initialize();

    final result = await controller.uploadAvatar(
      bytes: Uint8List.fromList(const [7, 8, 9]),
      fileName: 'avatar.jpg',
      contentType: 'image/jpeg',
    );

    expect(result, MemberRepositoryErrorCode.avatarUploadFailed);
    expect(repository.uploadCalls, 1);
  });

  test(
    'loads notification preferences from repository during initialize',
    () async {
      final repository = _FakeMemberRepository(profile: buildProfile());
      final preferencesRepository =
          _FakeProfileNotificationPreferencesRepository(
            initial: const ProfileNotificationPreferences(
              eventReminders: false,
              scholarshipUpdates: true,
              fundTransactions: false,
              systemNotices: true,
              quietHoursEnabled: true,
            ),
          );
      final controller = ProfileController(
        memberRepository: repository,
        session: buildSession(),
        notificationPreferencesRepository: preferencesRepository,
      );

      await controller.initialize();

      expect(controller.notificationPreferences.eventReminders, isFalse);
      expect(controller.notificationPreferences.fundTransactions, isFalse);
      expect(controller.notificationPreferences.quietHoursEnabled, isTrue);
    },
  );

  test('persists notification preference updates via repository', () async {
    final repository = _FakeMemberRepository(profile: buildProfile());
    final preferencesRepository =
        _FakeProfileNotificationPreferencesRepository();
    final controller = ProfileController(
      memberRepository: repository,
      session: buildSession(),
      notificationPreferencesRepository: preferencesRepository,
    );

    await controller.initialize();
    await controller.updateEventRemindersPreference(false);
    await controller.updateQuietHoursPreference(true);

    expect(preferencesRepository.saveCalls, 2);
    expect(controller.notificationPreferences.eventReminders, isFalse);
    expect(controller.notificationPreferences.quietHoursEnabled, isTrue);
  });

  test(
    'unlinked session skips remote profile and preference loading',
    () async {
      final repository = _FakeMemberRepository(profile: buildProfile());
      final preferencesRepository =
          _FakeProfileNotificationPreferencesRepository();
      final controller = ProfileController(
        memberRepository: repository,
        session: buildSession(
          memberId: '',
          clanId: '',
          branchId: '',
          primaryRole: 'GUEST',
          accessMode: AuthMemberAccessMode.unlinked,
          linkedAuthUid: false,
        ),
        notificationPreferencesRepository: preferencesRepository,
      );

      await controller.initialize();

      expect(controller.profile, isNull);
      expect(controller.errorMessage, isNull);
      expect(
        controller.notificationPreferences,
        const ProfileNotificationPreferences(),
      );
      expect(repository.loadWorkspaceCalls, 0);
      expect(preferencesRepository.loadCalls, 0);
    },
  );
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({required this.profile, this.failUpload = false});

  MemberProfile profile;
  final bool failUpload;
  int uploadCalls = 0;
  int loadWorkspaceCalls = 0;

  @override
  bool get isSandbox => true;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    loadWorkspaceCalls += 1;
    return MemberWorkspaceSnapshot(members: [profile], branches: const []);
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) async {
    profile = profile.copyWith(
      fullName: draft.fullName,
      nickName: draft.nickName,
      phoneE164: draft.phoneInput,
      email: draft.email,
      addressText: draft.addressText,
      jobTitle: draft.jobTitle,
      bio: draft.bio,
      socialLinks: draft.socialLinks,
    );
    return profile;
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    uploadCalls += 1;
    if (failUpload) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.avatarUploadFailed,
      );
    }

    profile = profile.copyWith(avatarUrl: 'debug://avatar/$memberId/$fileName');
    return profile;
  }

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {}
}

class _FakeProfileNotificationPreferencesRepository
    implements ProfileNotificationPreferencesRepository {
  _FakeProfileNotificationPreferencesRepository({
    ProfileNotificationPreferences? initial,
  }) : _preferences = initial ?? const ProfileNotificationPreferences();

  ProfileNotificationPreferences _preferences;
  int saveCalls = 0;
  int loadCalls = 0;

  @override
  bool get isSandbox => true;

  @override
  Future<ProfileNotificationPreferences> load({
    required AuthSession session,
  }) async {
    loadCalls += 1;
    return _preferences;
  }

  @override
  Future<ProfileNotificationPreferences> save({
    required AuthSession session,
    required ProfileNotificationPreferences preferences,
  }) async {
    saveCalls += 1;
    _preferences = preferences;
    return preferences;
  }
}
