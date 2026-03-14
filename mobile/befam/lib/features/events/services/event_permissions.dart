import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';

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
    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final isClaimedSession =
        session.accessMode == AuthMemberAccessMode.claimed &&
        session.linkedAuthUid &&
        hasClanContext;

    final canManage =
        isClaimedSession &&
        const {'SUPER_ADMIN', 'CLAN_ADMIN', 'BRANCH_ADMIN'}.contains(role);

    return EventPermissions(
      canViewWorkspace: hasClanContext,
      canManageEvents: canManage,
      sessionBranchId: session.branchId,
    );
  }
}
