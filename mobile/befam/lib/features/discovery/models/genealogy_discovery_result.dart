class GenealogyDiscoveryResult {
  const GenealogyDiscoveryResult({
    required this.id,
    required this.clanId,
    required this.genealogyName,
    required this.leaderName,
    required this.provinceCity,
    required this.summary,
    required this.memberCount,
    required this.branchCount,
    this.hasPendingJoinRequest = false,
    this.pendingJoinRequestSubmittedAtEpochMs,
    this.isHiddenWhilePending = false,
  });

  final String id;
  final String clanId;
  final String genealogyName;
  final String leaderName;
  final String provinceCity;
  final String summary;
  final int memberCount;
  final int branchCount;
  final bool hasPendingJoinRequest;
  final int? pendingJoinRequestSubmittedAtEpochMs;
  final bool isHiddenWhilePending;

  factory GenealogyDiscoveryResult.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final clanId = (json['clanId'] as String? ?? id).trim();
    return GenealogyDiscoveryResult(
      id: id.isEmpty ? clanId : id,
      clanId: clanId,
      genealogyName:
          (json['genealogyName'] as String? ?? 'Gia phả chưa đặt tên').trim(),
      leaderName: (json['leaderName'] as String? ?? 'Chưa có trưởng tộc')
          .trim(),
      provinceCity: (json['provinceCity'] as String? ?? 'Chưa rõ địa phương')
          .trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      branchCount: (json['branchCount'] as num?)?.toInt() ?? 0,
      hasPendingJoinRequest: json['hasPendingJoinRequest'] == true,
      pendingJoinRequestSubmittedAtEpochMs:
          (json['pendingJoinRequestSubmittedAtEpochMs'] as num?)?.toInt(),
      isHiddenWhilePending: json['isHiddenWhilePending'] == true,
    );
  }
}
