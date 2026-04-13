import '../models/profile_draft.dart';

enum ProfileQualityCheckActionTarget {
  nickname,
  jobTitle,
  bio,
  contact,
  address,
  social,
}

List<ProfileQualityCheckActionTarget> buildProfileQualityCheckActions(
  ProfileDraft draft, {
  int maxActions = 4,
}) {
  final actions = <ProfileQualityCheckActionTarget>[];

  if (draft.nickName.trim().isEmpty) {
    actions.add(ProfileQualityCheckActionTarget.nickname);
  }
  if (draft.jobTitle.trim().isEmpty) {
    actions.add(ProfileQualityCheckActionTarget.jobTitle);
  }
  if (draft.bio.trim().isEmpty) {
    actions.add(ProfileQualityCheckActionTarget.bio);
  }

  final hasPhone = draft.phoneInput.trim().isNotEmpty;
  final hasEmail = draft.email.trim().isNotEmpty;
  if (!hasPhone || !hasEmail) {
    actions.add(ProfileQualityCheckActionTarget.contact);
  }

  if (draft.addressText.trim().isEmpty) {
    actions.add(ProfileQualityCheckActionTarget.address);
  }

  final hasSocial = [
    draft.facebook,
    draft.zalo,
    draft.linkedin,
  ].any((value) => value.trim().isNotEmpty);
  if (!hasSocial) {
    actions.add(ProfileQualityCheckActionTarget.social);
  }

  return actions.take(maxActions).toList(growable: false);
}
