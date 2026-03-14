enum GenealogyScopeType { clan, branch }

class GenealogyScope {
  const GenealogyScope.clan({required this.clanId})
    : type = GenealogyScopeType.clan,
      branchId = null;

  const GenealogyScope.branch({
    required this.clanId,
    required this.branchId,
  }) : type = GenealogyScopeType.branch;

  final GenealogyScopeType type;
  final String clanId;
  final String? branchId;

  String get cacheKey {
    return switch (type) {
      GenealogyScopeType.clan => 'clan:$clanId',
      GenealogyScopeType.branch => 'branch:$clanId:${branchId ?? ''}',
    };
  }
}
