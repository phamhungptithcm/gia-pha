class JoinRequestDraft {
  const JoinRequestDraft({
    required this.clanId,
    required this.applicantName,
    required this.relationshipToFamily,
    required this.contactInfo,
    this.message,
    this.applicantMemberId,
  });

  final String clanId;
  final String applicantName;
  final String relationshipToFamily;
  final String contactInfo;
  final String? message;
  final String? applicantMemberId;

  Map<String, dynamic> toPayload() {
    return {
      'clanId': clanId.trim(),
      'applicantName': applicantName.trim(),
      'relationshipToFamily': relationshipToFamily.trim(),
      'contactInfo': contactInfo.trim(),
      if ((message ?? '').trim().isNotEmpty) 'message': message!.trim(),
      if ((applicantMemberId ?? '').trim().isNotEmpty)
        'applicantMemberId': applicantMemberId!.trim(),
    };
  }
}
