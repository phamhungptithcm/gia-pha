class ClanContextOption {
  const ClanContextOption({
    required this.clanId,
    required this.clanName,
    required this.memberId,
    required this.primaryRole,
    this.branchId,
    this.displayName,
    this.status,
  });

  final String clanId;
  final String clanName;
  final String memberId;
  final String primaryRole;
  final String? branchId;
  final String? displayName;
  final String? status;

  String get normalizedClanId => clanId.trim();
}
