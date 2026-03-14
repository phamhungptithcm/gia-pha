import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_member_summary.dart';
import '../models/clan_profile.dart';
import '../services/clan_permissions.dart';
import '../services/clan_repository.dart';

class ClanController extends ChangeNotifier {
  ClanController({
    required ClanRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session,
       permissions = ClanPermissions.forSession(session);

  final ClanRepository _repository;
  final AuthSession _session;

  final ClanPermissions permissions;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  ClanProfile? _clan;
  List<BranchProfile> _branches = const [];
  List<ClanMemberSummary> _members = const [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  ClanProfile? get clan => _clan;
  List<BranchProfile> get branches => _branches;
  List<ClanMemberSummary> get members => _members;
  bool get hasClan => _clan != null;

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _repository.loadWorkspace(session: _session);
      _clan = snapshot.clan;
      _branches = snapshot.branches;
      _members = snapshot.members;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveClan(ClanDraft draft) async {
    if (!permissions.canEditClanSettings) {
      _errorMessage = 'permission_denied';
      notifyListeners();
      return false;
    }

    return _runSave(() async {
      await _repository.saveClan(session: _session, draft: draft);
      await refresh();
    });
  }

  Future<bool> saveBranch({
    String? branchId,
    required BranchDraft draft,
  }) async {
    if (!permissions.canManageBranches) {
      _errorMessage = 'permission_denied';
      notifyListeners();
      return false;
    }

    return _runSave(() async {
      await _repository.saveBranch(
        session: _session,
        branchId: branchId,
        draft: draft,
      );
      await refresh();
    });
  }

  String memberName(String? memberId) {
    if (memberId == null || memberId.isEmpty) {
      return '';
    }

    final member = _members.firstWhere(
      (candidate) => candidate.id == memberId,
      orElse: () => ClanMemberSummary(
        id: memberId,
        fullName: memberId,
        branchId: null,
        primaryRole: null,
        phoneE164: null,
      ),
    );
    return member.shortLabel;
  }

  Future<bool> _runSave(Future<void> Function() action) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
