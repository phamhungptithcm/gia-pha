import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../core/widgets/address_action_tools.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../ai/services/ai_assist_service.dart';
import '../../ai/services/ai_product_analytics_service.dart';
import '../../calendar/services/lunar_conversion_engine.dart';
import '../../calendar/presentation/dual_calendar_workspace_page.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../../member/models/member_draft.dart';
import '../../member/models/member_workspace_snapshot.dart';
import '../../member/services/member_repository.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/memorial_ritual.dart';
import '../services/event_repository.dart';
import '../services/event_validation.dart';
import 'event_controller.dart';

class EventWorkspacePage extends StatefulWidget {
  const EventWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.availableClanContexts = const [],
    this.onSwitchClanContext,
    this.initialEventId,
    this.nowProvider,
    this.lunarConversionEngine,
    this.aiAssistService,
  });

  final AuthSession session;
  final EventRepository repository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;
  final String? initialEventId;
  final DateTime Function()? nowProvider;
  final LunarConversionEngine? lunarConversionEngine;
  final AiAssistService? aiAssistService;

  @override
  State<EventWorkspacePage> createState() => _EventWorkspacePageState();
}

class _EventWorkspacePageState extends State<EventWorkspacePage> {
  static const int _eventBatchSize = 24;
  static const double _eventLazyThresholdPx = 420;

  late EventController _controller;
  late AuthSession _activeSession;
  late final AiAssistService _aiAssistService;
  late final TextEditingController _searchController;
  late final ScrollController _workspaceScrollController;
  int _visibleEventCount = _eventBatchSize;
  String _eventListSeed = '';
  String? _pendingInitialEventId;

  AuthSession get _session => _activeSession;

  DateTime _nowLocal() => (widget.nowProvider ?? DateTime.now)().toLocal();

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _aiAssistService = widget.aiAssistService ?? createDefaultAiAssistService();
    _controller = _buildController(_session);
    _searchController = TextEditingController();
    _workspaceScrollController = ScrollController()
      ..addListener(_handleWorkspaceScroll);
    _pendingInitialEventId = _normalizeInitialEventId(widget.initialEventId);
    unawaited(_controller.initialize().then((_) => _tryOpenInitialEvent()));
  }

  @override
  void didUpdateWidget(covariant EventWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.session != widget.session;
    final repositoryChanged = oldWidget.repository != widget.repository;
    final nowProviderChanged = oldWidget.nowProvider != widget.nowProvider;
    final lunarEngineChanged =
        oldWidget.lunarConversionEngine != widget.lunarConversionEngine;
    if (!sessionChanged &&
        !repositoryChanged &&
        !nowProviderChanged &&
        !lunarEngineChanged) {
      return;
    }
    _activeSession = widget.session;
    _controller.dispose();
    _controller = _buildController(_session);
    final incomingInitialEventId = _normalizeInitialEventId(
      widget.initialEventId,
    );
    if (incomingInitialEventId != _pendingInitialEventId) {
      _pendingInitialEventId = incomingInitialEventId;
    }
    unawaited(_controller.initialize().then((_) => _tryOpenInitialEvent()));
  }

  @override
  void dispose() {
    _workspaceScrollController.removeListener(_handleWorkspaceScroll);
    _workspaceScrollController.dispose();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  EventController _buildController(AuthSession session) {
    return EventController(
      repository: widget.repository,
      session: session,
      nowProvider: widget.nowProvider,
      lunarConversionEngine: widget.lunarConversionEngine,
    );
  }

  String? _normalizeInitialEventId(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _tryOpenInitialEvent() {
    final initialEventId = _pendingInitialEventId;
    if (initialEventId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final event = _controller.eventById(initialEventId);
        if (event == null) {
          return;
        }
        _pendingInitialEventId = null;
        _openDetail(event);
      });
    }
  }

  void _handleWorkspaceScroll() {
    if (!_workspaceScrollController.hasClients) {
      return;
    }
    if (_workspaceScrollController.position.extentAfter >
        _eventLazyThresholdPx) {
      return;
    }
    final total = _controller.filteredEvents.length;
    if (_visibleEventCount >= total) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _visibleEventCount = math.min(
        total,
        _visibleEventCount + _eventBatchSize,
      );
    });
  }

  void _syncVisibleEventState(List<EventRecord> filteredEvents) {
    final seed = filteredEvents.isEmpty
        ? '0'
        : '${filteredEvents.length}:${filteredEvents.first.id}:${filteredEvents.last.id}';
    if (seed == _eventListSeed) {
      return;
    }
    _eventListSeed = seed;
    _visibleEventCount = math.min(filteredEvents.length, _eventBatchSize);
  }

  List<_EventGroupBucket> _groupEventsByMonth(
    BuildContext context,
    List<EventRecord> events, {
    required DateTime nowLocal,
  }) {
    final grouped = <String, List<EventRecord>>{};
    for (final event in events) {
      final local = _controller.displayStartsAt(event, now: nowLocal);
      final month = '${local.month.toString().padLeft(2, '0')}/${local.year}';
      final label = context.l10n.pick(vi: 'Tháng $month', en: 'Month $month');
      grouped.putIfAbsent(label, () => <EventRecord>[]).add(event);
    }
    return grouped.entries
        .map(
          (entry) => _EventGroupBucket(label: entry.key, events: entry.value),
        )
        .toList(growable: false);
  }

  Future<void> _openEventEditor({
    EventRecord? event,
    EventDraft? initialDraft,
  }) async {
    if (event == null) {
      await _openDualCalendarCreateEditor(initialDraft: initialDraft);
      return;
    }

    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventEditorSheet(
          session: _session,
          title: context.l10n.eventFormEditTitle,
          initialDraft: EventDraft.fromRecord(event),
          branches: _controller.branches,
          members: _controller.members,
          aiAssistService: _aiAssistService,
          isSaving: _controller.isSaving,
          onSubmit: (draft) {
            return _controller.saveEvent(eventId: event.id, draft: draft);
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

  Future<void> _openDualCalendarCreateEditor({EventDraft? initialDraft}) async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return DualCalendarWorkspacePage(
            session: _session,
            availableClanContexts: widget.availableClanContexts,
            onSwitchClanContext: widget.onSwitchClanContext,
            memberRepository: _EventWorkspaceMemberRepositoryAdapter(
              members: _controller.members,
              branches: _controller.branches,
            ),
            autoOpenCreateEditor: true,
            initialCreateDraft: initialDraft,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    if (didSave == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.eventSaveSuccess)));
    }
    await _controller.refresh();
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

  Future<void> _openQuickMemorialSetup(MemorialChecklistItem item) async {
    final deathDate = item.deathDate;
    if (deathDate == null) {
      return;
    }

    await _openEventEditor(
      initialDraft: _buildQuickMemorialDraft(
        member: item.member,
        deathDate: deathDate,
        now: _nowLocal(),
      ),
    );
  }

  Future<void> _openQuickRitualSetup({
    required MemorialRitualChecklistItem item,
    required MemorialRitualChecklistMilestoneItem milestoneItem,
  }) async {
    if (!milestoneItem.isMissing) {
      return;
    }

    await _openEventEditor(
      initialDraft: _buildQuickRitualDraft(
        member: item.member,
        deathDate: item.deathDate,
        milestone: milestoneItem.milestone,
      ),
    );
  }

  Future<void> _openMemorialChecklistCenter({
    required _MemorialChecklistCategory initialCategory,
  }) async {
    final l10n = context.l10n;
    final now = _nowLocal();
    final entries = <_MemorialChecklistEntry>[];

    for (final item in _controller.memorialRitualChecklistItems) {
      for (final milestoneItem in item.milestones) {
        final category = switch (milestoneItem.milestone.type) {
          MemorialRitualMilestoneType.first49Days ||
          MemorialRitualMilestoneType.first50Days ||
          MemorialRitualMilestoneType.day100 =>
            _MemorialChecklistCategory.prayer,
          MemorialRitualMilestoneType.year1 => _MemorialChecklistCategory.year1,
          MemorialRitualMilestoneType.year2 => _MemorialChecklistCategory.year2,
        };
        final status = _entryStatusForRitualMilestone(milestoneItem);
        final entryId =
            'ritual_${item.member.id}_${milestoneItem.milestone.key}';
        entries.add(
          _MemorialChecklistEntry(
            id: entryId,
            category: category,
            member: item.member,
            branchName: _controller.branchName(item.member.branchId),
            deathDate: item.deathDate,
            expectedAt: milestoneItem.expectedDate,
            title: _ritualMilestoneLabel(l10n, milestoneItem.milestone.type),
            status: status,
            configuredEvent: milestoneItem.configuredEvent,
            onQuickSetup:
                _controller.permissions.canManageEvents &&
                    milestoneItem.isMissing
                ? () => _openQuickRitualSetup(
                    item: item,
                    milestoneItem: milestoneItem,
                  )
                : null,
            onOpenEvent: milestoneItem.configuredEvent == null
                ? null
                : () => _openDetail(milestoneItem.configuredEvent!),
          ),
        );
      }
    }

    for (final item in _controller.memorialChecklistItems) {
      final deathDate = item.deathDate;
      if (deathDate == null) {
        continue;
      }
      final yearsSinceDeath = _yearsSince(deathDate: deathDate, now: now);
      if (yearsSinceDeath < 3) {
        continue;
      }
      final status = _entryStatusForMemorialItem(item);
      final expectedAt = _nextMemorialOccurrence(
        deathDate: deathDate,
        now: now,
      );
      entries.add(
        _MemorialChecklistEntry(
          id: 'memorial_${item.member.id}',
          category: _MemorialChecklistCategory.anniversary,
          member: item.member,
          branchName: _controller.branchName(item.member.branchId),
          deathDate: deathDate,
          expectedAt: expectedAt,
          title: l10n.pick(vi: 'Giỗ kỵ hằng năm', en: 'Yearly memorial'),
          status: status,
          configuredEvent: item.primaryEvent,
          onQuickSetup:
              _controller.permissions.canManageEvents && !item.hasMemorialEvent
              ? () => _openQuickMemorialSetup(item)
              : null,
          onOpenEvent: item.primaryEvent == null
              ? null
              : () => _openDetail(item.primaryEvent!),
        ),
      );
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _MemorialChecklistCenterPage(
          entries: entries,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  int _yearsSince({required DateTime deathDate, required DateTime now}) {
    var years = now.year - deathDate.year;
    final anniversaryThisYear = _safeLocalDate(
      year: now.year,
      month: deathDate.month,
      day: deathDate.day,
    );
    final nowDate = DateTime(now.year, now.month, now.day);
    if (nowDate.isBefore(
      DateTime(
        anniversaryThisYear.year,
        anniversaryThisYear.month,
        anniversaryThisYear.day,
      ),
    )) {
      years -= 1;
    }
    return years;
  }

  _ChecklistEntryStatus _entryStatusForRitualMilestone(
    MemorialRitualChecklistMilestoneItem milestone,
  ) {
    if (milestone.isMissing) {
      return _ChecklistEntryStatus.missing;
    }
    if (milestone.hasDateMismatch) {
      return _ChecklistEntryStatus.mismatch;
    }
    return _ChecklistEntryStatus.configured;
  }

  _ChecklistEntryStatus _entryStatusForMemorialItem(
    MemorialChecklistItem item,
  ) {
    if (!item.hasMemorialEvent) {
      return _ChecklistEntryStatus.missing;
    }
    if (item.hasDateMismatch) {
      return _ChecklistEntryStatus.mismatch;
    }
    return _ChecklistEntryStatus.configured;
  }

  Future<void> _openLongevityCelebrationList() async {
    final candidates = _controller.longevityCelebrationCandidates;
    if (candidates.isEmpty) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _LongevityCelebrationListPage(
          candidates: candidates,
          branchNameFor: _controller.branchName,
          onOpenMemberDetail: _openLongevityMemberDetail,
        ),
      ),
    );
  }

  Future<void> _openLongevityMemberDetail(
    LongevityCelebrationCandidate candidate,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _LongevityMemberDetailPage(
          member: candidate.member,
          milestoneAge: candidate.milestoneAge,
          celebrationDate: candidate.celebrationDate,
          branchName: _controller.branchName(candidate.member.branchId),
        ),
      ),
    );
  }

  EventDraft _buildQuickMemorialDraft({
    required MemberProfile member,
    required DateTime deathDate,
    required DateTime now,
  }) {
    final l10n = context.l10n;
    final startAt = _nextMemorialOccurrence(deathDate: deathDate, now: now);
    final defaultBranchId = _controller.permissions.sessionBranchId;
    final branchId = member.branchId.trim().isEmpty
        ? defaultBranchId
        : member.branchId;
    final base = EventDraft.empty(defaultBranchId: branchId);

    return base.copyWith(
      branchId: branchId,
      title: l10n.eventQuickMemorialTitle(member.fullName),
      description: l10n.eventQuickMemorialDescription(
        _formatDateInput(deathDate),
      ),
      eventType: EventType.deathAnniversary,
      targetMemberId: member.id,
      startsAt: startAt,
      endsAt: startAt.add(const Duration(hours: 2)),
      isRecurring: true,
      recurrenceRule: 'FREQ=YEARLY',
      reminderOffsetsMinutes: const [10080, 1440, 120],
      visibility: 'clan',
      status: 'scheduled',
      ritualKey: null,
      ritualPreset: null,
      isAutoGenerated: false,
    );
  }

  EventDraft _buildQuickRitualDraft({
    required MemberProfile member,
    required DateTime deathDate,
    required MemorialRitualMilestone milestone,
  }) {
    final l10n = context.l10n;
    final defaultBranchId = _controller.permissions.sessionBranchId;
    final branchId = member.branchId.trim().isEmpty
        ? defaultBranchId
        : member.branchId;
    final base = EventDraft.empty(defaultBranchId: branchId);
    final milestoneLabel = _ritualMilestoneLabel(l10n, milestone.type);
    final startAt = _safeLocalDate(
      year: milestone.expectedAt.year,
      month: milestone.expectedAt.month,
      day: milestone.expectedAt.day,
      hour: 9,
      minute: 0,
    );

    return base.copyWith(
      branchId: branchId,
      title: l10n.eventQuickRitualTitle(milestoneLabel, member.fullName),
      description: l10n.eventQuickRitualDescription(
        milestoneLabel,
        _formatDateInput(deathDate),
      ),
      eventType: EventType.deathAnniversary,
      targetMemberId: member.id,
      startsAt: startAt,
      endsAt: startAt.add(const Duration(hours: 2)),
      isRecurring: false,
      clearRecurrenceRule: true,
      reminderOffsetsMinutes: const [10080, 1440, 120],
      visibility: 'clan',
      status: 'scheduled',
      ritualKey: milestone.key,
      ritualPreset: memorialRitualPresetCode(kDefaultMemorialRitualPreset),
      isAutoGenerated: true,
    );
  }

  DateTime _nextMemorialOccurrence({
    required DateTime deathDate,
    required DateTime now,
  }) {
    final nowLocal = now.toLocal();
    final initialCandidate = _safeLocalDate(
      year: nowLocal.year,
      month: deathDate.month,
      day: deathDate.day,
      hour: 9,
      minute: 0,
    );

    if (!initialCandidate.isBefore(nowLocal)) {
      return initialCandidate;
    }

    return _safeLocalDate(
      year: nowLocal.year + 1,
      month: deathDate.month,
      day: deathDate.day,
      hour: 9,
      minute: 0,
    );
  }

  DateTime _safeLocalDate({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
  }) {
    final value = DateTime(year, month, day, hour, minute);
    if (value.month == month && value.day == day) {
      return value;
    }

    // Clamp invalid calendar days (e.g. Feb 29 in non-leap years) to month end.
    return DateTime(year, month + 1, 0, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final l10n = context.l10n;
        final colorScheme = Theme.of(context).colorScheme;
        final nowLocal = _nowLocal();
        final hasActiveFilters =
            _controller.query.trim().isNotEmpty ||
            _controller.typeFilter != null;
        final filteredEvents = _controller.filteredEvents;
        _syncVisibleEventState(filteredEvents);
        final visibleEvents = filteredEvents
            .take(_visibleEventCount)
            .toList(growable: false);
        final groupedVisibleEvents = _groupEventsByMonth(
          context,
          visibleEvents,
          nowLocal: nowLocal,
        );
        void clearFilters() {
          _searchController.clear();
          _controller.updateQuery('');
          _controller.updateTypeFilter(null);
        }

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
                  tooltip: l10n.eventCreateAction,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.pick(vi: 'Thêm sự kiện', en: 'Add event')),
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải sự kiện...',
                      en: 'Loading events...',
                    ),
                  )
                : !_controller.hasClanContext
                ? _WorkspaceEmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.eventNoContextTitle,
                    description: l10n.eventNoContextDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: AppWorkspaceViewport(
                      child: ListView(
                        controller: _workspaceScrollController,
                        key: const Key('event-workspace-scroll'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: appWorkspacePagePadding(
                          context,
                          top: 16,
                          bottom: 32,
                        ),
                        children: [
                          if (_controller.permissions.isReadOnly) ...[
                            _MessageCard(
                              icon: Icons.visibility_outlined,
                              title: l10n.eventReadOnlyTitle,
                              description: l10n.eventReadOnlyDescription,
                              tone: colorScheme.secondaryContainer,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_controller.errorMessage != null) ...[
                            _MessageCard(
                              icon: Icons.error_outline,
                              title: l10n.eventLoadErrorTitle,
                              description: l10n.eventLoadErrorDescription,
                              tone: colorScheme.errorContainer,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _controller.refresh,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.eventRefreshAction),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AppWorkspaceSurface(
                            padding: const EdgeInsets.all(16),
                            child: _FilterPanel(
                              searchController: _searchController,
                              selectedType: _controller.typeFilter,
                              totalEventCount: _controller.events.length,
                              filteredEventCount: filteredEvents.length,
                              upcomingCount: _controller.upcomingCount,
                              memorialCount: _controller.memorialCount,
                              onQueryChanged: _controller.updateQuery,
                              onTypeChanged: _controller.updateTypeFilter,
                              onClear: clearFilters,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _MemorialQuickAccessCard(
                            prayerPendingCount: _controller
                                .memorialRitualChecklistItems
                                .expand((item) => item.milestones)
                                .where(
                                  (milestone) =>
                                      milestone.milestone.type ==
                                          MemorialRitualMilestoneType
                                              .first49Days ||
                                      milestone.milestone.type ==
                                          MemorialRitualMilestoneType
                                              .first50Days ||
                                      milestone.milestone.type ==
                                          MemorialRitualMilestoneType.day100,
                                )
                                .where(
                                  (milestone) =>
                                      milestone.isMissing ||
                                      milestone.hasDateMismatch,
                                )
                                .length,
                            year1PendingCount: _controller
                                .memorialRitualChecklistItems
                                .expand((item) => item.milestones)
                                .where(
                                  (milestone) =>
                                      milestone.milestone.type ==
                                      MemorialRitualMilestoneType.year1,
                                )
                                .where(
                                  (milestone) =>
                                      milestone.isMissing ||
                                      milestone.hasDateMismatch,
                                )
                                .length,
                            year2PendingCount: _controller
                                .memorialRitualChecklistItems
                                .expand((item) => item.milestones)
                                .where(
                                  (milestone) =>
                                      milestone.milestone.type ==
                                      MemorialRitualMilestoneType.year2,
                                )
                                .where(
                                  (milestone) =>
                                      milestone.isMissing ||
                                      milestone.hasDateMismatch,
                                )
                                .length,
                            annualMemorialPendingCount: _controller
                                .memorialChecklistItems
                                .where(
                                  (item) =>
                                      item.deathDate != null &&
                                      _yearsSince(
                                            deathDate: item.deathDate!,
                                            now: nowLocal,
                                          ) >=
                                          3 &&
                                      (!item.hasMemorialEvent ||
                                          item.hasDateMismatch),
                                )
                                .length,
                            onOpenPrayer: () => _openMemorialChecklistCenter(
                              initialCategory:
                                  _MemorialChecklistCategory.prayer,
                            ),
                            onOpenYear1: () => _openMemorialChecklistCenter(
                              initialCategory: _MemorialChecklistCategory.year1,
                            ),
                            onOpenYear2: () => _openMemorialChecklistCenter(
                              initialCategory: _MemorialChecklistCategory.year2,
                            ),
                            onOpenAnniversary: () =>
                                _openMemorialChecklistCenter(
                                  initialCategory:
                                      _MemorialChecklistCategory.anniversary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          if (_controller.showLongevityReminderLink) ...[
                            AppWorkspaceSurface(
                              padding: const EdgeInsets.all(16),
                              child: _LongevityReminderLinkCard(
                                key: const Key(
                                  'event-longevity-reminder-link-card',
                                ),
                                candidates:
                                    _controller.longevityCelebrationCandidates,
                                celebrationDate:
                                    _controller.longevityCelebrationDate,
                                onOpenList: _openLongevityCelebrationList,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            l10n.pick(
                              vi: 'Sự kiện sắp tới gần nhất',
                              en: 'Nearest upcoming events',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (filteredEvents.isEmpty)
                            _WorkspaceEmptyState(
                              icon: Icons.event_busy_outlined,
                              title: hasActiveFilters
                                  ? l10n.pick(
                                      vi: 'Không tìm thấy sự kiện phù hợp',
                                      en: 'No events match these filters',
                                    )
                                  : l10n.eventListEmptyTitle,
                              description: hasActiveFilters
                                  ? l10n.pick(
                                      vi: 'Thử từ khóa hoặc loại sự kiện khác.',
                                      en: 'Try a different query or event type.',
                                    )
                                  : l10n.eventListEmptyDescription,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final bucket in groupedVisibleEvents) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      bucket.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  for (var i = 0; i < bucket.events.length; i++)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom: i == bucket.events.length - 1
                                            ? 12
                                            : 10,
                                      ),
                                      child: _EventSummaryCard(
                                        key: Key(
                                          'event-row-${bucket.events[i].id}',
                                        ),
                                        event: bucket.events[i],
                                        displayStartsAt: _controller
                                            .displayStartsAt(
                                              bucket.events[i],
                                              now: nowLocal,
                                            ),
                                        displayEndsAt: _controller
                                            .displayEndsAt(
                                              bucket.events[i],
                                              now: nowLocal,
                                            ),
                                        branchName: _controller.branchName(
                                          bucket.events[i].branchId,
                                        ),
                                        targetMemberName: _controller
                                            .memberName(
                                              bucket.events[i].targetMemberId,
                                            ),
                                        onTap: () =>
                                            _openDetail(bucket.events[i]),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                        ],
                      ),
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
    final branchName = event == null
        ? ''
        : controller.branchName(event.branchId);
    final targetMemberName = event == null
        ? ''
        : controller.memberName(event.targetMemberId);
    final audienceSummary = event == null
        ? ''
        : _joinNonEmptyText([branchName, targetMemberName]);
    final locationSummary = event == null
        ? ''
        : _joinNonEmptyText([event.locationName, event.locationAddress]);
    final scheduleSummary = event == null
        ? ''
        : _formatEventScheduleSummary(
            event.startsAt.toLocal(),
            event.endsAt?.toLocal(),
          );

    return Scaffold(
      key: Key('event-detail-page-$eventId'),
      appBar: AppBar(
        title: Text(
          event?.title.trim().isNotEmpty == true
              ? event!.title
              : l10n.eventDetailTitle,
        ),
        actions: [
          if (event != null && controller.permissions.canManageEvents)
            if (!event.isAutoGenerated)
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
          : AppWorkspaceViewport(
              child: ListView(
                padding: appWorkspacePagePadding(context, top: 20, bottom: 32),
                children: [
                  AppWorkspaceSurface(
                    gradient: appWorkspaceHeroGradient(context),
                    showAccentOrbs: true,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ContextBadge(
                              icon: Icons.event_note_outlined,
                              label: l10n.eventTypeLabel(event.eventType),
                            ),
                            _ContextBadge(
                              icon: event.isRecurring
                                  ? Icons.autorenew
                                  : Icons.looks_one_outlined,
                              label: event.isRecurring
                                  ? l10n.pick(vi: 'Lặp lại', en: 'Repeats')
                                  : l10n.pick(vi: 'Một lần', en: 'One-time'),
                            ),
                            _ContextBadge(
                              icon: event.isAutoGenerated
                                  ? Icons.auto_awesome_outlined
                                  : Icons.edit_calendar_outlined,
                              label: event.isAutoGenerated
                                  ? l10n.pick(
                                      vi: 'Tự động tạo',
                                      en: 'Auto-generated',
                                    )
                                  : l10n.pick(vi: 'Tạo thủ công', en: 'Manual'),
                            ),
                          ],
                        ),
                        if (event.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            event.description.trim(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _DetailOverviewRow(
                          icon: Icons.schedule_outlined,
                          label: l10n.pick(vi: 'Thời gian', en: 'Schedule'),
                          value: scheduleSummary,
                        ),
                        const SizedBox(height: 12),
                        _DetailOverviewRow(
                          icon: Icons.groups_2_outlined,
                          label: l10n.pick(vi: 'Liên quan', en: 'Related'),
                          value: audienceSummary.isEmpty
                              ? l10n.pick(vi: 'Toàn tộc', en: 'Whole clan')
                              : audienceSummary,
                        ),
                        const SizedBox(height: 12),
                        _DetailOverviewRow(
                          icon: Icons.location_on_outlined,
                          label: l10n.pick(vi: 'Địa điểm', en: 'Location'),
                          value: locationSummary.isEmpty
                              ? l10n.eventFieldUnset
                              : locationSummary,
                          trailing: AddressDirectionIconButton(
                            address: event.locationAddress,
                            label: event.title,
                          ),
                        ),
                        if (event.reminderOffsetsMinutes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.pick(vi: 'Nhắc trước', en: 'Remind before'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final offset in event.reminderOffsetsMinutes)
                                Chip(label: Text(_humanizeOffset(offset))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: l10n.pick(vi: 'Điểm chính', en: 'Core details'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          label: l10n.eventFieldBranch,
                          value: branchName.isEmpty
                              ? l10n.pick(vi: 'Toàn tộc', en: 'Whole clan')
                              : branchName,
                        ),
                        _SummaryRow(
                          label: l10n.eventFieldTargetMember,
                          value: targetMemberName.isEmpty
                              ? l10n.eventFieldUnset
                              : targetMemberName,
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
                          trailing: AddressDirectionIconButton(
                            address: event.locationAddress,
                            label: event.title,
                          ),
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
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: l10n.pick(
                      vi: 'Thiết lập lịch',
                      en: 'Schedule settings',
                    ),
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
                  const SizedBox(height: 12),
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
            ),
    );
  }
}

class _LongevityReminderLinkCard extends StatelessWidget {
  const _LongevityReminderLinkCard({
    super.key,
    required this.candidates,
    required this.celebrationDate,
    required this.onOpenList,
  });

  final List<LongevityCelebrationCandidate> candidates;
  final DateTime? celebrationDate;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = candidates.length;
    final summary = celebrationDate == null
        ? l10n.pick(
            vi: 'Có $count thành viên đến mốc mừng thọ.',
            en: '$count members are reaching a longevity milestone.',
          )
        : l10n.pick(
            vi: 'Có $count thành viên đến mốc mừng thọ vào ${_formatDateInput(celebrationDate!)}.',
            en: '$count members are reaching a longevity milestone on ${_formatDateInput(celebrationDate!)}.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('event-longevity-link-button'),
          onPressed: onOpenList,
          icon: const Icon(Icons.card_giftcard_outlined),
          label: Text(
            l10n.pick(
              vi: 'Xem danh sách được mừng thọ',
              en: 'View longevity list',
            ),
          ),
        ),
      ],
    );
  }
}

class _LongevityCelebrationListPage extends StatelessWidget {
  const _LongevityCelebrationListPage({
    required this.candidates,
    required this.branchNameFor,
    required this.onOpenMemberDetail,
  });

  final List<LongevityCelebrationCandidate> candidates;
  final String Function(String? branchId) branchNameFor;
  final Future<void> Function(LongevityCelebrationCandidate candidate)
  onOpenMemberDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick(vi: 'Danh sách mừng thọ sắp tới', en: 'Upcoming longevity'),
        ),
      ),
      body: candidates.isEmpty
          ? _WorkspaceEmptyState(
              icon: Icons.card_giftcard_outlined,
              title: l10n.pick(
                vi: 'Chưa có thành viên đạt mốc mừng thọ',
                en: 'No longevity milestone yet',
              ),
              description: l10n.pick(
                vi: 'Danh sách sẽ hiện khi có thành viên còn sống đạt mốc 70, 75, 80...',
                en: 'This list appears when living members reach 70, 75, 80...',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final member = candidate.member;
                final branchName = branchNameFor(member.branchId);
                final address = member.addressText?.trim() ?? '';
                final ageLabel = l10n.pick(
                  vi: '${candidate.milestoneAge} tuổi',
                  en: '${candidate.milestoneAge} years',
                );
                return Card(
                  child: ListTile(
                    key: Key('event-longevity-member-row-${member.id}'),
                    onTap: () => onOpenMemberDetail(candidate),
                    title: Text(
                      member.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (branchName.isNotEmpty)
                            Text(
                              branchName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                    trailing: Chip(label: Text(ageLabel)),
                  ),
                );
              },
            ),
    );
  }
}

class _LongevityMemberDetailPage extends StatelessWidget {
  const _LongevityMemberDetailPage({
    required this.member,
    required this.milestoneAge,
    required this.celebrationDate,
    required this.branchName,
  });

  final MemberProfile member;
  final int milestoneAge;
  final DateTime celebrationDate;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final address = member.addressText?.trim() ?? '';
    final ageLabel = l10n.pick(
      vi: '$milestoneAge tuổi',
      en: '$milestoneAge years',
    );

    return Scaffold(
      appBar: AppBar(title: Text(member.fullName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _SectionCard(
            title: l10n.pick(vi: 'Chi tiết thành viên', en: 'Member details'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  label: l10n.pick(
                    vi: 'Mốc mừng thọ',
                    en: 'Longevity milestone',
                  ),
                  value: ageLabel,
                ),
                _SummaryRow(
                  label: l10n.pick(vi: 'Ngày mừng thọ', en: 'Celebration date'),
                  value: _formatDateInput(celebrationDate),
                ),
                _SummaryRow(
                  label: l10n.pick(vi: 'Chi', en: 'Branch'),
                  value: branchName.isEmpty ? l10n.eventFieldUnset : branchName,
                ),
                _SummaryRow(
                  label: l10n.pick(vi: 'Ngày sinh', en: 'Birth date'),
                  value: (member.birthDate ?? '').trim().isEmpty
                      ? l10n.eventFieldUnset
                      : member.birthDate!,
                ),
                _SummaryRow(
                  label: l10n.pick(vi: 'Địa chỉ', en: 'Address'),
                  value: address.isEmpty ? l10n.eventFieldUnset : address,
                  trailing: address.isEmpty
                      ? null
                      : AddressDirectionIconButton(
                          address: address,
                          label: member.fullName,
                        ),
                  isLast: true,
                ),
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
    required this.session,
    required this.title,
    required this.initialDraft,
    required this.branches,
    required this.members,
    required this.aiAssistService,
    required this.onSubmit,
    required this.isSaving,
  });

  final AuthSession session;
  final String title;
  final EventDraft initialDraft;
  final List<BranchProfile> branches;
  final List<MemberProfile> members;
  final AiAssistService aiAssistService;
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
  late final AiProductAnalyticsService _aiAnalyticsService;

  late EventType _selectedType;
  String? _selectedBranchId;
  String? _selectedTargetMemberId;
  late bool _isRecurring;
  late List<int> _reminderOffsets;
  int _step = 0;
  bool _isSubmitting = false;
  bool _isGeneratingAiCopy = false;

  EventValidationIssueCode? _validationIssue;
  EventRepositoryErrorCode? _submitError;
  EventAiSuggestion? _aiSuggestion;

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
    _aiAnalyticsService = createDefaultAiProductAnalyticsService();

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

  bool _validateStepZero() {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _validationIssue = EventValidationIssueCode.missingTitle;
      });
      return false;
    }
    if (_selectedType.isMemorial &&
        (_selectedTargetMemberId == null ||
            _selectedTargetMemberId!.trim().isEmpty)) {
      setState(() {
        _validationIssue =
            EventValidationIssueCode.memorialRequiresTargetMember;
      });
      return false;
    }
    return true;
  }

  bool _validateStepOne() {
    final startsAt = _parseDateTimeInput(_startsAtController.text.trim());
    if (startsAt == null) {
      setState(() {
        _validationIssue = EventValidationIssueCode.invalidTimeRange;
      });
      return false;
    }

    final endInput = _endsAtController.text.trim();
    if (endInput.isEmpty) {
      return true;
    }

    final endsAt = _parseDateTimeInput(endInput);
    if (endsAt == null || !endsAt.isAfter(startsAt)) {
      setState(() {
        _validationIssue = EventValidationIssueCode.invalidTimeRange;
      });
      return false;
    }
    return true;
  }

  EventDraft _buildDraft({
    required DateTime startsAt,
    required DateTime? endsAt,
  }) {
    return EventDraft(
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
      ritualKey: _selectedType.isMemorial
          ? widget.initialDraft.ritualKey
          : null,
      ritualPreset: _selectedType.isMemorial
          ? widget.initialDraft.ritualPreset
          : null,
      isAutoGenerated:
          _selectedType.isMemorial && widget.initialDraft.isAutoGenerated,
    );
  }

  bool get _canGenerateAiSuggestion {
    if (_isGeneratingAiCopy || _isSubmitting || widget.isSaving) {
      return false;
    }
    if (!_selectedType.isMemorial) {
      return true;
    }
    return (_selectedTargetMemberId?.trim().isNotEmpty ?? false);
  }

  Future<void> _suggestWithAi() async {
    if (!_canGenerateAiSuggestion) {
      return;
    }

    final locale = Localizations.localeOf(context).languageCode;
    final startsAt =
        _parseDateTimeInput(_startsAtController.text.trim()) ??
        widget.initialDraft.startsAt;
    final endInput = _endsAtController.text.trim();
    final endsAt = endInput.isEmpty ? null : _parseDateTimeInput(endInput);
    final draft = _buildDraft(startsAt: startsAt, endsAt: endsAt);
    final aiStopwatch = Stopwatch()..start();
    unawaited(
      _aiAnalyticsService.trackEventSuggestionRequested(
        eventType: draft.eventType.wireName,
        hasTitle: draft.title.trim().isNotEmpty,
        hasDescription: draft.description.trim().isNotEmpty,
        hasLocation:
            draft.locationName.trim().isNotEmpty ||
            draft.locationAddress.trim().isNotEmpty,
        hasTargetMember: (draft.targetMemberId ?? '').trim().isNotEmpty,
        hasSchedule: draft.startsAt.toString().trim().isNotEmpty,
      ),
    );

    setState(() {
      _isGeneratingAiCopy = true;
    });

    try {
      final suggestion = await widget.aiAssistService.draftEventCopy(
        session: widget.session,
        locale: locale,
        draft: draft,
      );
      aiStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        _aiAnalyticsService.trackEventSuggestionCompleted(
          eventType: draft.eventType.wireName,
          usedFallback: suggestion.usedFallback,
          hasTitleSuggestion: suggestion.title.trim().isNotEmpty,
          hasDescriptionSuggestion: suggestion.description.trim().isNotEmpty,
          reminderSuggestionCount:
              suggestion.recommendedReminderOffsetsMinutes.length,
          elapsedMs: aiStopwatch.elapsedMilliseconds,
        ),
      );
      setState(() {
        _aiSuggestion = suggestion;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Bản gợi ý đã sẵn sàng. Chọn từng phần bạn muốn áp dụng.',
              en: 'Suggestions are ready. Apply only the parts you want.',
            ),
          ),
        ),
      );
    } on AiAssistServiceException catch (error) {
      aiStopwatch.stop();
      if (!mounted) {
        return;
      }
      unawaited(
        _aiAnalyticsService.trackEventSuggestionFailed(
          eventType: draft.eventType.wireName,
          reason: error.code ?? 'unknown',
          elapsedMs: aiStopwatch.elapsedMilliseconds,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiCopy = false;
        });
      } else {
        _isGeneratingAiCopy = false;
      }
    }
  }

  void _applySuggestedTitle() {
    final suggestion = _aiSuggestion;
    if (suggestion == null || suggestion.title.trim().isEmpty) {
      return;
    }
    setState(() {
      _titleController.text = suggestion.title;
    });
    unawaited(
      _aiAnalyticsService.trackEventSuggestionApplied(
        eventType: _selectedType.wireName,
        section: 'title',
      ),
    );
  }

  void _applySuggestedDescription() {
    final suggestion = _aiSuggestion;
    if (suggestion == null || suggestion.description.trim().isEmpty) {
      return;
    }
    setState(() {
      _descriptionController.text = suggestion.description;
    });
    unawaited(
      _aiAnalyticsService.trackEventSuggestionApplied(
        eventType: _selectedType.wireName,
        section: 'description',
      ),
    );
  }

  void _applySuggestedText() {
    final suggestion = _aiSuggestion;
    if (suggestion == null) {
      return;
    }
    setState(() {
      if (suggestion.title.trim().isNotEmpty) {
        _titleController.text = suggestion.title;
      }
      if (suggestion.description.trim().isNotEmpty) {
        _descriptionController.text = suggestion.description;
      }
    });
    unawaited(
      _aiAnalyticsService.trackEventSuggestionApplied(
        eventType: _selectedType.wireName,
        section: 'text',
      ),
    );
  }

  void _applySuggestedReminders() {
    final suggestion = _aiSuggestion;
    if (suggestion == null ||
        suggestion.recommendedReminderOffsetsMinutes.isEmpty) {
      return;
    }
    setState(() {
      _reminderOffsets = EventValidation.sanitizeReminderOffsets(
        suggestion.recommendedReminderOffsetsMinutes,
      );
    });
    unawaited(
      _aiAnalyticsService.trackEventSuggestionApplied(
        eventType: _selectedType.wireName,
        section: 'reminders',
      ),
    );
  }

  void _openReminderReview() {
    if (!_validateStepZero()) {
      return;
    }
    if (!_validateStepOne()) {
      setState(() {
        _step = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Điền thời gian và địa điểm trước khi áp dụng mốc nhắc gợi ý.',
              en: 'Add the schedule first before applying suggested reminders.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _validationIssue = null;
      _submitError = null;
      _step = 2;
    });
  }

  void _moveToStep(int targetStep) {
    if (targetStep <= _step) {
      setState(() {
        _validationIssue = null;
        _submitError = null;
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
      _validationIssue = null;
      _submitError = null;
      _step = targetStep;
    });
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final existing = _parseDateTimeInput(controller.text.trim())?.toLocal();
    final now = DateTime.now();
    final initial = existing ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      controller.text = _formatDateTimeInput(selected);
    });
  }

  Future<void> _submitOrContinue() async {
    if (_isSubmitting || widget.isSaving) {
      return;
    }
    setState(() {
      _validationIssue = null;
      _submitError = null;
    });

    if (_step == 0) {
      if (_validateStepZero()) {
        setState(() => _step = 1);
      }
      return;
    }
    if (_step == 1) {
      if (_validateStepOne()) {
        setState(() => _step = 2);
      }
      return;
    }

    if (!_validateStepZero() || !_validateStepOne()) {
      return;
    }

    final startsAt = _parseDateTimeInput(_startsAtController.text.trim())!;
    final endInput = _endsAtController.text.trim();
    final endsAt = endInput.isEmpty ? null : _parseDateTimeInput(endInput);
    final draft = _buildDraft(startsAt: startsAt, endsAt: endsAt);
    final validation = EventValidation.validate(draft);
    if (!validation.isValid) {
      setState(() {
        _validationIssue = validation.issues.first.code;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final error = await widget.onSubmit(draft);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
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

  Widget _buildTextSuggestionCard(BuildContext context) {
    final suggestion = _aiSuggestion;
    if (suggestion == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hasTitleSuggestion = suggestion.title.trim().isNotEmpty;
    final hasDescriptionSuggestion = suggestion.description.trim().isNotEmpty;
    final hasReminderSuggestion =
        suggestion.recommendedReminderOffsetsMinutes.isNotEmpty;
    if (!hasTitleSuggestion &&
        !hasDescriptionSuggestion &&
        !hasReminderSuggestion &&
        suggestion.rationale.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceSurface(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Bản gợi ý mới', en: 'Suggested draft'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.usedFallback
                ? l10n.pick(
                    vi: 'Đang dùng chế độ gợi ý nội bộ để giữ kết quả ổn định.',
                    en: 'Using the built-in suggestion mode to keep the guidance stable.',
                  )
                : l10n.pick(
                    vi: 'Xem trước từng phần rồi áp dụng đúng chỗ bạn cần.',
                    en: 'Preview each part before applying it.',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasTitleSuggestion) ...[
            const SizedBox(height: 12),
            _EventSuggestionPreviewRow(
              label: l10n.pick(vi: 'Tiêu đề', en: 'Title'),
              value: suggestion.title,
            ),
          ],
          if (hasDescriptionSuggestion) ...[
            const SizedBox(height: 10),
            _EventSuggestionPreviewRow(
              label: l10n.pick(vi: 'Mô tả', en: 'Description'),
              value: suggestion.description,
            ),
          ],
          if (hasReminderSuggestion) ...[
            const SizedBox(height: 10),
            _EventSuggestionPreviewRow(
              label: l10n.pick(vi: 'Mốc nhắc gợi ý', en: 'Suggested reminders'),
              value: suggestion.recommendedReminderOffsetsMinutes
                  .map(_humanizeOffset)
                  .join(', '),
            ),
          ],
          if (suggestion.rationale.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in suggestion.rationale)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasTitleSuggestion)
                OutlinedButton(
                  key: const Key('event-ai-apply-title-button'),
                  onPressed: _applySuggestedTitle,
                  child: Text(
                    l10n.pick(vi: 'Áp dụng tiêu đề', en: 'Apply title'),
                  ),
                ),
              if (hasDescriptionSuggestion)
                OutlinedButton(
                  key: const Key('event-ai-apply-description-button'),
                  onPressed: _applySuggestedDescription,
                  child: Text(
                    l10n.pick(vi: 'Áp dụng mô tả', en: 'Apply description'),
                  ),
                ),
              if (hasTitleSuggestion || hasDescriptionSuggestion)
                FilledButton.tonal(
                  key: const Key('event-ai-apply-text-button'),
                  onPressed: _applySuggestedText,
                  child: Text(
                    l10n.pick(vi: 'Áp dụng phần chữ', en: 'Apply text'),
                  ),
                ),
              if (hasReminderSuggestion)
                FilledButton.tonalIcon(
                  key: const Key('event-ai-open-reminders-button'),
                  onPressed: _openReminderReview,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    l10n.pick(
                      vi: 'Xem mốc nhắc ở bước sau',
                      en: 'Review reminders next',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSuggestionCard(BuildContext context) {
    final suggestion = _aiSuggestion;
    if (suggestion == null ||
        suggestion.recommendedReminderOffsetsMinutes.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AppWorkspaceSurface(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(
              vi: 'Mốc nhắc gợi ý đã sẵn sàng',
              en: 'Suggested reminders are ready',
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final offset in suggestion.recommendedReminderOffsetsMinutes)
                Chip(label: Text(_humanizeOffset(offset))),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            key: const Key('event-ai-apply-reminders-button'),
            onPressed: _applySuggestedReminders,
            icon: const Icon(Icons.alarm_on_outlined),
            label: Text(
              l10n.pick(
                vi: 'Áp dụng mốc nhắc gợi ý',
                en: 'Apply suggested reminders',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errorText = _errorText();
    final theme = Theme.of(context);
    final isFinalStep = _step == 2;
    final isBusy = _isSubmitting || widget.isSaving;
    String branchLabel(String? branchId) {
      final normalized = (branchId ?? '').trim();
      if (normalized.isEmpty) {
        return '';
      }
      for (final branch in widget.branches) {
        if (branch.id == normalized) {
          return branch.name;
        }
      }
      return '';
    }

    String memberLabel(String? memberId) {
      final normalized = (memberId ?? '').trim();
      if (normalized.isEmpty) {
        return '';
      }
      for (final member in widget.members) {
        if (member.id == normalized) {
          return member.fullName;
        }
      }
      return '';
    }

    final branchSummary = branchLabel(_selectedBranchId);
    final targetSummary = memberLabel(_selectedTargetMemberId);
    final schedulePreview = _joinNonEmptyText([
      _startsAtController.text.trim(),
      _endsAtController.text.trim(),
    ]);
    final locationPreview = _joinNonEmptyText([
      _locationNameController.text.trim(),
      _locationAddressController.text.trim(),
    ]);
    final reminderPreview = _reminderOffsets.isEmpty
        ? l10n.pick(vi: 'Chưa thiết lập', en: 'Not set')
        : _reminderOffsets.map(_humanizeOffset).join(', ');
    final stepTitle = switch (_step) {
      0 => l10n.pick(vi: 'Thông tin chính', en: 'Core details'),
      1 => l10n.pick(vi: 'Thời gian và địa điểm', en: 'Schedule and place'),
      _ => l10n.pick(vi: 'Nhắc lịch và xem lại', en: 'Reminders and review'),
    };
    final stepDescription = switch (_step) {
      0 => l10n.pick(
        vi: 'Điền phần tối thiểu để người khác hiểu đây là sự kiện gì và dành cho ai.',
        en: 'Capture the minimum details so others can immediately understand the event.',
      ),
      1 => l10n.pick(
        vi: 'Chốt thời gian và địa điểm trước, rồi mới nghĩ đến nhắc lịch.',
        en: 'Lock the date, time, and place before moving to reminders.',
      ),
      _ => l10n.pick(
        vi: 'Chỉ giữ các mốc nhắc thật cần thiết rồi kiểm tra nhanh trước khi lưu.',
        en: 'Keep only the reminders you need, then do a quick review before saving.',
      ),
    };

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
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppWorkspaceSurface(
                  gradient: appWorkspaceHeroGradient(context),
                  showAccentOrbs: true,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.pick(
                          vi: 'Điền từng phần ngắn để không bị rối khi tạo hoặc cập nhật sự kiện.',
                          en: 'Complete one short section at a time to keep event setup clear.',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ContextBadge(
                            icon: Icons.event_note_outlined,
                            label: l10n.eventTypeLabel(_selectedType),
                          ),
                          if (branchSummary.isNotEmpty)
                            _ContextBadge(
                              icon: Icons.account_tree_outlined,
                              label: branchSummary,
                            ),
                          if (targetSummary.isNotEmpty)
                            _ContextBadge(
                              icon: Icons.person_outline,
                              label: targetSummary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppWorkspaceSurface(
                  padding: const EdgeInsets.all(12),
                  child: _EventEditorStepIndicator(
                    currentStep: _step,
                    labels: [
                      l10n.pick(vi: 'Thông tin', en: 'Info'),
                      l10n.pick(vi: 'Thời gian', en: 'Schedule'),
                      l10n.pick(vi: 'Nhắc lịch', en: 'Reminders'),
                    ],
                    onStepSelected: (step) => _moveToStep(step),
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
                AppWorkspaceSurface(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EditorSectionLead(
                        title: stepTitle,
                        description: stepDescription,
                      ),
                      if (_step == 0) ...[
                        AppWorkspaceSurface(
                          color: theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Gợi ý nội dung nhanh',
                                  en: 'Quick content suggestions',
                                ),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.pick(
                                  vi: 'Tạo bản nháp tiêu đề và mô tả theo loại sự kiện hiện tại. Mốc nhắc chỉ được áp dụng khi bạn xác nhận ở bước nhắc lịch.',
                                  en: 'Generate a first-draft title and description for this event type. Reminder suggestions are only applied after you confirm them in the reminder step.',
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.pick(
                                  vi: 'AI chỉ dùng dữ liệu sự kiện hiện tại để tạo gợi ý. Bạn vẫn cần xem lại trước khi áp dụng.',
                                  en: 'AI only uses the current event details to draft suggestions. Review each suggestion before applying it.',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  key: const Key('event-ai-suggest-button'),
                                  onPressed: _canGenerateAiSuggestion
                                      ? _suggestWithAi
                                      : null,
                                  icon: _isGeneratingAiCopy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome_outlined),
                                  label: Text(
                                    _isGeneratingAiCopy
                                        ? l10n.pick(
                                            vi: 'Đang gợi ý...',
                                            en: 'Generating...',
                                          )
                                        : l10n.pick(
                                            vi: 'Tạo bản nháp gợi ý',
                                            en: 'Generate suggestions',
                                          ),
                                  ),
                                ),
                              ),
                              if (_isGeneratingAiCopy) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.pick(
                                    vi: 'Đang tạo gợi ý, thường mất vài giây.',
                                    en: 'Generating suggestions. This usually takes a few seconds.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (_selectedType.isMemorial &&
                                  (_selectedTargetMemberId?.trim().isEmpty ??
                                      true)) ...[
                                const SizedBox(height: 10),
                                Text(
                                  l10n.pick(
                                    vi: 'Chọn người được tưởng niệm trước để gợi ý bám đúng ngữ cảnh.',
                                    en: 'Select the memorial member first so the suggestion stays specific.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (_aiSuggestion != null) ...[
                                const SizedBox(height: 10),
                                _buildTextSuggestionCard(context),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          key: Key(
                            'event-type-dropdown-${_selectedType.wireName}',
                          ),
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
                                ? Text(
                                    l10n.pick(
                                      vi: 'Lặp lại hằng năm',
                                      en: 'Repeats yearly',
                                    ),
                                  )
                                : Text(l10n.eventRecurringNo),
                            onChanged: (value) {
                              setState(() {
                                _isRecurring = value;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('event-description-field'),
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l10n.eventFormDescriptionLabel,
                          ),
                        ),
                      ],
                      if (_step == 1) ...[
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
                                  suffixIcon: IconButton(
                                    tooltip: l10n.pick(
                                      vi: 'Chọn thời gian bắt đầu',
                                      en: 'Pick start date and time',
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () => _pickDateTime(
                                            _startsAtController,
                                          ),
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
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
                                  suffixIcon: IconButton(
                                    tooltip: l10n.pick(
                                      vi: 'Chọn thời gian kết thúc',
                                      en: 'Pick end date and time',
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () =>
                                              _pickDateTime(_endsAtController),
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
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
                        AddressAutocompleteField(
                          controller: _locationAddressController,
                          textInputAction: TextInputAction.next,
                          labelText: l10n.eventFormLocationAddressLabel,
                          hintText: l10n.pick(
                            vi: 'Số nhà, đường, phường/xã, quận/huyện...',
                            en: 'Street, ward, district...',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        AppWorkspaceSurface(
                          color: theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(vi: 'Xem nhanh', en: 'Quick check'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Lịch diễn ra',
                                  en: 'Schedule',
                                ),
                                value: schedulePreview.isEmpty
                                    ? l10n.eventFieldUnset
                                    : schedulePreview,
                              ),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Địa điểm',
                                  en: 'Location',
                                ),
                                value: locationPreview.isEmpty
                                    ? l10n.eventFieldUnset
                                    : locationPreview,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_step == 2) ...[
                        Text(
                          l10n.eventFormReminderSectionTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.pick(
                            vi: 'Giữ ít mốc nhắc nhưng đủ để không bỏ sót việc quan trọng.',
                            en: 'Keep reminders focused so important follow-ups are not missed.',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_aiSuggestion != null &&
                            _aiSuggestion!
                                .recommendedReminderOffsetsMinutes
                                .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildReminderSuggestionCard(context),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 14),
                        AppWorkspaceSurface(
                          color: theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Tóm tắt trước khi lưu',
                                  en: 'Review before saving',
                                ),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SummaryRow(
                                label: l10n.eventFieldType,
                                value: l10n.eventTypeLabel(_selectedType),
                              ),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Chi hoặc người liên quan',
                                  en: 'Branch or related member',
                                ),
                                value:
                                    _joinNonEmptyText([
                                      branchSummary,
                                      targetSummary,
                                    ]).isEmpty
                                    ? l10n.eventFieldUnset
                                    : _joinNonEmptyText([
                                        branchSummary,
                                        targetSummary,
                                      ]),
                              ),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Lịch diễn ra',
                                  en: 'Schedule',
                                ),
                                value: schedulePreview.isEmpty
                                    ? l10n.eventFieldUnset
                                    : schedulePreview,
                              ),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Địa điểm',
                                  en: 'Location',
                                ),
                                value: locationPreview.isEmpty
                                    ? l10n.eventFieldUnset
                                    : locationPreview,
                              ),
                              _SummaryRow(
                                label: l10n.pick(
                                  vi: 'Nhắc trước',
                                  en: 'Reminders',
                                ),
                                value: reminderPreview,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : _step == 0
                            ? () => Navigator.of(context).pop()
                            : () {
                                setState(() {
                                  _validationIssue = null;
                                  _submitError = null;
                                  _step -= 1;
                                });
                              },
                        icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back),
                        label: Text(
                          _step == 0
                              ? l10n.profileCancelAction
                              : l10n.pick(vi: 'Quay lại', en: 'Back'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('event-save-button'),
                        onPressed: isBusy ? null : _submitOrContinue,
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isFinalStep
                                    ? Icons.save_outlined
                                    : Icons.arrow_forward,
                              ),
                        label: Text(
                          isFinalStep
                              ? l10n.eventFormSaveAction
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
      ),
    );
  }
}

class _EventEditorStepIndicator extends StatelessWidget {
  const _EventEditorStepIndicator({
    required this.currentStep,
    required this.labels,
    required this.onStepSelected,
  });

  final int currentStep;
  final List<String> labels;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const circleSize = 32.0;
    const connectorThickness = 3.0;
    const connectorHorizontalInset = 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (labels.length > 1)
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var index = 0; index < labels.length - 1; index++)
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: connectorThickness,
                              margin: const EdgeInsets.symmetric(
                                horizontal: connectorHorizontalInset,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: index < currentStep
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Expanded(
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: Key('event-editor-step-${index + 1}-circle'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onStepSelected(index),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: circleSize,
                                height: circleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index <= currentStep
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: index <= currentStep
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('event-editor-step-${index + 1}-label'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onStepSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: index == currentStep
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

enum _MemorialChecklistCategory { prayer, year1, year2, anniversary }

enum _ChecklistEntryStatus { configured, missing, mismatch }

class _MemorialChecklistEntry {
  const _MemorialChecklistEntry({
    required this.id,
    required this.category,
    required this.member,
    required this.branchName,
    required this.deathDate,
    required this.expectedAt,
    required this.title,
    required this.status,
    required this.configuredEvent,
    required this.onQuickSetup,
    required this.onOpenEvent,
  });

  final String id;
  final _MemorialChecklistCategory category;
  final MemberProfile member;
  final String branchName;
  final DateTime deathDate;
  final DateTime expectedAt;
  final String title;
  final _ChecklistEntryStatus status;
  final EventRecord? configuredEvent;
  final Future<void> Function()? onQuickSetup;
  final VoidCallback? onOpenEvent;
}

class _MemorialQuickAccessCard extends StatelessWidget {
  const _MemorialQuickAccessCard({
    required this.prayerPendingCount,
    required this.year1PendingCount,
    required this.year2PendingCount,
    required this.annualMemorialPendingCount,
    required this.onOpenPrayer,
    required this.onOpenYear1,
    required this.onOpenYear2,
    required this.onOpenAnniversary,
  });

  final int prayerPendingCount;
  final int year1PendingCount;
  final int year2PendingCount;
  final int annualMemorialPendingCount;
  final Future<void> Function() onOpenPrayer;
  final Future<void> Function() onOpenYear1;
  final Future<void> Function() onOpenYear2;
  final Future<void> Function() onOpenAnniversary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      (
        key: 'event-memorial-access-prayer',
        icon: Icons.self_improvement_outlined,
        title: l10n.pick(
          vi: 'Lễ tiết cầu siêu (49/100 ngày)',
          en: 'Prayer rituals (49/100 days)',
        ),
        pendingCount: prayerPendingCount,
        onTap: onOpenPrayer,
      ),
      (
        key: 'event-memorial-access-year1',
        icon: Icons.looks_one_outlined,
        title: l10n.pick(vi: 'Lễ Tiểu Tường (1 năm)', en: 'First-year ritual'),
        pendingCount: year1PendingCount,
        onTap: onOpenYear1,
      ),
      (
        key: 'event-memorial-access-year2',
        icon: Icons.looks_two_outlined,
        title: l10n.pick(vi: 'Lễ Đại Tường (2 năm)', en: 'Second-year ritual'),
        pendingCount: year2PendingCount,
        onTap: onOpenYear2,
      ),
      (
        key: 'event-memorial-access-anniversary',
        icon: Icons.history_edu_outlined,
        title: l10n.pick(
          vi: 'Giỗ Kỵ (từ 3 năm trở đi)',
          en: 'Yearly memorial (from year 3)',
        ),
        pendingCount: annualMemorialPendingCount,
        onTap: onOpenAnniversary,
      ),
    ];

    return AppWorkspaceSurface(
      key: const Key('event-memorial-quick-access-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Truy cập nhanh', en: 'Quick access'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.pick(
              vi: 'Thiết lập nhanh các mốc giỗ và cầu siêu đang thiếu.',
              en: 'Quick setup for missing memorial and prayer milestones.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isTwoColumns = maxWidth >= 700;
              final tileWidth = isTwoColumns ? (maxWidth - 12) / 2 : maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: tileWidth,
                      child: AppAsyncAction(
                        onPressed: action.onTap,
                        builder: (context, onPressed, isLoading) {
                          return OutlinedButton(
                            key: Key(action.key),
                            onPressed: onPressed,
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              children: [
                                isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(action.icon, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    action.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text('${action.pendingCount}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_outlined),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemorialChecklistCenterPage extends StatefulWidget {
  const _MemorialChecklistCenterPage({
    required this.entries,
    required this.initialCategory,
  });

  final List<_MemorialChecklistEntry> entries;
  final _MemorialChecklistCategory initialCategory;

  @override
  State<_MemorialChecklistCenterPage> createState() =>
      _MemorialChecklistCenterPageState();
}

class _MemorialChecklistCenterPageState
    extends State<_MemorialChecklistCenterPage> {
  late _MemorialChecklistCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedEntries =
        widget.entries
            .where((entry) => entry.category == _selectedCategory)
            .toList(growable: false)
          ..sort((left, right) {
            final byDate = left.expectedAt.compareTo(right.expectedAt);
            if (byDate != 0) {
              return byDate;
            }
            return left.member.fullName.toLowerCase().compareTo(
              right.member.fullName.toLowerCase(),
            );
          });
    final configuredCount = selectedEntries
        .where((entry) => entry.status == _ChecklistEntryStatus.configured)
        .length;
    final pendingCount = selectedEntries
        .where((entry) => entry.status != _ChecklistEntryStatus.configured)
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(_categoryTitle(_selectedCategory, l10n))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            l10n.pick(
              vi: '${selectedEntries.length} mục • $configuredCount đã thiết lập • $pendingCount cần xử lý',
              en: '${selectedEntries.length} items • $configuredCount configured • $pendingCount need action',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _MemorialChecklistCategory.values)
                ChoiceChip(
                  key: Key('event-memorial-category-${category.name}'),
                  label: Text(_categoryChipLabel(category, l10n)),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    if (!selected) {
                      return;
                    }
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedEntries.isEmpty)
            _WorkspaceEmptyState(
              icon: Icons.inbox_outlined,
              title: l10n.pick(
                vi: 'Chưa có dữ liệu cho nhóm này',
                en: 'No entries for this category',
              ),
              description: l10n.pick(
                vi: 'Hệ thống chưa ghi nhận thành viên cần thiết lập nghi lễ ở nhóm đang chọn.',
                en: 'No members need setup in this category yet.',
              ),
            )
          else
            Column(
              children: [
                for (
                  var index = 0;
                  index < selectedEntries.length;
                  index++
                ) ...[
                  _MemorialChecklistEntryTile(entry: selectedEntries[index]),
                  if (index != selectedEntries.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _categoryTitle(
    _MemorialChecklistCategory category,
    AppLocalizations l10n,
  ) {
    return switch (category) {
      _MemorialChecklistCategory.prayer => l10n.pick(
        vi: 'Lễ tiết cầu siêu (49/100 ngày)',
        en: 'Prayer rituals (49/100 days)',
      ),
      _MemorialChecklistCategory.year1 => l10n.pick(
        vi: 'Lễ Tiểu Tường (1 năm)',
        en: 'First-year ritual',
      ),
      _MemorialChecklistCategory.year2 => l10n.pick(
        vi: 'Lễ Đại Tường (2 năm)',
        en: 'Second-year ritual',
      ),
      _MemorialChecklistCategory.anniversary => l10n.pick(
        vi: 'Giỗ Kỵ (từ 3 năm trở đi)',
        en: 'Yearly memorial (from year 3)',
      ),
    };
  }

  String _categoryChipLabel(
    _MemorialChecklistCategory category,
    AppLocalizations l10n,
  ) {
    return switch (category) {
      _MemorialChecklistCategory.prayer => l10n.pick(
        vi: '49/100 ngày',
        en: '49/100 days',
      ),
      _MemorialChecklistCategory.year1 => l10n.pick(
        vi: 'Tiểu tường',
        en: 'Year 1',
      ),
      _MemorialChecklistCategory.year2 => l10n.pick(
        vi: 'Đại tường',
        en: 'Year 2',
      ),
      _MemorialChecklistCategory.anniversary => l10n.pick(
        vi: 'Giỗ kỵ',
        en: 'Yearly memorial',
      ),
    };
  }
}

class _MemorialChecklistEntryTile extends StatelessWidget {
  const _MemorialChecklistEntryTile({required this.entry});

  final _MemorialChecklistEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = switch (entry.status) {
      _ChecklistEntryStatus.configured => (
        label: l10n.pick(vi: 'Đã thiết lập', en: 'Configured'),
        color: colorScheme.secondaryContainer,
        icon: Icons.check_circle_outline,
      ),
      _ChecklistEntryStatus.missing => (
        label: l10n.pick(vi: 'Chưa thiết lập', en: 'Not set'),
        color: colorScheme.errorContainer,
        icon: Icons.pending_outlined,
      ),
      _ChecklistEntryStatus.mismatch => (
        label: l10n.pick(vi: 'Cần kiểm tra', en: 'Needs review'),
        color: colorScheme.tertiaryContainer,
        icon: Icons.warning_amber_outlined,
      ),
    };

    return Padding(
      key: Key('event-memorial-entry-${entry.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.member.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(entry.title, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(status.icon, size: 15),
                side: BorderSide.none,
                backgroundColor: status.color,
                visualDensity: VisualDensity.compact,
                label: Text(status.label),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pick(
              vi: 'Ngày dự kiến: ${_formatDateInput(entry.expectedAt)} • Ngày mất: ${_formatDateInput(entry.deathDate)}',
              en: 'Expected date: ${_formatDateInput(entry.expectedAt)} • Death date: ${_formatDateInput(entry.deathDate)}',
            ),
            style: theme.textTheme.bodySmall,
          ),
          if (entry.branchName.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${l10n.eventFieldBranch}: ${entry.branchName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (entry.configuredEvent != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.pick(
                vi: 'Sự kiện hiện có: ${_formatDateInput(entry.configuredEvent!.startsAt.toLocal())}',
                en: 'Existing event date: ${_formatDateInput(entry.configuredEvent!.startsAt.toLocal())}',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (entry.onQuickSetup != null || entry.onOpenEvent != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.onQuickSetup != null)
                  AppAsyncAction(
                    onPressed: entry.onQuickSetup!,
                    builder: (context, onPressed, isLoading) {
                      return FilledButton.tonalIcon(
                        key: Key(
                          'event-memorial-entry-quick-setup-${entry.id}',
                        ),
                        onPressed: onPressed,
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high_outlined),
                        label: Text(
                          l10n.pick(vi: 'Thiết lập nhanh', en: 'Quick setup'),
                        ),
                      );
                    },
                  ),
                if (entry.onOpenEvent != null)
                  TextButton.icon(
                    key: Key('event-memorial-entry-open-${entry.id}'),
                    onPressed: entry.onOpenEvent,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: Text(l10n.pick(vi: 'Mở sự kiện', en: 'Open event')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.selectedType,
    required this.totalEventCount,
    required this.filteredEventCount,
    required this.upcomingCount,
    required this.memorialCount,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final EventType? selectedType;
  final int totalEventCount;
  final int filteredEventCount;
  final int upcomingCount;
  final int memorialCount;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventType?> onTypeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasActiveFilters =
        searchController.text.trim().isNotEmpty || selectedType != null;
    final summaryText = hasActiveFilters
        ? l10n.pick(
            vi: '$filteredEventCount / $totalEventCount sự kiện',
            en: '$filteredEventCount of $totalEventCount events',
          )
        : l10n.pick(
            vi: '$totalEventCount sự kiện • $upcomingCount sắp diễn ra • $memorialCount ngày giỗ',
            en: '$totalEventCount events • $upcomingCount upcoming • $memorialCount memorials',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.pick(
              vi: 'Tìm tên sự kiện, địa điểm hoặc người liên quan',
              en: 'Search title, place, or related member',
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.eventFilterClearAction,
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
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
            if (hasActiveFilters) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all_outlined),
                label: Text(l10n.eventFilterClearAction),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          summaryText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EventGroupBucket {
  const _EventGroupBucket({required this.label, required this.events});

  final String label;
  final List<EventRecord> events;
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    super.key,
    required this.event,
    required this.displayStartsAt,
    required this.displayEndsAt,
    required this.branchName,
    required this.targetMemberName,
    this.onTap,
  });

  final EventRecord event;
  final DateTime displayStartsAt;
  final DateTime? displayEndsAt;
  final String branchName;
  final String targetMemberName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final scheduleSummary = _formatEventScheduleSummary(
      displayStartsAt,
      displayEndsAt,
    );
    final audienceSummary = _joinNonEmptyText([branchName, targetMemberName]);
    final locationSummary = _joinNonEmptyText([
      event.locationName.trim(),
      event.locationAddress.trim(),
    ]);

    return AppWorkspaceSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                const SizedBox(height: 8),
                _CardInfoRow(
                  icon: Icons.schedule_outlined,
                  text: scheduleSummary,
                ),
                if (audienceSummary.isNotEmpty)
                  _CardInfoRow(
                    icon: Icons.account_tree_outlined,
                    text: audienceSummary,
                  ),
                if (locationSummary.isNotEmpty)
                  _CardInfoRow(
                    icon: Icons.place_outlined,
                    text: locationSummary,
                    trailing: event.locationAddress.trim().isEmpty
                        ? null
                        : AddressDirectionIconButton(
                            address: event.locationAddress.trim(),
                            iconSize: 18,
                          ),
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
      ),
    );
  }
}

class _CardInfoRow extends StatelessWidget {
  const _CardInfoRow({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceSurface(
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
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailOverviewRow extends StatelessWidget {
  const _DetailOverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _EditorSectionLead extends StatelessWidget {
  const _EditorSectionLead({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    return AppWorkspaceSurface(
      color: tone,
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSuggestionPreviewRow extends StatelessWidget {
  const _EventSuggestionPreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.trailing,
  });

  final String label;
  final String value;
  final bool isLast;
  final Widget? trailing;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventWorkspaceMemberRepositoryAdapter implements MemberRepository {
  const _EventWorkspaceMemberRepositoryAdapter({
    required this.members,
    required this.branches,
  });

  final List<MemberProfile> members;
  final List<BranchProfile> branches;

  @override
  bool get isSandbox => true;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    return MemberWorkspaceSnapshot(
      members: List<MemberProfile>.from(members),
      branches: List<BranchProfile>.from(branches),
    );
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) {
    throw const MemberRepositoryException(
      MemberRepositoryErrorCode.permissionDenied,
      'Member update is not available in event create flow.',
    );
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    throw const MemberRepositoryException(
      MemberRepositoryErrorCode.permissionDenied,
      'Avatar upload is not available in event create flow.',
    );
  }

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    throw const MemberRepositoryException(
      MemberRepositoryErrorCode.permissionDenied,
      'Location update is not available in event create flow.',
    );
  }

  @override
  Future<void> notifyNearbyRelativesDetected({
    required AuthSession session,
    required String clanId,
    required String memberId,
    required List<String> relativeMemberIds,
    double? closestDistanceKm,
  }) {
    throw const MemberRepositoryException(
      MemberRepositoryErrorCode.permissionDenied,
      'Nearby relative notification is not available in event create flow.',
    );
  }
}

String _ritualMilestoneLabel(
  AppLocalizations l10n,
  MemorialRitualMilestoneType type,
) {
  return switch (type) {
    MemorialRitualMilestoneType.first49Days => l10n.eventRitualMilestone49Days,
    MemorialRitualMilestoneType.first50Days => l10n.eventRitualMilestone50Days,
    MemorialRitualMilestoneType.day100 => l10n.eventRitualMilestone100Days,
    MemorialRitualMilestoneType.year1 => l10n.eventRitualMilestone1Year,
    MemorialRitualMilestoneType.year2 => l10n.eventRitualMilestone2Year,
  };
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

String _joinNonEmptyText(List<String?> values) {
  return values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' • ');
}

String _formatEventScheduleSummary(DateTime start, DateTime? end) {
  final startText = _formatDateTimeInput(start);
  if (end == null) {
    return startText;
  }
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    final endHour = end.hour.toString().padLeft(2, '0');
    final endMinute = end.minute.toString().padLeft(2, '0');
    return '$startText - $endHour:$endMinute';
  }
  return '$startText -> ${_formatDateTimeInput(end)}';
}

String _formatDateInput(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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
