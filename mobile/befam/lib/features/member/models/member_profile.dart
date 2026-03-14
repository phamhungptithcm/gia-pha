import 'member_social_links.dart';

class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.clanId,
    required this.branchId,
    required this.fullName,
    required this.normalizedFullName,
    required this.nickName,
    required this.gender,
    required this.birthDate,
    required this.deathDate,
    required this.phoneE164,
    required this.email,
    required this.addressText,
    required this.jobTitle,
    required this.avatarUrl,
    required this.bio,
    required this.socialLinks,
    required this.parentIds,
    required this.childrenIds,
    required this.spouseIds,
    required this.generation,
    required this.primaryRole,
    required this.status,
    required this.isMinor,
    required this.authUid,
  });

  final String id;
  final String clanId;
  final String branchId;
  final String fullName;
  final String normalizedFullName;
  final String nickName;
  final String? gender;
  final String? birthDate;
  final String? deathDate;
  final String? phoneE164;
  final String? email;
  final String? addressText;
  final String? jobTitle;
  final String? avatarUrl;
  final String? bio;
  final MemberSocialLinks socialLinks;
  final List<String> parentIds;
  final List<String> childrenIds;
  final List<String> spouseIds;
  final int generation;
  final String primaryRole;
  final String status;
  final bool isMinor;
  final String? authUid;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  String get displayName => nickName.trim().isEmpty ? fullName : nickName;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  MemberProfile copyWith({
    String? id,
    String? clanId,
    String? branchId,
    String? fullName,
    String? normalizedFullName,
    String? nickName,
    String? gender,
    String? birthDate,
    String? deathDate,
    String? phoneE164,
    String? email,
    String? addressText,
    String? jobTitle,
    String? avatarUrl,
    String? bio,
    MemberSocialLinks? socialLinks,
    List<String>? parentIds,
    List<String>? childrenIds,
    List<String>? spouseIds,
    int? generation,
    String? primaryRole,
    String? status,
    bool? isMinor,
    String? authUid,
  }) {
    return MemberProfile(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
      branchId: branchId ?? this.branchId,
      fullName: fullName ?? this.fullName,
      normalizedFullName: normalizedFullName ?? this.normalizedFullName,
      nickName: nickName ?? this.nickName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      phoneE164: phoneE164 ?? this.phoneE164,
      email: email ?? this.email,
      addressText: addressText ?? this.addressText,
      jobTitle: jobTitle ?? this.jobTitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      socialLinks: socialLinks ?? this.socialLinks,
      parentIds: parentIds ?? this.parentIds,
      childrenIds: childrenIds ?? this.childrenIds,
      spouseIds: spouseIds ?? this.spouseIds,
      generation: generation ?? this.generation,
      primaryRole: primaryRole ?? this.primaryRole,
      status: status ?? this.status,
      isMinor: isMinor ?? this.isMinor,
      authUid: authUid ?? this.authUid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'branchId': branchId,
      'fullName': fullName,
      'normalizedFullName': normalizedFullName,
      'nickName': nickName,
      'gender': gender,
      'birthDate': birthDate,
      'deathDate': deathDate,
      'phoneE164': phoneE164,
      'email': email,
      'addressText': addressText,
      'jobTitle': jobTitle,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'socialLinks': socialLinks.toJson(),
      'parentIds': parentIds,
      'childrenIds': childrenIds,
      'spouseIds': spouseIds,
      'generation': generation,
      'primaryRole': primaryRole,
      'status': status,
      'isMinor': isMinor,
      'authUid': authUid,
    };
  }

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      normalizedFullName:
          json['normalizedFullName'] as String? ??
          (json['fullName'] as String? ?? '').trim().toLowerCase(),
      nickName: json['nickName'] as String? ?? '',
      gender: json['gender'] as String?,
      birthDate: json['birthDate'] as String?,
      deathDate: json['deathDate'] as String?,
      phoneE164: json['phoneE164'] as String?,
      email: json['email'] as String?,
      addressText: json['addressText'] as String?,
      jobTitle: json['jobTitle'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      socialLinks: MemberSocialLinks.fromJson(
        json['socialLinks'] as Map<String, dynamic>?,
      ),
      parentIds: _stringList(json['parentIds']),
      childrenIds: _stringList(json['childrenIds']),
      spouseIds: _stringList(json['spouseIds']),
      generation: json['generation'] as int? ?? 1,
      primaryRole: json['primaryRole'] as String? ?? 'MEMBER',
      status: json['status'] as String? ?? 'active',
      isMinor: json['isMinor'] as bool? ?? false,
      authUid: json['authUid'] as String?,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
}
