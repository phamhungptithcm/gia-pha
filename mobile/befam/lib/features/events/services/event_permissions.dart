import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';

class EventPermissions {
  const EventPermissions({
    required this.canViewWorkspace,
    required this.canManageEvents,
    required this.sessionBranchId,
  });

  final bool canViewWorkspace;
  final bool canManageEvents;
  final String? sessionBranchId;

  bool get isReadOnly => canViewWorkspace && !canManageEvents;

  factory EventPermissions.forSession(AuthSession session) {
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final canManage = GovernanceRoleMatrix.canManageEvents(session);

    return EventPermissions(
      canViewWorkspace: hasClanContext,
      canManageEvents: canManage,
      sessionBranchId: session.branchId,
    );
  }
}
