class MemberSocialLinks {
  const MemberSocialLinks({this.facebook, this.zalo, this.linkedin});

  final String? facebook;
  final String? zalo;
  final String? linkedin;

  bool get isEmpty =>
      _isBlank(facebook) && _isBlank(zalo) && _isBlank(linkedin);

  MemberSocialLinks copyWith({
    String? facebook,
    String? zalo,
    String? linkedin,
  }) {
    return MemberSocialLinks(
      facebook: facebook ?? this.facebook,
      zalo: zalo ?? this.zalo,
      linkedin: linkedin ?? this.linkedin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facebook': _nullableTrim(facebook),
      'zalo': _nullableTrim(zalo),
      'linkedin': _nullableTrim(linkedin),
    };
  }

  factory MemberSocialLinks.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MemberSocialLinks();
    }

    return MemberSocialLinks(
      facebook: json['facebook'] as String?,
      zalo: json['zalo'] as String?,
      linkedin: json['linkedin'] as String?,
    );
  }
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
