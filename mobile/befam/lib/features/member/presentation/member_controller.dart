import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../models/member_draft.dart';
import '../models/member_list_filters.dart';
import '../models/member_profile.dart';
import '../services/member_permissions.dart';
import '../services/member_repository.dart';

class MemberController extends ChangeNotifier {
  MemberController({
    required MemberRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session,
       permissions = MemberPermissions.forSession(session);

  final MemberRepository _repository;
  final AuthSession _session;
  final MemberPermissions permissions;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  List<MemberProfile> _members = const [];
  List<BranchProfile> _branches = const [];
  MemberListFilters _filters = const MemberListFilters();

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingAvatar => _isUploadingAvatar;
  String? get errorMessage => _errorMessage;
  List<MemberProfile> get members => _members;
  List<BranchProfile> get branches => _branches;
  MemberListFilters get filters => _filters;
  bool get hasClanContext => permissions.canViewWorkspace;

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
    final normalizedQuery = _filters.query.trim().toLowerCase();
    return _accessibleMembers
        .where((member) {
          final branchMatches =
              _filters.branchId == null || _filters.branchId == member.branchId;
          final generationMatches =
              _filters.generation == null ||
              _filters.generation == member.generation;
          final queryMatches =
              normalizedQuery.isEmpty ||
              member.fullName.toLowerCase().contains(normalizedQuery) ||
              member.nickName.toLowerCase().contains(normalizedQuery) ||
              (member.phoneE164?.toLowerCase().contains(normalizedQuery) ??
                  false);

          return branchMatches && generationMatches && queryMatches;
        })
        .toList(growable: false);
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
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearchQuery(String value) {
    _filters = _filters.copyWith(query: value);
    notifyListeners();
  }

  void updateBranchFilter(String? branchId) {
    _filters = _filters.copyWith(
      branchId: branchId,
      clearBranch: branchId == null,
    );
    notifyListeners();
  }

  void updateGenerationFilter(int? generation) {
    _filters = _filters.copyWith(
      generation: generation,
      clearGeneration: generation == null,
    );
    notifyListeners();
  }

  Future<MemberRepositoryErrorCode?> saveMember({
    String? memberId,
    required MemberDraft draft,
  }) async {
    MemberDraft draftToSave = draft;

    if (memberId == null && !permissions.canCreateInBranch(draft.branchId)) {
      return MemberRepositoryErrorCode.permissionDenied;
    }

    if (memberId != null) {
      final existing = _members.firstWhereOrNull(
        (member) => member.id == memberId,
      );
      if (existing == null || !permissions.canEditMember(existing, _session)) {
        return MemberRepositoryErrorCode.permissionDenied;
      }

      if (permissions.canEditAnyMember) {
        if (!permissions.canManageBranch(draft.branchId ?? existing.branchId)) {
          return MemberRepositoryErrorCode.permissionDenied;
        }
      } else {
        draftToSave = draft.copyWith(
          branchId: existing.branchId,
          generation: existing.generation,
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
      return error.code;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<MemberRepositoryErrorCode?> uploadAvatar({
    required MemberProfile member,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (!permissions.canUploadAvatar(member, _session)) {
      return MemberRepositoryErrorCode.permissionDenied;
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
      return error.code;
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

  String branchName(String branchId) {
    return _branches
            .firstWhereOrNull((branch) => branch.id == branchId)
            ?.name ??
        branchId;
  }
}
