import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/performance_measurement_logger.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../models/member_draft.dart';
import '../models/member_list_filters.dart';
import '../models/member_profile.dart';
import '../services/member_search_analytics_service.dart';
import '../services/member_permissions.dart';
import '../services/member_repository.dart';
import '../services/member_search_provider.dart';

class MemberController extends ChangeNotifier {
  MemberController({
    required MemberRepository repository,
    required AuthSession session,
    MemberSearchProvider? searchProvider,
    MemberSearchAnalyticsService? searchAnalyticsService,
    PerformanceMeasurementLogger? performanceLogger,
  }) : _repository = repository,
       _session = session,
       _searchProvider = searchProvider ?? createDefaultMemberSearchProvider(),
       _searchAnalyticsService =
           searchAnalyticsService ??
           createDefaultMemberSearchAnalyticsService(),
       _performanceLogger = performanceLogger ?? PerformanceMeasurementLogger(),
       permissions = MemberPermissions.forSession(session);

  final MemberRepository _repository;
  final AuthSession _session;
  final MemberSearchProvider _searchProvider;
  final MemberSearchAnalyticsService _searchAnalyticsService;
  final PerformanceMeasurementLogger _performanceLogger;
  final MemberPermissions permissions;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  List<MemberProfile> _members = const [];
  List<BranchProfile> _branches = const [];
  MemberListFilters _filters = const MemberListFilters();
  List<MemberProfile> _searchResults = const [];
  bool _isSearching = false;
  String? _searchError;
  int _searchRevision = 0;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingAvatar => _isUploadingAvatar;
  String? get errorMessage => _errorMessage;
  List<MemberProfile> get members => _members;
  List<BranchProfile> get branches => _branches;
  MemberListFilters get filters => _filters;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  bool get hasClanContext => permissions.canViewWorkspace;
  bool get canAssignRoleManually => permissions.canAssignRoleManually;

  List<String> get assignableCreateRoles => const [
    GovernanceRoles.member,
    GovernanceRoles.clanLeader,
    GovernanceRoles.branchAdmin,
    GovernanceRoles.treasurer,
    GovernanceRoles.scholarshipCouncilHead,
    GovernanceRoles.adminSupport,
  ];

  List<MemberProfile> get _accessibleMembers {
    return _members
        .where((member) => permissions.canViewMember(member, _session))
        .toList(growable: false);
  }

  List<BranchProfile> get visibleBranches {
    if (permissions.canEditAnyMember &&
        permissions.restrictedBranchId == null) {
      return _branches;
    }

    final branchId = permissions.canEditAnyMember
        ? permissions.restrictedBranchId
        : permissions.sessionBranchId;
    if (branchId == null || branchId.isEmpty) {
      return const [];
    }

    return _branches
        .where((branch) => branch.id == branchId)
        .toList(growable: false);
  }

  List<int> get generationOptions {
    final values =
        _accessibleMembers.map((member) => member.generation).toSet().toList()
          ..sort();
    return values;
  }

  List<MemberProfile> get filteredMembers {
    return _searchResults;
  }

  MemberProfile? get selfMember {
    final memberId = _session.memberId;
    if (memberId == null || memberId.isEmpty) {
      return null;
    }

    return _members.firstWhereOrNull((member) => member.id == memberId);
  }

  MemberProfile? memberById(String memberId) {
    return _members.firstWhereOrNull((member) => member.id == memberId);
  }

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _repository.loadWorkspace(session: _session);
      _members = snapshot.members;
      _branches = snapshot.branches;
      await _runSearch(trackAnalytics: false);
    } catch (error) {
      _errorMessage = error.toString();
      _searchResults = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearchQuery(String value) {
    if (_filters.query == value) {
      return;
    }
    _filters = _filters.copyWith(query: value);
    unawaited(_runSearch());
  }

  void updateBranchFilter(String? branchId) {
    if (_filters.branchId == branchId) {
      return;
    }
    _filters = _filters.copyWith(
      branchId: branchId,
      clearBranch: branchId == null,
    );
    _trackFiltersUpdated();
    unawaited(_runSearch());
  }

  void updateGenerationFilter(int? generation) {
    if (_filters.generation == generation) {
      return;
    }
    _filters = _filters.copyWith(
      generation: generation,
      clearGeneration: generation == null,
    );
    _trackFiltersUpdated();
    unawaited(_runSearch());
  }

  Future<void> retrySearch() async {
    unawaited(
      _searchAnalyticsService.trackRetryRequested(
        queryLength: _filters.query.trim().length,
        hasBranchFilter: _filters.branchId != null,
        hasGenerationFilter: _filters.generation != null,
      ),
    );
    await _runSearch();
  }

  Future<MemberRepositoryException?> saveMember({
    String? memberId,
    required MemberDraft draft,
  }) async {
    MemberDraft draftToSave = draft;
    final resolvedBranchId = _resolveBranchForDraft(draft);

    if (memberId == null && !permissions.canCreateInBranch(resolvedBranchId)) {
      return const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    if (memberId == null) {
      draftToSave = draft.copyWith(
        primaryRole: resolveCreateRoleForDraft(draft),
      );
    }

    if (memberId != null) {
      final existing = _members.firstWhereOrNull(
        (member) => member.id == memberId,
      );
      if (existing == null || !permissions.canEditMember(existing, _session)) {
        return const MemberRepositoryException(
          MemberRepositoryErrorCode.permissionDenied,
        );
      }

      if (permissions.canEditAnyMember) {
        if (!permissions.canManageBranch(
          resolvedBranchId ?? existing.branchId,
        )) {
          return const MemberRepositoryException(
            MemberRepositoryErrorCode.permissionDenied,
          );
        }
      } else {
        draftToSave = draft.copyWith(
          branchId: existing.branchId,
          generation: existing.generation,
          parentIds: existing.parentIds,
        );
      }
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveMember(
        session: _session,
        memberId: memberId,
        draft: draftToSave,
      );
      await refresh();
      return null;
    } on MemberRepositoryException catch (error) {
      return error;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<MemberRepositoryException?> uploadAvatar({
    required MemberProfile member,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (!permissions.canUploadAvatar(member, _session)) {
      return const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    _isUploadingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.uploadAvatar(
        session: _session,
        memberId: member.id,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      await refresh();
      return null;
    } on MemberRepositoryException catch (error) {
      return error;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  bool canEditMember(MemberProfile member) {
    return permissions.canEditMember(member, _session);
  }

  bool canUploadAvatar(MemberProfile member) {
    return permissions.canUploadAvatar(member, _session);
  }

  void trackMemberOpened(MemberProfile member) {
    unawaited(
      _searchAnalyticsService.trackResultOpened(
        memberId: member.id,
        branchId: member.branchId,
        generation: member.generation,
      ),
    );
  }

  String branchName(String branchId) {
    return _branches
            .firstWhereOrNull((branch) => branch.id == branchId)
            ?.name ??
        branchId;
  }

  String? _resolveBranchForDraft(MemberDraft draft) {
    final selectedParentId = draft.parentIds.firstOrNull;
    if (selectedParentId == null || selectedParentId.isEmpty) {
      return draft.branchId;
    }
    return _members
        .firstWhereOrNull((member) => member.id == selectedParentId)
        ?.branchId;
  }

  String resolveCreateRoleForDraft(MemberDraft draft) {
    if (!canAssignRoleManually) {
      return resolveAutoRoleForDraft(draft);
    }

    final normalized = GovernanceRoleMatrix.normalizeRole(draft.primaryRole);
    if (assignableCreateRoles.contains(normalized)) {
      return normalized;
    }

    return GovernanceRoles.member;
  }

  String resolveAutoRoleForDraft(MemberDraft draft) {
    final hasSelectedParent =
        draft.parentIds.firstOrNull?.trim().isNotEmpty ?? false;
    if (hasSelectedParent) {
      return GovernanceRoles.member;
    }

    final resolvedBranchId = _resolveBranchForDraft(draft);
    final resolvedGeneration = _resolveGenerationForDraft(draft);
    final normalizedRoles = _members
        .map((member) => GovernanceRoleMatrix.normalizeRole(member.primaryRole))
        .toSet();
    final hasClanLeadership = normalizedRoles.any(
      (role) =>
          role == GovernanceRoles.superAdmin ||
          role == GovernanceRoles.clanAdmin ||
          role == GovernanceRoles.clanOwner ||
          role == GovernanceRoles.clanLeader,
    );
    if (!hasClanLeadership && resolvedGeneration <= 1) {
      return GovernanceRoles.clanLeader;
    }

    if (resolvedBranchId != null && resolvedBranchId.isNotEmpty) {
      final hasBranchAdmin = _members.any(
        (member) =>
            member.branchId == resolvedBranchId &&
            GovernanceRoleMatrix.normalizeRole(member.primaryRole) ==
                GovernanceRoles.branchAdmin,
      );
      if (!hasBranchAdmin && resolvedGeneration <= 2) {
        return GovernanceRoles.branchAdmin;
      }
    }

    return GovernanceRoles.member;
  }

  int _resolveGenerationForDraft(MemberDraft draft) {
    final selectedParentId = draft.parentIds.firstOrNull;
    if (selectedParentId == null || selectedParentId.isEmpty) {
      return draft.generation;
    }

    final selectedParent = _members.firstWhereOrNull(
      (member) => member.id == selectedParentId,
    );
    if (selectedParent == null) {
      return draft.generation;
    }

    return selectedParent.generation + 1;
  }

  void _trackFiltersUpdated() {
    unawaited(
      _searchAnalyticsService.trackFiltersUpdated(
        queryLength: _filters.query.trim().length,
        hasBranchFilter: _filters.branchId != null,
        hasGenerationFilter: _filters.generation != null,
      ),
    );
  }

  Future<void> _runSearch({bool trackAnalytics = true}) async {
    final revision = ++_searchRevision;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    var status = 'success';

    final query = MemberSearchQuery(
      query: _filters.query,
      branchId: _filters.branchId,
      generation: _filters.generation,
    );
    final searchStopwatch = Stopwatch()..start();

    try {
      final results = await _searchProvider.search(
        members: _accessibleMembers,
        query: query,
      );
      if (revision != _searchRevision) {
        status = 'stale';
        return;
      }

      _searchResults = results;
      _isSearching = false;
      notifyListeners();

      if (trackAnalytics) {
        unawaited(
          _searchAnalyticsService.trackSearchSubmitted(
            queryLength: query.query.trim().length,
            hasBranchFilter: query.branchId != null,
            hasGenerationFilter: query.generation != null,
            resultCount: results.length,
          ),
        );
      }
    } catch (_) {
      if (revision != _searchRevision) {
        status = 'stale';
        return;
      }

      _searchResults = const [];
      _isSearching = false;
      _searchError = 'search_failed';
      status = 'failed';
      notifyListeners();

      if (trackAnalytics) {
        unawaited(
          _searchAnalyticsService.trackSearchFailed(
            queryLength: query.query.trim().length,
            hasBranchFilter: query.branchId != null,
            hasGenerationFilter: query.generation != null,
          ),
        );
      }
    } finally {
      searchStopwatch.stop();
      _performanceLogger.logDuration(
        metric: 'member_search.query',
        elapsed: searchStopwatch.elapsed,
        warnAfter: const Duration(milliseconds: 250),
        dimensions: {
          'status': status,
          'query_length': query.query.trim().length,
          'has_branch_filter': query.branchId == null ? 0 : 1,
          'has_generation_filter': query.generation == null ? 0 : 1,
        },
      );
    }
  }
}
