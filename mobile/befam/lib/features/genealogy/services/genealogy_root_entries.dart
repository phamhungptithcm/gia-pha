import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/genealogy_root_entry.dart';
import '../models/genealogy_scope.dart';

List<GenealogyRootEntry> buildGenealogyRootEntries({
  required GenealogyScope scope,
  required AuthSession session,
  required List<MemberProfile> members,
  required List<BranchProfile> branches,
  required Map<String, List<String>> parentMap,
}) {
  final membersById = {for (final member in members) member.id: member};
  final reasonsByMember = <String, Set<GenealogyRootReason>>{};

  void addReason(String? memberId, GenealogyRootReason reason) {
    if (memberId == null || !membersById.containsKey(memberId)) {
      return;
    }
    reasonsByMember.putIfAbsent(memberId, () => <GenealogyRootReason>{}).add(reason);
  }

  addReason(session.memberId, GenealogyRootReason.currentMember);
  for (final branch in branches) {
    addReason(branch.leaderMemberId, GenealogyRootReason.branchLeader);
    addReason(branch.viceLeaderMemberId, GenealogyRootReason.branchViceLeader);
  }

  for (final member in members) {
    if ((parentMap[member.id] ?? const <String>[]).isEmpty) {
      addReason(
        member.id,
        scope.type == GenealogyScopeType.clan
            ? GenealogyRootReason.clanRoot
            : GenealogyRootReason.scopeRoot,
      );
    }
  }

  final entries = reasonsByMember.entries.map((entry) {
    final reasons = entry.value.toList(growable: false)
      ..sort((left, right) => rootReasonPriority(right) - rootReasonPriority(left));
    return GenealogyRootEntry(memberId: entry.key, reasons: reasons);
  }).toList(growable: false)
    ..sort((left, right) {
      final byPriority = entryPriority(right.reasons) - entryPriority(left.reasons);
      if (byPriority != 0) {
        return byPriority;
      }

      final leftMember = membersById[left.memberId]!;
      final rightMember = membersById[right.memberId]!;
      final byGeneration = leftMember.generation.compareTo(rightMember.generation);
      if (byGeneration != 0) {
        return byGeneration;
      }

      return leftMember.fullName.toLowerCase().compareTo(
        rightMember.fullName.toLowerCase(),
      );
    });

  return entries;
}

int entryPriority(List<GenealogyRootReason> reasons) {
  return reasons.fold<int>(
    0,
    (current, reason) =>
        current > rootReasonPriority(reason) ? current : rootReasonPriority(reason),
  );
}

int rootReasonPriority(GenealogyRootReason reason) {
  return switch (reason) {
    GenealogyRootReason.currentMember => 100,
    GenealogyRootReason.branchLeader => 90,
    GenealogyRootReason.branchViceLeader => 80,
    GenealogyRootReason.clanRoot => 70,
    GenealogyRootReason.scopeRoot => 60,
  };
}
