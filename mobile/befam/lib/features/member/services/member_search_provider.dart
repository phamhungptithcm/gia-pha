import '../models/member_profile.dart';
import '../../auth/services/phone_number_formatter.dart';

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

    final normalizedQuery = _normalizeForSearch(query.query);
    final queryTokens = _tokenizeQuery(normalizedQuery);
    final ranked = <_RankedMember>[];

    for (final member in members) {
      final branchMatches =
          query.branchId == null || query.branchId == member.branchId;
      final generationMatches =
          query.generation == null || query.generation == member.generation;
      if (!branchMatches || !generationMatches) {
        continue;
      }

      if (normalizedQuery.isEmpty) {
        ranked.add(_RankedMember(member: member, score: 0));
        continue;
      }

      final score = _scoreMatch(
        member: member,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
      );
      if (score == null) {
        continue;
      }
      ranked.add(_RankedMember(member: member, score: score));
    }

    ranked.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) {
        return byScore;
      }
      final byName = left.member.fullName.compareTo(right.member.fullName);
      if (byName != 0) {
        return byName;
      }
      return left.member.id.compareTo(right.member.id);
    });

    return ranked.map((entry) => entry.member).toList(growable: false);
  }

  int? _scoreMatch({
    required MemberProfile member,
    required String normalizedQuery,
    required List<String> queryTokens,
  }) {
    final fullName = _normalizeForSearch(member.fullName);
    final normalizedFullName = _normalizeForSearch(member.normalizedFullName);
    final nickName = _normalizeForSearch(member.nickName);
    final normalizedPhoneQuery = normalizedQuery.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    final normalizedPhoneDigitsQuery = normalizedPhoneQuery.replaceAll('+', '');
    final phoneKeys = PhoneNumberFormatter.comparisonKeys(member.phoneE164);

    var score = -1;
    void apply(bool condition, int value) {
      if (!condition) {
        return;
      }
      if (value > score) {
        score = value;
      }
    }

    apply(
      fullName == normalizedQuery || normalizedFullName == normalizedQuery,
      120,
    );
    apply(
      fullName.startsWith(normalizedQuery) ||
          normalizedFullName.startsWith(normalizedQuery),
      105,
    );
    apply(
      fullName.contains(normalizedQuery) ||
          normalizedFullName.contains(normalizedQuery),
      90,
    );

    apply(nickName == normalizedQuery, 110);
    apply(nickName.startsWith(normalizedQuery), 98);
    apply(nickName.contains(normalizedQuery), 82);

    apply(
      normalizedPhoneQuery.isNotEmpty &&
          phoneKeys.any(
            (key) =>
                key.contains(normalizedPhoneQuery) ||
                (normalizedPhoneDigitsQuery.isNotEmpty &&
                    key
                        .replaceAll('+', '')
                        .contains(normalizedPhoneDigitsQuery)),
          ),
      70,
    );

    if (queryTokens.isNotEmpty) {
      final fullNameTokens = fullName
          .split(' ')
          .map((token) => token.trim())
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      final tokenMatches = queryTokens
          .where(
            (queryToken) => fullNameTokens.any(
              (nameToken) => nameToken.startsWith(queryToken),
            ),
          )
          .length;
      if (tokenMatches > 0) {
        apply(true, 75 + tokenMatches);
      }
    }

    return score < 0 ? null : score;
  }
}

MemberSearchProvider createDefaultMemberSearchProvider() {
  return const LocalMemberSearchProvider();
}

class _RankedMember {
  const _RankedMember({required this.member, required this.score});

  final MemberProfile member;
  final int score;
}

final RegExp _accentARegex = RegExp('[àáạảãăằắặẳẵâầấậẩẫ]');
final RegExp _accentERegex = RegExp('[èéẹẻẽêềếệểễ]');
final RegExp _accentIRegex = RegExp('[ìíịỉĩ]');
final RegExp _accentORegex = RegExp('[òóọỏõôồốộổỗơờớợởỡ]');
final RegExp _accentURegex = RegExp('[ùúụủũưừứựửữ]');
final RegExp _accentYRegex = RegExp('[ỳýỵỷỹ]');
final RegExp _accentDRegex = RegExp('[đ]');
final RegExp _whitespaceRegex = RegExp(r'\s+');

String _normalizeForSearch(String value) {
  var normalized = value.toLowerCase().trim();
  if (normalized.isEmpty) {
    return '';
  }

  normalized = normalized
      .replaceAll(_accentARegex, 'a')
      .replaceAll(_accentERegex, 'e')
      .replaceAll(_accentIRegex, 'i')
      .replaceAll(_accentORegex, 'o')
      .replaceAll(_accentURegex, 'u')
      .replaceAll(_accentYRegex, 'y')
      .replaceAll(_accentDRegex, 'd')
      .replaceAll(_whitespaceRegex, ' ');

  return normalized;
}

List<String> _tokenizeQuery(String normalizedQuery) {
  if (normalizedQuery.isEmpty) {
    return const [];
  }
  return normalizedQuery
      .split(' ')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}
