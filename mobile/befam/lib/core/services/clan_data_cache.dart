import '../../features/clan/models/branch_profile.dart';
import '../../features/member/models/member_profile.dart';

/// Per-session in-memory cache for clan-wide member and branch lists.
///
/// Multiple feature repositories (Member, Event, Genealogy, Scholarship)
/// each perform independent Firestore reads of the same `members` and
/// `branches` collections filtered by `clanId`. This cache is a single
/// source of truth that is populated on the first read and reused for the
/// remainder of the session, eliminating redundant round-trips.
///
/// The cache is invalidated:
/// - explicitly via [invalidate] when a member or branch is written, or
/// - automatically after [ttl] (default 5 minutes) so stale data does not
///   persist across background/foreground cycles.
class ClanDataCache {
  ClanDataCache._();

  static final ClanDataCache _shared = ClanDataCache._();

  factory ClanDataCache.shared() => _shared;

  static const Duration ttl = Duration(minutes: 5);

  final Map<String, _ClanEntry> _entries = {};

  // ── members ──────────────────────────────────────────────────────────────

  List<MemberProfile>? readMembers(String clanId) {
    return _entries[clanId]?._validMembers;
  }

  void writeMembers(String clanId, List<MemberProfile> members) {
    _entries.putIfAbsent(clanId, _ClanEntry.new).._membersAt = DateTime.now()
      .._members = members;
  }

  // ── branches ─────────────────────────────────────────────────────────────

  List<BranchProfile>? readBranches(String clanId) {
    return _entries[clanId]?._validBranches;
  }

  void writeBranches(String clanId, List<BranchProfile> branches) {
    _entries.putIfAbsent(clanId, _ClanEntry.new).._branchesAt = DateTime.now()
      .._branches = branches;
  }

  // ── invalidation ─────────────────────────────────────────────────────────

  /// Clears members and/or branches for [clanId].
  /// Pass [members] / [branches] flags to selectively invalidate.
  void invalidate(
    String clanId, {
    bool members = true,
    bool branches = true,
  }) {
    final entry = _entries[clanId];
    if (entry == null) {
      return;
    }
    if (members) {
      entry._members = null;
      entry._membersAt = null;
    }
    if (branches) {
      entry._branches = null;
      entry._branchesAt = null;
    }
  }

  /// Clears all cached data (e.g. on sign-out or clan context switch).
  void clear() => _entries.clear();
}

class _ClanEntry {
  List<MemberProfile>? _members;
  DateTime? _membersAt;

  List<BranchProfile>? _branches;
  DateTime? _branchesAt;

  List<MemberProfile>? get _validMembers {
    final at = _membersAt;
    if (_members == null || at == null) {
      return null;
    }
    if (DateTime.now().difference(at) > ClanDataCache.ttl) {
      _members = null;
      _membersAt = null;
      return null;
    }
    return _members;
  }

  List<BranchProfile>? get _validBranches {
    final at = _branchesAt;
    if (_branches == null || at == null) {
      return null;
    }
    if (DateTime.now().difference(at) > ClanDataCache.ttl) {
      _branches = null;
      _branchesAt = null;
      return null;
    }
    return _branches;
  }
}
