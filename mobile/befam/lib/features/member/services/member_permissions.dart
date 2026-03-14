import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/member_profile.dart';

class MemberPermissions {
  const MemberPermissions({
    required this.canViewWorkspace,
    required this.canCreateMembers,
    required this.canEditAnyMember,
    required this.canViewAllMembers,
    required this.canEditOwnProfile,
    required this.restrictedBranchId,
    required this.sessionMemberId,
    required this.sessionBranchId,
  });

  final bool canViewWorkspace;
  final bool canCreateMembers;
  final bool canEditAnyMember;
  final bool canViewAllMembers;
  final bool canEditOwnProfile;
  final String? restrictedBranchId;
  final String? sessionMemberId;
  final String? sessionBranchId;

  bool get isReadOnly =>
      canViewWorkspace && !canCreateMembers && !canEditAnyMember;

  bool get canEditOrganizationFields => canEditAnyMember;

  factory MemberPermissions.forSession(AuthSession session) {
    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final isClaimedSession =
        session.accessMode == AuthMemberAccessMode.claimed &&
        session.linkedAuthUid &&
        hasClanContext;

    final canEditOwn =
        isClaimedSession && (session.memberId?.isNotEmpty ?? false);
    final isSuperOrClanAdmin =
        isClaimedSession && const {'SUPER_ADMIN', 'CLAN_ADMIN'}.contains(role);
    final isBranchAdmin =
        isClaimedSession &&
        role == 'BRANCH_ADMIN' &&
        (session.branchId?.isNotEmpty ?? false);

    return MemberPermissions(
      canViewWorkspace: hasClanContext,
      canCreateMembers: isSuperOrClanAdmin || isBranchAdmin,
      canEditAnyMember: isSuperOrClanAdmin || isBranchAdmin,
      canViewAllMembers: isSuperOrClanAdmin,
      canEditOwnProfile: canEditOwn,
      restrictedBranchId: isBranchAdmin ? session.branchId : null,
      sessionMemberId: session.memberId,
      sessionBranchId: session.branchId,
    );
  }

  bool canManageBranch(String? branchId) {
    if (canEditAnyMember) {
      if (restrictedBranchId == null) {
        return branchId != null && branchId.isNotEmpty;
      }

      return restrictedBranchId == branchId;
    }

    if (branchId == null || branchId.isEmpty) {
      return false;
    }

    return sessionBranchId != null && sessionBranchId == branchId;
  }

  bool canViewMember(MemberProfile member, AuthSession session) {
    if (!canViewWorkspace) {
      return false;
    }

    if (canViewAllMembers) {
      return true;
    }

    if (canEditAnyMember) {
      return canManageBranch(member.branchId);
    }

    return session.memberId != null && session.memberId == member.id;
  }

  bool canEditMember(MemberProfile member, AuthSession session) {
    if (canEditAnyMember && canManageBranch(member.branchId)) {
      return true;
    }

    return canEditOwnProfile && session.memberId == member.id;
  }

  bool canUploadAvatar(MemberProfile member, AuthSession session) {
    return canEditMember(member, session);
  }

  bool canCreateInBranch(String? branchId) {
    return canCreateMembers && canManageBranch(branchId);
  }
}
