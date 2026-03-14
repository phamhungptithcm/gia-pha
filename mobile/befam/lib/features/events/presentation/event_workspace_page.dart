import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../services/event_repository.dart';
import '../services/event_validation.dart';
import 'event_controller.dart';

class EventWorkspacePage extends StatefulWidget {
  const EventWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
  });

  final AuthSession session;
  final EventRepository repository;

  @override
  State<EventWorkspacePage> createState() => _EventWorkspacePageState();
}

class _EventWorkspacePageState extends State<EventWorkspacePage> {
  late final EventController _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _controller = EventController(
      repository: widget.repository,
      session: widget.session,
    );
    _searchController = TextEditingController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEventEditor({EventRecord? event}) async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventEditorSheet(
          title: event == null
              ? context.l10n.eventFormCreateTitle
              : context.l10n.eventFormEditTitle,
          initialDraft: event == null
              ? EventDraft.empty(
                  defaultBranchId: _controller.permissions.sessionBranchId,
                )
              : EventDraft.fromRecord(event),
          branches: _controller.branches,
          members: _controller.members,
          isSaving: _controller.isSaving,
          onSubmit: (draft) {
            return _controller.saveEvent(eventId: event?.id, draft: draft);
          },
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.eventSaveSuccess)));
    }
  }

  void _openDetail(EventRecord event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _EventDetailPage(
          eventId: event.id,
          controller: _controller,
          onEdit: _openEventEditor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final l10n = context.l10n;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.eventWorkspaceTitle),
            actions: [
              IconButton(
                tooltip: l10n.eventRefreshAction,
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: _controller.permissions.canManageEvents
              ? FloatingActionButton.extended(
                  key: const Key('event-create-button'),
                  onPressed: () => _openEventEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.eventCreateAction),
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_controller.hasClanContext
                ? _WorkspaceEmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.eventNoContextTitle,
                    description: l10n.eventNoContextDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        _WorkspaceHero(
                          title: l10n.eventHeroTitle,
                          description: l10n.eventHeroDescription,
                          canCreateEvents:
                              _controller.permissions.canManageEvents,
                          onCreateEvent: _controller.permissions.canManageEvents
                              ? () => _openEventEditor()
                              : null,
                        ),
                        const SizedBox(height: 20),
                        if (_controller.permissions.isReadOnly) ...[
                          _MessageCard(
                            icon: Icons.visibility_outlined,
                            title: l10n.eventReadOnlyTitle,
                            description: l10n.eventReadOnlyDescription,
                            tone: colorScheme.secondaryContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_controller.errorMessage != null) ...[
                          _MessageCard(
                            icon: Icons.error_outline,
                            title: l10n.eventLoadErrorTitle,
                            description: l10n.eventLoadErrorDescription,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _StatGrid(
                          items: [
                            _StatTile(
                              label: l10n.eventStatTotal,
                              value: '${_controller.events.length}',
                              icon: Icons.event_note_outlined,
                            ),
                            _StatTile(
                              label: l10n.eventStatUpcoming,
                              value: '${_controller.upcomingCount}',
                              icon: Icons.upcoming_outlined,
                            ),
                            _StatTile(
                              label: l10n.eventStatMemorial,
                              value: '${_controller.memorialCount}',
                              icon: Icons.emoji_people_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.eventFilterSectionTitle,
                          child: _FilterPanel(
                            searchController: _searchController,
                            selectedType: _controller.typeFilter,
                            onQueryChanged: _controller.updateQuery,
                            onTypeChanged: _controller.updateTypeFilter,
                            onClear: () {
                              _searchController.clear();
                              _controller.updateQuery('');
                              _controller.updateTypeFilter(null);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.eventListSectionTitle,
                          actionLabel: _controller.permissions.canManageEvents
                              ? l10n.eventCreateAction
                              : null,
                          onAction: _controller.permissions.canManageEvents
                              ? () => _openEventEditor()
                              : null,
                          child: _controller.filteredEvents.isEmpty
                              ? _WorkspaceEmptyState(
                                  icon: Icons.event_busy_outlined,
                                  title: l10n.eventListEmptyTitle,
                                  description: l10n.eventListEmptyDescription,
                                )
                              : Column(
                                  children: [
                                    for (final event
                                        in _controller.filteredEvents)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              event ==
                                                  _controller
                                                      .filteredEvents
                                                      .last
                                              ? 0
                                              : 14,
                                        ),
                                        child: _EventSummaryCard(
                                          key: Key('event-row-${event.id}'),
                                          event: event,
                                          branchName: _controller.branchName(
                                            event.branchId,
                                          ),
                                          targetMemberName: _controller
                                              .memberName(event.targetMemberId),
                                          onTap: () => _openDetail(event),
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

class _EventDetailPage extends StatelessWidget {
  const _EventDetailPage({
    required this.eventId,
    required this.controller,
    required this.onEdit,
  });

  final String eventId;
  final EventController controller;
  final Future<void> Function({EventRecord? event}) onEdit;

  @override
  Widget build(BuildContext context) {
    final event = controller.eventById(eventId);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.eventDetailTitle),
        actions: [
          if (event != null && controller.permissions.canManageEvents)
            IconButton(
              key: const Key('event-detail-edit-button'),
              tooltip: l10n.eventEditAction,
              onPressed: () => onEdit(event: event),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: event == null
          ? _WorkspaceEmptyState(
              icon: Icons.search_off,
              title: l10n.eventDetailNotFoundTitle,
              description: l10n.eventDetailNotFoundDescription,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _SectionCard(
                  title: event.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        label: l10n.eventFieldType,
                        value: l10n.eventTypeLabel(event.eventType),
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldBranch,
                        value: controller.branchName(event.branchId).isEmpty
                            ? l10n.eventFieldUnset
                            : controller.branchName(event.branchId),
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldTargetMember,
                        value:
                            controller.memberName(event.targetMemberId).isEmpty
                            ? l10n.eventFieldUnset
                            : controller.memberName(event.targetMemberId),
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldLocationName,
                        value: event.locationName.trim().isEmpty
                            ? l10n.eventFieldUnset
                            : event.locationName,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldLocationAddress,
                        value: event.locationAddress.trim().isEmpty
                            ? l10n.eventFieldUnset
                            : event.locationAddress,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldDescription,
                        value: event.description.trim().isEmpty
                            ? l10n.eventFieldUnset
                            : event.description,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: l10n.eventDetailTimingSection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        label: l10n.eventFieldStartsAt,
                        value: _formatDateTimeInput(event.startsAt.toLocal()),
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldEndsAt,
                        value: event.endsAt == null
                            ? l10n.eventFieldUnset
                            : _formatDateTimeInput(event.endsAt!.toLocal()),
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldTimezone,
                        value: event.timezone,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldRecurring,
                        value: event.isRecurring
                            ? l10n.eventRecurringYes
                            : l10n.eventRecurringNo,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldRecurrenceRule,
                        value: event.recurrenceRule ?? l10n.eventFieldUnset,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldVisibility,
                        value: event.visibility,
                      ),
                      _SummaryRow(
                        label: l10n.eventFieldStatus,
                        value: event.status,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: l10n.eventDetailReminderSection,
                  child: event.reminderOffsetsMinutes.isEmpty
                      ? _WorkspaceEmptyState(
                          icon: Icons.notifications_none_outlined,
                          title: l10n.eventReminderEmptyTitle,
                          description: l10n.eventReminderEmptyDescription,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final offset in event.reminderOffsetsMinutes)
                              Chip(label: Text(_humanizeOffset(offset))),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.title,
    required this.initialDraft,
    required this.branches,
    required this.members,
    required this.onSubmit,
    required this.isSaving,
  });

  final String title;
  final EventDraft initialDraft;
  final List<BranchProfile> branches;
  final List<MemberProfile> members;
  final bool isSaving;
  final Future<EventRepositoryErrorCode?> Function(EventDraft draft) onSubmit;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _locationAddressController;
  late final TextEditingController _startsAtController;
  late final TextEditingController _endsAtController;
  late final TextEditingController _timezoneController;
  late final TextEditingController _reminderInputController;

  late EventType _selectedType;
  String? _selectedBranchId;
  String? _selectedTargetMemberId;
  late bool _isRecurring;
  late List<int> _reminderOffsets;

  EventValidationIssueCode? _validationIssue;
  EventRepositoryErrorCode? _submitError;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);
    _locationNameController = TextEditingController(text: draft.locationName);
    _locationAddressController = TextEditingController(
      text: draft.locationAddress,
    );
    _startsAtController = TextEditingController(
      text: _formatDateTimeInput(draft.startsAt.toLocal()),
    );
    _endsAtController = TextEditingController(
      text: draft.endsAt == null
          ? ''
          : _formatDateTimeInput(draft.endsAt!.toLocal()),
    );
    _timezoneController = TextEditingController(text: draft.timezone);
    _reminderInputController = TextEditingController();

    _selectedType = draft.eventType;
    _selectedBranchId = draft.branchId;
    _selectedTargetMemberId = draft.targetMemberId;
    _isRecurring = draft.isRecurring;
    _reminderOffsets = EventValidation.sanitizeReminderOffsets(
      draft.reminderOffsetsMinutes,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    _timezoneController.dispose();
    _reminderInputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _validationIssue = null;
      _submitError = null;
    });

    final startsAt = _parseDateTimeInput(_startsAtController.text.trim());
    if (startsAt == null) {
      setState(() {
        _validationIssue = EventValidationIssueCode.invalidTimeRange;
      });
      return;
    }

    DateTime? endsAt;
    final endInput = _endsAtController.text.trim();
    if (endInput.isNotEmpty) {
      endsAt = _parseDateTimeInput(endInput);
      if (endsAt == null) {
        setState(() {
          _validationIssue = EventValidationIssueCode.invalidTimeRange;
        });
        return;
      }
    }

    final draft = EventDraft(
      branchId: _selectedBranchId,
      title: _titleController.text,
      description: _descriptionController.text,
      eventType: _selectedType,
      targetMemberId: _selectedType.isMemorial ? _selectedTargetMemberId : null,
      locationName: _locationNameController.text,
      locationAddress: _locationAddressController.text,
      startsAt: startsAt,
      endsAt: endsAt,
      timezone: _timezoneController.text,
      isRecurring: _selectedType.isMemorial ? _isRecurring : false,
      recurrenceRule: _selectedType.isMemorial && _isRecurring
          ? 'FREQ=YEARLY'
          : null,
      reminderOffsetsMinutes: _reminderOffsets,
      visibility: widget.initialDraft.visibility,
      status: widget.initialDraft.status,
    );

    final validation = EventValidation.validate(draft);
    if (!validation.isValid) {
      setState(() {
        _validationIssue = validation.issues.first.code;
      });
      return;
    }

    final error = await widget.onSubmit(draft);
    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitError = error;
    });
  }

  void _addReminderOffset(int offsetMinutes) {
    if (offsetMinutes <= 0 || _reminderOffsets.contains(offsetMinutes)) {
      return;
    }

    setState(() {
      _reminderOffsets = EventValidation.sanitizeReminderOffsets([
        ..._reminderOffsets,
        offsetMinutes,
      ]);
    });
  }

  void _addReminderOffsetFromInput() {
    final parsed = int.tryParse(_reminderInputController.text.trim());
    if (parsed == null) {
      return;
    }

    _addReminderOffset(parsed);
    _reminderInputController.clear();
  }

  void _removeReminderOffset(int offsetMinutes) {
    setState(() {
      _reminderOffsets = _reminderOffsets
          .where((value) => value != offsetMinutes)
          .toList(growable: false);
    });
  }

  String? _errorText() {
    final l10n = context.l10n;

    if (_validationIssue != null) {
      return switch (_validationIssue!) {
        EventValidationIssueCode.missingTitle =>
          l10n.eventValidationTitleRequired,
        EventValidationIssueCode.invalidTimeRange =>
          l10n.eventValidationTimeRange,
        EventValidationIssueCode.invalidReminderOffsets =>
          l10n.eventValidationReminderOffsets,
        EventValidationIssueCode.memorialRequiresTargetMember =>
          l10n.eventValidationMemorialTarget,
        EventValidationIssueCode.memorialRequiresYearlyRecurrence =>
          l10n.eventValidationMemorialRule,
      };
    }

    if (_submitError != null) {
      return switch (_submitError!) {
        EventRepositoryErrorCode.permissionDenied => l10n.eventErrorPermission,
        EventRepositoryErrorCode.eventNotFound => l10n.eventErrorNotFound,
        EventRepositoryErrorCode.invalidTitle =>
          l10n.eventValidationTitleRequired,
        EventRepositoryErrorCode.invalidTimeRange =>
          l10n.eventValidationTimeRange,
        EventRepositoryErrorCode.invalidMemorialTarget =>
          l10n.eventValidationMemorialTarget,
        EventRepositoryErrorCode.invalidRecurrence =>
          l10n.eventValidationMemorialRule,
        EventRepositoryErrorCode.invalidReminderOffsets =>
          l10n.eventValidationReminderOffsets,
      };
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errorText = _errorText();
    final theme = Theme.of(context);

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (errorText != null) ...[
                  _MessageCard(
                    icon: Icons.error_outline,
                    title: l10n.eventLoadErrorTitle,
                    description: errorText,
                    tone: theme.colorScheme.errorContainer,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  key: const Key('event-title-field'),
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormTitleLabel,
                    hintText: l10n.eventFormTitleHint,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EventType>(
                  key: Key('event-type-dropdown-${_selectedType.wireName}'),
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormTypeLabel,
                  ),
                  items: [
                    for (final type in EventType.values)
                      DropdownMenuItem<EventType>(
                        value: type,
                        child: Text(l10n.eventTypeLabel(type)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedType = value;
                      if (!_selectedType.isMemorial) {
                        _selectedTargetMemberId = null;
                        _isRecurring = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: Key(
                    'event-branch-dropdown-${_selectedBranchId ?? 'all'}',
                  ),
                  initialValue: _selectedBranchId,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormBranchLabel,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.eventFilterTypeAll),
                    ),
                    for (final branch in widget.branches)
                      DropdownMenuItem<String?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBranchId = value;
                    });
                  },
                ),
                if (_selectedType.isMemorial) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: Key(
                      'event-target-member-dropdown-${_selectedTargetMemberId ?? 'unset'}',
                    ),
                    initialValue: _selectedTargetMemberId,
                    decoration: InputDecoration(
                      labelText: l10n.eventFormTargetMemberLabel,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.eventFieldUnset),
                      ),
                      for (final member in widget.members)
                        DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTargetMemberId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    key: const Key('event-recurring-switch'),
                    value: _isRecurring,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.eventFormRecurringMemorialLabel),
                    subtitle: _isRecurring
                        ? const Text('FREQ=YEARLY')
                        : Text(l10n.eventRecurringNo),
                    onChanged: (value) {
                      setState(() {
                        _isRecurring = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('event-start-field'),
                        controller: _startsAtController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.eventFormStartsAtLabel,
                          hintText: l10n.eventFormDateTimeHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('event-end-field'),
                        controller: _endsAtController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.eventFormEndsAtLabel,
                          hintText: l10n.eventFormDateTimeHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _timezoneController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormTimezoneLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormLocationNameLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationAddressController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormLocationAddressLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.eventFormDescriptionLabel,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.eventFormReminderSectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final offset in _reminderOffsets)
                      InputChip(
                        key: Key('event-reminder-chip-$offset'),
                        label: Text(_humanizeOffset(offset)),
                        onDeleted: () => _removeReminderOffset(offset),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _addReminderOffset(10080),
                      child: Text(l10n.eventFormReminderPresetWeek),
                    ),
                    OutlinedButton(
                      onPressed: () => _addReminderOffset(1440),
                      child: Text(l10n.eventFormReminderPresetDay),
                    ),
                    OutlinedButton(
                      onPressed: () => _addReminderOffset(120),
                      child: Text(l10n.eventFormReminderPresetHours),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('event-reminder-input'),
                        controller: _reminderInputController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.eventFormReminderCustomLabel,
                          hintText: l10n.eventFormReminderCustomHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      key: const Key('event-reminder-add-button'),
                      onPressed: _addReminderOffsetFromInput,
                      icon: const Icon(Icons.add_alert_outlined),
                      label: Text(l10n.eventFormReminderAddAction),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('event-save-button'),
                    onPressed: widget.isSaving ? null : _submit,
                    icon: widget.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.eventFormSaveAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.selectedType,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final EventType? selectedType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventType?> onTypeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            labelText: l10n.eventSearchLabel,
            hintText: l10n.eventSearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<EventType?>(
                key: Key(
                  'event-filter-type-${selectedType?.wireName ?? 'all'}',
                ),
                initialValue: selectedType,
                decoration: InputDecoration(labelText: l10n.eventFormTypeLabel),
                items: [
                  DropdownMenuItem<EventType?>(
                    value: null,
                    child: Text(l10n.eventFilterTypeAll),
                  ),
                  for (final type in EventType.values)
                    DropdownMenuItem<EventType?>(
                      value: type,
                      child: Text(l10n.eventTypeLabel(type)),
                    ),
                ],
                onChanged: onTypeChanged,
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_outlined),
              label: Text(l10n.eventFilterClearAction),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.title,
    required this.description,
    required this.canCreateEvents,
    this.onCreateEvent,
  });

  final String title;
  final String description;
  final bool canCreateEvents;
  final VoidCallback? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          if (canCreateEvents) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateEvent,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.eventCreateAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    super.key,
    required this.event,
    required this.branchName,
    required this.targetMemberName,
    this.onTap,
  });

  final EventRecord event;
  final String branchName;
  final String targetMemberName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(l10n.eventTypeLabel(event.eventType)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: colorScheme.secondaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CardInfoRow(
                icon: Icons.schedule_outlined,
                text:
                    '${_formatDateTimeInput(event.startsAt.toLocal())} • ${event.timezone}',
              ),
              if (event.endsAt != null)
                _CardInfoRow(
                  icon: Icons.hourglass_bottom_outlined,
                  text: _formatDateTimeInput(event.endsAt!.toLocal()),
                ),
              if (branchName.isNotEmpty)
                _CardInfoRow(
                  icon: Icons.account_tree_outlined,
                  text: branchName,
                ),
              if (targetMemberName.isNotEmpty)
                _CardInfoRow(
                  icon: Icons.person_outline,
                  text: targetMemberName,
                ),
              if (event.locationName.trim().isNotEmpty)
                _CardInfoRow(
                  icon: Icons.place_outlined,
                  text: event.locationName,
                ),
              if (event.reminderOffsetsMinutes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final offset in event.reminderOffsetsMinutes)
                      Chip(
                        label: Text(_humanizeOffset(offset)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardInfoRow extends StatelessWidget {
  const _CardInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatTile> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = switch (width) {
      > 1000 => 3,
      > 680 => 3,
      _ => 1,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 4.2 : 1.9,
      ),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add),
                    label: Text(actionLabel!),
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

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(description),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String _humanizeOffset(int offsetMinutes) {
  if (offsetMinutes % 1440 == 0) {
    return '${offsetMinutes ~/ 1440}d';
  }

  if (offsetMinutes % 60 == 0) {
    return '${offsetMinutes ~/ 60}h';
  }

  return '${offsetMinutes}m';
}

String _formatDateTimeInput(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

DateTime? _parseDateTimeInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final normalized = trimmed.replaceFirst('T', ' ');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$',
  ).firstMatch(normalized);

  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);

    final value = DateTime(year, month, day, hour, minute);
    if (value.year == year &&
        value.month == month &&
        value.day == day &&
        value.hour == hour &&
        value.minute == minute) {
      return value;
    }
    return null;
  }

  return DateTime.tryParse(trimmed)?.toLocal();
}
