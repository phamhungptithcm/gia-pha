import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/services/clan_permissions.dart';
import 'package:befam/features/events/services/event_permissions.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/services/member_permissions.dart';
import 'package:befam/features/relationship/services/relationship_permissions.dart';
import 'package:befam/features/scholarship/services/scholarship_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClanPermissions', () {
    test('clan admin can edit clan settings and manage branches', () {
      final permissions = ClanPermissions.forSession(
        _session(primaryRole: 'CLAN_ADMIN'),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canEditClanSettings, isTrue);
      expect(permissions.canManageBranches, isTrue);
      expect(permissions.canAssignLeadership, isTrue);
      expect(permissions.isReadOnly, isFalse);
    });

    test('branch admin can manage branches but cannot edit clan settings', () {
      final permissions = ClanPermissions.forSession(
        _session(primaryRole: 'BRANCH_ADMIN'),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canEditClanSettings, isFalse);
      expect(permissions.canManageBranches, isTrue);
      expect(permissions.canAssignLeadership, isTrue);
    });

    test('unlinked session is read-only even with admin role label', () {
      final permissions = ClanPermissions.forSession(
        _session(
          primaryRole: 'CLAN_ADMIN',
          accessMode: AuthMemberAccessMode.unlinked,
          linkedAuthUid: false,
        ),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canEditClanSettings, isFalse);
      expect(permissions.canManageBranches, isFalse);
      expect(permissions.isReadOnly, isTrue);
    });
  });

  group('MemberPermissions', () {
    test('branch admin is restricted to own branch for member management', () {
      final permissions = MemberPermissions.forSession(
        _session(primaryRole: 'BRANCH_ADMIN', branchId: 'branch-1'),
      );

      expect(permissions.canCreateMembers, isTrue);
      expect(permissions.canEditAnyMember, isTrue);
      expect(permissions.canManageBranch('branch-1'), isTrue);
      expect(permissions.canManageBranch('branch-2'), isFalse);
      expect(permissions.canCreateInBranch('branch-2'), isFalse);
    });

    test('regular claimed member can edit and view only own profile', () {
      final session = _session(
        primaryRole: 'MEMBER',
        memberId: 'member-self',
        branchId: 'branch-2',
      );
      final permissions = MemberPermissions.forSession(session);
      final self = _member(id: 'member-self', branchId: 'branch-2');
      final other = _member(id: 'member-other', branchId: 'branch-2');

      expect(permissions.canEditAnyMember, isFalse);
      expect(permissions.canEditOwnProfile, isTrue);
      expect(permissions.canEditMember(self, session), isTrue);
      expect(permissions.canEditMember(other, session), isFalse);
      expect(permissions.canViewMember(self, session), isTrue);
      expect(permissions.canViewMember(other, session), isFalse);
    });

    test('super admin can view all members but requires non-empty branch id to manage branch write actions', () {
      final permissions = MemberPermissions.forSession(
        _session(primaryRole: 'SUPER_ADMIN'),
      );

      expect(permissions.canViewAllMembers, isTrue);
      expect(permissions.canManageBranch('branch-9'), isTrue);
      expect(permissions.canManageBranch(''), isFalse);
      expect(permissions.canManageBranch(null), isFalse);
    });
  });

  group('RelationshipPermissions', () {
    test('branch admin can mutate only members within own branch', () {
      final permissions = RelationshipPermissions.forSession(
        _session(primaryRole: 'BRANCH_ADMIN', branchId: 'branch-1'),
      );
      final first = _member(id: 'm1', branchId: 'branch-1');
      final second = _member(id: 'm2', branchId: 'branch-1');
      final third = _member(id: 'm3', branchId: 'branch-2');

      expect(permissions.canEditSensitiveRelationships, isTrue);
      expect(permissions.canMutateBetween(first, second), isTrue);
      expect(permissions.canMutateBetween(first, third), isFalse);
    });

    test('unlinked session cannot mutate relationships even with admin role', () {
      final permissions = RelationshipPermissions.forSession(
        _session(
          primaryRole: 'CLAN_ADMIN',
          accessMode: AuthMemberAccessMode.unlinked,
          linkedAuthUid: false,
        ),
      );

      expect(permissions.canEditSensitiveRelationships, isFalse);
      expect(
        permissions.canMutateBetween(
          _member(id: 'm1', branchId: 'branch-1'),
          _member(id: 'm2', branchId: 'branch-1'),
        ),
        isFalse,
      );
    });
  });

  group('EventPermissions', () {
    test('claimed admins can manage events', () {
      final permissions = EventPermissions.forSession(
        _session(primaryRole: 'CLAN_ADMIN'),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canManageEvents, isTrue);
      expect(permissions.isReadOnly, isFalse);
    });

    test('members are read-only in event workspace', () {
      final permissions = EventPermissions.forSession(
        _session(primaryRole: 'MEMBER'),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canManageEvents, isFalse);
      expect(permissions.isReadOnly, isTrue);
    });
  });

  group('ScholarshipPermissions', () {
    test('claimed member can submit but cannot manage programs', () {
      final permissions = ScholarshipPermissions.forSession(
        _session(primaryRole: 'MEMBER'),
      );

      expect(permissions.canViewWorkspace, isTrue);
      expect(permissions.canSubmitSubmissions, isTrue);
      expect(permissions.canManagePrograms, isFalse);
      expect(permissions.canReviewQueue, isFalse);
    });

    test('branch admin can manage scholarship programs and review queue', () {
      final permissions = ScholarshipPermissions.forSession(
        _session(primaryRole: 'BRANCH_ADMIN'),
      );

      expect(permissions.canManagePrograms, isTrue);
      expect(permissions.canReviewQueue, isTrue);
    });
  });
}

AuthSession _session({
  String primaryRole = 'MEMBER',
  String? clanId = 'clan-1',
  String? branchId = 'branch-1',
  String? memberId = 'member-1',
  AuthMemberAccessMode accessMode = AuthMemberAccessMode.claimed,
  bool linkedAuthUid = true,
}) {
  return AuthSession(
    uid: 'debug:user',
    loginMethod: AuthEntryMethod.phone,
    phoneE164: '+84900000000',
    displayName: 'Debug User',
    clanId: clanId,
    branchId: branchId,
    memberId: memberId,
    primaryRole: primaryRole,
    accessMode: accessMode,
    linkedAuthUid: linkedAuthUid,
    isSandbox: true,
    signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
  );
}

MemberProfile _member({
  required String id,
  String clanId = 'clan-1',
  String branchId = 'branch-1',
}) {
  return MemberProfile(
    id: id,
    clanId: clanId,
    branchId: branchId,
    fullName: 'Member $id',
    normalizedFullName: 'member $id',
    nickName: '',
    gender: null,
    birthDate: null,
    deathDate: null,
    phoneE164: null,
    email: null,
    addressText: null,
    jobTitle: null,
    avatarUrl: null,
    bio: null,
    socialLinks: const MemberSocialLinks(),
    parentIds: const [],
    childrenIds: const [],
    spouseIds: const [],
    generation: 1,
    primaryRole: 'MEMBER',
    status: 'active',
    isMinor: false,
    authUid: null,
  );
}
