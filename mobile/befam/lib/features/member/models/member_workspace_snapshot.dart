import '../../clan/models/branch_profile.dart';
import 'member_profile.dart';

class MemberWorkspaceSnapshot {
  const MemberWorkspaceSnapshot({
    required this.members,
    required this.branches,
  });

  final List<MemberProfile> members;
  final List<BranchProfile> branches;
}
