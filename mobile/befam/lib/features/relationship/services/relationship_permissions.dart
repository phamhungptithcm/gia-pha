import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
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
    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    final hasClaimedAdminAccess =
        session.accessMode == AuthMemberAccessMode.claimed &&
        session.linkedAuthUid &&
        (session.clanId?.isNotEmpty ?? false) &&
        const {'SUPER_ADMIN', 'CLAN_ADMIN', 'BRANCH_ADMIN'}.contains(role);

    return RelationshipPermissions(
      canEditSensitiveRelationships: hasClaimedAdminAccess,
      clanScope: session.clanId,
      branchScope: role == 'BRANCH_ADMIN' ? session.branchId : null,
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
