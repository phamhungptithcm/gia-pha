class ResolvedChildAccess {
  const ResolvedChildAccess({
    required this.childIdentifier,
    required this.maskedDestination,
    this.memberId,
    this.displayName,
    this.clanId,
    this.branchId,
    this.primaryRole,
  });

  final String childIdentifier;
  final String maskedDestination;
  final String? memberId;
  final String? displayName;
  final String? clanId;
  final String? branchId;
  final String? primaryRole;
}
