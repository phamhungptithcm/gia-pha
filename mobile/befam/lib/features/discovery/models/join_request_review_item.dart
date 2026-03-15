class JoinRequestReviewItem {
  const JoinRequestReviewItem({
    required this.id,
    required this.clanId,
    required this.status,
    required this.applicantName,
    required this.relationshipToFamily,
    required this.contactInfo,
    this.message,
  });

  final String id;
  final String clanId;
  final String status;
  final String applicantName;
  final String relationshipToFamily;
  final String contactInfo;
  final String? message;

  factory JoinRequestReviewItem.fromJson(Map<String, dynamic> json) {
    return JoinRequestReviewItem(
      id: (json['id'] as String? ?? '').trim(),
      clanId: (json['clanId'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'pending').trim(),
      applicantName: (json['applicantName'] as String? ?? 'Ẩn danh').trim(),
      relationshipToFamily:
          (json['relationshipToFamily'] as String? ?? 'Chưa rõ quan hệ').trim(),
      contactInfo: (json['contactInfo'] as String? ?? '').trim(),
      message: (json['message'] as String?)?.trim(),
    );
  }
}
