class ResolvedChildAccess {
  const ResolvedChildAccess({
    required this.childIdentifier,
    required this.parentPhoneE164,
    this.memberId,
    this.displayName,
  });

  final String childIdentifier;
  final String parentPhoneE164;
  final String? memberId;
  final String? displayName;
}
