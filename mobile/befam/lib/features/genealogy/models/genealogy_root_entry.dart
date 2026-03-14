enum GenealogyRootReason {
  currentMember,
  clanRoot,
  scopeRoot,
  branchLeader,
  branchViceLeader,
}

class GenealogyRootEntry {
  const GenealogyRootEntry({
    required this.memberId,
    required this.reasons,
  });

  final String memberId;
  final List<GenealogyRootReason> reasons;
}
