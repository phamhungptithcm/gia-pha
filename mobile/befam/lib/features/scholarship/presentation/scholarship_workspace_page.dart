import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/models/auth_session.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_program_draft.dart';
import '../services/scholarship_repository.dart';
import 'scholarship_controller.dart';

class ScholarshipWorkspacePage extends StatefulWidget {
  const ScholarshipWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
  });

  final AuthSession session;
  final ScholarshipRepository repository;

  @override
  State<ScholarshipWorkspacePage> createState() =>
      _ScholarshipWorkspacePageState();
}

class _ScholarshipWorkspacePageState extends State<ScholarshipWorkspacePage> {
  late final ScholarshipController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScholarshipController(
      repository: widget.repository,
      session: widget.session,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openProgramForm() async {
    final draft = await showModalBottomSheet<ScholarshipProgramDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
          ? 'Scholarship program saved.'
          : 'Could not save scholarship program (${error.name}).',
    );
  }

  Future<void> _openAwardLevelForm(String programId) async {
    final draft = await showModalBottomSheet<AwardLevelDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
          ? 'Award level saved.'
          : 'Could not save award level (${error.name}).',
    );
  }

  Future<void> _openSubmissionForm(String programId) async {
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
          ? 'Submission created.'
          : 'Could not create submission (${error.name}).',
    );
  }

  Future<String?> _uploadEvidence(String fileName) async {
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
      _showResultSnackBar('Could not upload evidence file.');
      return null;
    }

    _showResultSnackBar('Evidence uploaded.');
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
          );
        },
      ),
    );
  }

  Future<void> _reviewSubmission({
    required AchievementSubmission submission,
    required bool approved,
  }) async {
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

    _showResultSnackBar(
      error == null
          ? (approved ? 'Submission approved.' : 'Submission rejected.')
          : 'Could not review submission (${error.name}).',
    );
  }

  Future<String?> _openReviewNoteDialog() async {
    String note = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject submission'),
          content: TextField(
            key: const Key('scholarship-review-note-input'),
            maxLines: 3,
            onChanged: (value) {
              note = value;
            },
            decoration: const InputDecoration(
              labelText: 'Review note',
              hintText: 'Tell the member why this was rejected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('scholarship-reject-confirm-button'),
              onPressed: () => Navigator.of(context).pop(note.trim()),
              child: const Text('Reject'),
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final selectedProgram = _controller.selectedProgram;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scholarship programs'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_controller.permissions.canViewWorkspace
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Scholarship workspace requires an active clan context.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      key: const Key('scholarship-workspace-list'),
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
                                'Scholarship program workspace',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create programs, configure award levels, submit achievements, and review decisions.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              if (_controller.canCreatePrograms) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  key: const Key(
                                    'scholarship-open-program-form-button',
                                  ),
                                  onPressed: _controller.isSaving
                                      ? null
                                      : _openProgramForm,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create program'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_controller.permissions.isReadOnly) ...[
                          Card(
                            color: colorScheme.secondaryContainer,
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'You have read-only scholarship access in this session.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _SectionCard(
                          title: 'Program list',
                          actionLabel: _controller.canCreatePrograms
                              ? 'New program'
                              : null,
                          actionKey: const Key(
                            'scholarship-open-program-form-button-inline',
                          ),
                          onAction: _controller.canCreatePrograms
                              ? _openProgramForm
                              : null,
                          child: _controller.programs.isEmpty
                              ? const _InlineEmpty(
                                  message:
                                      'No scholarship programs yet. Create one to start the yearly flow.',
                                )
                              : Column(
                                  children: [
                                    for (final program in _controller.programs)
                                      Card(
                                        key: Key(
                                          'scholarship-program-card-${program.id}',
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: ListTile(
                                          onTap: () => _controller
                                              .selectProgram(program.id),
                                          title: Text(program.title),
                                          subtitle: Text(
                                            '${program.year} • ${program.status.toUpperCase()}',
                                          ),
                                          leading: Icon(
                                            Icons.school_outlined,
                                            color:
                                                program.id ==
                                                    selectedProgram?.id
                                                ? colorScheme.primary
                                                : null,
                                          ),
                                          trailing: IconButton(
                                            key: Key(
                                              'scholarship-open-program-detail-${program.id}',
                                            ),
                                            tooltip: 'Open detail',
                                            onPressed: () =>
                                                _openProgramDetail(program.id),
                                            icon: const Icon(
                                              Icons.arrow_forward_ios,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Program detail',
                          child: selectedProgram == null
                              ? const _InlineEmpty(
                                  message:
                                      'Select a scholarship program to inspect award levels and submissions.',
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          label:
                                              'Status: ${selectedProgram.status.toUpperCase()}',
                                        ),
                                        _StatusBadge(
                                          label:
                                              'Year: ${selectedProgram.year}',
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
                          title: 'Award level list',
                          actionLabel:
                              _controller.canCreateAwardLevels &&
                                  selectedProgram != null
                              ? 'Add award level'
                              : null,
                          actionKey: const Key(
                            'scholarship-open-award-form-button',
                          ),
                          onAction:
                              _controller.canCreateAwardLevels &&
                                  selectedProgram != null
                              ? () => _openAwardLevelForm(selectedProgram.id)
                              : null,
                          child: selectedProgram == null
                              ? const _InlineEmpty(
                                  message: 'Choose a program first.',
                                )
                              : _controller.selectedProgramAwardLevels.isEmpty
                              ? const _InlineEmpty(
                                  message:
                                      'No award levels yet. Add at least one so members can submit.',
                                )
                              : Column(
                                  children: [
                                    for (final awardLevel
                                        in _controller
                                            .selectedProgramAwardLevels)
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
                                          '${awardLevel.rewardType.toUpperCase()} • '
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
                        _SectionCard(
                          title: 'Submission create form',
                          actionLabel:
                              _controller.canSubmitAchievements &&
                                  selectedProgram != null
                              ? 'New submission'
                              : null,
                          actionKey: const Key(
                            'scholarship-open-submission-form-button',
                          ),
                          onAction:
                              _controller.canSubmitAchievements &&
                                  selectedProgram != null
                              ? () => _openSubmissionForm(selectedProgram.id)
                              : null,
                          child: selectedProgram == null
                              ? const _InlineEmpty(
                                  message: 'Choose a program first.',
                                )
                              : !_controller.canSubmitAchievements
                              ? const _InlineEmpty(
                                  message:
                                      'Your session cannot submit scholarship achievements.',
                                )
                              : const Text(
                                  'Use New submission to attach evidence and send the request for review.',
                                ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Submissions',
                          child: selectedProgram == null
                              ? const _InlineEmpty(
                                  message: 'Choose a program first.',
                                )
                              : _controller.selectedProgramSubmissions.isEmpty
                              ? const _InlineEmpty(
                                  message:
                                      'No submissions in this program yet.',
                                )
                              : Column(
                                  children: [
                                    for (final submission
                                        in _controller
                                            .selectedProgramSubmissions)
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
                                                'Student: ${submission.studentNameSnapshot}',
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Evidence files: ${submission.evidenceUrls.length}',
                                              ),
                                              if (submission.reviewNote !=
                                                      null &&
                                                  submission.reviewNote!
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Review note: ${submission.reviewNote}',
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Review queue',
                          child: !_controller.canReviewSubmissions
                              ? const _InlineEmpty(
                                  message:
                                      'Your session cannot review scholarship submissions.',
                                )
                              : _controller.reviewQueue.isEmpty
                              ? const _InlineEmpty(
                                  message:
                                      'No pending submissions in the review queue.',
                                )
                              : Column(
                                  children: [
                                    for (final submission
                                        in _controller.reviewQueue)
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
                                                'Member: ${_controller.memberName(submission.memberId)}',
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
                                                              .isReviewing
                                                          ? null
                                                          : () {
                                                              _reviewSubmission(
                                                                submission:
                                                                    submission,
                                                                approved: true,
                                                              );
                                                            },
                                                      icon: const Icon(
                                                        Icons.check,
                                                      ),
                                                      label: const Text(
                                                        'Approve',
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
                                                              .isReviewing
                                                          ? null
                                                          : () {
                                                              _reviewSubmission(
                                                                submission:
                                                                    submission,
                                                                approved: false,
                                                              );
                                                            },
                                                      icon: const Icon(
                                                        Icons.close,
                                                      ),
                                                      label: const Text(
                                                        'Reject',
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

  @override
  Widget build(BuildContext context) {
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
          appBar: AppBar(title: const Text('Program detail')),
          body: SafeArea(
            child: program == null
                ? const Center(
                    child: Text(
                      'This scholarship program is no longer available.',
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
                      Text('${program.year} • ${program.status.toUpperCase()}'),
                      const SizedBox(height: 12),
                      Text(program.description),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Award levels',
                        actionLabel: controller.canCreateAwardLevels
                            ? 'Add award'
                            : null,
                        actionKey: const Key(
                          'scholarship-detail-open-award-form-button',
                        ),
                        onAction: controller.canCreateAwardLevels
                            ? () => onAddAwardLevel(program.id)
                            : null,
                        child: awardLevels.isEmpty
                            ? const _InlineEmpty(
                                message:
                                    'No award levels for this program yet.',
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
                        title: 'Submissions',
                        actionLabel: controller.canSubmitAchievements
                            ? 'New submission'
                            : null,
                        actionKey: const Key(
                          'scholarship-detail-open-submission-form-button',
                        ),
                        onAction: controller.canSubmitAchievements
                            ? () => onCreateSubmission(program.id)
                            : null,
                        child: submissions.isEmpty
                            ? const _InlineEmpty(
                                message: 'No submissions for this program yet.',
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
                                              label: submission.status
                                                  .toUpperCase(),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Evidence files: ${submission.evidenceUrls.length}',
                                            ),
                                            if (controller
                                                    .canReviewSubmissions &&
                                                submission.isPending) ...[
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      key: Key(
                                                        'scholarship-detail-approve-${submission.id}',
                                                      ),
                                                      onPressed: () {
                                                        onReviewSubmission(
                                                          submission:
                                                              submission,
                                                          approved: true,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Approve',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: FilledButton.tonal(
                                                      key: Key(
                                                        'scholarship-detail-reject-${submission.id}',
                                                      ),
                                                      onPressed: () {
                                                        onReviewSubmission(
                                                          submission:
                                                              submission,
                                                          approved: false,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Reject',
                                                      ),
                                                    ),
                                                  ),
                                                ],
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

class _ProgramFormSheetState extends State<_ProgramFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _yearController;
  late final TextEditingController _submissionOpenController;
  late final TextEditingController _submissionCloseController;
  late final TextEditingController _reviewCloseController;
  String _status = 'open';

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

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final year =
        int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    Navigator.of(context).pop(
      ScholarshipProgramDraft(
        title: title,
        description: _descriptionController.text.trim(),
        year: year,
        status: _status,
        submissionOpenAtIso: _nullableText(_submissionOpenController.text),
        submissionCloseAtIso: _nullableText(_submissionCloseController.text),
        reviewCloseAtIso: _nullableText(_reviewCloseController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create scholarship program',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('scholarship-program-title-input'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: '2026 Scholarship Program',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-program-description-input'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-program-year-input'),
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('scholarship-program-status-input'),
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _status = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-program-open-date-input'),
              controller: _submissionOpenController,
              decoration: const InputDecoration(
                labelText: 'Submission open (ISO date optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-program-close-date-input'),
              controller: _submissionCloseController,
              decoration: const InputDecoration(
                labelText: 'Submission close (ISO date optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-program-review-date-input'),
              controller: _reviewCloseController,
              decoration: const InputDecoration(
                labelText: 'Review close (ISO date optional)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('scholarship-program-save-button'),
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
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
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _amountController;
  late final TextEditingController _criteriaController;
  String _rewardType = 'cash';

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

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

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

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create award level',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('scholarship-award-name-input'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-award-description-input'),
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-award-sort-order-input'),
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sort order'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('scholarship-award-reward-type-input'),
              initialValue: _rewardType,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'gift', child: Text('Gift')),
                DropdownMenuItem(
                  value: 'certificate',
                  child: Text('Certificate'),
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
              decoration: const InputDecoration(labelText: 'Reward type'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-award-amount-input'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reward amount (minor)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-award-criteria-input'),
              controller: _criteriaController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Criteria'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('scholarship-award-save-button'),
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
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
  late final TextEditingController _studentNameController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _evidenceFileNameController;
  final List<String> _evidenceUrls = [];
  bool _isUploading = false;
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

  void _submit() {
    final awardLevelId = _selectedAwardLevelId;
    if (awardLevelId == null || awardLevelId.isEmpty) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

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

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create submission',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (widget.awardLevels.isEmpty)
              const _InlineEmpty(
                message:
                    'Create an award level first. Submissions require an award level.',
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
                decoration: const InputDecoration(labelText: 'Award level'),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-submission-student-input'),
              controller: _studentNameController,
              decoration: const InputDecoration(labelText: 'Student name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-submission-title-input'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Achievement title'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-submission-description-input'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('scholarship-evidence-file-input'),
              controller: _evidenceFileNameController,
              decoration: const InputDecoration(
                labelText: 'Evidence file name',
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload evidence file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_evidenceUrls.isEmpty)
              const Text('No uploaded evidence yet.')
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
                        tooltip: 'Remove',
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('scholarship-submission-save-button'),
                    onPressed: widget.awardLevels.isEmpty ? null : _submit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
