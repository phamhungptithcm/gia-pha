import '../../auth/models/auth_session.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_workspace_snapshot.dart';
import 'firebase_clan_repository.dart';

abstract interface class ClanRepository {
  bool get isSandbox;

  Future<ClanWorkspaceSnapshot> loadWorkspace({required AuthSession session});

  Future<void> saveClan({
    required AuthSession session,
    required ClanDraft draft,
  });

  Future<BranchProfile> saveBranch({
    required AuthSession session,
    String? branchId,
    required BranchDraft draft,
  });
}

ClanRepository createDefaultClanRepository({AuthSession? session}) {
  return FirebaseClanRepository();
}
