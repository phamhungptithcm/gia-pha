import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_disbursement_fund.dart';
import '../models/scholarship_program_draft.dart';
import '../services/scholarship_repository.dart';
import 'scholarship_controller.dart';

class ScholarshipWorkspacePage extends StatefulWidget {
  const ScholarshipWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.availableClanContexts = const [],
    this.onSwitchClanContext,
  });

  final AuthSession session;
  final ScholarshipRepository repository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;

  @override
  State<ScholarshipWorkspacePage> createState() =>
      _ScholarshipWorkspacePageState();
}

class _ScholarshipWorkspacePageState extends State<ScholarshipWorkspacePage> {
  static const int _lazyPageSize = 20;
  static const double _lazyLoadThresholdPx = 480;

  late ScholarshipController _controller;
  late AuthSession _activeSession;
  final ScrollController _workspaceScrollController = ScrollController();
  bool _showAddFabMenu = false;
  int _visibleProgramCount = 0;
  int _visibleSubmissionCount = 0;
  String? _lazySubmissionProgramId;

  AuthSession get _session => _activeSession;

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _controller = ScholarshipController(
      repository: widget.repository,
      session: _session,
    );
    _workspaceScrollController.addListener(_handleWorkspaceScroll);
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(covariant ScholarshipWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session &&
        oldWidget.repository == widget.repository) {
      return;
    }
    _activeSession = widget.session;
    _controller.dispose();
    _controller = ScholarshipController(
      repository: widget.repository,
      session: _session,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _workspaceScrollController.removeListener(_handleWorkspaceScroll);
    _workspaceScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleWorkspaceScroll() {
    if (!_workspaceScrollController.hasClients) {
      return;
    }
    if (_workspaceScrollController.position.extentAfter >
        _lazyLoadThresholdPx) {
      return;
    }
    if (_expandVisibleCounts() && mounted) {
      setState(() {});
    }
  }

  bool _expandVisibleCounts() {
    bool changed = false;
    final expandedPrograms = _expandVisibleCount(
      current: _visibleProgramCount,
      total: _controller.programs.length,
    );
    if (expandedPrograms != _visibleProgramCount) {
      _visibleProgramCount = expandedPrograms;
      changed = true;
    }

    final expandedSubmissions = _expandVisibleCount(
      current: _visibleSubmissionCount,
      total: _controller.selectedProgramSubmissions.length,
    );
    if (expandedSubmissions != _visibleSubmissionCount) {
      _visibleSubmissionCount = expandedSubmissions;
      changed = true;
    }
    return changed;
  }

  int _initialVisibleCount(int total) {
    if (total <= 0) {
      return 0;
    }
    return total < _lazyPageSize ? total : _lazyPageSize;
  }

  int _normalizeVisibleCount({required int current, required int total}) {
    if (total <= 0) {
      return 0;
    }
    final baseline = _initialVisibleCount(total);
    if (current <= 0) {
      return baseline;
    }
    if (current < baseline) {
      return baseline;
    }
    if (current > total) {
      return total;
    }
    return current;
  }

  int _expandVisibleCount({required int current, required int total}) {
    if (total <= 0) {
      return 0;
    }
    if (current <= 0) {
      return _initialVisibleCount(total);
    }
    if (current >= total) {
      return total;
    }
    final expanded = current + _lazyPageSize;
    return expanded >= total ? total : expanded;
  }

  void _syncLazyState({
    required String? selectedProgramId,
    required int programCount,
    required int submissionCount,
  }) {
    _visibleProgramCount = _normalizeVisibleCount(
      current: _visibleProgramCount,
      total: programCount,
    );

    if (_lazySubmissionProgramId != selectedProgramId) {
      _lazySubmissionProgramId = selectedProgramId;
      _visibleSubmissionCount = _initialVisibleCount(submissionCount);
      return;
    }

    _visibleSubmissionCount = _normalizeVisibleCount(
      current: _visibleSubmissionCount,
      total: submissionCount,
    );
  }

  Future<void> _openProgramForm() async {
    final l10n = context.l10n;
    final draft = await showModalBottomSheet<ScholarshipProgramDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _ProgramFormSheet(),
    );

    if (draft == null) {
      return;
    }

    final error = await _controller.createProgram(draft: draft);
    if (!mounted) {
      return;
    }

    _showResultSnackBar(
      error == null
          ? l10n.pick(
              vi: 'Đã lưu chương trình khuyến học.',
              en: 'Scholarship program saved.',
            )
          : l10n.pick(
              vi: 'Không thể lưu chương trình khuyến học (${error.name}).',
              en: 'Could not save scholarship program (${error.name}).',
            ),
    );
  }

  Future<void> _openProgramFormFromFab() async {
    if (_controller.isSaving) {
      return;
    }
    if (mounted) {
      setState(() => _showAddFabMenu = false);
    }
    await _openProgramForm();
  }

  Future<void> _openAwardLevelForm(String programId) async {
    final l10n = context.l10n;
    final draft = await showModalBottomSheet<AwardLevelDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _AwardLevelFormSheet(),
    );

    if (draft == null) {
      return;
    }

    final error = await _controller.createAwardLevel(
      programId: programId,
      draft: draft,
    );
    if (!mounted) {
      return;
    }

    _showResultSnackBar(
      error == null
          ? l10n.pick(vi: 'Đã lưu mức thưởng.', en: 'Award level saved.')
          : l10n.pick(
              vi: 'Không thể lưu mức thưởng (${error.name}).',
              en: 'Could not save award level (${error.name}).',
            ),
    );
  }

  Future<void> _openAwardLevelFormFromFab() async {
    final selectedProgram = _controller.selectedProgram;
    if (_controller.isSaving || selectedProgram == null) {
      return;
    }
    if (mounted) {
      setState(() => _showAddFabMenu = false);
    }
    await _openAwardLevelForm(selectedProgram.id);
  }

  Future<void> _openSubmissionForm(String programId) async {
    final l10n = context.l10n;
    final draft = await showModalBottomSheet<AchievementSubmissionDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SubmissionFormSheet(
          programId: programId,
          awardLevels: _controller.awardLevels
              .where((awardLevel) => awardLevel.programId == programId)
              .toList(growable: false),
          onUploadEvidence: _uploadEvidence,
        );
      },
    );

    if (draft == null) {
      return;
    }

    final error = await _controller.createSubmission(draft: draft);
    if (!mounted) {
      return;
    }

    _showResultSnackBar(
      error == null
          ? l10n.pick(vi: 'Đã tạo hồ sơ đề cử.', en: 'Submission created.')
          : l10n.pick(
              vi: 'Không thể tạo hồ sơ đề cử (${error.name}).',
              en: 'Could not create submission (${error.name}).',
            ),
    );
  }

  Future<void> _openSubmissionFormFromFab() async {
    final selectedProgram = _controller.selectedProgram;
    if (_controller.isSaving || selectedProgram == null) {
      return;
    }
    if (mounted) {
      setState(() => _showAddFabMenu = false);
    }
    await _openSubmissionForm(selectedProgram.id);
  }

  Future<String?> _uploadEvidence(String fileName) async {
    final l10n = context.l10n;
    final safeFileName = fileName.trim().isEmpty ? 'evidence.txt' : fileName;
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Scholarship evidence payload for $safeFileName at '
        '${DateTime.now().toIso8601String()}',
      ),
    );

    final url = await _controller.uploadEvidence(
      fileName: safeFileName,
      bytes: bytes,
      contentType: 'text/plain',
    );

    if (!mounted) {
      return url;
    }

    if (url == null) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Không thể tải tệp minh chứng lên.',
          en: 'Could not upload evidence file.',
        ),
      );
      return null;
    }

    _showResultSnackBar(
      l10n.pick(vi: 'Đã tải lên minh chứng.', en: 'Evidence uploaded.'),
    );
    return url;
  }

  Future<void> _openProgramDetail(String programId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ScholarshipProgramDetailPage(
            controller: _controller,
            programId: programId,
            onAddAwardLevel: _openAwardLevelForm,
            onCreateSubmission: _openSubmissionForm,
            onReviewSubmission: _reviewSubmission,
            onDisburseSubmission: _disburseSubmission,
          );
        },
      ),
    );
  }

  Future<void> _reviewSubmission({
    required AchievementSubmission submission,
    required bool approved,
  }) async {
    final l10n = context.l10n;
    String? note;
    if (!approved) {
      note = await _openReviewNoteDialog();
      if (!mounted) {
        return;
      }
      if (note == null) {
        return;
      }
    }

    final error = await _controller.reviewSubmission(
      submissionId: submission.id,
      approved: approved,
      reviewNote: note,
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      _showResultSnackBar(
        approved
            ? l10n.pick(
                vi: 'Đã ghi nhận phiếu. Hồ sơ sẽ được duyệt khi đủ 2/3 phiếu thuận.',
                en: 'Vote recorded. Submission will approve when 2 council heads approve.',
              )
            : l10n.pick(
                vi: 'Đã ghi nhận phiếu từ chối.',
                en: 'Rejection vote recorded.',
              ),
      );
      return;
    }

    final errorHint = _controller.errorMessage?.toLowerCase() ?? '';
    if (errorHint.contains('duplicate_vote')) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Bạn đã bỏ phiếu cho hồ sơ này rồi.',
          en: 'You have already voted for this submission.',
        ),
      );
      return;
    }
    if (errorHint.contains('permission')) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Chỉ Trưởng hội đồng học bổng mới có quyền bỏ phiếu.',
          en: 'Only Scholarship Council Heads can vote.',
        ),
      );
      return;
    }
    if (errorHint.contains('council_configuration_invalid') ||
        errorHint.contains('council configuration invalid') ||
        errorHint.contains('exactly 3 active council heads')) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Hội đồng học bổng phải có đúng 3 Trưởng hội đồng đang hoạt động để áp dụng quy tắc 2/3.',
          en: 'Scholarship council must have exactly 3 active heads for the 2-of-3 workflow.',
        ),
      );
      return;
    }

    _showResultSnackBar(
      l10n.pick(
        vi: 'Không thể xử lý duyệt hồ sơ (${error.name}).',
        en: 'Could not review submission (${error.name}).',
      ),
    );
  }

  Future<void> _disburseSubmission({
    required AchievementSubmission submission,
  }) async {
    if (_controller.isDisbursing) {
      return;
    }
    final l10n = context.l10n;

    List<ScholarshipDisbursementFund> funds;
    try {
      funds = await _controller.loadDisbursementFunds();
    } on ScholarshipRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ScholarshipRepositoryErrorCode.permissionDenied) {
        _showResultSnackBar(
          l10n.pick(
            vi: 'Bạn chưa có quyền thực hiện chi quỹ học bổng.',
            en: 'Your role cannot disburse scholarship funds.',
          ),
        );
        return;
      }
      _showResultSnackBar(
        l10n.pick(
          vi: 'Không thể tải danh sách quỹ để giải ngân.',
          en: 'Could not load funds for disbursement.',
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    if (funds.isEmpty) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Chưa có quỹ hoạt động để chi học bổng.',
          en: 'No active funds are available for disbursement.',
        ),
      );
      return;
    }

    final disbursementInput = await _openDisbursementDialog(
      submission: submission,
      funds: funds,
    );
    if (!mounted || disbursementInput == null) {
      return;
    }

    final error = await _controller.disburseSubmission(
      submissionId: submission.id,
      fundId: disbursementInput.fundId,
      note: disbursementInput.note,
    );
    if (!mounted) {
      return;
    }

    if (error == null) {
      _showResultSnackBar(
        l10n.pick(
          vi: 'Đã ghi nhận chi quỹ học bổng thành công.',
          en: 'Scholarship disbursement has been recorded.',
        ),
      );
      return;
    }

    switch (error) {
      case ScholarshipRepositoryErrorCode.fundNotFound:
        _showResultSnackBar(
          l10n.pick(
            vi: 'Quỹ đã chọn không còn khả dụng.',
            en: 'The selected fund is no longer available.',
          ),
        );
        return;
      case ScholarshipRepositoryErrorCode.insufficientFundBalance:
        _showResultSnackBar(
          l10n.pick(
            vi: 'Số dư quỹ không đủ để giải ngân hồ sơ này.',
            en: 'The selected fund does not have enough balance.',
          ),
        );
        return;
      case ScholarshipRepositoryErrorCode.submissionAlreadyDisbursed:
        _showResultSnackBar(
          l10n.pick(
            vi: 'Hồ sơ này đã được giải ngân trước đó.',
            en: 'This submission was already disbursed.',
          ),
        );
        return;
      case ScholarshipRepositoryErrorCode.permissionDenied:
        _showResultSnackBar(
          l10n.pick(
            vi: 'Bạn không có quyền chi quỹ học bổng.',
            en: 'You do not have permission to disburse scholarship funds.',
          ),
        );
        return;
      default:
        _showResultSnackBar(
          l10n.pick(
            vi: 'Không thể ghi nhận chi quỹ (${error.name}).',
            en: 'Could not complete disbursement (${error.name}).',
          ),
        );
        return;
    }
  }

  Future<_ScholarshipDisbursementInput?> _openDisbursementDialog({
    required AchievementSubmission submission,
    required List<ScholarshipDisbursementFund> funds,
  }) async {
    var selectedFundId = funds.first.id;
    final noteController = TextEditingController();
    final l10n = context.l10n;
    final awardLevel = _controller.awardLevelById(submission.awardLevelId);
    final amountLabel = awardLevel == null
        ? l10n.pick(vi: 'Không xác định', en: 'Unknown')
        : '${_formatMinorAmount(awardLevel.rewardAmountMinor)} VND';

    final result = await showDialog<_ScholarshipDisbursementInput>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                l10n.pick(
                  vi: 'Chi học bổng từ quỹ',
                  en: 'Disburse scholarship from fund',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pick(
                      vi: 'Hồ sơ: ${submission.title}',
                      en: 'Submission: ${submission.title}',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.pick(
                      vi: 'Mức chi dự kiến: $amountLabel',
                      en: 'Planned amount: $amountLabel',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const Key('scholarship-disbursement-fund-picker'),
                    initialValue: selectedFundId,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Chọn quỹ', en: 'Select fund'),
                    ),
                    items: [
                      for (final fund in funds)
                        DropdownMenuItem<String>(
                          value: fund.id,
                          child: Text(
                            '${fund.name} • ${_formatMinorAmount(fund.balanceMinor)} ${fund.currency}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      setState(() {
                        selectedFundId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('scholarship-disbursement-note-input'),
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Ghi chú (tuỳ chọn)',
                        en: 'Note (optional)',
                      ),
                      hintText: l10n.pick(
                        vi: 'Ví dụ: Đợt trao học bổng quý I',
                        en: 'For example: Q1 scholarship disbursement',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.profileCancelAction),
                ),
                AppAsyncAction(
                  onPressed: () async {
                    Navigator.of(context).pop(
                      _ScholarshipDisbursementInput(
                        fundId: selectedFundId,
                        note: _nullableText(noteController.text),
                      ),
                    );
                  },
                  builder: (context, onPressed, isLoading) {
                    return FilledButton.icon(
                      key: const Key('scholarship-disbursement-confirm-button'),
                      onPressed: onPressed,
                      icon: AppStableLoadingChild(
                        isLoading: isLoading,
                        indicatorSize: 16,
                        indicatorStrokeWidth: 2,
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      label: AppStableLoadingChild(
                        isLoading: isLoading,
                        child: Text(
                          l10n.pick(
                            vi: 'Ghi nhận chi quỹ',
                            en: 'Record disbursement',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
    noteController.dispose();
    return result;
  }

  Future<String?> _openReviewNoteDialog() async {
    String note = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.pick(vi: 'Từ chối hồ sơ', en: 'Reject submission')),
          content: TextField(
            key: const Key('scholarship-review-note-input'),
            maxLines: 3,
            onChanged: (value) {
              note = value;
            },
            decoration: InputDecoration(
              labelText: l10n.pick(vi: 'Ghi chú xét duyệt', en: 'Review note'),
              hintText: l10n.pick(
                vi: 'Nêu lý do từ chối cho thành viên',
                en: 'Tell the member why this was rejected',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.profileCancelAction),
            ),
            FilledButton(
              key: const Key('scholarship-reject-confirm-button'),
              onPressed: () => Navigator.of(context).pop(note.trim()),
              child: Text(l10n.pick(vi: 'Từ chối', en: 'Reject')),
            ),
          ],
        );
      },
    );
  }

  void _showResultSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final selectedProgram = _controller.selectedProgram;
        final selectedProgramAwardLevels =
            _controller.selectedProgramAwardLevels;
        final selectedProgramSubmissions =
            _controller.selectedProgramSubmissions;
        _syncLazyState(
          selectedProgramId: selectedProgram?.id,
          programCount: _controller.programs.length,
          submissionCount: selectedProgramSubmissions.length,
        );
        final visiblePrograms = _controller.programs
            .take(_visibleProgramCount)
            .toList(growable: false);
        final visibleSubmissions = selectedProgramSubmissions
            .take(_visibleSubmissionCount)
            .toList(growable: false);
        final reviewQueue = _controller.reviewQueue;
        final canCreateProgramAction = _controller.canCreatePrograms;
        final canCreateAwardAction =
            _controller.canCreateAwardLevels && selectedProgram != null;
        final canCreateSubmissionAction =
            _controller.canSubmitAchievements && selectedProgram != null;
        final hasAnyFabAction =
            canCreateProgramAction ||
            canCreateAwardAction ||
            canCreateSubmissionAction;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.pick(
                vi: 'Chương trình khuyến học',
                en: 'Scholarship programs',
              ),
            ),
            actions: [
              IconButton(
                tooltip: l10n.pick(vi: 'Tải lại', en: 'Refresh'),
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: hasAnyFabAction
              ? _ScholarshipAddActionFab(
                  isMenuOpen: _showAddFabMenu,
                  canCreateProgram:
                      canCreateProgramAction && !_controller.isSaving,
                  canCreateAward: canCreateAwardAction && !_controller.isSaving,
                  canCreateSubmission:
                      canCreateSubmissionAction && !_controller.isSaving,
                  onToggleMenu: () {
                    setState(() => _showAddFabMenu = !_showAddFabMenu);
                  },
                  onCreateProgram: _openProgramFormFromFab,
                  onCreateAward: _openAwardLevelFormFromFab,
                  onCreateSubmission: _openSubmissionFormFromFab,
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải không gian khuyến học...',
                      en: 'Loading scholarship workspace...',
                    ),
                  )
                : !_controller.permissions.canViewWorkspace
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.pick(
                          vi: 'Khuyến học cần ngữ cảnh gia phả đang hoạt động.',
                          en: 'Scholarship requires an active clan context.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      controller: _workspaceScrollController,
                      key: const Key('scholarship-workspace-list'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        Container(
                          key: const Key('scholarship-workspace-title'),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primaryContainer,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Không gian chương trình khuyến học',
                                  en: 'Scholarship program workspace',
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.pick(
                                  vi: 'Tạo chương trình, mức thưởng và duyệt hồ sơ.',
                                  en: 'Create programs, set awards, and review submissions.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 4),
                        if (_controller.permissions.isReadOnly) ...[
                          Card(
                            color: colorScheme.secondaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n.pick(
                                  vi: 'Bạn đang ở chế độ chỉ xem với module khuyến học.',
                                  en: 'You have read-only scholarship access in this session.',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_controller.canViewApprovalHistory) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.pick(
                                      vi: 'Trạng thái hội đồng',
                                      en: 'Governance status',
                                    ),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.pick(
                                      vi: 'Trưởng hội đồng: ${_controller.councilHeadMemberIds.length}/3 vị trí đang hoạt động',
                                      en: 'Council heads: ${_controller.councilHeadMemberIds.length}/3 seats active',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.pick(
                                      vi: 'Hồ sơ sẽ tự chốt khi đạt 2 phiếu duyệt (hoặc 2 phiếu từ chối).',
                                      en: 'Submissions auto-finalize at 2 approvals (or 2 rejections).',
                                    ),
                                  ),
                                  if (!_controller
                                      .isCouncilVotingConfigured) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.pick(
                                        vi: 'Cần đúng 3 Trưởng hội đồng đang hoạt động để áp dụng quy tắc 2/3.',
                                        en: 'Exactly 3 active council heads are required for the 2-of-3 rule.',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: colorScheme.error),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _ListSectionTitle(
                          title: l10n.pick(
                            vi: 'Danh sách chương trình',
                            en: 'Program list',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _controller.programs.isEmpty
                            ? _InlineEmpty(
                                message: l10n.pick(
                                  vi: 'Chưa có chương trình. Hãy tạo mới để bắt đầu.',
                                  en: 'No programs yet. Create one to get started.',
                                ),
                              )
                            : Column(
                                children: [
                                  for (final program in visiblePrograms)
                                    Card(
                                      key: Key(
                                        'scholarship-program-card-${program.id}',
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        onTap: () {
                                          if (_showAddFabMenu) {
                                            setState(
                                              () => _showAddFabMenu = false,
                                            );
                                          }
                                          _controller.selectProgram(program.id);
                                        },
                                        title: Text(program.title),
                                        subtitle: Text(
                                          '${program.year} • ${_programStatusLabel(context, program.status)}',
                                        ),
                                        leading: Icon(
                                          Icons.school_outlined,
                                          color:
                                              program.id == selectedProgram?.id
                                              ? colorScheme.primary
                                              : null,
                                        ),
                                        trailing: IconButton(
                                          key: Key(
                                            'scholarship-open-program-detail-${program.id}',
                                          ),
                                          tooltip: l10n.pick(
                                            vi: 'Mở chi tiết',
                                            en: 'Open detail',
                                          ),
                                          onPressed: () {
                                            if (_showAddFabMenu) {
                                              setState(
                                                () => _showAddFabMenu = false,
                                              );
                                            }
                                            unawaited(
                                              _openProgramDetail(program.id),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.arrow_forward_ios,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                        if (_controller.programs.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: l10n.pick(
                              vi: 'Chi tiết chương trình',
                              en: 'Program detail',
                            ),
                            child: selectedProgram == null
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Chọn một chương trình để xem chi tiết.',
                                      en: 'Select a program to view details.',
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedProgram.title,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusBadge(
                                            label: l10n.pick(
                                              vi: 'Trạng thái: ${_programStatusLabel(context, selectedProgram.status)}',
                                              en: 'Status: ${_programStatusLabel(context, selectedProgram.status)}',
                                            ),
                                          ),
                                          _StatusBadge(
                                            label: l10n.pick(
                                              vi: 'Năm: ${selectedProgram.year}',
                                              en: 'Year: ${selectedProgram.year}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (selectedProgram
                                          .description
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(selectedProgram.description),
                                      ],
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: l10n.pick(
                              vi: 'Danh sách mức thưởng',
                              en: 'Award level list',
                            ),
                            child: selectedProgram == null
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Vui lòng chọn chương trình trước.',
                                      en: 'Choose a program first.',
                                    ),
                                  )
                                : selectedProgramAwardLevels.isEmpty
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Chưa có mức thưởng. Hãy thêm ít nhất một mức.',
                                      en: 'No award levels yet. Add at least one.',
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final awardLevel
                                          in selectedProgramAwardLevels)
                                        ListTile(
                                          key: Key(
                                            'scholarship-award-level-${awardLevel.id}',
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                            Icons.workspace_premium_outlined,
                                          ),
                                          title: Text(awardLevel.name),
                                          subtitle: Text(
                                            '${_rewardTypeLabel(context, awardLevel.rewardType)} • '
                                            '${awardLevel.rewardAmountMinor}',
                                          ),
                                          trailing: Text(
                                            '#${awardLevel.sortOrder}',
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _ListSectionTitle(
                            title: l10n.pick(
                              vi: 'Danh sách hồ sơ',
                              en: 'Submissions',
                            ),
                          ),
                          const SizedBox(height: 10),
                          selectedProgram == null
                              ? _InlineEmpty(
                                  message: l10n.pick(
                                    vi: 'Vui lòng chọn chương trình trước.',
                                    en: 'Choose a program first.',
                                  ),
                                )
                              : selectedProgramSubmissions.isEmpty
                              ? _InlineEmpty(
                                  message: l10n.pick(
                                    vi: 'Chưa có hồ sơ nào trong chương trình này.',
                                    en: 'No submissions in this program yet.',
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (final submission in visibleSubmissions)
                                      Card(
                                        key: Key(
                                          'scholarship-submission-${submission.id}',
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      submission.title,
                                                      style: theme
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                                  _StatusBadge(
                                                    label: submission.status
                                                        .toUpperCase(),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                l10n.pick(
                                                  vi: 'Học sinh: ${submission.studentNameSnapshot}',
                                                  en: 'Student: ${submission.studentNameSnapshot}',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                l10n.pick(
                                                  vi: 'Số tệp minh chứng: ${submission.evidenceUrls.length}',
                                                  en: 'Evidence files: ${submission.evidenceUrls.length}',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                l10n.pick(
                                                  vi: 'Phiếu hội đồng: ${submission.approvalCount} thuận • ${submission.rejectionCount} chống',
                                                  en: 'Council votes: ${submission.approvalCount} approve • ${submission.rejectionCount} reject',
                                                ),
                                              ),
                                              if (submission.isApproved) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Giải ngân: ${_disbursementStatusLabel(context, submission)}',
                                                    en: 'Disbursement: ${_disbursementStatusLabel(context, submission)}',
                                                  ),
                                                ),
                                              ],
                                              if (_controller
                                                      .canDisburseFromFund &&
                                                  submission
                                                      .isPendingDisbursement) ...[
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: AppAsyncAction(
                                                    enabled: !_controller
                                                        .isDisbursing,
                                                    onPressed: () async {
                                                      await _disburseSubmission(
                                                        submission: submission,
                                                      );
                                                    },
                                                    builder: (context, onPressed, isLoading) {
                                                      return FilledButton.icon(
                                                        key: Key(
                                                          'scholarship-disburse-${submission.id}',
                                                        ),
                                                        onPressed: onPressed,
                                                        icon: AppStableLoadingChild(
                                                          isLoading:
                                                              isLoading ||
                                                              _controller
                                                                  .isDisbursing,
                                                          indicatorSize: 16,
                                                          child: const Icon(
                                                            Icons
                                                                .account_balance_wallet_outlined,
                                                          ),
                                                        ),
                                                        label: AppStableLoadingChild(
                                                          isLoading:
                                                              isLoading ||
                                                              _controller
                                                                  .isDisbursing,
                                                          child: Text(
                                                            l10n.pick(
                                                              vi: 'Chi từ quỹ',
                                                              en: 'Disburse from fund',
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                              if (submission.reviewNote !=
                                                      null &&
                                                  submission.reviewNote!
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Ghi chú xét duyệt: ${submission.reviewNote}',
                                                    en: 'Review note: ${submission.reviewNote}',
                                                  ),
                                                ),
                                              ],
                                              if (submission.finalDecisionReason
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Lý do kết luận: ${submission.finalDecisionReason}',
                                                    en: 'Final reason: ${submission.finalDecisionReason}',
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: l10n.pick(
                              vi: 'Hàng đợi xét duyệt',
                              en: 'Review queue',
                            ),
                            child: !_controller.canReviewSubmissions
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Vai trò hiện tại chưa có quyền xét duyệt hồ sơ.',
                                      en: 'Your session cannot review scholarship submissions.',
                                    ),
                                  )
                                : !_controller.isCouncilVotingConfigured
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Hội đồng học bổng phải có đúng 3 Trưởng hội đồng đang hoạt động trước khi bỏ phiếu.',
                                      en: 'Scholarship council must have exactly 3 active heads before voting.',
                                    ),
                                  )
                                : reviewQueue.isEmpty
                                ? _InlineEmpty(
                                    message: l10n.pick(
                                      vi: 'Không có hồ sơ chờ trong hàng đợi xét duyệt.',
                                      en: 'No pending submissions in the review queue.',
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final submission in reviewQueue)
                                        Card(
                                          key: Key(
                                            'scholarship-review-item-${submission.id}',
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  submission.title,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Thành viên: ${_controller.memberName(submission.memberId)}',
                                                    en: 'Member: ${_controller.memberName(submission.memberId)}',
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Quy tắc 2/3 hội đồng • ${submission.approvalCount}/2 phiếu duyệt',
                                                    en: '2-of-3 council rule • ${submission.approvalCount}/2 approvals',
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        key: Key(
                                                          'scholarship-approve-${submission.id}',
                                                        ),
                                                        onPressed:
                                                            _controller
                                                                    .isReviewing ||
                                                                !_controller
                                                                    .isCouncilVotingConfigured ||
                                                                _controller
                                                                    .hasCurrentReviewerVoted(
                                                                      submission,
                                                                    )
                                                            ? null
                                                            : () {
                                                                _reviewSubmission(
                                                                  submission:
                                                                      submission,
                                                                  approved:
                                                                      true,
                                                                );
                                                              },
                                                        icon: const Icon(
                                                          Icons.check,
                                                        ),
                                                        label: Text(
                                                          l10n.pick(
                                                            vi: 'Duyệt',
                                                            en: 'Approve',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: FilledButton.tonalIcon(
                                                        key: Key(
                                                          'scholarship-reject-${submission.id}',
                                                        ),
                                                        onPressed:
                                                            _controller
                                                                    .isReviewing ||
                                                                !_controller
                                                                    .isCouncilVotingConfigured ||
                                                                _controller
                                                                    .hasCurrentReviewerVoted(
                                                                      submission,
                                                                    )
                                                            ? null
                                                            : () {
                                                                _reviewSubmission(
                                                                  submission:
                                                                      submission,
                                                                  approved:
                                                                      false,
                                                                );
                                                              },
                                                        icon: const Icon(
                                                          Icons.close,
                                                        ),
                                                        label: Text(
                                                          l10n.pick(
                                                            vi: 'Từ chối',
                                                            en: 'Reject',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          if (_controller.canViewApprovalHistory) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: l10n.pick(
                                vi: 'Nhật ký xét duyệt',
                                en: 'Approval activity log',
                              ),
                              child: _controller.approvalLogs.isEmpty
                                  ? _InlineEmpty(
                                      message: l10n.pick(
                                        vi: 'Chưa có hoạt động xét duyệt nào cho gia phả này.',
                                        en: 'No approval activity yet for this clan.',
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (final log
                                            in _controller.approvalLogs.take(
                                              25,
                                            ))
                                          ListTile(
                                            key: Key(
                                              'scholarship-approval-log-${log.id}',
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              log.action == 'finalized'
                                                  ? Icons.flag_outlined
                                                  : Icons.how_to_vote_outlined,
                                            ),
                                            title: Text(
                                              '${_approvalActionLabel(context, log.action)} • ${_approvalDecisionLabel(context, log.decision)}',
                                            ),
                                            subtitle: Text(
                                              [
                                                l10n.pick(
                                                  vi: 'Hồ sơ ${log.submissionId} • ${_controller.memberName(log.actorMemberId)}',
                                                  en: 'Submission ${log.submissionId} • ${_controller.memberName(log.actorMemberId)}',
                                                ),
                                                _formatApprovalLogTimestamp(
                                                  context,
                                                  log.createdAtIso,
                                                ),
                                                if (log.note
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true)
                                                  l10n.pick(
                                                    vi: 'Ghi chú: ${log.note}',
                                                    en: 'Note: ${log.note}',
                                                  ),
                                              ].join('\n'),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class ScholarshipProgramDetailPage extends StatelessWidget {
  const ScholarshipProgramDetailPage({
    super.key,
    required this.controller,
    required this.programId,
    required this.onAddAwardLevel,
    required this.onCreateSubmission,
    required this.onReviewSubmission,
    required this.onDisburseSubmission,
  });

  final ScholarshipController controller;
  final String programId;
  final Future<void> Function(String programId) onAddAwardLevel;
  final Future<void> Function(String programId) onCreateSubmission;
  final Future<void> Function({
    required AchievementSubmission submission,
    required bool approved,
  })
  onReviewSubmission;
  final Future<void> Function({required AchievementSubmission submission})
  onDisburseSubmission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final program = controller.programById(programId);
        final awardLevels = controller.awardLevels
            .where((awardLevel) => awardLevel.programId == programId)
            .toList(growable: false);
        final submissions = controller.submissions
            .where((submission) => submission.programId == programId)
            .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.pick(vi: 'Chi tiết chương trình', en: 'Program detail'),
            ),
          ),
          body: SafeArea(
            child: program == null
                ? Center(
                    child: Text(
                      l10n.pick(
                        vi: 'Chương trình khuyến học này không còn khả dụng.',
                        en: 'This scholarship program is no longer available.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text(
                        program.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${program.year} • ${_programStatusLabel(context, program.status)}',
                      ),
                      const SizedBox(height: 12),
                      Text(program.description),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: l10n.pick(vi: 'Mức thưởng', en: 'Award levels'),
                        actionLabel: controller.canCreateAwardLevels
                            ? l10n.pick(vi: 'Thêm mức thưởng', en: 'Add award')
                            : null,
                        actionKey: const Key(
                          'scholarship-detail-open-award-form-button',
                        ),
                        onAction: controller.canCreateAwardLevels
                            ? () => onAddAwardLevel(program.id)
                            : null,
                        child: awardLevels.isEmpty
                            ? _InlineEmpty(
                                message: l10n.pick(
                                  vi: 'Chương trình này chưa có mức thưởng.',
                                  en: 'No award levels for this program yet.',
                                ),
                              )
                            : Column(
                                children: [
                                  for (final awardLevel in awardLevels)
                                    ListTile(
                                      key: Key(
                                        'scholarship-detail-award-${awardLevel.id}',
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(awardLevel.name),
                                      subtitle: Text(awardLevel.criteriaText),
                                      trailing: Text(
                                        '#${awardLevel.sortOrder}',
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.pick(vi: 'Hồ sơ đề cử', en: 'Submissions'),
                        actionLabel: controller.canSubmitAchievements
                            ? l10n.pick(vi: 'Hồ sơ mới', en: 'New submission')
                            : null,
                        actionKey: const Key(
                          'scholarship-detail-open-submission-form-button',
                        ),
                        onAction: controller.canSubmitAchievements
                            ? () => onCreateSubmission(program.id)
                            : null,
                        child: submissions.isEmpty
                            ? _InlineEmpty(
                                message: l10n.pick(
                                  vi: 'Chưa có hồ sơ nào cho chương trình này.',
                                  en: 'No submissions for this program yet.',
                                ),
                              )
                            : Column(
                                children: [
                                  for (final submission in submissions)
                                    Card(
                                      key: Key(
                                        'scholarship-detail-submission-${submission.id}',
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              submission.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            _StatusBadge(
                                              label: _submissionStatusLabel(
                                                context,
                                                submission.status,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              l10n.pick(
                                                vi: 'Số tệp minh chứng: ${submission.evidenceUrls.length}',
                                                en: 'Evidence files: ${submission.evidenceUrls.length}',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.pick(
                                                vi: 'Phiếu hội đồng: ${submission.approvalCount} thuận • ${submission.rejectionCount} chống',
                                                en: 'Council votes: ${submission.approvalCount} approve • ${submission.rejectionCount} reject',
                                              ),
                                            ),
                                            if (submission.isApproved) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                l10n.pick(
                                                  vi: 'Giải ngân: ${_disbursementStatusLabel(context, submission)}',
                                                  en: 'Disbursement: ${_disbursementStatusLabel(context, submission)}',
                                                ),
                                              ),
                                            ],
                                            if (submission.finalDecisionReason
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                l10n.pick(
                                                  vi: 'Lý do kết luận: ${submission.finalDecisionReason}',
                                                  en: 'Final reason: ${submission.finalDecisionReason}',
                                                ),
                                              ),
                                            ],
                                            if (controller
                                                    .canReviewSubmissions &&
                                                submission.isPending) ...[
                                              if (!controller
                                                  .isCouncilVotingConfigured) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.pick(
                                                    vi: 'Tạm khóa bỏ phiếu vì hội đồng chưa đủ 3 Trưởng hội đồng hoạt động.',
                                                    en: 'Voting is temporarily locked because the council does not have 3 active heads.',
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      key: Key(
                                                        'scholarship-detail-approve-${submission.id}',
                                                      ),
                                                      onPressed:
                                                          controller
                                                                  .isReviewing ||
                                                              !controller
                                                                  .isCouncilVotingConfigured ||
                                                              controller
                                                                  .hasCurrentReviewerVoted(
                                                                    submission,
                                                                  )
                                                          ? null
                                                          : () {
                                                              onReviewSubmission(
                                                                submission:
                                                                    submission,
                                                                approved: true,
                                                              );
                                                            },
                                                      child: Text(
                                                        l10n.pick(
                                                          vi: 'Duyệt',
                                                          en: 'Approve',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: FilledButton.tonal(
                                                      key: Key(
                                                        'scholarship-detail-reject-${submission.id}',
                                                      ),
                                                      onPressed:
                                                          controller
                                                                  .isReviewing ||
                                                              !controller
                                                                  .isCouncilVotingConfigured ||
                                                              controller
                                                                  .hasCurrentReviewerVoted(
                                                                    submission,
                                                                  )
                                                          ? null
                                                          : () {
                                                              onReviewSubmission(
                                                                submission:
                                                                    submission,
                                                                approved: false,
                                                              );
                                                            },
                                                      child: Text(
                                                        l10n.pick(
                                                          vi: 'Từ chối',
                                                          en: 'Reject',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (controller
                                                    .canDisburseFromFund &&
                                                submission
                                                    .isPendingDisbursement) ...[
                                              const SizedBox(height: 10),
                                              AppAsyncAction(
                                                enabled:
                                                    !controller.isDisbursing,
                                                onPressed: () async {
                                                  await onDisburseSubmission(
                                                    submission: submission,
                                                  );
                                                },
                                                builder: (context, onPressed, isLoading) {
                                                  return Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: FilledButton.icon(
                                                      key: Key(
                                                        'scholarship-detail-disburse-${submission.id}',
                                                      ),
                                                      onPressed: onPressed,
                                                      icon: AppStableLoadingChild(
                                                        isLoading:
                                                            isLoading ||
                                                            controller
                                                                .isDisbursing,
                                                        indicatorSize: 16,
                                                        child: const Icon(
                                                          Icons
                                                              .account_balance_wallet_outlined,
                                                        ),
                                                      ),
                                                      label: AppStableLoadingChild(
                                                        isLoading:
                                                            isLoading ||
                                                            controller
                                                                .isDisbursing,
                                                        child: Text(
                                                          l10n.pick(
                                                            vi: 'Chi từ quỹ',
                                                            en: 'Disburse from fund',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ProgramFormSheet extends StatefulWidget {
  const _ProgramFormSheet();

  @override
  State<_ProgramFormSheet> createState() => _ProgramFormSheetState();
}

class _SheetHintCard extends StatelessWidget {
  const _SheetHintCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionHeading extends StatelessWidget {
  const _SheetSectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetStepIndicator extends StatelessWidget {
  const _SheetStepIndicator({
    required this.currentStep,
    required this.labels,
    this.onStepSelected,
  });

  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onStepSelected == null
                  ? null
                  : () => onStepSelected!(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: index <= currentStep
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: index <= currentStep
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: index == currentStep
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (index < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 24),
                color: index < currentStep
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _ProgramFormSheetState extends State<_ProgramFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _yearController;
  late final TextEditingController _submissionOpenController;
  late final TextEditingController _submissionCloseController;
  late final TextEditingController _reviewCloseController;
  String _status = 'open';
  int _step = 0;
  String? _validationMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _yearController = TextEditingController(text: '${DateTime.now().year}');
    _submissionOpenController = TextEditingController();
    _submissionCloseController = TextEditingController();
    _reviewCloseController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _yearController.dispose();
    _submissionOpenController.dispose();
    _submissionCloseController.dispose();
    _reviewCloseController.dispose();
    super.dispose();
  }

  bool _validateStepZero() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Hãy điền đủ thông tin cơ bản trước khi tiếp tục.',
          en: 'Please complete the basic information before continuing.',
        );
      });
      return false;
    }
    return true;
  }

  bool _validateStepOne() {
    final l10n = context.l10n;
    final open = DateTime.tryParse(_submissionOpenController.text.trim());
    final close = DateTime.tryParse(_submissionCloseController.text.trim());
    final review = DateTime.tryParse(_reviewCloseController.text.trim());
    if (_submissionOpenController.text.trim().isNotEmpty && open == null) {
      setState(() {
        _validationMessage = l10n.pick(
          vi: 'Ngày mở nhận hồ sơ chưa đúng định dạng.',
          en: 'Submission open date is not a valid date.',
        );
      });
      return false;
    }
    if (_submissionCloseController.text.trim().isNotEmpty && close == null) {
      setState(() {
        _validationMessage = l10n.pick(
          vi: 'Ngày đóng nhận hồ sơ chưa đúng định dạng.',
          en: 'Submission close date is not a valid date.',
        );
      });
      return false;
    }
    if (_reviewCloseController.text.trim().isNotEmpty && review == null) {
      setState(() {
        _validationMessage = l10n.pick(
          vi: 'Hạn xét duyệt chưa đúng định dạng.',
          en: 'Review close date is not a valid date.',
        );
      });
      return false;
    }
    if (open != null && close != null && close.isBefore(open)) {
      setState(() {
        _validationMessage = l10n.pick(
          vi: 'Ngày đóng nhận hồ sơ phải sau ngày mở nhận hồ sơ.',
          en: 'Submission close date must be after submission open date.',
        );
      });
      return false;
    }
    if (close != null && review != null && review.isBefore(close)) {
      setState(() {
        _validationMessage = l10n.pick(
          vi: 'Hạn xét duyệt phải sau ngày đóng nhận hồ sơ.',
          en: 'Review close date must be after submission close date.',
        );
      });
      return false;
    }
    return true;
  }

  void _submitOrContinue() {
    if (_isSubmitting) {
      return;
    }
    if (_step == 0) {
      if (_validateStepZero()) {
        setState(() {
          _validationMessage = null;
          _step = 1;
        });
      }
      return;
    }
    if (_step == 1) {
      if (_validateStepOne()) {
        setState(() {
          _validationMessage = null;
          _step = 2;
        });
      }
      return;
    }

    if (!_validateStepZero() || !_validateStepOne()) {
      return;
    }
    setState(() {
      _validationMessage = null;
      _isSubmitting = true;
    });

    final year =
        int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    Navigator.of(context).pop(
      ScholarshipProgramDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        year: year,
        status: _status,
        submissionOpenAtIso: _nullableText(_submissionOpenController.text),
        submissionCloseAtIso: _nullableText(_submissionCloseController.text),
        reviewCloseAtIso: _nullableText(_reviewCloseController.text),
      ),
    );
  }

  Future<void> _pickIsoDate(TextEditingController controller) async {
    final existing = DateTime.tryParse(controller.text.trim());
    final initialDate = existing ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initialDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isFinalStep = _step == 2;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(
                  vi: 'Tạo chương trình khuyến học',
                  en: 'Create scholarship program',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SheetStepIndicator(
                currentStep: _step,
                labels: [
                  l10n.pick(vi: 'Thông tin', en: 'Info'),
                  l10n.pick(vi: 'Mốc thời gian', en: 'Timeline'),
                  l10n.pick(vi: 'Xác nhận', en: 'Confirm'),
                ],
                onStepSelected: (targetStep) {
                  if (targetStep <= _step) {
                    setState(() {
                      _validationMessage = null;
                      _step = targetStep;
                    });
                    return;
                  }
                  if (_step == 0 && !_validateStepZero()) {
                    return;
                  }
                  if (_step <= 1 && targetStep >= 2 && !_validateStepOne()) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                    _step = targetStep;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_validationMessage != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _validationMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_step == 0) ...[
                _SheetHintCard(
                  icon: Icons.auto_awesome_outlined,
                  title: l10n.pick(
                    vi: 'Thiết lập nhanh trong 3 phần',
                    en: 'Set up in 3 quick sections',
                  ),
                  message: l10n.pick(
                    vi: 'Thông tin cơ bản, mốc thời gian và xác nhận.',
                    en: 'Basic info, timeline, and confirmation.',
                  ),
                ),
                const SizedBox(height: 14),
                _SheetSectionHeading(
                  title: l10n.pick(
                    vi: '1. Thông tin cơ bản',
                    en: '1. Basic info',
                  ),
                  subtitle: l10n.pick(
                    vi: 'Tên, mô tả, năm và trạng thái.',
                    en: 'Name, description, year, and status.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('scholarship-program-title-input'),
                  controller: _titleController,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.pick(
                        vi: 'Vui lòng nhập tiêu đề chương trình.',
                        en: 'Please enter a program title.',
                      );
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Tiêu đề', en: 'Title'),
                    hintText: l10n.pick(
                      vi: 'Chương trình khuyến học 2026',
                      en: '2026 Scholarship Program',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('scholarship-program-description-input'),
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('scholarship-program-year-input'),
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null ||
                              parsed < 2000 ||
                              parsed > 2100) {
                            return l10n.pick(
                              vi: 'Năm cần nằm trong khoảng 2000-2100.',
                              en: 'Year must be between 2000 and 2100.',
                            );
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: l10n.pick(vi: 'Năm', en: 'Year'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('scholarship-program-status-input'),
                        initialValue: _status,
                        items: [
                          DropdownMenuItem(
                            value: 'open',
                            child: Text(l10n.pick(vi: 'Đang mở', en: 'Open')),
                          ),
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text(l10n.pick(vi: 'Nháp', en: 'Draft')),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text(l10n.pick(vi: 'Đã đóng', en: 'Closed')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _status = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: l10n.pick(vi: 'Trạng thái', en: 'Status'),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_step == 1) ...[
                _SheetSectionHeading(
                  title: l10n.pick(
                    vi: '2. Mốc thời gian (tùy chọn)',
                    en: '2. Timeline (optional)',
                  ),
                  subtitle: l10n.pick(
                    vi: 'Chạm để chọn ngày.',
                    en: 'Tap to pick dates.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('scholarship-program-open-date-input'),
                  controller: _submissionOpenController,
                  readOnly: true,
                  onTap: () => _pickIsoDate(_submissionOpenController),
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Mở nhận hồ sơ (ISO - tùy chọn)',
                      en: 'Submission open (ISO date optional)',
                    ),
                    hintText: l10n.pick(vi: 'YYYY-MM-DD', en: 'YYYY-MM-DD'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('scholarship-program-close-date-input'),
                  controller: _submissionCloseController,
                  readOnly: true,
                  onTap: () => _pickIsoDate(_submissionCloseController),
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Đóng nhận hồ sơ (ISO - tùy chọn)',
                      en: 'Submission close (ISO date optional)',
                    ),
                    hintText: l10n.pick(vi: 'YYYY-MM-DD', en: 'YYYY-MM-DD'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('scholarship-program-review-date-input'),
                  controller: _reviewCloseController,
                  readOnly: true,
                  onTap: () => _pickIsoDate(_reviewCloseController),
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Hạn xét duyệt (ISO - tùy chọn)',
                      en: 'Review close (ISO date optional)',
                    ),
                    hintText: l10n.pick(vi: 'YYYY-MM-DD', en: 'YYYY-MM-DD'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pick(
                    vi: 'Để trống nếu chưa chốt lịch. Có thể sửa sau.',
                    en: 'Leave blank if not finalized. You can update later.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
                _SheetSectionHeading(
                  title: l10n.pick(vi: '3. Xác nhận', en: '3. Confirm'),
                  subtitle: l10n.pick(
                    vi: 'Lưu để tạo chương trình.',
                    en: 'Save to create the program.',
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pick(
                            vi: 'Tiêu đề: ${_titleController.text.trim()}',
                            en: 'Title: ${_titleController.text.trim()}',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.pick(
                            vi: 'Năm: ${_yearController.text.trim()} • ${_status.toUpperCase()}',
                            en: 'Year: ${_yearController.text.trim()} • ${_status.toUpperCase()}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : _step == 0
                          ? () => Navigator.of(context).pop()
                          : () {
                              setState(() {
                                _validationMessage = null;
                                _step -= 1;
                              });
                            },
                      child: Text(
                        _step == 0
                            ? l10n.profileCancelAction
                            : l10n.pick(vi: 'Quay lại', en: 'Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('scholarship-program-save-button'),
                      onPressed: _isSubmitting ? null : _submitOrContinue,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isFinalStep
                                  ? l10n.pick(vi: 'Lưu', en: 'Save')
                                  : l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardLevelFormSheet extends StatefulWidget {
  const _AwardLevelFormSheet();

  @override
  State<_AwardLevelFormSheet> createState() => _AwardLevelFormSheetState();
}

class _AwardLevelFormSheetState extends State<_AwardLevelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _amountController;
  late final TextEditingController _criteriaController;
  String _rewardType = 'cash';
  int _step = 0;
  String? _validationMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _sortOrderController = TextEditingController(text: '10');
    _amountController = TextEditingController(text: '0');
    _criteriaController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    _amountController.dispose();
    _criteriaController.dispose();
    super.dispose();
  }

  bool _validateStepZero() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Hãy điền đủ thông tin nhận diện mức thưởng.',
          en: 'Please complete the award identity information.',
        );
      });
      return false;
    }
    return true;
  }

  bool _validateStepOne() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Giá trị phần thưởng cần là số không âm.',
          en: 'Reward amount must be a non-negative number.',
        );
      });
      return false;
    }
    return true;
  }

  void _submitOrContinue() {
    if (_isSubmitting) {
      return;
    }
    if (_step == 0) {
      if (_validateStepZero()) {
        setState(() {
          _validationMessage = null;
          _step = 1;
        });
      }
      return;
    }
    if (_step == 1) {
      if (_validateStepOne()) {
        setState(() {
          _validationMessage = null;
          _step = 2;
        });
      }
      return;
    }

    if (!_validateStepZero() || !_validateStepOne()) {
      return;
    }
    setState(() {
      _validationMessage = null;
      _isSubmitting = true;
    });

    final name = _nameController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 10;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    Navigator.of(context).pop(
      AwardLevelDraft(
        name: name,
        description: _descriptionController.text.trim(),
        sortOrder: sortOrder,
        rewardType: _rewardType,
        rewardAmountMinor: amount,
        criteriaText: _criteriaController.text.trim(),
        status: 'active',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isFinalStep = _step == 2;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(vi: 'Tạo mức thưởng', en: 'Create award level'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SheetStepIndicator(
                currentStep: _step,
                labels: [
                  l10n.pick(vi: 'Nhận diện', en: 'Identity'),
                  l10n.pick(vi: 'Giá trị', en: 'Value'),
                  l10n.pick(vi: 'Xác nhận', en: 'Confirm'),
                ],
                onStepSelected: (targetStep) {
                  if (targetStep <= _step) {
                    setState(() {
                      _validationMessage = null;
                      _step = targetStep;
                    });
                    return;
                  }
                  if (_step == 0 && !_validateStepZero()) {
                    return;
                  }
                  if (_step <= 1 && targetStep >= 2 && !_validateStepOne()) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                    _step = targetStep;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_validationMessage != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _validationMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_step == 0) ...[
                _SheetHintCard(
                  icon: Icons.tips_and_updates_outlined,
                  title: l10n.pick(
                    vi: 'Đặt mức thưởng rõ ràng',
                    en: 'Define a clear award level',
                  ),
                  message: l10n.pick(
                    vi: 'Tên ngắn gọn, tiêu chí cụ thể, giá trị dễ đối chiếu khi duyệt hồ sơ.',
                    en: 'Use a concise name, clear criteria, and measurable reward value.',
                  ),
                ),
                const SizedBox(height: 14),
                _SheetSectionHeading(
                  title: l10n.pick(
                    vi: '1. Nhận diện mức thưởng',
                    en: '1. Award identity',
                  ),
                  subtitle: l10n.pick(
                    vi: 'Tên và mô tả ngắn giúp gia đình hiểu mục tiêu của mức thưởng.',
                    en: 'Name and short description help families understand this level.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('scholarship-award-name-input'),
                  controller: _nameController,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.pick(
                        vi: 'Vui lòng nhập tên mức thưởng.',
                        en: 'Please enter an award level name.',
                      );
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Tên mức thưởng', en: 'Name'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('scholarship-award-description-input'),
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('scholarship-award-sort-order-input'),
                        controller: _sortOrderController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return l10n.pick(
                              vi: 'Thứ tự hiển thị cần là số dương.',
                              en: 'Sort order must be a positive number.',
                            );
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Thứ tự hiển thị',
                            en: 'Sort order',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('scholarship-award-reward-type-input'),
                        initialValue: _rewardType,
                        items: [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text(l10n.pick(vi: 'Tiền mặt', en: 'Cash')),
                          ),
                          DropdownMenuItem(
                            value: 'gift',
                            child: Text(l10n.pick(vi: 'Quà tặng', en: 'Gift')),
                          ),
                          DropdownMenuItem(
                            value: 'certificate',
                            child: Text(
                              l10n.pick(vi: 'Chứng nhận', en: 'Certificate'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _rewardType = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Loại phần thưởng',
                            en: 'Reward type',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_step == 1) ...[
                _SheetSectionHeading(
                  title: l10n.pick(
                    vi: '2. Loại và giá trị',
                    en: '2. Type and value',
                  ),
                  subtitle: l10n.pick(
                    vi: 'Chọn loại phần thưởng trước, sau đó nhập giá trị tương ứng.',
                    en: 'Choose reward type first, then enter the corresponding value.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('scholarship-award-amount-input'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Giá trị phần thưởng (đơn vị nhỏ)',
                      en: 'Reward amount (minor)',
                    ),
                    hintText: _rewardType == 'cash' ? '500000' : '1',
                  ),
                ),
              ] else ...[
                _SheetSectionHeading(
                  title: l10n.pick(
                    vi: '3. Tiêu chí và xem trước',
                    en: '3. Criteria and preview',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('scholarship-award-criteria-input'),
                  controller: _criteriaController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Tiêu chí', en: 'Criteria'),
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.preview_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.pick(
                              vi: 'Xem trước: ${_nameController.text.trim().isEmpty ? 'Mức thưởng mới' : _nameController.text.trim()} • ${_rewardTypeLabel(context, _rewardType)} • Giá trị ${_amountController.text.trim().isEmpty ? '0' : _amountController.text.trim()}',
                              en: 'Preview: ${_nameController.text.trim().isEmpty ? 'New award level' : _nameController.text.trim()} • ${_rewardTypeLabel(context, _rewardType)} • Amount ${_amountController.text.trim().isEmpty ? '0' : _amountController.text.trim()}',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : _step == 0
                          ? () => Navigator.of(context).pop()
                          : () {
                              setState(() {
                                _validationMessage = null;
                                _step -= 1;
                              });
                            },
                      child: Text(
                        _step == 0
                            ? l10n.profileCancelAction
                            : l10n.pick(vi: 'Quay lại', en: 'Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('scholarship-award-save-button'),
                      onPressed: _isSubmitting ? null : _submitOrContinue,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isFinalStep
                                  ? l10n.pick(vi: 'Lưu', en: 'Save')
                                  : l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionFormSheet extends StatefulWidget {
  const _SubmissionFormSheet({
    required this.programId,
    required this.awardLevels,
    required this.onUploadEvidence,
  });

  final String programId;
  final List<AwardLevel> awardLevels;
  final Future<String?> Function(String fileName) onUploadEvidence;

  @override
  State<_SubmissionFormSheet> createState() => _SubmissionFormSheetState();
}

class _SubmissionFormSheetState extends State<_SubmissionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _studentNameController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _evidenceFileNameController;
  final List<String> _evidenceUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  int _step = 0;
  String? _validationMessage;
  String? _selectedAwardLevelId;

  @override
  void initState() {
    super.initState();
    _studentNameController = TextEditingController();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _evidenceFileNameController = TextEditingController(
      text: 'certificate.txt',
    );
    _selectedAwardLevelId = widget.awardLevels.isNotEmpty
        ? widget.awardLevels.first.id
        : null;
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _evidenceFileNameController.dispose();
    super.dispose();
  }

  Future<void> _uploadEvidence() async {
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final fileName = _evidenceFileNameController.text.trim();
    final url = await widget.onUploadEvidence(fileName);
    if (!mounted) {
      return;
    }

    if (url != null) {
      setState(() {
        _evidenceUrls.add(url);
      });
    }

    setState(() {
      _isUploading = false;
    });
  }

  bool _validateStepZero() {
    if (widget.awardLevels.isEmpty) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Bạn cần tạo mức thưởng trước khi gửi hồ sơ.',
          en: 'Create an award level before submitting.',
        );
      });
      return false;
    }
    final awardLevelId = _selectedAwardLevelId;
    if (awardLevelId == null || awardLevelId.isEmpty) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Vui lòng chọn mức thưởng cho hồ sơ.',
          en: 'Please select an award level for this submission.',
        );
      });
      return false;
    }
    return true;
  }

  bool _validateStepOne() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _validationMessage = context.l10n.pick(
          vi: 'Vui lòng nhập tiêu đề thành tích.',
          en: 'Please enter an achievement title.',
        );
      });
      return false;
    }
    return true;
  }

  void _submitOrContinue() {
    if (_isSubmitting) {
      return;
    }
    if (_step == 0) {
      if (_validateStepZero()) {
        setState(() {
          _validationMessage = null;
          _step = 1;
        });
      }
      return;
    }
    if (_step == 1) {
      if (_validateStepOne()) {
        setState(() {
          _validationMessage = null;
          _step = 2;
        });
      }
      return;
    }
    if (!_validateStepZero() || !_validateStepOne()) {
      return;
    }
    setState(() {
      _validationMessage = null;
      _isSubmitting = true;
    });
    final awardLevelId = _selectedAwardLevelId!;
    final title = _titleController.text.trim();
    Navigator.of(context).pop(
      AchievementSubmissionDraft(
        programId: widget.programId,
        awardLevelId: awardLevelId,
        studentName: _studentNameController.text.trim(),
        title: title,
        description: _descriptionController.text.trim(),
        evidenceUrls: _evidenceUrls,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isFinalStep = _step == 2;
    final primaryDisabled =
        _isSubmitting || (_step == 0 && widget.awardLevels.isEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(vi: 'Tạo hồ sơ đề cử', en: 'Create submission'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SheetStepIndicator(
                currentStep: _step,
                labels: [
                  l10n.pick(vi: 'Mức thưởng', en: 'Award'),
                  l10n.pick(vi: 'Thành tích', en: 'Achievement'),
                  l10n.pick(vi: 'Minh chứng', en: 'Evidence'),
                ],
                onStepSelected: (targetStep) {
                  if (targetStep <= _step) {
                    setState(() {
                      _validationMessage = null;
                      _step = targetStep;
                    });
                    return;
                  }
                  if (_step == 0 && !_validateStepZero()) {
                    return;
                  }
                  if (_step <= 1 && targetStep >= 2 && !_validateStepOne()) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                    _step = targetStep;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_validationMessage != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _validationMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_step == 0) ...[
                if (widget.awardLevels.isEmpty)
                  _InlineEmpty(
                    message: l10n.pick(
                      vi: 'Hãy tạo mức thưởng trước. Hồ sơ đề cử yêu cầu chọn mức thưởng.',
                      en: 'Create an award level first. Submissions require an award level.',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: const Key('scholarship-submission-award-input'),
                    initialValue: _selectedAwardLevelId,
                    items: [
                      for (final awardLevel in widget.awardLevels)
                        DropdownMenuItem(
                          value: awardLevel.id,
                          child: Text(awardLevel.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedAwardLevelId = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Mức thưởng', en: 'Award level'),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('scholarship-submission-student-input'),
                  controller: _studentNameController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Tên học sinh',
                      en: 'Student name',
                    ),
                  ),
                ),
              ] else if (_step == 1) ...[
                TextField(
                  key: const Key('scholarship-submission-title-input'),
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Tiêu đề thành tích',
                      en: 'Achievement title',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('scholarship-submission-description-input'),
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                  ),
                ),
              ] else ...[
                TextField(
                  key: const Key('scholarship-evidence-file-input'),
                  controller: _evidenceFileNameController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Tên tệp minh chứng',
                      en: 'Evidence file name',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('scholarship-upload-evidence-button'),
                        onPressed: _isUploading ? null : _uploadEvidence,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(
                          l10n.pick(
                            vi: 'Tải tệp minh chứng',
                            en: 'Upload evidence file',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_evidenceUrls.isEmpty)
                  Text(
                    l10n.pick(
                      vi: 'Chưa có minh chứng nào được tải lên.',
                      en: 'No uploaded evidence yet.',
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final entry in _evidenceUrls.indexed)
                        ListTile(
                          key: Key('scholarship-evidence-url-${entry.$1}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            entry.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: l10n.pick(vi: 'Xóa', en: 'Remove'),
                            onPressed: () {
                              setState(() {
                                _evidenceUrls.removeAt(entry.$1);
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : _step == 0
                          ? () => Navigator.of(context).pop()
                          : () {
                              setState(() {
                                _validationMessage = null;
                                _step -= 1;
                              });
                            },
                      child: Text(
                        _step == 0
                            ? l10n.profileCancelAction
                            : l10n.pick(vi: 'Quay lại', en: 'Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('scholarship-submission-save-button'),
                      onPressed: primaryDisabled ? null : _submitOrContinue,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isFinalStep
                                  ? l10n.pick(vi: 'Gửi hồ sơ', en: 'Submit')
                                  : l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScholarshipAddActionFab extends StatelessWidget {
  const _ScholarshipAddActionFab({
    required this.isMenuOpen,
    required this.canCreateProgram,
    required this.canCreateAward,
    required this.canCreateSubmission,
    required this.onToggleMenu,
    required this.onCreateProgram,
    required this.onCreateAward,
    required this.onCreateSubmission,
  });

  final bool isMenuOpen;
  final bool canCreateProgram;
  final bool canCreateAward;
  final bool canCreateSubmission;
  final VoidCallback onToggleMenu;
  final Future<void> Function() onCreateProgram;
  final Future<void> Function() onCreateAward;
  final Future<void> Function() onCreateSubmission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMenuOpen) ...[
          FloatingActionButton.extended(
            key: const Key('scholarship-create-program-fab'),
            heroTag: 'scholarship-create-program-fab',
            onPressed: canCreateProgram
                ? () => unawaited(onCreateProgram())
                : null,
            icon: const Icon(Icons.school_outlined),
            label: Text(l10n.pick(vi: 'Thêm chương trình', en: 'Add program')),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            key: const Key('scholarship-create-award-fab'),
            heroTag: 'scholarship-create-award-fab',
            onPressed: canCreateAward ? () => unawaited(onCreateAward()) : null,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: Text(
              l10n.pick(vi: 'Thêm mức thưởng', en: 'Add award level'),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            key: const Key('scholarship-create-submission-fab'),
            heroTag: 'scholarship-create-submission-fab',
            onPressed: canCreateSubmission
                ? () => unawaited(onCreateSubmission())
                : null,
            icon: const Icon(Icons.note_add_outlined),
            label: Text(
              l10n.pick(vi: 'Tạo hồ sơ đề cử', en: 'Create submission'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          key: const Key('scholarship-main-add-fab'),
          heroTag: 'scholarship-main-add-fab',
          onPressed: onToggleMenu,
          tooltip: l10n.pick(vi: 'Thêm mới', en: 'Add'),
          child: Icon(isMenuOpen ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    key: actionKey,
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ListSectionTitle extends StatelessWidget {
  const _ListSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _ScholarshipDisbursementInput {
  const _ScholarshipDisbursementInput({
    required this.fundId,
    required this.note,
  });

  final String fundId;
  final String? note;
}

String _programStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  return switch (status.trim().toLowerCase()) {
    'open' => l10n.pick(vi: 'Đang mở', en: 'Open'),
    'draft' => l10n.pick(vi: 'Nháp', en: 'Draft'),
    'closed' => l10n.pick(vi: 'Đã đóng', en: 'Closed'),
    _ => status.trim().toUpperCase(),
  };
}

String _rewardTypeLabel(BuildContext context, String rewardType) {
  final l10n = context.l10n;
  return switch (rewardType.trim().toLowerCase()) {
    'cash' => l10n.pick(vi: 'Tiền mặt', en: 'Cash'),
    'gift' => l10n.pick(vi: 'Quà tặng', en: 'Gift'),
    'certificate' => l10n.pick(vi: 'Chứng nhận', en: 'Certificate'),
    _ => rewardType.trim().toUpperCase(),
  };
}

String _submissionStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  return switch (status.trim().toLowerCase()) {
    'pending' => l10n.pick(vi: 'Đang chờ', en: 'Pending'),
    'approved' => l10n.pick(vi: 'Đã duyệt', en: 'Approved'),
    'rejected' => l10n.pick(vi: 'Đã từ chối', en: 'Rejected'),
    _ => status.trim().toUpperCase(),
  };
}

String _disbursementStatusLabel(
  BuildContext context,
  AchievementSubmission submission,
) {
  final l10n = context.l10n;
  final status = submission.disbursementStatus.trim().toLowerCase();
  if (status == 'disbursed') {
    final fundId = submission.disbursedFundId?.trim() ?? '';
    if (fundId.isNotEmpty) {
      return l10n.pick(
        vi: 'Đã chi từ quỹ $fundId',
        en: 'Disbursed from fund $fundId',
      );
    }
    return l10n.pick(vi: 'Đã chi quỹ', en: 'Disbursed');
  }
  if (submission.isApproved) {
    return l10n.pick(vi: 'Chờ chi quỹ', en: 'Pending disbursement');
  }
  return l10n.pick(vi: 'Chưa áp dụng', en: 'Not applicable');
}

String _approvalActionLabel(BuildContext context, String action) {
  final l10n = context.l10n;
  return switch (action.trim().toLowerCase()) {
    'vote' => l10n.pick(vi: 'Bỏ phiếu', en: 'Vote'),
    'finalized' => l10n.pick(vi: 'Chốt kết quả', en: 'Finalized'),
    'disbursed' => l10n.pick(vi: 'Chi quỹ', en: 'Disbursed'),
    _ => action.trim().toUpperCase(),
  };
}

String _approvalDecisionLabel(BuildContext context, String? decision) {
  final l10n = context.l10n;
  return switch (decision?.trim().toLowerCase()) {
    'approved' => l10n.pick(vi: 'Duyệt', en: 'Approved'),
    'rejected' => l10n.pick(vi: 'Từ chối', en: 'Rejected'),
    'disbursed' => l10n.pick(vi: 'Đã chi', en: 'Disbursed'),
    null || '' => l10n.pick(vi: 'không có', en: 'n/a'),
    _ => decision!.toUpperCase(),
  };
}

String _formatApprovalLogTimestamp(BuildContext context, String value) {
  final l10n = context.l10n;
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return l10n.pick(vi: 'Thời gian: không xác định', en: 'Time: unknown');
  }

  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final rendered =
      '${twoDigits(parsed.day)}/${twoDigits(parsed.month)}/${parsed.year} '
      '${twoDigits(parsed.hour)}:${twoDigits(parsed.minute)}';
  return l10n.pick(vi: 'Thời gian: $rendered', en: 'Time: $rendered');
}

String _formatMinorAmount(int amountMinor) {
  final negative = amountMinor < 0;
  final digits = amountMinor.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final offset = digits.length - index;
    buffer.write(digits[index]);
    if (offset > 1 && offset % 3 == 1) {
      buffer.write(',');
    }
  }
  return negative ? '-${buffer.toString()}' : buffer.toString();
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
