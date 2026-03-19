import 'dart:async';

import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/models/branch_profile.dart';
import 'package:befam/features/genealogy/models/genealogy_read_segment.dart';
import 'package:befam/features/genealogy/models/genealogy_scope.dart';
import 'package:befam/features/genealogy/services/genealogy_graph_algorithms.dart';
import 'package:befam/features/genealogy/services/genealogy_read_repository.dart';
import 'package:befam/features/genealogy/services/genealogy_root_entries.dart';
import 'package:befam/features/genealogy/services/genealogy_segment_cache.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/relationship/models/relationship_record.dart';
import 'package:collection/collection.dart';
import '../../../core/services/debug_genealogy_store.dart';

class DebugGenealogyReadRepository implements GenealogyReadRepository {
  DebugGenealogyReadRepository({
    required DebugGenealogyStore store,
    GenealogySegmentCache? cache,
  }) : _store = store,
       _cache = cache ?? GenealogySegmentCache.shared();

  factory DebugGenealogyReadRepository.seeded() {
    return DebugGenealogyReadRepository(store: DebugGenealogyStore.seeded());
  }

  final DebugGenealogyStore _store;
  final GenealogySegmentCache _cache;

  @override
  bool get isSandbox => true;

  @override
  Future<GenealogyReadSegment> loadClanSegment({
    required AuthSession session,
    bool allowCached = true,
  }) async {
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return GenealogyReadSegment.empty(const GenealogyScope.clan(clanId: ''));
    }

    final scope = GenealogyScope.clan(clanId: clanId);
    if (allowCached) {
      final cached = _cache.read(scope);
      if (cached != null) {
        return _retargetCachedSegment(cached: cached, session: session);
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final members = _store.members.values
        .where((member) => member.clanId == clanId)
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final branches = _store.branches.values
        .where((branch) => branch.clanId == clanId)
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);
    final memberIds = members.map((member) => member.id).toSet();
    final relationships = _store.relationships.values
        .where(
          (relationship) =>
              relationship.clanId == clanId &&
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
    final clanId = session.clanId;
    final resolvedBranchId = branchId ?? session.branchId;
    if (clanId == null ||
        clanId.isEmpty ||
        resolvedBranchId == null ||
        resolvedBranchId.isEmpty) {
      return GenealogyReadSegment.empty(
        GenealogyScope.branch(
          clanId: clanId ?? '',
          branchId: resolvedBranchId ?? '',
        ),
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

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final members = _store.members.values
        .where(
          (member) =>
              member.clanId == clanId && member.branchId == resolvedBranchId,
        )
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final memberIds = members.map((member) => member.id).toSet();
    final branch = _store.branches[resolvedBranchId];
    final branches = [if (branch != null && branch.clanId == clanId) branch];
    final relationships = _store.relationships.values
        .where(
          (relationship) =>
              relationship.clanId == clanId &&
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
