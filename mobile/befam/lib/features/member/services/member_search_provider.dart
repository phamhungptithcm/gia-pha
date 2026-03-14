import '../models/member_profile.dart';

class MemberSearchQuery {
  const MemberSearchQuery({
    required this.query,
    this.branchId,
    this.generation,
  });

  final String query;
  final String? branchId;
  final int? generation;
}

abstract interface class MemberSearchProvider {
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  });
}

class LocalMemberSearchProvider implements MemberSearchProvider {
  const LocalMemberSearchProvider({
    this.latency = const Duration(milliseconds: 120),
  });

  final Duration latency;

  @override
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  }) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    final normalizedQuery = query.query.trim().toLowerCase();
    final results = members
        .where((member) {
          final branchMatches =
              query.branchId == null || query.branchId == member.branchId;
          final generationMatches =
              query.generation == null || query.generation == member.generation;
          final textMatches =
              normalizedQuery.isEmpty ||
              member.fullName.toLowerCase().contains(normalizedQuery) ||
              member.nickName.toLowerCase().contains(normalizedQuery) ||
              (member.phoneE164?.toLowerCase().contains(normalizedQuery) ??
                  false);
          return branchMatches && generationMatches && textMatches;
        })
        .toList(growable: false);

    results.sort((left, right) {
      final byName = left.fullName.compareTo(right.fullName);
      if (byName != 0) {
        return byName;
      }
      return left.id.compareTo(right.id);
    });
    return results;
  }
}

MemberSearchProvider createDefaultMemberSearchProvider() {
  return const LocalMemberSearchProvider();
}
