import 'package:befam/features/profile/models/profile_draft.dart';
import 'package:befam/features/profile/services/profile_quality_check_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prioritizes missing profile fields that improve recognition', () {
    const draft = ProfileDraft(
      fullName: 'Nguyen Minh',
      nickName: '',
      phoneInput: '',
      email: '',
      addressText: '',
      jobTitle: '',
      bio: '',
      facebook: '',
      zalo: '',
      linkedin: '',
    );

    final actions = buildProfileQualityCheckActions(draft);

    expect(actions, const [
      ProfileQualityCheckActionTarget.nickname,
      ProfileQualityCheckActionTarget.jobTitle,
      ProfileQualityCheckActionTarget.bio,
      ProfileQualityCheckActionTarget.contact,
    ]);
  });

  test('skips filled sections and keeps social prompt when contact exists', () {
    const draft = ProfileDraft(
      fullName: 'Nguyen Minh',
      nickName: 'Minh',
      phoneInput: '+84901234567',
      email: '',
      addressText: 'Da Nang, Viet Nam',
      jobTitle: 'Clan admin',
      bio: '',
      facebook: '',
      zalo: '',
      linkedin: '',
    );

    final actions = buildProfileQualityCheckActions(draft, maxActions: 6);

    expect(actions, const [
      ProfileQualityCheckActionTarget.bio,
      ProfileQualityCheckActionTarget.contact,
      ProfileQualityCheckActionTarget.social,
    ]);
  });
}
