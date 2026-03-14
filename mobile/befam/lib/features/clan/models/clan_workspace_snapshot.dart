import 'branch_profile.dart';
import 'clan_member_summary.dart';
import 'clan_profile.dart';

class ClanWorkspaceSnapshot {
  const ClanWorkspaceSnapshot({
    required this.clan,
    required this.branches,
    required this.members,
  });

  final ClanProfile? clan;
  final List<BranchProfile> branches;
  final List<ClanMemberSummary> members;
}
