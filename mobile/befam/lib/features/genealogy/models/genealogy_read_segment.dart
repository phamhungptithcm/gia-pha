import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../../relationship/models/relationship_record.dart';
import 'genealogy_graph.dart';
import 'genealogy_root_entry.dart';
import 'genealogy_scope.dart';

class GenealogyReadSegment {
  const GenealogyReadSegment({
    required this.scope,
    required this.members,
    required this.branches,
    required this.relationships,
    required this.graph,
    required this.rootEntries,
    required this.loadedAt,
    required this.fromCache,
  });

  final GenealogyScope scope;
  final List<MemberProfile> members;
  final List<BranchProfile> branches;
  final List<RelationshipRecord> relationships;
  final GenealogyGraph graph;
  final List<GenealogyRootEntry> rootEntries;
  final DateTime loadedAt;
  final bool fromCache;

  bool get isEmpty => members.isEmpty;

  GenealogyReadSegment copyWith({
    GenealogyScope? scope,
    List<MemberProfile>? members,
    List<BranchProfile>? branches,
    List<RelationshipRecord>? relationships,
    GenealogyGraph? graph,
    List<GenealogyRootEntry>? rootEntries,
    DateTime? loadedAt,
    bool? fromCache,
  }) {
    return GenealogyReadSegment(
      scope: scope ?? this.scope,
      members: members ?? this.members,
      branches: branches ?? this.branches,
      relationships: relationships ?? this.relationships,
      graph: graph ?? this.graph,
      rootEntries: rootEntries ?? this.rootEntries,
      loadedAt: loadedAt ?? this.loadedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  static GenealogyReadSegment empty(GenealogyScope scope) {
    return GenealogyReadSegment(
      scope: scope,
      members: const [],
      branches: const [],
      relationships: const [],
      graph: const GenealogyGraph(
        membersById: {},
        parentMap: {},
        childMap: {},
        spouseMap: {},
        siblingGroups: {},
        generationLabels: {},
      ),
      rootEntries: const [],
      loadedAt: DateTime.fromMillisecondsSinceEpoch(0),
      fromCache: false,
    );
  }
}
