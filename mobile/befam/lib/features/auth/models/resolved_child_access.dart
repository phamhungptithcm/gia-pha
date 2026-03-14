class ResolvedChildAccess {
  const ResolvedChildAccess({
    required this.childIdentifier,
    required this.parentPhoneE164,
    this.memberId,
    this.displayName,
    this.clanId,
    this.branchId,
    this.primaryRole,
  });

  final String childIdentifier;
  final String parentPhoneE164;
  final String? memberId;
  final String? displayName;
  final String? clanId;
  final String? branchId;
  final String? primaryRole;
}
