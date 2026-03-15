import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../member/models/member_profile.dart';

class RelationshipPermissions {
  const RelationshipPermissions({
    required this.canEditSensitiveRelationships,
    required this.clanScope,
    required this.branchScope,
  });

  final bool canEditSensitiveRelationships;
  final String? clanScope;
  final String? branchScope;

  factory RelationshipPermissions.forSession(AuthSession session) {
    final role = GovernanceRoleMatrix.normalizeRole(session.primaryRole);
    final hasClaimedAdminAccess =
        GovernanceRoleMatrix.canEditSensitiveRelationships(session);

    return RelationshipPermissions(
      canEditSensitiveRelationships: hasClaimedAdminAccess,
      clanScope: session.clanId,
      branchScope: role == GovernanceRoles.branchAdmin ? session.branchId : null,
    );
  }

  bool canMutateBetween(MemberProfile first, MemberProfile second) {
    if (!canEditSensitiveRelationships || clanScope == null) {
      return false;
    }

    if (first.clanId != clanScope || second.clanId != clanScope) {
      return false;
    }

    if (branchScope == null) {
      return true;
    }

    return first.branchId == branchScope && second.branchId == branchScope;
  }
}
