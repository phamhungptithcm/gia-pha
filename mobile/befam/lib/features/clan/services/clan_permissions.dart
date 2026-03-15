import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';

class ClanPermissions {
  const ClanPermissions({
    required this.canViewWorkspace,
    required this.canEditClanSettings,
    required this.canManageBranches,
    required this.canAssignLeadership,
    required this.canBootstrapClan,
  });

  final bool canViewWorkspace;
  final bool canEditClanSettings;
  final bool canManageBranches;
  final bool canAssignLeadership;
  final bool canBootstrapClan;

  bool get isReadOnly =>
      canViewWorkspace && !canEditClanSettings && !canManageBranches;

  factory ClanPermissions.forSession(AuthSession session) {
    final hasClanContext = (session.clanId?.isNotEmpty ?? false);
    final canBootstrapClan = GovernanceRoleMatrix.canBootstrapClan(session);
    final canEditClanSettings = hasClanContext
        ? GovernanceRoleMatrix.canManageClanSettings(session)
        : canBootstrapClan;
    final canManageBranches = hasClanContext
        ? GovernanceRoleMatrix.canManageBranches(session)
        : false;

    return ClanPermissions(
      canViewWorkspace: hasClanContext || canBootstrapClan,
      canEditClanSettings: canEditClanSettings,
      canManageBranches: canManageBranches,
      canAssignLeadership: canManageBranches,
      canBootstrapClan: canBootstrapClan,
    );
  }
}
