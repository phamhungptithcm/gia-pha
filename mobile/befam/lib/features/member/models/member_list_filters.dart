class MemberListFilters {
  const MemberListFilters({this.query = '', this.branchId, this.generation});

  final String query;
  final String? branchId;
  final int? generation;

  MemberListFilters copyWith({
    String? query,
    String? branchId,
    int? generation,
    bool clearBranch = false,
    bool clearGeneration = false,
  }) {
    return MemberListFilters(
      query: query ?? this.query,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      generation: clearGeneration ? null : (generation ?? this.generation),
    );
  }
}
