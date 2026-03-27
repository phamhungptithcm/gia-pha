import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firestore_paged_query_loader.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../../relationship/models/relationship_record.dart';
import '../models/genealogy_read_segment.dart';
import '../models/genealogy_scope.dart';
import 'genealogy_graph_algorithms.dart';
import 'genealogy_read_repository.dart';
import 'genealogy_root_entries.dart';
import 'genealogy_segment_cache.dart';

class FirebaseGenealogyReadRepository implements GenealogyReadRepository {
  static const int _workspacePageSize = 250;
  static const int _workspaceMaxDocuments = 3000;

  FirebaseGenealogyReadRepository({
    FirebaseFirestore? firestore,
    GenealogySegmentCache? cache,
    FirestorePagedQueryLoader? pagedQueryLoader,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _cache = cache ?? GenealogySegmentCache.shared(),
       _pagedQueryLoader =
           pagedQueryLoader ?? const FirestorePagedQueryLoader();

  final FirebaseFirestore _firestore;
  final GenealogySegmentCache _cache;
  final FirestorePagedQueryLoader _pagedQueryLoader;

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');

  CollectionReference<Map<String, dynamic>> get _relationships =>
      _firestore.collection('relationships');

  @override
  bool get isSandbox => false;

  @override
  Future<GenealogyReadSegment> loadClanSegment({
    required AuthSession session,
    bool allowCached = true,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return GenealogyReadSegment.empty(const GenealogyScope.clan(clanId: ''));
    }

    final scope = GenealogyScope.clan(clanId: clanId);
    if (allowCached) {
      final cached = _cache.read(scope);
      if (cached != null) {
        return _retargetCachedSegment(cached: cached, session: session);
      }
    }

    final results =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
          _fetchPagedDocuments(_members.where('clanId', isEqualTo: clanId)),
          _fetchPagedDocuments(_branches.where('clanId', isEqualTo: clanId)),
          _fetchPagedDocuments(
            _relationships.where('clanId', isEqualTo: clanId),
          ),
        ]);

    final members = results[0]
        .map((doc) => MemberProfile.fromJson(doc.data()))
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final branches = results[1]
        .map((doc) => BranchProfile.fromJson(doc.data()))
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);
    final memberIds = members.map((member) => member.id).toSet();
    final relationships = results[2]
        .map((doc) => RelationshipRecord.fromJson(doc.data()))
        .where(
          (relationship) =>
              relationship.isActive &&
              memberIds.contains(relationship.personAId) &&
              memberIds.contains(relationship.personBId),
        )
        .sortedBy((relationship) => relationship.id)
        .toList(growable: false);

    return _buildAndCacheSegment(
      scope: scope,
      session: session,
      members: members,
      branches: branches,
      relationships: relationships,
    );
  }

  @override
  Future<GenealogyReadSegment> loadBranchSegment({
    required AuthSession session,
    String? branchId,
    bool allowCached = true,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = (session.clanId ?? '').trim();
    final resolvedBranchId = (branchId ?? session.branchId ?? '').trim();
    if (clanId.isEmpty || resolvedBranchId.isEmpty) {
      return GenealogyReadSegment.empty(
        GenealogyScope.branch(clanId: clanId, branchId: resolvedBranchId),
      );
    }

    final scope = GenealogyScope.branch(
      clanId: clanId,
      branchId: resolvedBranchId,
    );
    if (allowCached) {
      final cached = _cache.read(scope);
      if (cached != null) {
        return _retargetCachedSegment(cached: cached, session: session);
      }
    }

    final memberSnapshot = await _fetchPagedDocuments(
      _members
          .where('clanId', isEqualTo: clanId)
          .where('branchId', isEqualTo: resolvedBranchId),
    );
    final branchDoc = await _branches.doc(resolvedBranchId).get();
    final relationshipSnapshot = await _fetchPagedDocuments(
      _relationships.where('clanId', isEqualTo: clanId),
    );

    final members = memberSnapshot
        .map((doc) => MemberProfile.fromJson(doc.data()))
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final memberIds = members.map((member) => member.id).toSet();
    final branches = [
      if (branchDoc.exists &&
          branchDoc.data() != null &&
          (branchDoc.data()!['clanId'] as String?)?.trim() == clanId)
        BranchProfile.fromJson(branchDoc.data()!),
    ];
    final relationships = relationshipSnapshot
        .map((doc) => RelationshipRecord.fromJson(doc.data()))
        .where(
          (relationship) =>
              relationship.isActive &&
              memberIds.contains(relationship.personAId) &&
              memberIds.contains(relationship.personBId),
        )
        .sortedBy((relationship) => relationship.id)
        .toList(growable: false);

    return _buildAndCacheSegment(
      scope: scope,
      session: session,
      members: members,
      branches: branches,
      relationships: relationships,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchPagedDocuments(
    Query<Map<String, dynamic>> baseQuery, {
    int pageSize = _workspacePageSize,
    int maxDocuments = _workspaceMaxDocuments,
  }) async {
    return _pagedQueryLoader.loadAll(
      baseQuery: baseQuery,
      pageSize: pageSize,
      maxDocuments: maxDocuments,
    );
  }

  GenealogyReadSegment _buildAndCacheSegment({
    required GenealogyScope scope,
    required AuthSession session,
    required List<MemberProfile> members,
    required List<BranchProfile> branches,
    required List<RelationshipRecord> relationships,
  }) {
    final graph = GenealogyGraphAlgorithms.buildAdjacencyMap(
      members: members,
      relationships: relationships,
      focusMemberId: session.memberId,
    );
    final segment = GenealogyReadSegment(
      scope: scope,
      members: members,
      branches: branches,
      relationships: relationships,
      graph: graph,
      rootEntries: buildGenealogyRootEntries(
        scope: scope,
        session: session,
        members: members,
        branches: branches,
        parentMap: graph.parentMap,
      ),
      loadedAt: DateTime.now(),
      fromCache: false,
    );
    _cache.write(segment);
    return segment;
  }

  GenealogyReadSegment _retargetCachedSegment({
    required GenealogyReadSegment cached,
    required AuthSession session,
  }) {
    final graph = GenealogyGraphAlgorithms.buildAdjacencyMap(
      members: cached.members,
      relationships: cached.relationships,
      focusMemberId: session.memberId,
    );
    return cached.copyWith(
      graph: graph,
      rootEntries: buildGenealogyRootEntries(
        scope: cached.scope,
        session: session,
        members: cached.members,
        branches: cached.branches,
        parentMap: graph.parentMap,
      ),
      fromCache: true,
    );
  }
}
