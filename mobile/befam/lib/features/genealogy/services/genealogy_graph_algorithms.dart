import 'dart:collection';

import 'package:collection/collection.dart';

import '../../member/models/member_profile.dart';
import '../../relationship/models/relationship_record.dart';
import '../models/genealogy_generation_label.dart';
import '../models/genealogy_graph.dart';

class GenealogyGraphAlgorithms {
  const GenealogyGraphAlgorithms._();

  static GenealogyGraph buildAdjacencyMap({
    required Iterable<MemberProfile> members,
    required Iterable<RelationshipRecord> relationships,
    String? focusMemberId,
  }) {
    final membersById = {
      for (final member in members) member.id: member,
    };
    final parentSets = <String, Set<String>>{
      for (final memberId in membersById.keys) memberId: <String>{},
    };
    final childSets = <String, Set<String>>{
      for (final memberId in membersById.keys) memberId: <String>{},
    };
    final spouseSets = <String, Set<String>>{
      for (final memberId in membersById.keys) memberId: <String>{},
    };

    for (final relationship in relationships.where((entry) => entry.isActive)) {
      if (!membersById.containsKey(relationship.personAId) ||
          !membersById.containsKey(relationship.personBId)) {
        continue;
      }

      switch (relationship.type) {
        case RelationshipType.parentChild:
          childSets[relationship.personAId]!.add(relationship.personBId);
          parentSets[relationship.personBId]!.add(relationship.personAId);
        case RelationshipType.spouse:
          spouseSets[relationship.personAId]!.add(relationship.personBId);
          spouseSets[relationship.personBId]!.add(relationship.personAId);
      }
    }

    final parentMap = _sortedMap(parentSets, membersById);
    final childMap = _sortedMap(childSets, membersById);
    final spouseMap = _sortedMap(spouseSets, membersById);
    final siblingGroups = computeSiblingGroups(
      membersById: membersById,
      parentMap: parentMap,
      childMap: childMap,
    );

    return GenealogyGraph(
      membersById: Map.unmodifiable(membersById),
      parentMap: Map.unmodifiable(parentMap),
      childMap: Map.unmodifiable(childMap),
      spouseMap: Map.unmodifiable(spouseMap),
      siblingGroups: Map.unmodifiable(siblingGroups),
      generationLabels: Map.unmodifiable(
        buildGenerationLabels(
          membersById: membersById,
          parentMap: parentMap,
          childMap: childMap,
          spouseMap: spouseMap,
          focusMemberId: focusMemberId,
        ),
      ),
    );
  }

  static List<String> buildAncestryPath({
    required GenealogyGraph graph,
    required String memberId,
    int maxDepth = 8,
  }) {
    final member = graph.membersById[memberId];
    if (member == null) {
      return const [];
    }

    final path = <String>[memberId];
    var currentId = memberId;
    var depth = 0;
    while (depth < maxDepth) {
      final parents = graph.parentsOf(currentId);
      if (parents.isEmpty) {
        break;
      }
      final nextParentId = parents.sorted(_memberIdComparator(graph)).first;
      path.add(nextParentId);
      currentId = nextParentId;
      depth += 1;
    }
    return path;
  }

  static List<String> buildDescendantsTraversal({
    required GenealogyGraph graph,
    required String memberId,
    int maxDepth = 3,
  }) {
    if (!graph.membersById.containsKey(memberId)) {
      return const [];
    }

    final result = <String>[];
    final visited = <String>{memberId};
    final queue = Queue<({String memberId, int depth})>()
      ..add((memberId: memberId, depth: 0));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.depth >= maxDepth) {
        continue;
      }

      for (final childId in graph.childrenOf(current.memberId)) {
        if (!visited.add(childId)) {
          continue;
        }
        result.add(childId);
        queue.add((memberId: childId, depth: current.depth + 1));
      }
    }

    return result;
  }

  static Map<String, List<String>> computeSiblingGroups({
    required Map<String, MemberProfile> membersById,
    required Map<String, List<String>> parentMap,
    required Map<String, List<String>> childMap,
  }) {
    final groups = <String, List<String>>{};
    for (final memberId in membersById.keys) {
      final siblingIds = <String>{};
      for (final parentId in parentMap[memberId] ?? const <String>[]) {
        siblingIds.addAll(childMap[parentId] ?? const <String>[]);
      }
      siblingIds.remove(memberId);
      groups[memberId] = siblingIds.toList(growable: false)
        ..sort(_memberIdComparatorFromMap(membersById));
    }
    return groups;
  }

  static Map<String, GenealogyGenerationLabel> buildGenerationLabels({
    required Map<String, MemberProfile> membersById,
    required Map<String, List<String>> parentMap,
    required Map<String, List<String>> childMap,
    required Map<String, List<String>> spouseMap,
    String? focusMemberId,
  }) {
    final relativeLevels = <String, int>{};
    if (focusMemberId != null && membersById.containsKey(focusMemberId)) {
      final queue = Queue<({String memberId, int level})>()
        ..add((memberId: focusMemberId, level: 0));

      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        final existingLevel = relativeLevels[current.memberId];
        if (existingLevel != null && existingLevel.abs() <= current.level.abs()) {
          continue;
        }
        relativeLevels[current.memberId] = current.level;

        for (final parentId in parentMap[current.memberId] ?? const <String>[]) {
          if (!relativeLevels.containsKey(parentId)) {
            queue.add((memberId: parentId, level: current.level - 1));
          }
        }
        for (final childId in childMap[current.memberId] ?? const <String>[]) {
          if (!relativeLevels.containsKey(childId)) {
            queue.add((memberId: childId, level: current.level + 1));
          }
        }
        for (final spouseId in spouseMap[current.memberId] ?? const <String>[]) {
          if (!relativeLevels.containsKey(spouseId)) {
            queue.add((memberId: spouseId, level: current.level));
          }
        }
      }
    }

    return {
      for (final entry in membersById.entries)
        entry.key: GenealogyGenerationLabel(
          absoluteGeneration: entry.value.generation,
          relativeLevel: relativeLevels[entry.key],
        ),
    };
  }

  static Map<String, List<String>> _sortedMap(
    Map<String, Set<String>> source,
    Map<String, MemberProfile> membersById,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: entry.value.toList(growable: false)
          ..sort(_memberIdComparatorFromMap(membersById)),
    };
  }

  static Comparator<String> _memberIdComparator(GenealogyGraph graph) {
    return _memberIdComparatorFromMap(graph.membersById);
  }

  static Comparator<String> _memberIdComparatorFromMap(
    Map<String, MemberProfile> membersById,
  ) {
    return (left, right) {
      final leftMember = membersById[left];
      final rightMember = membersById[right];
      final leftGeneration = leftMember?.generation ?? 999;
      final rightGeneration = rightMember?.generation ?? 999;
      if (leftGeneration != rightGeneration) {
        return leftGeneration.compareTo(rightGeneration);
      }

      final byName = (leftMember?.fullName ?? left).toLowerCase().compareTo(
        (rightMember?.fullName ?? right).toLowerCase(),
      );
      if (byName != 0) {
        return byName;
      }
      return left.compareTo(right);
    };
  }
}
