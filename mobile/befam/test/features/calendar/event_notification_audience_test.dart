import 'package:befam/features/calendar/models/event_notification_audience.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final members = <MemberProfile>[
    _member(
      id: 'm1',
      branchId: 'branch_a',
      fullName: 'An',
      gender: 'male',
      birthDate: '1980-01-01',
      parentIds: const ['p1', 'p2'],
      primaryRole: 'CLAN_ADMIN',
    ),
    _member(
      id: 'm2',
      branchId: 'branch_a',
      fullName: 'Binh',
      gender: 'male',
      birthDate: '1984-01-01',
      parentIds: const ['p1', 'p2'],
      primaryRole: 'BRANCH_ADMIN',
    ),
    _member(
      id: 'm3',
      branchId: 'branch_a',
      fullName: 'Chi',
      gender: 'female',
      birthDate: '1987-01-01',
      parentIds: const ['p1', 'p2'],
    ),
    _member(
      id: 'm4',
      branchId: 'branch_a',
      fullName: 'Dung',
      gender: 'male',
      birthDate: '1990-01-01',
      parentIds: const ['p1', 'p2'],
      primaryRole: 'VICE_LEADER',
    ),
    _member(
      id: 'm5',
      branchId: 'branch_b',
      fullName: 'Hung',
      gender: 'male',
      birthDate: '1982-01-01',
      parentIds: const [],
    ),
    _member(
      id: 'm6',
      branchId: 'branch_b',
      fullName: 'Khanh',
      gender: 'female',
      birthDate: '1993-01-01',
      parentIds: const [],
    ),
  ];

  test('clan_all supports named exclusions and daughter exclusion rule', () {
    const audience = EventNotificationAudience(
      mode: EventNotificationAudienceMode.clanAll,
      excludeMemberIds: ['m5'],
      excludeRules: [EventNotificationAudienceExcludeRule.female],
    );

    final recipients = audience.resolveRecipients(
      members: members,
      fallbackMembers: const [],
    );

    expect(recipients.map((member) => member.id), ['m1', 'm2', 'm4']);
  });

  test(
    'branch_all filters to branch and can exclude members not lead/deputy',
    () {
      const audience = EventNotificationAudience(
        mode: EventNotificationAudienceMode.branchAll,
        branchId: 'branch_a',
        excludeRules: [EventNotificationAudienceExcludeRule.nonLeaderOrVice],
      );

      final recipients = audience.resolveRecipients(
        members: members,
        fallbackMembers: const [],
      );

      expect(recipients.map((member) => member.id), ['m1', 'm2', 'm4']);
    },
  );

  test('named mode keeps only include list and ignores exclusions', () {
    const audience = EventNotificationAudience(
      mode: EventNotificationAudienceMode.named,
      includeMemberIds: ['m4', 'm2', 'missing'],
      excludeMemberIds: ['m2'],
      excludeRules: [EventNotificationAudienceExcludeRule.female],
    );

    final recipients = audience.resolveRecipients(
      members: members,
      fallbackMembers: const [],
    );

    expect(recipients.map((member) => member.id), ['m2', 'm4']);
  });

  test(
    'automatically excludes deceased member and routes to next living son',
    () {
      final withDeceasedEldest = members
          .map((member) {
            if (member.id != 'm1') {
              return member;
            }
            return member.copyWith(deathDate: '2024-05-10');
          })
          .toList(growable: false);

      const audience = EventNotificationAudience(
        mode: EventNotificationAudienceMode.named,
        includeMemberIds: ['m1'],
      );

      final recipients = audience.resolveRecipients(
        members: withDeceasedEldest,
        fallbackMembers: const [],
      );

      expect(recipients.map((member) => member.id), ['m2']);
    },
  );

  test('deceased status is auto-excluded from recipient list', () {
    final withDeceasedStatus = members
        .map((member) {
          if (member.id != 'm5') {
            return member;
          }
          return member.copyWith(status: 'deceased');
        })
        .toList(growable: false);

    const audience = EventNotificationAudience(
      mode: EventNotificationAudienceMode.clanAll,
    );

    final recipients = audience.resolveRecipients(
      members: withDeceasedStatus,
      fallbackMembers: const [],
    );

    expect(recipients.map((member) => member.id), [
      'm1',
      'm2',
      'm3',
      'm4',
      'm6',
    ]);
  });

  test('uses fallback members when primary member list is empty', () {
    const audience = EventNotificationAudience(
      mode: EventNotificationAudienceMode.clanAll,
    );

    final recipients = audience.resolveRecipients(
      members: const [],
      fallbackMembers: [members.last],
    );

    expect(recipients.map((member) => member.id), ['m6']);
  });
}

MemberProfile _member({
  required String id,
  required String branchId,
  required String fullName,
  required String gender,
  required String birthDate,
  required List<String> parentIds,
  String primaryRole = 'MEMBER',
  String? deathDate,
  String status = 'active',
}) {
  return MemberProfile(
    id: id,
    clanId: 'clan_001',
    branchId: branchId,
    fullName: fullName,
    normalizedFullName: fullName.toLowerCase(),
    nickName: '',
    gender: gender,
    birthDate: birthDate,
    deathDate: deathDate,
    phoneE164: null,
    email: null,
    addressText: null,
    jobTitle: null,
    avatarUrl: null,
    bio: null,
    socialLinks: const MemberSocialLinks(),
    parentIds: parentIds,
    childrenIds: const [],
    spouseIds: const [],
    generation: 1,
    primaryRole: primaryRole,
    status: status,
    isMinor: false,
    authUid: null,
  );
}
