import '../../member/models/member_profile.dart';

class ProfileDraft {
  const ProfileDraft({
    required this.fullName,
    required this.nickName,
    required this.phoneInput,
    required this.email,
    required this.addressText,
    required this.jobTitle,
    required this.bio,
    required this.facebook,
    required this.zalo,
    required this.linkedin,
  });

  final String fullName;
  final String nickName;
  final String phoneInput;
  final String email;
  final String addressText;
  final String jobTitle;
  final String bio;
  final String facebook;
  final String zalo;
  final String linkedin;

  factory ProfileDraft.fromMember(MemberProfile profile) {
    return ProfileDraft(
      fullName: profile.fullName,
      nickName: profile.nickName,
      phoneInput: profile.phoneE164 ?? '',
      email: profile.email ?? '',
      addressText: profile.addressText ?? '',
      jobTitle: profile.jobTitle ?? '',
      bio: profile.bio ?? '',
      facebook: profile.socialLinks.facebook ?? '',
      zalo: profile.socialLinks.zalo ?? '',
      linkedin: profile.socialLinks.linkedin ?? '',
    );
  }
}
