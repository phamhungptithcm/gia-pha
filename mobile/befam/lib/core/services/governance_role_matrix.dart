import '../../features/auth/models/auth_member_access_mode.dart';
import '../../features/auth/models/auth_session.dart';

abstract final class GovernanceRoles {
  static const superAdmin = 'SUPER_ADMIN';
  static const clanAdmin = 'CLAN_ADMIN';
  static const clanOwner = 'CLAN_OWNER';
  static const clanLeader = 'CLAN_LEADER';
  static const branchAdmin = 'BRANCH_ADMIN';
  static const treasurer = 'TREASURER';
  static const scholarshipCouncilHead = 'SCHOLARSHIP_COUNCIL_HEAD';
  static const adminSupport = 'ADMIN_SUPPORT';
  static const member = 'MEMBER';
  static const guest = 'GUEST';

  static const genealogyManagers = <String>{
    superAdmin,
    clanAdmin,
    clanOwner,
    clanLeader,
    branchAdmin,
    adminSupport,
  };

  static const clanSettingsManagers = <String>{
    superAdmin,
    clanAdmin,
    clanOwner,
    clanLeader,
    adminSupport,
  };

  static const scholarshipManagers = <String>{
    superAdmin,
    clanAdmin,
    branchAdmin,
  };

  static const scholarshipReviewers = <String>{scholarshipCouncilHead};

  static const joinRequestReviewers = <String>{
    superAdmin,
    clanAdmin,
    branchAdmin,
    adminSupport,
    'CLAN_LEADER',
    'VICE_LEADER',
    'SUPPORTER_OF_LEADER',
  };

  static const financeViewers = <String>{
    superAdmin,
    clanAdmin,
    branchAdmin,
    treasurer,
  };

  static const financeManagers = <String>{superAdmin, clanAdmin, treasurer};
}

abstract final class GovernanceRoleMatrix {
  static String normalizeRole(String? role) {
    final trimmed = role?.trim().toUpperCase() ?? '';
    return trimmed.isEmpty ? GovernanceRoles.guest : trimmed;
  }

  static bool isClaimedClanSession(AuthSession session) {
    return session.accessMode == AuthMemberAccessMode.claimed &&
        session.linkedAuthUid &&
        (session.clanId?.trim().isNotEmpty ?? false);
  }

  static bool canManageClanSettings(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.clanSettingsManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canManageBranches(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.genealogyManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canManageMembers(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.genealogyManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canEditSensitiveRelationships(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.genealogyManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canManageEvents(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.genealogyManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canViewFinance(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.financeViewers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canManageFinance(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.financeManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canManageScholarshipPrograms(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.scholarshipManagers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canSubmitScholarship(AuthSession session) {
    return isClaimedClanSession(session) &&
        (session.memberId?.trim().isNotEmpty ?? false);
  }

  static bool canVoteScholarship(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.scholarshipReviewers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canViewScholarshipApprovalLogs(AuthSession session) {
    if (!isClaimedClanSession(session)) {
      return false;
    }
    final role = normalizeRole(session.primaryRole);
    return GovernanceRoles.scholarshipManagers.contains(role) ||
        GovernanceRoles.scholarshipReviewers.contains(role);
  }

  static bool canReviewJoinRequests(AuthSession session) {
    return isClaimedClanSession(session) &&
        GovernanceRoles.joinRequestReviewers.contains(
          normalizeRole(session.primaryRole),
        );
  }

  static bool canBootstrapClan(AuthSession session) {
    final noClanContext = (session.clanId?.trim().isEmpty ?? true);
    return noClanContext && session.accessMode == AuthMemberAccessMode.unlinked;
  }
}
