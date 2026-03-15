import 'member_profile.dart';
import 'member_social_links.dart';

class MemberDraft {
  const MemberDraft({
    required this.branchId,
    required this.parentIds,
    required this.fullName,
    required this.nickName,
    required this.gender,
    required this.birthDate,
    required this.deathDate,
    required this.phoneInput,
    required this.email,
    required this.addressText,
    required this.jobTitle,
    required this.bio,
    required this.generation,
    required this.socialLinks,
    this.primaryRole = 'MEMBER',
    this.status = 'active',
    this.isMinor = false,
  });

  final String? branchId;
  final List<String> parentIds;
  final String fullName;
  final String nickName;
  final String? gender;
  final String? birthDate;
  final String? deathDate;
  final String phoneInput;
  final String email;
  final String addressText;
  final String jobTitle;
  final String bio;
  final int generation;
  final MemberSocialLinks socialLinks;
  final String primaryRole;
  final String status;
  final bool isMinor;

  MemberDraft copyWith({
    String? branchId,
    List<String>? parentIds,
    String? fullName,
    String? nickName,
    String? gender,
    String? birthDate,
    String? deathDate,
    String? phoneInput,
    String? email,
    String? addressText,
    String? jobTitle,
    String? bio,
    int? generation,
    MemberSocialLinks? socialLinks,
    String? primaryRole,
    String? status,
    bool? isMinor,
  }) {
    return MemberDraft(
      branchId: branchId ?? this.branchId,
      parentIds: parentIds ?? this.parentIds,
      fullName: fullName ?? this.fullName,
      nickName: nickName ?? this.nickName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      phoneInput: phoneInput ?? this.phoneInput,
      email: email ?? this.email,
      addressText: addressText ?? this.addressText,
      jobTitle: jobTitle ?? this.jobTitle,
      bio: bio ?? this.bio,
      generation: generation ?? this.generation,
      socialLinks: socialLinks ?? this.socialLinks,
      primaryRole: primaryRole ?? this.primaryRole,
      status: status ?? this.status,
      isMinor: isMinor ?? this.isMinor,
    );
  }

  factory MemberDraft.empty({String? defaultBranchId}) {
    return MemberDraft(
      branchId: defaultBranchId,
      parentIds: const [],
      fullName: '',
      nickName: '',
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneInput: '',
      email: '',
      addressText: '',
      jobTitle: '',
      bio: '',
      generation: 1,
      socialLinks: const MemberSocialLinks(),
    );
  }

  factory MemberDraft.fromProfile(MemberProfile profile) {
    return MemberDraft(
      branchId: profile.branchId,
      parentIds: profile.parentIds,
      fullName: profile.fullName,
      nickName: profile.nickName,
      gender: profile.gender,
      birthDate: profile.birthDate,
      deathDate: profile.deathDate,
      phoneInput: profile.phoneE164 ?? '',
      email: profile.email ?? '',
      addressText: profile.addressText ?? '',
      jobTitle: profile.jobTitle ?? '',
      bio: profile.bio ?? '',
      generation: profile.generation,
      socialLinks: profile.socialLinks,
      primaryRole: profile.primaryRole,
      status: profile.status,
      isMinor: profile.isMinor,
    );
  }
}
