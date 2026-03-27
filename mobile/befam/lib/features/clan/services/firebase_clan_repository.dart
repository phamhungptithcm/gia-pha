import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/firestore_paged_query_loader.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/inflight_task_cache.dart';
import '../../auth/models/auth_session.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_member_summary.dart';
import '../models/clan_profile.dart';
import '../models/clan_workspace_snapshot.dart';
import 'clan_repository.dart';

class FirebaseClanRepository implements ClanRepository {
  static const int _workspacePageSize = 250;
  static const int _workspaceMaxBranches = 1500;
  static const int _workspaceMaxMembers = 3000;

  FirebaseClanRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    FirestorePagedQueryLoader? pagedQueryLoader,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnvironment.firebaseFunctionsRegion,
           ),
       _auth = auth ?? FirebaseAuth.instance,
       _pagedQueryLoader =
           pagedQueryLoader ?? const FirestorePagedQueryLoader();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirestorePagedQueryLoader _pagedQueryLoader;
  final InflightTaskCache<String, ClanWorkspaceSnapshot> _workspaceLoadCache =
      InflightTaskCache<String, ClanWorkspaceSnapshot>();

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
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = await _resolveClanId(session);
    if (clanId == null || clanId.isEmpty) {
      return const ClanWorkspaceSnapshot(clan: null, branches: [], members: []);
    }

    return _workspaceLoadCache.run(clanId, () async {
      final results = await Future.wait<Object>([
        _clans.doc(clanId).get(),
        _fetchPagedDocuments(
          _branches.where('clanId', isEqualTo: clanId),
          maxDocuments: _workspaceMaxBranches,
        ),
        _fetchPagedDocuments(
          _members.where('clanId', isEqualTo: clanId),
          maxDocuments: _workspaceMaxMembers,
        ),
      ]);

      final clanSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final branchDocs =
          results[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final memberDocs =
          results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;

      final clan = clanSnapshot.data() == null
          ? null
          : ClanProfile.fromJson(clanSnapshot.data()!);
      final branches = branchDocs
          .map((doc) => BranchProfile.fromJson(doc.data()))
          .sortedBy((branch) => branch.name.toLowerCase())
          .toList(growable: false);
      final members = memberDocs
          .map((doc) => ClanMemberSummary.fromJson(doc.data()))
          .sortedBy((member) => member.fullName.toLowerCase())
          .toList(growable: false);

      return ClanWorkspaceSnapshot(
        clan: clan,
        branches: branches,
        members: members,
      );
    });
  }

  @override
  Future<void> saveClan({
    required AuthSession session,
    required ClanDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = await _resolveClanId(session);
    if (clanId == null || clanId.isEmpty) {
      await _bootstrapClanWorkspace(session: session, draft: draft);
      return;
    }

    final now = FieldValue.serverTimestamp();
    final actor = session.memberId ?? session.uid;
    final existingBranchesCount = await _branches
        .where('clanId', isEqualTo: clanId)
        .count()
        .get();
    final existingMembersCount = await _members
        .where('clanId', isEqualTo: clanId)
        .count()
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
          existingClan.data()?['memberCount'] ?? existingMembersCount.count,
      'branchCount':
          existingClan.data()?['branchCount'] ?? existingBranchesCount.count,
      'updatedAt': now,
      'updatedBy': actor,
      if (!existingClan.exists) 'createdAt': now,
      if (!existingClan.exists) 'createdBy': actor,
    };

    await _clans.doc(clanId).set(payload, SetOptions(merge: true));
    _workspaceLoadCache.invalidate(clanId);
  }

  @override
  Future<BranchProfile> saveBranch({
    required AuthSession session,
    String? branchId,
    required BranchDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = await _resolveClanId(session);
    if (clanId == null || clanId.isEmpty) {
      throw StateError('A clan context is required before saving branch data.');
    }

    final branchRef = branchId == null
        ? _branches.doc()
        : _branches.doc(branchId);
    final existing = await branchRef.get();
    if (existing.exists &&
        (existing.data()?['clanId'] as String?)?.trim() != clanId) {
      throw StateError('Cannot update a branch outside the active clan.');
    }
    final actor = session.memberId ?? session.uid;
    final now = FieldValue.serverTimestamp();
    final existingMemberCount =
        existing.data()?['memberCount'] as int? ??
        (await _members
                .where('clanId', isEqualTo: clanId)
                .where('branchId', isEqualTo: branchRef.id)
                .count()
                .get())
            .count;

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
        (await _branches.where('clanId', isEqualTo: clanId).count().get())
            .count;
    await clanRef.set({
      'id': clanId,
      'branchCount': currentBranchCount,
      'updatedAt': now,
      'updatedBy': actor,
    }, SetOptions(merge: true));
    _workspaceLoadCache.invalidate(clanId);

    return BranchProfile.fromJson(payload);
  }

  Future<void> _bootstrapClanWorkspace({
    required AuthSession session,
    required ClanDraft draft,
  }) async {
    final callable = _functions.httpsCallable('bootstrapClanWorkspace');
    await callable.call(<String, dynamic>{
      'name': draft.name,
      'slug': draft.slug,
      'description': draft.description,
      'countryCode': draft.countryCode,
      'founderName': draft.founderName,
      'logoUrl': draft.logoUrl,
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == session.uid) {
      await currentUser.getIdToken(true);
    }
  }

  Future<String?> _resolveClanId(AuthSession session) async {
    final sessionClanId = session.clanId?.trim();
    if (sessionClanId != null && sessionClanId.isNotEmpty) {
      return sessionClanId;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != session.uid) {
      return null;
    }

    try {
      final token = await currentUser.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      final claimClanIds = claims['clanIds'];
      if (claimClanIds is List) {
        for (final claim in claimClanIds) {
          if (claim is String && claim.trim().isNotEmpty) {
            return claim.trim();
          }
        }
      }

      final claimClanId = (claims['clanId'] as String?)?.trim();
      if (claimClanId != null && claimClanId.isNotEmpty) {
        return claimClanId;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchPagedDocuments(
    Query<Map<String, dynamic>> baseQuery, {
    required int maxDocuments,
  }) async {
    return _pagedQueryLoader.loadAll(
      baseQuery: baseQuery,
      pageSize: _workspacePageSize,
      maxDocuments: maxDocuments,
    );
  }
}
