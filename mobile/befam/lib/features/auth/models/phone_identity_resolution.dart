enum PhoneIdentityResolutionStatus { needsSelection, createNewOnly }

class PhoneIdentityCandidate {
  const PhoneIdentityCandidate({
    required this.memberId,
    required this.displayName,
    required this.displayNameMasked,
    required this.birthHint,
    required this.clanLabel,
    required this.roleLabel,
    required this.memberStatus,
    required this.selectable,
    required this.blockedReason,
  });

  final String memberId;
  final String displayName;
  final String displayNameMasked;
  final String? birthHint;
  final String? clanLabel;
  final String? roleLabel;
  final String? memberStatus;
  final bool selectable;
  final String? blockedReason;

  factory PhoneIdentityCandidate.fromMap(Map<String, dynamic> data) {
    String? normalizeNullableString(dynamic value) {
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return PhoneIdentityCandidate(
      memberId: normalizeNullableString(data['memberId']) ?? '',
      displayName:
          normalizeNullableString(data['displayName']) ??
          normalizeNullableString(data['displayNameMasked']) ??
          '***',
      displayNameMasked:
          normalizeNullableString(data['displayNameMasked']) ?? '***',
      birthHint: normalizeNullableString(data['birthHint']),
      clanLabel: normalizeNullableString(data['clanLabel']),
      roleLabel: normalizeNullableString(data['roleLabel']),
      memberStatus: normalizeNullableString(data['memberStatus']),
      selectable: data['selectable'] == true,
      blockedReason: normalizeNullableString(data['blockedReason']),
    );
  }
}

class PhoneIdentityResolution {
  const PhoneIdentityResolution({
    required this.status,
    required this.phoneE164,
    required this.allowCreateNew,
    required this.candidates,
  });

  final PhoneIdentityResolutionStatus status;
  final String phoneE164;
  final bool allowCreateNew;
  final List<PhoneIdentityCandidate> candidates;
}
