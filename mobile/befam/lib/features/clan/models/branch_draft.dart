import 'branch_profile.dart';

class BranchDraft {
  const BranchDraft({
    required this.name,
    required this.code,
    required this.generationLevelHint,
    required this.leaderMemberId,
    required this.viceLeaderMemberId,
    this.status = 'active',
  });

  final String name;
  final String code;
  final int generationLevelHint;
  final String? leaderMemberId;
  final String? viceLeaderMemberId;
  final String status;

  BranchDraft copyWith({
    String? name,
    String? code,
    int? generationLevelHint,
    String? leaderMemberId,
    String? viceLeaderMemberId,
    String? status,
  }) {
    return BranchDraft(
      name: name ?? this.name,
      code: code ?? this.code,
      generationLevelHint: generationLevelHint ?? this.generationLevelHint,
      leaderMemberId: leaderMemberId ?? this.leaderMemberId,
      viceLeaderMemberId: viceLeaderMemberId ?? this.viceLeaderMemberId,
      status: status ?? this.status,
    );
  }

  factory BranchDraft.empty() {
    return const BranchDraft(
      name: '',
      code: '',
      generationLevelHint: 1,
      leaderMemberId: null,
      viceLeaderMemberId: null,
    );
  }

  factory BranchDraft.fromProfile(BranchProfile profile) {
    return BranchDraft(
      name: profile.name,
      code: profile.code,
      generationLevelHint: profile.generationLevelHint,
      leaderMemberId: profile.leaderMemberId,
      viceLeaderMemberId: profile.viceLeaderMemberId,
      status: profile.status,
    );
  }
}
