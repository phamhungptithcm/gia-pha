import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/services/debug_member_repository.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildClanAdminSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  test(
    'creates a new member profile and updates branch member counts',
    () async {
      final repository = DebugMemberRepository.seeded();
      final session = buildClanAdminSession();

      final before = await repository.loadWorkspace(session: session);
      final branchBefore = before.branches.firstWhere(
        (branch) => branch.id == 'branch_demo_001',
      );
      expect(branchBefore.memberCount, 3);

      final created = await repository.saveMember(
        session: session,
        draft: const MemberDraft(
          branchId: 'branch_demo_001',
          fullName: 'Phạm Gia Hưng',
          nickName: 'Gia Hưng',
          gender: 'male',
          birthDate: '2020-05-20',
          deathDate: null,
          phoneInput: '+84906667777',
          email: 'gia-hung@befam.vn',
          addressText: 'Da Nang, Viet Nam',
          jobTitle: 'Student',
          bio: 'Member profile created in repository tests.',
          generation: 7,
          socialLinks: MemberSocialLinks(
            facebook: 'https://facebook.com/giahung',
          ),
        ),
      );

      expect(created.fullName, 'Phạm Gia Hưng');
      expect(created.phoneE164, '+84906667777');

      final after = await repository.loadWorkspace(session: session);
      final branchAfter = after.branches.firstWhere(
        (branch) => branch.id == 'branch_demo_001',
      );
      expect(branchAfter.memberCount, 4);
      expect(after.members.any((member) => member.id == created.id), isTrue);
    },
  );

  test(
    'allows editing an existing member without flagging the same phone as duplicate',
    () async {
      final repository = DebugMemberRepository.seeded();
      final session = buildClanAdminSession();
      final snapshot = await repository.loadWorkspace(session: session);
      final existing = snapshot.members.firstWhere(
        (member) => member.id == 'member_demo_parent_001',
      );

      final updated = await repository.saveMember(
        session: session,
        memberId: existing.id,
        draft: MemberDraft.fromProfile(
          existing,
        ).copyWith(jobTitle: 'Head of Operations'),
      );

      expect(updated.jobTitle, 'Head of Operations');
      expect(updated.phoneE164, '+84901234567');
    },
  );

  test('rejects duplicate phone numbers across member profiles', () async {
    final repository = DebugMemberRepository.seeded();
    final session = buildClanAdminSession();

    expect(
      () => repository.saveMember(
        session: session,
        draft: const MemberDraft(
          branchId: 'branch_demo_001',
          fullName: 'Trùng số điện thoại',
          nickName: '',
          gender: null,
          birthDate: null,
          deathDate: null,
          phoneInput: '+84901234567',
          email: '',
          addressText: '',
          jobTitle: '',
          bio: '',
          generation: 5,
          socialLinks: MemberSocialLinks(),
        ),
      ),
      throwsA(
        isA<MemberRepositoryException>().having(
          (error) => error.code,
          'code',
          MemberRepositoryErrorCode.duplicatePhone,
        ),
      ),
    );
  });

  test('uploads avatar content and persists the new avatar url', () async {
    final repository = DebugMemberRepository.seeded();
    final session = buildClanAdminSession();

    final updated = await repository.uploadAvatar(
      session: session,
      memberId: 'member_demo_parent_001',
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      fileName: 'avatar.jpg',
    );

    expect(
      updated.avatarUrl,
      startsWith('debug://avatar/member_demo_parent_001/'),
    );

    final snapshot = await repository.loadWorkspace(session: session);
    final stored = snapshot.members.firstWhere(
      (member) => member.id == 'member_demo_parent_001',
    );
    expect(
      stored.avatarUrl,
      startsWith('debug://avatar/member_demo_parent_001/'),
    );
  });
}
