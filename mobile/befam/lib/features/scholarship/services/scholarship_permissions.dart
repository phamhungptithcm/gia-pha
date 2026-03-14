import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';

class ScholarshipPermissions {
  const ScholarshipPermissions({
    required this.canViewWorkspace,
    required this.canManagePrograms,
    required this.canSubmitSubmissions,
    required this.canReviewQueue,
  });

  final bool canViewWorkspace;
  final bool canManagePrograms;
  final bool canSubmitSubmissions;
  final bool canReviewQueue;

  bool get isReadOnly =>
      canViewWorkspace && !canManagePrograms && !canSubmitSubmissions;

  factory ScholarshipPermissions.forSession(AuthSession session) {
    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final isClaimedSession =
        session.accessMode == AuthMemberAccessMode.claimed &&
        session.linkedAuthUid &&
        hasClanContext;

    final canManage =
        isClaimedSession &&
        const {'SUPER_ADMIN', 'CLAN_ADMIN', 'BRANCH_ADMIN'}.contains(role);
    final canSubmit =
        isClaimedSession && (session.memberId?.isNotEmpty ?? false);

    return ScholarshipPermissions(
      canViewWorkspace: hasClanContext,
      canManagePrograms: canManage,
      canSubmitSubmissions: canSubmit,
      canReviewQueue: canManage,
    );
  }
}
