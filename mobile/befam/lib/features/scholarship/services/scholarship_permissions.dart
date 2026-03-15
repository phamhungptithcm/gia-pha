import '../../auth/models/auth_session.dart';
import '../../../core/services/governance_role_matrix.dart';

class ScholarshipPermissions {
  const ScholarshipPermissions({
    required this.canViewWorkspace,
    required this.canManagePrograms,
    required this.canSubmitSubmissions,
    required this.canReviewQueue,
    required this.canViewApprovalHistory,
  });

  final bool canViewWorkspace;
  final bool canManagePrograms;
  final bool canSubmitSubmissions;
  final bool canReviewQueue;
  final bool canViewApprovalHistory;

  bool get isReadOnly =>
      canViewWorkspace && !canManagePrograms && !canSubmitSubmissions;

  factory ScholarshipPermissions.forSession(AuthSession session) {
    final hasClanContext = session.clanId?.isNotEmpty ?? false;
    final canManage = GovernanceRoleMatrix.canManageScholarshipPrograms(session);
    final canSubmit = GovernanceRoleMatrix.canSubmitScholarship(session);
    final canReviewQueue = GovernanceRoleMatrix.canVoteScholarship(session);
    final canViewApprovalHistory =
        GovernanceRoleMatrix.canViewScholarshipApprovalLogs(session);

    return ScholarshipPermissions(
      canViewWorkspace: hasClanContext,
      canManagePrograms: canManage,
      canSubmitSubmissions: canSubmit,
      canReviewQueue: canReviewQueue,
      canViewApprovalHistory: canViewApprovalHistory,
    );
  }
}
