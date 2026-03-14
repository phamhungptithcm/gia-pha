class ClanMemberSummary {
  const ClanMemberSummary({
    required this.id,
    required this.fullName,
    required this.branchId,
    required this.primaryRole,
    required this.phoneE164,
  });

  final String id;
  final String fullName;
  final String? branchId;
  final String? primaryRole;
  final String? phoneE164;

  String get shortLabel => fullName.trim().isEmpty ? id : fullName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'branchId': branchId,
      'primaryRole': primaryRole,
      'phoneE164': phoneE164,
    };
  }

  factory ClanMemberSummary.fromJson(Map<String, dynamic> json) {
    return ClanMemberSummary(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      branchId: json['branchId'] as String?,
      primaryRole: json['primaryRole'] as String?,
      phoneE164: json['phoneE164'] as String?,
    );
  }
}
