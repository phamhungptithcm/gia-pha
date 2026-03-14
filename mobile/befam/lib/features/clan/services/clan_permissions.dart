import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';

class ClanPermissions {
  const ClanPermissions({
    required this.canViewWorkspace,
    required this.canEditClanSettings,
    required this.canManageBranches,
    required this.canAssignLeadership,
  });

  final bool canViewWorkspace;
  final bool canEditClanSettings;
  final bool canManageBranches;
  final bool canAssignLeadership;

  bool get isReadOnly =>
      canViewWorkspace && !canEditClanSettings && !canManageBranches;

  factory ClanPermissions.forSession(AuthSession session) {
    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    final hasClanContext = (session.clanId?.isNotEmpty ?? false);
    final isClaimedAdmin =
        session.accessMode == AuthMemberAccessMode.claimed &&
        hasClanContext &&
        session.linkedAuthUid;
    final canEditClanSettings =
        isClaimedAdmin && RoleCaseSet.contains(role, clanSettingsRoles);
    final canManageBranches =
        isClaimedAdmin && RoleCaseSet.contains(role, branchManagementRoles);

    return ClanPermissions(
      canViewWorkspace: hasClanContext,
      canEditClanSettings: canEditClanSettings,
      canManageBranches: canManageBranches,
      canAssignLeadership: canManageBranches,
    );
  }

  static const Set<String> clanSettingsRoles = {'SUPER_ADMIN', 'CLAN_ADMIN'};

  static const Set<String> branchManagementRoles = {
    'SUPER_ADMIN',
    'CLAN_ADMIN',
    'BRANCH_ADMIN',
  };
}

abstract final class RoleCaseSet {
  static bool contains(String value, Set<String> haystack) {
    return haystack.contains(value.toUpperCase());
  }
}
