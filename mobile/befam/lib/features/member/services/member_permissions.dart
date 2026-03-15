import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';
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
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final isClaimedSession = GovernanceRoleMatrix.isClaimedClanSession(session);
    final role = GovernanceRoleMatrix.normalizeRole(session.primaryRole);

    final canEditOwn =
        isClaimedSession && (session.memberId?.isNotEmpty ?? false);
    final isSuperOrClanAdmin = isClaimedSession &&
        const {GovernanceRoles.superAdmin, GovernanceRoles.clanAdmin}.contains(
          role,
        );
    final isBranchAdmin = isClaimedSession &&
        role == GovernanceRoles.branchAdmin &&
        (session.branchId?.isNotEmpty ?? false);
    final isSupportStaff =
        isClaimedSession && role == GovernanceRoles.adminSupport;

    final canCreateMembers = isSuperOrClanAdmin || isBranchAdmin || isSupportStaff;
    final canEditAnyMember = isSuperOrClanAdmin || isBranchAdmin || isSupportStaff;
    final canViewAllMembers = isSuperOrClanAdmin || isSupportStaff;

    return MemberPermissions(
      canViewWorkspace: hasClanContext,
      canCreateMembers: canCreateMembers,
      canEditAnyMember: canEditAnyMember,
      canViewAllMembers: canViewAllMembers,
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
