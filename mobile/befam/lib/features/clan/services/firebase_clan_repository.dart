import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_member_summary.dart';
import '../models/clan_profile.dart';
import '../models/clan_workspace_snapshot.dart';
import 'clan_repository.dart';

class FirebaseClanRepository implements ClanRepository {
  FirebaseClanRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clans =>
      _firestore.collection('clans');

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  @override
  bool get isSandbox => false;

  @override
  Future<ClanWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const ClanWorkspaceSnapshot(clan: null, branches: [], members: []);
    }

    final results = await Future.wait([
      _clans.doc(clanId).get(),
      _branches.where('clanId', isEqualTo: clanId).get(),
      _members.where('clanId', isEqualTo: clanId).get(),
    ]);

    final clanSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final branchSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final memberSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;

    final clan = clanSnapshot.data() == null
        ? null
        : ClanProfile.fromJson(clanSnapshot.data()!);
    final branches = branchSnapshot.docs
        .map((doc) => BranchProfile.fromJson(doc.data()))
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);
    final members = memberSnapshot.docs
        .map((doc) => ClanMemberSummary.fromJson(doc.data()))
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);

    return ClanWorkspaceSnapshot(
      clan: clan,
      branches: branches,
      members: members,
    );
  }

  @override
  Future<void> saveClan({
    required AuthSession session,
    required ClanDraft draft,
  }) async {
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw StateError('A clan context is required before saving clan data.');
    }

    final now = FieldValue.serverTimestamp();
    final actor = session.memberId ?? session.uid;
    final existingBranches = await _branches
        .where('clanId', isEqualTo: clanId)
        .get();
    final existingMembers = await _members
        .where('clanId', isEqualTo: clanId)
        .get();
    final existingClan = await _clans.doc(clanId).get();

    final payload = {
      'id': clanId,
      'name': draft.name,
      'slug': draft.slug,
      'description': draft.description,
      'countryCode': draft.countryCode,
      'founderName': draft.founderName,
      'logoUrl': draft.logoUrl,
      'status': draft.status,
      'memberCount':
          existingClan.data()?['memberCount'] ?? existingMembers.docs.length,
      'branchCount':
          existingClan.data()?['branchCount'] ?? existingBranches.docs.length,
      'updatedAt': now,
      'updatedBy': actor,
      if (!existingClan.exists) 'createdAt': now,
      if (!existingClan.exists) 'createdBy': actor,
    };

    await _clans.doc(clanId).set(payload, SetOptions(merge: true));
  }

  @override
  Future<BranchProfile> saveBranch({
    required AuthSession session,
    String? branchId,
    required BranchDraft draft,
  }) async {
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw StateError('A clan context is required before saving branch data.');
    }

    final branchRef = branchId == null
        ? _branches.doc()
        : _branches.doc(branchId);
    final existing = await branchRef.get();
    final actor = session.memberId ?? session.uid;
    final now = FieldValue.serverTimestamp();
    final existingMemberCount =
        existing.data()?['memberCount'] as int? ??
        (await _members.where('branchId', isEqualTo: branchRef.id).get())
            .docs
            .length;

    final payload = {
      'id': branchRef.id,
      'clanId': clanId,
      'name': draft.name,
      'code': draft.code,
      'leaderMemberId': draft.leaderMemberId,
      'viceLeaderMemberId': draft.viceLeaderMemberId,
      'generationLevelHint': draft.generationLevelHint,
      'status': draft.status,
      'memberCount': existingMemberCount,
      'updatedAt': now,
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': now,
      if (!existing.exists) 'createdBy': actor,
    };

    await branchRef.set(payload, SetOptions(merge: true));

    final clanRef = _clans.doc(clanId);
    final currentBranchCount =
        (await _branches.where('clanId', isEqualTo: clanId).get()).docs.length;
    await clanRef.set({
      'id': clanId,
      'branchCount': currentBranchCount,
      'updatedAt': now,
      'updatedBy': actor,
    }, SetOptions(merge: true));

    return BranchProfile.fromJson(payload);
  }
}
