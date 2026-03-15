import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';

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
    final hasClanContext = (session.clanId?.isNotEmpty ?? false);
    final canEditClanSettings = GovernanceRoleMatrix.canManageClanSettings(
      session,
    );
    final canManageBranches = GovernanceRoleMatrix.canManageBranches(session);

    return ClanPermissions(
      canViewWorkspace: hasClanContext,
      canEditClanSettings: canEditClanSettings,
      canManageBranches: canManageBranches,
      canAssignLeadership: canManageBranches,
    );
  }
}
