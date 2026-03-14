class BranchProfile {
  const BranchProfile({
    required this.id,
    required this.clanId,
    required this.name,
    required this.code,
    required this.leaderMemberId,
    required this.viceLeaderMemberId,
    required this.generationLevelHint,
    required this.status,
    required this.memberCount,
  });

  final String id;
  final String clanId;
  final String name;
  final String code;
  final String? leaderMemberId;
  final String? viceLeaderMemberId;
  final int generationLevelHint;
  final String status;
  final int memberCount;

  BranchProfile copyWith({
    String? id,
    String? clanId,
    String? name,
    String? code,
    String? leaderMemberId,
    String? viceLeaderMemberId,
    int? generationLevelHint,
    String? status,
    int? memberCount,
  }) {
    return BranchProfile(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
      name: name ?? this.name,
      code: code ?? this.code,
      leaderMemberId: leaderMemberId ?? this.leaderMemberId,
      viceLeaderMemberId: viceLeaderMemberId ?? this.viceLeaderMemberId,
      generationLevelHint: generationLevelHint ?? this.generationLevelHint,
      status: status ?? this.status,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'name': name,
      'code': code,
      'leaderMemberId': leaderMemberId,
      'viceLeaderMemberId': viceLeaderMemberId,
      'generationLevelHint': generationLevelHint,
      'status': status,
      'memberCount': memberCount,
    };
  }

  factory BranchProfile.fromJson(Map<String, dynamic> json) {
    return BranchProfile(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      leaderMemberId: json['leaderMemberId'] as String?,
      viceLeaderMemberId: json['viceLeaderMemberId'] as String?,
      generationLevelHint: json['generationLevelHint'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
      memberCount: json['memberCount'] as int? ?? 0,
    );
  }
}
