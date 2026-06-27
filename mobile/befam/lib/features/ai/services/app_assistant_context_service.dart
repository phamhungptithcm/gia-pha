import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../../member/models/member_workspace_snapshot.dart';
import '../../member/services/member_repository.dart';
import '../../member/services/member_search_provider.dart';
import '../../../core/services/kinship_title_resolver.dart';

class AppAssistantMemberMatch {
  const AppAssistantMemberMatch({
    required this.memberId,
    required this.displayName,
    required this.fullName,
    required this.relationshipCode,
    required this.nickName,
    required this.branchName,
    required this.generation,
    required this.birthDate,
    required this.deathDate,
    required this.jobTitle,
    required this.hasPhone,
    required this.hasAddress,
    required this.parentCount,
    required this.childCount,
    required this.spouseCount,
  });

  final String memberId;
  final String displayName;
  final String fullName;
  final String relationshipCode;
  final String nickName;
  final String branchName;
  final int generation;
  final String birthDate;
  final String deathDate;
  final String jobTitle;
  final bool hasPhone;
  final bool hasAddress;
  final int parentCount;
  final int childCount;
  final int spouseCount;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'memberId': memberId,
      'displayName': displayName,
      'fullName': fullName,
      'relationshipCode': relationshipCode,
      'nickName': nickName,
      'branchName': branchName,
      'generation': generation,
      'birthDate': birthDate,
      'deathDate': deathDate,
      'jobTitle': jobTitle,
      'hasPhone': hasPhone,
      'hasAddress': hasAddress,
      'parentCount': parentCount,
      'childCount': childCount,
      'spouseCount': spouseCount,
    };
  }
}

class AppAssistantSearchContext {
  const AppAssistantSearchContext({
    required this.searchQueryHint,
    required this.activeClanName,
    required this.activeClanMemberCount,
    required this.activeClanBranchCount,
    required this.availableClanCount,
    required this.availableClanNames,
    required this.memberMatches,
  });

  final String searchQueryHint;
  final String activeClanName;
  final int activeClanMemberCount;
  final int activeClanBranchCount;
  final int availableClanCount;
  final List<String> availableClanNames;
  final List<AppAssistantMemberMatch> memberMatches;

  bool get hasSearchHint => searchQueryHint.trim().isNotEmpty;
  bool get hasMemberMatches => memberMatches.isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'searchQueryHint': searchQueryHint,
      'activeClanName': activeClanName,
      'activeClanMemberCount': activeClanMemberCount,
      'activeClanBranchCount': activeClanBranchCount,
      'availableClanCount': availableClanCount,
      'availableClanNames': availableClanNames,
      'memberMatches': memberMatches
          .map((entry) => entry.toMap())
          .toList(growable: false),
    };
  }
}

abstract interface class AppAssistantContextService {
  Future<AppAssistantSearchContext> buildSearchContext({
    required AuthSession session,
    required String question,
    String? activeClanName,
    List<ClanContextOption> availableClanContexts = const [],
  });
}

class MemberWorkspaceAssistantContextService
    implements AppAssistantContextService {
  MemberWorkspaceAssistantContextService({
    required MemberRepository memberRepository,
    MemberSearchProvider? memberSearchProvider,
    Duration snapshotCacheTtl = const Duration(minutes: 1),
    DateTime Function()? nowProvider,
  }) : _memberRepository = memberRepository,
       _memberSearchProvider =
           memberSearchProvider ??
           const LocalMemberSearchProvider(latency: Duration.zero),
       _snapshotCacheTtl = snapshotCacheTtl,
       _nowProvider = nowProvider ?? DateTime.now;

  final MemberRepository _memberRepository;
  final MemberSearchProvider _memberSearchProvider;
  final Duration _snapshotCacheTtl;
  final DateTime Function() _nowProvider;
  MemberWorkspaceSnapshot? _cachedSnapshot;
  String? _cachedSnapshotKey;
  DateTime? _cachedSnapshotAt;
  Future<MemberWorkspaceSnapshot>? _pendingWorkspaceLoad;
  String? _pendingWorkspaceLoadKey;

  @override
  Future<AppAssistantSearchContext> buildSearchContext({
    required AuthSession session,
    required String question,
    String? activeClanName,
    List<ClanContextOption> availableClanContexts = const [],
  }) async {
    final availableClanNames = _resolveClanNames(
      activeClanName: activeClanName,
      availableClanContexts: availableClanContexts,
    );
    final clanName = (activeClanName ?? '').trim();

    try {
      final snapshot = await _loadWorkspaceSnapshot(session: session);
      final searchQueryHint = _extractSearchQueryHint(question);
      final memberMatches = await _resolveMemberMatches(
        snapshot: snapshot,
        session: session,
        searchQueryHint: searchQueryHint,
      );

      return AppAssistantSearchContext(
        searchQueryHint: searchQueryHint,
        activeClanName: clanName,
        activeClanMemberCount: snapshot.members.length,
        activeClanBranchCount: snapshot.branches.length,
        availableClanCount: availableClanNames.length,
        availableClanNames: availableClanNames,
        memberMatches: memberMatches,
      );
    } catch (_) {
      return AppAssistantSearchContext(
        searchQueryHint: _extractSearchQueryHint(question),
        activeClanName: clanName,
        activeClanMemberCount: 0,
        activeClanBranchCount: 0,
        availableClanCount: availableClanNames.length,
        availableClanNames: availableClanNames,
        memberMatches: const [],
      );
    }
  }

  Future<MemberWorkspaceSnapshot> _loadWorkspaceSnapshot({
    required AuthSession session,
  }) async {
    final cacheKey = '${session.uid}:${session.clanId ?? ''}';
    final cachedSnapshot = _cachedSnapshot;
    final cachedAt = _cachedSnapshotAt;
    if (cachedSnapshot != null &&
        _cachedSnapshotKey == cacheKey &&
        cachedAt != null &&
        _nowProvider().difference(cachedAt) <= _snapshotCacheTtl) {
      return cachedSnapshot;
    }

    final pendingLoad = _pendingWorkspaceLoad;
    if (pendingLoad != null && _pendingWorkspaceLoadKey == cacheKey) {
      return pendingLoad;
    }

    final loadFuture = _memberRepository.loadWorkspace(session: session);
    _pendingWorkspaceLoad = loadFuture;
    _pendingWorkspaceLoadKey = cacheKey;
    try {
      final snapshot = await loadFuture;
      _cachedSnapshot = snapshot;
      _cachedSnapshotKey = cacheKey;
      _cachedSnapshotAt = _nowProvider();
      return snapshot;
    } finally {
      if (identical(_pendingWorkspaceLoad, loadFuture)) {
        _pendingWorkspaceLoad = null;
        _pendingWorkspaceLoadKey = null;
      }
    }
  }

  Future<List<AppAssistantMemberMatch>> _resolveMemberMatches({
    required MemberWorkspaceSnapshot snapshot,
    required AuthSession session,
    required String searchQueryHint,
  }) async {
    final normalizedQuery = searchQueryHint.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final viewer = _findViewer(snapshot: snapshot, session: session);
    final kinshipIntent = _detectKinshipSearchIntent(normalizedQuery);
    if (kinshipIntent != null && viewer != null) {
      final relationshipMatches = _resolveRelationshipMatches(
        snapshot: snapshot,
        viewer: viewer,
        intent: kinshipIntent,
      );
      if (relationshipMatches.isNotEmpty) {
        return relationshipMatches;
      }
    }

    final rankedMatches = await _memberSearchProvider.search(
      members: snapshot.members,
      query: MemberSearchQuery(query: normalizedQuery),
    );
    if (rankedMatches.isEmpty) {
      return const [];
    }

    final branchesById = <String, BranchProfile>{
      for (final branch in snapshot.branches) branch.id: branch,
    };

    return rankedMatches
        .take(5)
        .map(
          (member) => AppAssistantMemberMatch(
            memberId: member.id,
            displayName: member.displayName,
            fullName: member.fullName.trim(),
            relationshipCode: _relationshipCodeForMemberMatch(
              viewer: viewer,
              member: member,
            ),
            nickName: member.nickName.trim(),
            branchName:
                branchesById[member.branchId]?.name.trim().isNotEmpty == true
                ? branchesById[member.branchId]!.name.trim()
                : '',
            generation: member.generation,
            birthDate: (member.birthDate ?? '').trim(),
            deathDate: (member.deathDate ?? '').trim(),
            jobTitle: (member.jobTitle ?? '').trim(),
            hasPhone: (member.phoneE164 ?? '').trim().isNotEmpty,
            hasAddress: (member.addressText ?? '').trim().isNotEmpty,
            parentCount: member.parentIds.length,
            childCount: member.childrenIds.length,
            spouseCount: member.spouseIds.length,
          ),
        )
        .toList(growable: false);
  }

  List<AppAssistantMemberMatch> _resolveRelationshipMatches({
    required MemberWorkspaceSnapshot snapshot,
    required MemberProfile viewer,
    required _KinshipSearchIntent intent,
  }) {
    final branchesById = <String, BranchProfile>{
      for (final branch in snapshot.branches) branch.id: branch,
    };
    final membersById = <String, MemberProfile>{
      for (final member in snapshot.members) member.id: member,
    };
    final matches = <AppAssistantMemberMatch>[];

    for (final member in snapshot.members) {
      if (member.id == viewer.id) {
        continue;
      }
      if (!_matchesKinshipIntent(
        viewer: viewer,
        member: member,
        intent: intent,
      )) {
        continue;
      }
      matches.add(
        AppAssistantMemberMatch(
          memberId: member.id,
          displayName: member.displayName,
          fullName: member.fullName.trim(),
          relationshipCode: _relationshipCodeForMemberMatch(
            viewer: viewer,
            member: member,
          ),
          nickName: member.nickName.trim(),
          branchName:
              branchesById[member.branchId]?.name.trim().isNotEmpty == true
              ? branchesById[member.branchId]!.name.trim()
              : '',
          generation: member.generation,
          birthDate: (member.birthDate ?? '').trim(),
          deathDate: (member.deathDate ?? '').trim(),
          jobTitle: (member.jobTitle ?? '').trim(),
          hasPhone: (member.phoneE164 ?? '').trim().isNotEmpty,
          hasAddress: (member.addressText ?? '').trim().isNotEmpty,
          parentCount: member.parentIds.length,
          childCount: member.childrenIds.length,
          spouseCount: member.spouseIds.length,
        ),
      );
    }

    matches.sort((left, right) {
      final ageWeight = _compareRelativeAgeByMatch(
        left: membersById[left.memberId],
        right: membersById[right.memberId],
      );
      if (ageWeight != 0) {
        if (intent.requiredAgeDirection == _KinshipAgeDirection.younger) {
          return -ageWeight;
        }
        return ageWeight;
      }
      final byGeneration = left.generation.compareTo(right.generation);
      if (byGeneration != 0) {
        return byGeneration;
      }
      return left.fullName.compareTo(right.fullName);
    });

    return matches.take(5).toList(growable: false);
  }

  MemberProfile? _findViewer({
    required MemberWorkspaceSnapshot snapshot,
    required AuthSession session,
  }) {
    final viewerId = (session.memberId ?? '').trim();
    if (viewerId.isEmpty) {
      return null;
    }
    for (final member in snapshot.members) {
      if (member.id == viewerId) {
        return member;
      }
    }
    return null;
  }

  List<String> _resolveClanNames({
    required String? activeClanName,
    required List<ClanContextOption> availableClanContexts,
  }) {
    final names = <String>[];
    final normalized = <String>{};

    void addName(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }
      final key = trimmed.toLowerCase();
      if (!normalized.add(key)) {
        return;
      }
      names.add(trimmed);
    }

    addName(activeClanName ?? '');
    for (final option in availableClanContexts) {
      addName(option.clanName);
    }
    return names.take(6).toList(growable: false);
  }
}

class _KinshipSearchIntent {
  const _KinshipSearchIntent({
    required this.allowedRoles,
    this.requiredGender,
    this.requiredAgeDirection,
  });

  final Set<KinshipTitleRole> allowedRoles;
  final _KinshipGenderFilter? requiredGender;
  final _KinshipAgeDirection? requiredAgeDirection;
}

enum _KinshipGenderFilter { male, female }

enum _KinshipAgeDirection { older, younger }

_KinshipSearchIntent? _detectKinshipSearchIntent(String searchQueryHint) {
  final normalized = _normalizeSearchText(searchQueryHint);
  if (normalized.isEmpty) {
    return null;
  }

  if (_containsAny(normalized, const ['anh ho', 'anh em ho'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sameGenerationRelative},
      requiredGender: _KinshipGenderFilter.male,
      requiredAgeDirection: _KinshipAgeDirection.older,
    );
  }
  if (_containsAny(normalized, const ['chi ho'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sameGenerationRelative},
      requiredGender: _KinshipGenderFilter.female,
      requiredAgeDirection: _KinshipAgeDirection.older,
    );
  }
  if (_containsAny(normalized, const ['em ho'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sameGenerationRelative},
      requiredAgeDirection: _KinshipAgeDirection.younger,
    );
  }
  if (_containsAny(normalized, const [
    'anh chi em ho',
    'anh em ho',
    'chi em ho',
    'cousin',
    'ba con ho',
    'nguoi ho hang cung doi',
  ])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sameGenerationRelative},
    );
  }
  if (_containsAny(normalized, const ['anh trai', 'anh ruot'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sibling},
      requiredGender: _KinshipGenderFilter.male,
      requiredAgeDirection: _KinshipAgeDirection.older,
    );
  }
  if (_containsAny(normalized, const ['chi gai', 'chi ruot'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sibling},
      requiredGender: _KinshipGenderFilter.female,
      requiredAgeDirection: _KinshipAgeDirection.older,
    );
  }
  if (_containsAny(normalized, const ['em trai'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sibling},
      requiredGender: _KinshipGenderFilter.male,
      requiredAgeDirection: _KinshipAgeDirection.younger,
    );
  }
  if (_containsAny(normalized, const ['em gai'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.sibling},
      requiredGender: _KinshipGenderFilter.female,
      requiredAgeDirection: _KinshipAgeDirection.younger,
    );
  }
  if (_containsAny(normalized, const [
    'anh chi em',
    'anh chi em ruot',
    'anh em ruot',
    'chi em ruot',
    'sibling',
  ])) {
    return const _KinshipSearchIntent(allowedRoles: {KinshipTitleRole.sibling});
  }
  if (_containsAny(normalized, const ['cha', 'bo', 'ba', 'father', 'dad'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.parent},
      requiredGender: _KinshipGenderFilter.male,
    );
  }
  if (_containsAny(normalized, const ['me', 'ma ', 'mom', 'mother'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.parent},
      requiredGender: _KinshipGenderFilter.female,
    );
  }
  if (_containsAny(normalized, const ['phu huynh', 'bo me', 'parent'])) {
    return const _KinshipSearchIntent(allowedRoles: {KinshipTitleRole.parent});
  }
  if (_containsAny(normalized, const ['ong ba', 'grandparent'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {
        KinshipTitleRole.grandparent,
        KinshipTitleRole.greatGrandparent,
        KinshipTitleRole.greatGreatGrandparent,
      },
    );
  }
  if (_containsAny(normalized, const [
    'bac',
    'chu',
    'co',
    'di',
    'cau',
    'aunt',
    'uncle',
  ])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.elderRelativeOneGeneration},
    );
  }
  if (_containsAny(normalized, const ['con trai', 'son'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.child},
      requiredGender: _KinshipGenderFilter.male,
    );
  }
  if (_containsAny(normalized, const ['con gai', 'daughter'])) {
    return const _KinshipSearchIntent(
      allowedRoles: {KinshipTitleRole.child},
      requiredGender: _KinshipGenderFilter.female,
    );
  }
  if (_containsAny(normalized, const ['con ', 'child'])) {
    return const _KinshipSearchIntent(allowedRoles: {KinshipTitleRole.child});
  }

  return null;
}

bool _containsAny(String normalized, List<String> candidates) {
  for (final candidate in candidates) {
    if (normalized.contains(candidate)) {
      return true;
    }
  }
  return false;
}

bool _matchesKinshipIntent({
  required MemberProfile viewer,
  required MemberProfile member,
  required _KinshipSearchIntent intent,
}) {
  final role = KinshipTitleResolver.resolveRole(viewer: viewer, member: member);
  if (!intent.allowedRoles.contains(role)) {
    return false;
  }

  if (intent.requiredGender != null) {
    final gender = _genderFilterFor(member.gender);
    if (gender != intent.requiredGender) {
      return false;
    }
  }

  if (intent.requiredAgeDirection != null) {
    final ageDirection = _relativeAgeDirection(viewer: viewer, member: member);
    if (ageDirection != intent.requiredAgeDirection) {
      return false;
    }
  }

  return true;
}

_KinshipGenderFilter? _genderFilterFor(String? gender) {
  final normalized = (gender ?? '').trim().toLowerCase();
  if (normalized == 'male' || normalized == 'nam') {
    return _KinshipGenderFilter.male;
  }
  if (normalized == 'female' || normalized == 'nu' || normalized == 'nữ') {
    return _KinshipGenderFilter.female;
  }
  return null;
}

_KinshipAgeDirection? _relativeAgeDirection({
  required MemberProfile viewer,
  required MemberProfile member,
}) {
  final viewerBirth = DateTime.tryParse((viewer.birthDate ?? '').trim());
  final memberBirth = DateTime.tryParse((member.birthDate ?? '').trim());
  if (viewerBirth != null && memberBirth != null) {
    if (memberBirth.isBefore(viewerBirth)) {
      return _KinshipAgeDirection.older;
    }
    if (memberBirth.isAfter(viewerBirth)) {
      return _KinshipAgeDirection.younger;
    }
  }

  final sameParents =
      viewer.parentIds.isNotEmpty &&
      member.parentIds.isNotEmpty &&
      viewer.parentIds
          .toSet()
          .intersection(member.parentIds.toSet())
          .isNotEmpty;
  if (sameParents &&
      viewer.siblingOrder != null &&
      member.siblingOrder != null &&
      viewer.siblingOrder != member.siblingOrder) {
    return member.siblingOrder! < viewer.siblingOrder!
        ? _KinshipAgeDirection.older
        : _KinshipAgeDirection.younger;
  }

  return null;
}

int _compareRelativeAgeByMatch({
  required MemberProfile? left,
  required MemberProfile? right,
}) {
  if (left == null || right == null) {
    return 0;
  }
  final leftBirth = DateTime.tryParse((left.birthDate ?? '').trim());
  final rightBirth = DateTime.tryParse((right.birthDate ?? '').trim());
  if (leftBirth != null && rightBirth != null) {
    return leftBirth.compareTo(rightBirth);
  }
  return left.fullName.compareTo(right.fullName);
}

String _relationshipCodeForMemberMatch({
  required MemberProfile? viewer,
  required MemberProfile member,
}) {
  if (viewer == null) {
    return '';
  }
  final role = KinshipTitleResolver.resolveRole(viewer: viewer, member: member);
  return switch (role) {
    KinshipTitleRole.self => 'self',
    KinshipTitleRole.spouse => 'spouse',
    KinshipTitleRole.sibling => 'sibling',
    KinshipTitleRole.sameGenerationRelative => 'cousin',
    KinshipTitleRole.parent => 'parent',
    KinshipTitleRole.elderRelativeOneGeneration => 'aunt_uncle',
    KinshipTitleRole.grandparent => 'grandparent',
    KinshipTitleRole.greatGrandparent => 'great_grandparent',
    KinshipTitleRole.greatGreatGrandparent => 'great_great_grandparent',
    KinshipTitleRole.child => 'child',
    KinshipTitleRole.youngerRelativeOneGeneration => 'niece_nephew',
    KinshipTitleRole.grandchild => 'grandchild',
    KinshipTitleRole.greatGrandchild => 'great_grandchild',
    KinshipTitleRole.greatGreatGrandchild => 'great_great_grandchild',
    KinshipTitleRole.descendant => 'descendant',
  };
}

String _extractSearchQueryHint(String question) {
  final trimmed = question.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final quotedMatch = RegExp(
    r'["“](.+?)["”]',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (quotedMatch != null) {
    return quotedMatch.group(1)?.trim() ?? '';
  }

  final normalized = _normalizeSearchText(trimmed);
  if (normalized.isEmpty) {
    return '';
  }

  var earliestSuffixIndex = -1;
  for (final suffix in _nameQuestionSuffixes) {
    final index = normalized.indexOf(suffix);
    if (index < 0) {
      continue;
    }
    if (earliestSuffixIndex == -1 || index < earliestSuffixIndex) {
      earliestSuffixIndex = index;
    }
  }
  if (earliestSuffixIndex >= 0) {
    final candidate = trimmed.substring(0, earliestSuffixIndex).trim();
    return _stripSearchPrefix(candidate);
  }

  for (final keyword in _searchIntentKeywords) {
    final index = normalized.indexOf(keyword);
    if (index >= 0) {
      final start = _advanceOriginalOffset(trimmed, normalized, index);
      final candidate = trimmed.substring(start).trim();
      return _stripSearchPrefix(candidate);
    }
  }

  final tokenCount = normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .length;
  if (tokenCount >= 2 &&
      tokenCount <= 4 &&
      !_looksLikePureAppHelp(normalized)) {
    return trimmed;
  }

  return '';
}

bool _looksLikePureAppHelp(String normalized) {
  return _appHelpOnlyKeywords.any(normalized.contains);
}

String _stripSearchPrefix(String value) {
  var candidate = value.trim();
  for (final prefix in _leadingSearchPrefixes) {
    if (candidate.toLowerCase().startsWith(prefix)) {
      candidate = candidate.substring(prefix.length).trim();
    }
  }
  return candidate
      .replaceAll(RegExp(r'^[\s:,-]+'), '')
      .replaceAll(RegExp(r'[\s?.!,;:]+$'), '')
      .trim();
}

int _advanceOriginalOffset(String original, String normalized, int index) {
  if (index <= 0) {
    return 0;
  }

  var normalizedOffset = 0;
  for (
    var originalOffset = 0;
    originalOffset < original.length;
    originalOffset += 1
  ) {
    final current = _normalizeSearchText(
      original.substring(0, originalOffset + 1),
    );
    if (current.length > normalizedOffset) {
      normalizedOffset = current.length;
    }
    if (normalizedOffset > index) {
      return originalOffset + 1;
    }
  }
  return 0;
}

String _normalizeSearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(_accentARegex, 'a')
      .replaceAll(_accentERegex, 'e')
      .replaceAll(_accentIRegex, 'i')
      .replaceAll(_accentORegex, 'o')
      .replaceAll(_accentURegex, 'u')
      .replaceAll(_accentYRegex, 'y')
      .replaceAll(_accentDRegex, 'd')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const List<String> _searchIntentKeywords = <String>[
  'tim thong tin',
  'tim nguoi',
  'tim thanh vien',
  'tim ho so',
  'tim',
  'tra cuu',
  'search',
  'ai la',
  'cho toi xem',
];

const List<String> _nameQuestionSuffixes = <String>[
  ' o chi nao',
  ' thuoc chi nao',
  ' doi thu may',
  ' doi may',
  ' la ai',
  ' trong gia pha nao',
];

const List<String> _leadingSearchPrefixes = <String>[
  'tim thong tin ',
  'tim nguoi ',
  'tim thanh vien ',
  'tim ho so ',
  'tim ',
  'search ',
  'tra cuu ',
  'cho toi xem ',
  'nguoi than ',
  'thanh vien ',
  'member ',
  'ai la ',
];

const List<String> _appHelpOnlyKeywords = <String>[
  'cach ',
  'lam sao',
  'o dau',
  'how ',
  'where ',
  'tao su kien',
  'doi ngon ngu',
  'billing',
  'goi dich vu',
];

final RegExp _accentARegex = RegExp('[àáạảãăằắặẳẵâầấậẩẫ]');
final RegExp _accentERegex = RegExp('[èéẹẻẽêềếệểễ]');
final RegExp _accentIRegex = RegExp('[ìíịỉĩ]');
final RegExp _accentORegex = RegExp('[òóọỏõôồốộổỗơờớợởỡ]');
final RegExp _accentURegex = RegExp('[ùúụủũưừứựửữ]');
final RegExp _accentYRegex = RegExp('[ỳýỵỷỹ]');
final RegExp _accentDRegex = RegExp('[đ]');
