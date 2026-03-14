import 'package:flutter/foundation.dart';

import '../../../core/services/debug_genealogy_store.dart';
import '../../auth/models/auth_session.dart';
import 'debug_member_repository.dart';
import 'firebase_member_repository.dart';
import '../models/member_draft.dart';
import '../models/member_profile.dart';
import '../models/member_workspace_snapshot.dart';

enum MemberRepositoryErrorCode {
  duplicatePhone,
  permissionDenied,
  memberNotFound,
  avatarUploadFailed,
}

class MemberRepositoryException implements Exception {
  const MemberRepositoryException(this.code, [this.message]);

  final MemberRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class MemberRepository {
  bool get isSandbox;

  Future<MemberWorkspaceSnapshot> loadWorkspace({required AuthSession session});

  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  });

  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  });
}

MemberRepository createDefaultMemberRepository() {
  const useLiveBackend = bool.fromEnvironment('BEFAM_USE_LIVE_AUTH');
  if (kDebugMode && !useLiveBackend) {
    return DebugMemberRepository(store: DebugGenealogyStore.sharedSeeded());
  }

  return FirebaseMemberRepository();
}
