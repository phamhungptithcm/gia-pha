import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_member_access_mode.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../events/models/event_type.dart';
import '../../member/models/member_profile.dart';
import '../../member/services/member_repository.dart';
import '../models/calendar_date_mode.dart';
import '../models/calendar_display_mode.dart';
import '../models/dual_calendar_event.dart';
import '../models/event_notification_audience.dart';
import '../models/lunar_date.dart';
import '../models/lunar_recurrence_policy.dart';
import '../services/calendar_settings_store.dart';
import '../services/dual_calendar_event_store.dart';
import '../services/local_lunar_conversion_engine.dart';
import '../services/lunar_conversion_cache.dart';
import '../services/lunar_holiday_repository.dart';
import '../services/lunar_recurrence_resolver.dart';
import '../services/lunar_reminder_scheduler.dart';
import '../services/lunar_resolution_cache.dart';
import 'dual_calendar_controller.dart';

class DualCalendarWorkspacePage extends StatefulWidget {
  const DualCalendarWorkspacePage({
    super.key,
    this.session,
    this.controller,
    this.eventStore,
    this.holidayRepository,
    this.settingsStore,
    this.memberRepository,
  });

  final AuthSession? session;
  final DualCalendarController? controller;
  final DualCalendarEventStore? eventStore;
  final LunarHolidayRepository? holidayRepository;
  final CalendarSettingsStore? settingsStore;
  final MemberRepository? memberRepository;

  @override
  State<DualCalendarWorkspacePage> createState() =>
      _DualCalendarWorkspacePageState();
}

class _DualCalendarWorkspacePageState extends State<DualCalendarWorkspacePage> {
  late final DualCalendarController _controller;
  late final bool _ownsController;
  late final MemberRepository _memberRepository;
  List<MemberProfile> _members = const [];
  List<BranchProfile> _branches = const [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _memberRepository =
        widget.memberRepository ??
        createDefaultMemberRepository(session: widget.session);
    _controller = widget.controller ?? _buildDefaultController();
    unawaited(_controller.initialize());
    unawaited(_loadRecipientsDirectory());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            key: const Key('calendar-add-event-button'),
            onPressed: _controller.isSaving ? null : _openCreateEventSheet,
            tooltip: l10n.pick(vi: 'Tạo sự kiện', en: 'Create event'),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải lịch song song...',
                      en: 'Loading dual calendar...',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refreshAll,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      children: [
                        if (_controller.errorMessage case final message?) ...[
                          _InfoBanner(
                            icon: Icons.error_outline,
                            title: l10n.pick(
                              vi: 'Lỗi đồng bộ lịch',
                              en: 'Calendar sync issue',
                            ),
                            description: message,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _controller.refreshAll,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                l10n.pick(vi: 'Thử lại', en: 'Retry'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _SettingsCard(
                          controller: _controller,
                          onCreateEvent: _openCreateEventSheet,
                        ),
                        const SizedBox(height: 16),
                        _MonthHeader(
                          label: _monthHeaderLabel(
                            focusedMonth: _controller.focusedMonth,
                            displayMode: _controller.displayMode,
                            monthLunarMap: _controller.monthLunarMap,
                            l10n: l10n,
                          ),
                          onPreviousMonth: _controller.goToPreviousMonth,
                          onNextMonth: _controller.goToNextMonth,
                          onPickMonthYear: _openMonthYearPicker,
                          onToday: () {
                            final now = DateTime.now();
                            _controller.jumpToMonth(now);
                            _controller.selectDay(now);
                          },
                        ),
                        const SizedBox(height: 12),
                        _MonthGrid(
                          controller: _controller,
                          onSelectDay: _controller.selectDay,
                          onJumpToMonth: _controller.jumpToMonth,
                        ),
                        const SizedBox(height: 16),
                        _SelectedDayPanel(
                          controller: _controller,
                          onEditEvent: _openEditEventSheet,
                          onDeleteEvent: _deleteEvent,
                        ),
                        const SizedBox(height: 16),
                        _ReminderPanel(controller: _controller),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateEventSheet() async {
    await _loadRecipientsDirectory();
    if (!mounted) {
      return;
    }
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventEditorSheet(
          controller: _controller,
          initialDate: _controller.selectedDay,
          members: _members,
          branches: _branches,
          isRecipientsLoading: _isLoadingMembers,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Đã lưu sự kiện thành công.',
              en: 'Event saved successfully.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openEditEventSheet(DualCalendarEvent event) async {
    await _loadRecipientsDirectory();
    if (!mounted) {
      return;
    }
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventEditorSheet(
          controller: _controller,
          initialDate: _controller.selectedDay,
          editingEvent: event,
          members: _members,
          branches: _branches,
          isRecipientsLoading: _isLoadingMembers,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Đã cập nhật sự kiện thành công.',
              en: 'Event updated successfully.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _deleteEvent(DualCalendarEvent event) async {
    final l10n = context.l10n;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.pick(vi: 'Xóa sự kiện?', en: 'Delete event?')),
          content: Text(
            l10n.pick(
              vi: 'Gỡ "${event.title}" khỏi lịch của bạn?',
              en: 'Remove "${event.title}" from your calendar?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pick(vi: 'Xóa', en: 'Delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _controller.deleteEvent(event.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pick(vi: 'Đã xóa sự kiện.', en: 'Event deleted.'),
        ),
      ),
    );
  }

  Future<void> _openMonthYearPicker() async {
    final l10n = context.l10n;
    final isLunarView =
        _controller.displayMode == CalendarDisplayMode.lunarOnly;
    final anchorLunarDate = _anchorLunarDateForMonth(_controller.monthLunarMap);
    final initialYear = isLunarView
        ? (anchorLunarDate?.year ?? _controller.focusedMonth.year)
        : _controller.focusedMonth.year;
    final initialMonth = isLunarView
        ? (anchorLunarDate?.month ?? _controller.focusedMonth.month)
        : _controller.focusedMonth.month;

    final selection = await showModalBottomSheet<_MonthYearSelection>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MonthYearPickerSheet(
        initialYear: initialYear,
        initialMonth: initialMonth,
      ),
    );
    if (selection == null) {
      return;
    }

    if (isLunarView) {
      final resolved = await _controller.resolveLunarToSolar(
        lunarDate: LunarDate(
          year: selection.year,
          month: selection.month,
          day: 1,
        ),
        policy: LunarRecurrencePolicy.firstOccurrence,
        targetYear: selection.year,
      );
      if (resolved == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: 'Không thể mở tháng đã chọn. Hãy thử tháng khác.',
                en: 'Unable to open the selected month. Try another month.',
              ),
            ),
          ),
        );
        return;
      }
      await _controller.jumpToMonth(DateTime(resolved.year, resolved.month));
      _controller.selectDay(resolved);
      return;
    }

    final targetMonth = DateTime(selection.year, selection.month);
    await _controller.jumpToMonth(targetMonth);
    _controller.selectDay(targetMonth);
  }

  DualCalendarController _buildDefaultController() {
    final conversionCache = LunarConversionCache();
    final resolutionCache = LunarResolutionCache();
    final conversionEngine = LocalLunarConversionEngine(cache: conversionCache);
    return DualCalendarController(
      eventStore: widget.eventStore ?? createDefaultDualCalendarEventStore(),
      conversionEngine: conversionEngine,
      holidayRepository:
          widget.holidayRepository ?? createDefaultLunarHolidayRepository(),
      recurrenceResolver: LunarRecurrenceResolver(
        conversionEngine: conversionEngine,
        cache: resolutionCache,
      ),
      reminderScheduler: LunarReminderScheduler(),
      settingsStore:
          widget.settingsStore ?? createDefaultCalendarSettingsStore(),
      conversionCache: conversionCache,
      resolutionCache: resolutionCache,
    );
  }

  Future<void> _loadRecipientsDirectory() async {
    final session = widget.session;
    if (session == null ||
        session.accessMode != AuthMemberAccessMode.claimed ||
        (session.clanId ?? '').trim().isEmpty) {
      if (_members.isNotEmpty || _branches.isNotEmpty) {
        setState(() {
          _members = const [];
          _branches = const [];
        });
      }
      return;
    }

    if (_isLoadingMembers) {
      return;
    }

    _isLoadingMembers = true;
    try {
      final snapshot = await _memberRepository.loadWorkspace(session: session);
      if (!mounted) {
        return;
      }
      setState(() {
        _members = snapshot.members;
        _branches = snapshot.branches;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _members = const [];
        _branches = const [];
      });
    } finally {
      _isLoadingMembers = false;
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.controller, required this.onCreateEvent});

  final DualCalendarController controller;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = theme.textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final l10n = context.l10n;
    const displayModes = <CalendarDisplayMode>[
      CalendarDisplayMode.dual,
      CalendarDisplayMode.lunarOnly,
    ];
    final selectedMode = displayModes.contains(controller.displayMode)
        ? controller.displayMode
        : CalendarDisplayMode.dual;

    final displayModePicker = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<CalendarDisplayMode>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            side: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline,
                width: 1.1,
              );
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.surface;
              }
              return colorScheme.surface.withValues(alpha: 0.58);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant;
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          segments: [
            for (final mode in displayModes)
              ButtonSegment<CalendarDisplayMode>(
                value: mode,
                label: Text(l10n.calendarDisplayModeLabel(mode)),
              ),
          ],
          selected: {selectedMode},
          onSelectionChanged: (selection) {
            final mode = selection.firstOrNull;
            if (mode == null) {
              return;
            }
            controller.setDisplayMode(mode);
          },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.95),
            colorScheme.tertiaryContainer.withValues(alpha: 0.92),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                foregroundColor: colorScheme.primary,
                child: const Icon(Icons.calendar_month_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.pick(vi: 'Lịch song song', en: 'Dual calendar'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pick(
              vi: 'Theo dõi ngày dương và âm trong cùng một nơi. Chạm vào ngày để xem chi tiết và lời nhắc.',
              en: 'Track solar and lunar dates in one place. Tap a day to view details and reminders.',
            ),
            style: textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640 || textScale > 1.1;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    displayModePicker,
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onCreateEvent,
                      icon: const Icon(Icons.add),
                      label: Text(
                        l10n.pick(vi: 'Tạo sự kiện', en: 'Create event'),
                      ),
                    ),
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  displayModePicker,
                  OutlinedButton.icon(
                    onPressed: onCreateEvent,
                    icon: const Icon(Icons.add),
                    label: Text(
                      l10n.pick(vi: 'Tạo sự kiện', en: 'Create event'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendChip(
                icon: Icons.today,
                label: l10n.pick(vi: 'Hôm nay', en: 'Today'),
              ),
              _LegendChip(
                icon: Icons.celebration_outlined,
                label: l10n.pick(vi: 'Ngày lễ', en: 'Holiday'),
              ),
              _LegendChip(
                icon: Icons.event_note_outlined,
                label: l10n.pick(vi: 'Có sự kiện', en: 'Has event'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonthYear,
    required this.onToday,
  });

  final String label;
  final Future<void> Function() onPreviousMonth;
  final Future<void> Function() onNextMonth;
  final Future<void> Function() onPickMonthYear;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 470 || textScale > 1.15;

        final monthTitle = Tooltip(
          message: l10n.pick(
            vi: 'Chạm để đổi nhanh tháng và năm',
            en: 'Tap to quickly change month and year',
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => unawaited(onPickMonthYear()),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.unfold_more_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              Row(
                children: [
                  _MonthNavButton(
                    tooltip: l10n.pick(vi: 'Tháng trước', en: 'Previous month'),
                    icon: Icons.chevron_left,
                    onPressed: () => unawaited(onPreviousMonth()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: monthTitle),
                  const SizedBox(width: 8),
                  _MonthNavButton(
                    tooltip: l10n.pick(vi: 'Tháng sau', en: 'Next month'),
                    icon: Icons.chevron_right,
                    onPressed: () => unawaited(onNextMonth()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onToday,
                  child: Text(l10n.pick(vi: 'Hôm nay', en: 'Today')),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            _MonthNavButton(
              tooltip: l10n.pick(vi: 'Tháng trước', en: 'Previous month'),
              icon: Icons.chevron_left,
              onPressed: () => unawaited(onPreviousMonth()),
            ),
            const SizedBox(width: 8),
            Expanded(child: monthTitle),
            const SizedBox(width: 8),
            _MonthNavButton(
              tooltip: l10n.pick(vi: 'Tháng sau', en: 'Next month'),
              icon: Icons.chevron_right,
              onPressed: () => unawaited(onNextMonth()),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onToday,
              child: Text(l10n.pick(vi: 'Hôm nay', en: 'Today')),
            ),
          ],
        );
      },
    );
  }
}

class _MonthYearSelection {
  const _MonthYearSelection({required this.year, required this.month});

  final int year;
  final int month;
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({
    required this.initialYear,
    required this.initialMonth,
  });

  final int initialYear;
  final int initialMonth;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentYear = DateTime.now().year;
    final yearOptions = [
      for (var year = currentYear - 80; year <= currentYear + 40; year++) year,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Chọn tháng và năm', en: 'Choose month and year'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Tháng', en: 'Month'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (var month = 1; month <= 12; month++)
                      DropdownMenuItem<int>(
                        value: month,
                        child: Text(_monthName(l10n, month)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _month = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Năm', en: 'Year'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final year in yearOptions)
                      DropdownMenuItem<int>(value: year, child: Text('$year')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _year = value);
                  },
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
                  child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(_MonthYearSelection(year: _year, month: _month));
                  },
                  child: Text(l10n.pick(vi: 'Đi tới', en: 'Go')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _monthHeaderLabel({
  required DateTime focusedMonth,
  required CalendarDisplayMode displayMode,
  required Map<int, LunarDate> monthLunarMap,
  required AppLocalizations l10n,
}) {
  if (displayMode != CalendarDisplayMode.lunarOnly || monthLunarMap.isEmpty) {
    return '${_monthName(l10n, focusedMonth.month)} ${focusedMonth.year}';
  }

  final anchorLunarDate = _anchorLunarDateForMonth(monthLunarMap);
  if (anchorLunarDate == null) {
    return '${_monthName(l10n, focusedMonth.month)} ${focusedMonth.year}';
  }
  return '${_monthName(l10n, anchorLunarDate.month)} ${anchorLunarDate.year}';
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.controller,
    required this.onSelectDay,
    required this.onJumpToMonth,
  });

  final DualCalendarController controller;
  final ValueChanged<DateTime> onSelectDay;
  final Future<void> Function(DateTime month) onJumpToMonth;

  String _daySemanticsLabel(
    BuildContext context, {
    required DateTime day,
    required LunarDate? lunarDate,
    required int eventCount,
    required bool isToday,
    required bool isSelected,
    required bool isHoliday,
  }) {
    final l10n = context.l10n;
    final solarLabel = '${_monthName(l10n, day.month)} ${day.day}, ${day.year}';
    final lunarLabel = lunarDate == null
        ? l10n.pick(vi: 'Âm lịch chưa có dữ liệu', en: 'Lunar date unavailable')
        : l10n.pick(
            vi: 'Âm lịch ${lunarDate.displayLabel}',
            en: 'Lunar ${lunarDate.displayLabel}',
          );
    final eventsLabel = eventCount == 0
        ? l10n.pick(vi: 'không có sự kiện', en: 'no events')
        : l10n.pick(vi: '$eventCount sự kiện', en: '$eventCount events');
    final tags = <String>[
      if (isToday) l10n.pick(vi: 'hôm nay', en: 'today'),
      if (isSelected) l10n.pick(vi: 'đã chọn', en: 'selected'),
      if (isHoliday) l10n.pick(vi: 'ngày lễ', en: 'holiday'),
    ];
    final tagText = tags.isEmpty ? '' : ' (${tags.join(', ')})';
    return '$solarLabel, $lunarLabel, $eventsLabel$tagText';
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = controller.focusedMonth;
    final l10n = context.l10n;
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final offset = firstOfMonth.weekday - 1;
    final gridStart = firstOfMonth.subtract(Duration(days: offset));
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final today = DateTime.now();
    final childAspectRatio = switch (textScale) {
      > 1.6 => 0.50,
      > 1.4 => 0.58,
      > 1.2 => 0.66,
      _ => 0.76,
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _WeekdayLabel(l10n.pick(vi: 'T2', en: 'Mon')),
              _WeekdayLabel(l10n.pick(vi: 'T3', en: 'Tue')),
              _WeekdayLabel(l10n.pick(vi: 'T4', en: 'Wed')),
              _WeekdayLabel(l10n.pick(vi: 'T5', en: 'Thu')),
              _WeekdayLabel(l10n.pick(vi: 'T6', en: 'Fri')),
              _WeekdayLabel(l10n.pick(vi: 'T7', en: 'Sat')),
              _WeekdayLabel(l10n.pick(vi: 'CN', en: 'Sun')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: 42,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final day = gridStart.add(Duration(days: index));
            final isCurrentMonth = day.month == focusedMonth.month;
            final isSelected = _sameDay(day, controller.selectedDay);
            final isToday = _sameDay(day, today);

            final lunarDate = isCurrentMonth
                ? controller.lunarDateForDay(day)
                : null;
            final eventCount = controller.eventCountForDay(day);
            final isHoliday = isCurrentMonth && controller.isHolidayDay(day);

            return Semantics(
              button: true,
              selected: isSelected,
              label: _daySemanticsLabel(
                context,
                day: day,
                lunarDate: lunarDate,
                eventCount: eventCount,
                isToday: isToday,
                isSelected: isSelected,
                isHoliday: isHoliday,
              ),
              hint: l10n.pick(
                vi: 'Nhấn để xem chi tiết ngày',
                en: 'Tap to view day details',
              ),
              child: InkWell(
                key: Key('calendar-day-${_isoDay(day)}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  if (!isCurrentMonth) {
                    await onJumpToMonth(DateTime(day.year, day.month));
                  }
                  onSelectDay(day);
                },
                child: _DayTile(
                  day: day,
                  lunarDate: lunarDate,
                  isCurrentMonth: isCurrentMonth,
                  isSelected: isSelected,
                  isToday: isToday,
                  isHoliday: isHoliday,
                  eventCount: eventCount,
                  displayMode: controller.displayMode,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.controller,
    required this.onEditEvent,
    required this.onDeleteEvent,
  });

  final DualCalendarController controller;
  final ValueChanged<DualCalendarEvent> onEditEvent;
  final ValueChanged<DualCalendarEvent> onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final day = controller.selectedDay;
    final l10n = context.l10n;
    final lunarDate = controller.lunarDateForDay(day);
    final holidays = controller.holidaysForDay(day);
    final occurrences = controller.occurrencesForDay(day);
    final timeLabel = '${_monthName(l10n, day.month)} ${day.day}, ${day.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(
                vi: 'Ngày đã chọn: $timeLabel',
                en: 'Selected day: $timeLabel',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              lunarDate == null
                  ? l10n.pick(
                      vi: 'Ngày âm chưa có cho ngày này.',
                      en: 'Lunar date unavailable for this day.',
                    )
                  : l10n.pick(
                      vi: 'Âm lịch ${lunarDate.displayLabel}${lunarDate.isLeapMonth ? ' (tháng nhuận)' : ''}',
                      en: 'Lunar ${lunarDate.displayLabel}${lunarDate.isLeapMonth ? ' (Leap month)' : ''}',
                    ),
            ),
            if (holidays.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final holiday in holidays)
                    Chip(
                      avatar: const Icon(Icons.celebration, size: 16),
                      label: Text(holiday.name),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              occurrences.isEmpty
                  ? l10n.pick(
                      vi: 'Không có sự kiện cho ngày này.',
                      en: 'No events for this day.',
                    )
                  : l10n.pick(vi: 'Sự kiện', en: 'Events'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (occurrences.isEmpty)
              Text(
                l10n.pick(
                  vi: 'Tạo sự kiện âm lịch hoặc dương lịch để bắt đầu.',
                  en: 'Create a lunar or solar event to get started.',
                ),
              )
            else
              Column(
                children: [
                  for (final occurrence in occurrences)
                    _OccurrenceRow(
                      occurrence: occurrence,
                      onEdit: () => onEditEvent(occurrence.event),
                      onDelete: () => onDeleteEvent(occurrence.event),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({required this.controller});

  final DualCalendarController controller;

  @override
  Widget build(BuildContext context) {
    final reminders = controller.upcomingReminders;
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(vi: 'Lời nhắc sắp tới', en: 'Upcoming reminders'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (reminders.isEmpty)
              Text(
                l10n.pick(
                  vi: 'Không có lời nhắc trong khoảng thời gian hiện tại.',
                  en: 'No reminders scheduled in the current window.',
                ),
              )
            else
              Column(
                children: [
                  for (final reminder in reminders.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.pick(
                                vi: '${_formatDateTime(reminder.reminderAt)} · trước ${_formatReminderLeadTime(l10n, reminder.offsetMinutes)}',
                                en: '${_formatDateTime(reminder.reminderAt)} · ${_formatReminderLeadTime(l10n, reminder.offsetMinutes)} before',
                              ),
                            ),
                          ),
                        ],
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: IconButton(onPressed: onPressed, icon: Icon(icon)),
      ),
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({
    required this.occurrence,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEventOccurrence occurrence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final event = occurrence.event;
    final details = <String>[
      '${_formatDateTime(occurrence.occurrenceDate)} · ${l10n.calendarDateModeLabel(event.dateMode)}${event.isAnnualRecurring ? l10n.pick(vi: ' · hằng năm', en: ' · yearly') : ''}',
      if (event.eventType == EventType.deathAnniversary &&
          event.memorialForName.trim().isNotEmpty)
        l10n.pick(
          vi: 'Giỗ của: ${event.memorialForName.trim()}',
          en: 'Memorial for: ${event.memorialForName.trim()}',
        ),
      if (event.hostHousehold.trim().isNotEmpty)
        l10n.pick(
          vi: 'Nhà/chi: ${event.hostHousehold.trim()}',
          en: 'Household/branch: ${event.hostHousehold.trim()}',
        ),
      if (event.locationAddress.trim().isNotEmpty)
        l10n.pick(
          vi: 'Địa chỉ: ${event.locationAddress.trim()}',
          en: 'Address: ${event.locationAddress.trim()}',
        ),
      l10n.pick(
        vi: 'Người nhận: ${_audienceSummaryLabel(l10n, event.notificationAudience)}',
        en: 'Recipients: ${_audienceSummaryLabel(l10n, event.notificationAudience)}',
      ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          child: Icon(
            event.usesLunarDate
                ? Icons.nightlight_round
                : Icons.wb_sunny_outlined,
          ),
        ),
        title: Text(event.title),
        subtitle: Text(details.join('\n')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(l10n.pick(vi: 'Sửa', en: 'Edit')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.pick(vi: 'Xóa', en: 'Delete')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.lunarDate,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.isHoliday,
    required this.eventCount,
    required this.displayMode,
  });

  final DateTime day;
  final LunarDate? lunarDate;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final bool isHoliday;
  final int eventCount;
  final CalendarDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final background = switch ((isSelected, isToday, isHoliday)) {
      (true, _, _) => colorScheme.primaryContainer,
      (false, true, _) => colorScheme.secondaryContainer,
      (false, false, true) => colorScheme.tertiaryContainer,
      _ => colorScheme.surfaceContainerLow,
    };
    final foreground = isCurrentMonth
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.35);
    final solarPrimaryLabel = '${day.day}';
    final solarDetailLabel = '${day.day}/${day.month}';
    final lunarPrimaryLabel = lunarDate == null
        ? solarPrimaryLabel
        : '${lunarDate!.day}';
    final lunarDetailLabel = lunarDate == null
        ? solarDetailLabel
        : '${lunarDate!.day}/${lunarDate!.month}';
    final primaryLabel = switch (displayMode) {
      CalendarDisplayMode.dual => solarPrimaryLabel,
      CalendarDisplayMode.solarOnly => solarPrimaryLabel,
      CalendarDisplayMode.lunarOnly => lunarPrimaryLabel,
    };
    final String? secondaryLabel = switch (displayMode) {
      CalendarDisplayMode.dual => lunarDetailLabel,
      CalendarDisplayMode.solarOnly => null,
      CalendarDisplayMode.lunarOnly => solarDetailLabel,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 68;
        final veryCompact = constraints.maxHeight < 58 || textScale > 1.15;
        final horizontalPadding = compact ? 4.0 : 7.0;
        final verticalPadding = veryCompact ? 2.0 : (compact ? 3.0 : 6.0);
        final primaryFontSize = veryCompact ? 13.0 : (compact ? 15.0 : 17.0);
        final secondaryFontSize = veryCompact ? 8.5 : (compact ? 9.5 : 10.5);
        final showSecondaryCandidate = !veryCompact && secondaryLabel != null;
        final showEventBadgeCandidate =
            !veryCompact && eventCount > 0 && textScale <= 1.5;
        final innerHeight = (constraints.maxHeight - (verticalPadding * 2))
            .clamp(0.0, 999.0);
        final baseTextHeight = (primaryFontSize * 1.15);
        final secondaryTextHeight = (secondaryFontSize * 1.2) + 1;
        final showSecondaryLine =
            showSecondaryCandidate &&
            innerHeight >= (baseTextHeight + secondaryTextHeight + 1);
        final remainingHeightAfterText =
            innerHeight -
            baseTextHeight -
            (showSecondaryLine ? secondaryTextHeight : 0);
        final showEventBadge =
            showEventBadgeCandidate && remainingHeightAfterText >= 14;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: primaryFontSize,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ),
                        if (isToday && !veryCompact) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    if (showSecondaryLine) ...[
                      SizedBox(height: veryCompact ? 0 : 1),
                      Text(
                        secondaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: secondaryFontSize,
                          height: 1.05,
                          color: foreground.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showEventBadge)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event, size: 10, color: colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          '$eventCount',
                          style: TextStyle(
                            fontSize: compact ? 9 : 10,
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface.withValues(alpha: 0.82),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.controller,
    required this.initialDate,
    required this.members,
    required this.branches,
    required this.isRecipientsLoading,
    this.editingEvent,
  });

  final DualCalendarController controller;
  final DateTime initialDate;
  final List<MemberProfile> members;
  final List<BranchProfile> branches;
  final bool isRecipientsLoading;
  final DualCalendarEvent? editingEvent;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  static const _presetReminderOffsets = [10, 30, 120, 1440, 10080];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memorialForController = TextEditingController();
  final _hostHouseholdController = TextEditingController();
  final _locationAddressController = TextEditingController();
  EventType _eventType = EventType.deathAnniversary;
  CalendarDateMode _dateMode = CalendarDateMode.solar;
  DateTime _solarDate = DateTime.now();
  TimeOfDay _timeOfDay = const TimeOfDay(hour: 9, minute: 0);
  int _lunarYear = DateTime.now().year;
  int _lunarMonth = 1;
  int _lunarDay = 1;
  bool _isLeapMonth = false;
  bool _isAnnualRecurring = false;
  LunarRecurrencePolicy _recurrencePolicy =
      LunarRecurrencePolicy.firstOccurrence;
  final Set<int> _reminderOffsets = <int>{};
  EventNotificationAudienceMode _audienceMode =
      EventNotificationAudienceMode.clanAll;
  String? _audienceBranchId;
  final Set<String> _includeMemberIds = <String>{};
  final Set<String> _excludeMemberIds = <String>{};
  final Set<EventNotificationAudienceExcludeRule> _excludeRules =
      <EventNotificationAudienceExcludeRule>{};
  bool _isSubmitting = false;
  DateTime? _previewSolarDate;
  String? _previewError;
  int _previewRevision = 0;

  @override
  void initState() {
    super.initState();
    final event = widget.editingEvent;
    final initialDate = widget.initialDate;

    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _eventType = event.eventType;
      _memorialForController.text = event.memorialForName;
      _hostHouseholdController.text = event.hostHousehold;
      _locationAddressController.text = event.locationAddress;
      _dateMode = event.dateMode;
      _solarDate = event.solarDate;
      _timeOfDay = TimeOfDay(
        hour: event.solarDate.hour,
        minute: event.solarDate.minute,
      );
      _lunarYear = event.lunarDate?.year ?? event.solarDate.year;
      _lunarMonth = event.lunarDate?.month ?? 1;
      _lunarDay = event.lunarDate?.day ?? 1;
      _isLeapMonth = event.lunarDate?.isLeapMonth ?? false;
      _isAnnualRecurring = event.isAnnualRecurring;
      _recurrencePolicy = event.recurrencePolicy;
      _reminderOffsets.addAll(event.reminderOffsetsMinutes);
      _audienceMode = event.notificationAudience.mode;
      _audienceBranchId = event.notificationAudience.branchId;
      _includeMemberIds.addAll(event.notificationAudience.includeMemberIds);
      _excludeMemberIds.addAll(event.notificationAudience.excludeMemberIds);
      _excludeRules.addAll(event.notificationAudience.excludeRules);
    } else {
      _solarDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        9,
      );
      _lunarYear = initialDate.year;
      _reminderOffsets.addAll(const [1440]);
    }

    if (_audienceBranchId == null &&
        widget.branches.isNotEmpty &&
        _audienceMode == EventNotificationAudienceMode.branchAll) {
      _audienceBranchId = widget.branches.first.id;
    }

    _refreshLunarPreview();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _memorialForController.dispose();
    _hostHouseholdController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editingEvent == null
                    ? l10n.pick(vi: 'Tạo sự kiện', en: 'Create event')
                    : l10n.pick(vi: 'Chỉnh sửa sự kiện', en: 'Edit event'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('calendar-event-title-field'),
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Tiêu đề', en: 'Title'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventType>(
                key: Key('calendar-event-type-dropdown-${_eventType.wireName}'),
                initialValue: _eventType,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Loại sự kiện', en: 'Event type'),
                  border: const OutlineInputBorder(),
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
                  setState(() => _eventType = value);
                },
              ),
              if (_eventType.isMemorial) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _memorialForController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Giỗ của ai', en: 'Memorial for'),
                    hintText: l10n.pick(
                      vi: 'Ví dụ: Cụ Nguyễn Văn A',
                      en: 'Example: Ancestor Nguyen Van A',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _hostHouseholdController,
                decoration: InputDecoration(
                  labelText: l10n.pick(
                    vi: 'Nhà/chi tổ chức',
                    en: 'Host household/branch',
                  ),
                  hintText: l10n.pick(
                    vi: 'Ví dụ: Nhà trưởng chi',
                    en: 'Example: Main branch house',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationAddressController,
                decoration: InputDecoration(
                  labelText: l10n.pick(vi: 'Địa chỉ', en: 'Address'),
                  hintText: l10n.pick(
                    vi: 'Số nhà, đường, phường/xã, quận/huyện...',
                    en: 'Street, ward, district...',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CalendarDateMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in CalendarDateMode.values)
                    ButtonSegment<CalendarDateMode>(
                      value: mode,
                      label: Text(l10n.calendarDateModeLabel(mode)),
                    ),
                ],
                selected: {_dateMode},
                onSelectionChanged: (selection) {
                  final mode = selection.firstOrNull;
                  if (mode == null) {
                    return;
                  }
                  setState(() {
                    _dateMode = mode;
                  });
                  _refreshLunarPreview();
                },
              ),
              const SizedBox(height: 12),
              if (_dateMode == CalendarDateMode.solar)
                _SolarDateEditor(
                  solarDate: _solarDate,
                  timeOfDay: _timeOfDay,
                  onPickDate: _pickSolarDate,
                  onPickTime: _pickTime,
                )
              else
                _LunarDateEditor(
                  lunarYear: _lunarYear,
                  lunarMonth: _lunarMonth,
                  lunarDay: _lunarDay,
                  isLeapMonth: _isLeapMonth,
                  recurrencePolicy: _recurrencePolicy,
                  previewSolarDate: _previewSolarDate,
                  previewError: _previewError,
                  onYearChanged: (value) {
                    setState(() => _lunarYear = value);
                    _refreshLunarPreview();
                  },
                  onMonthChanged: (value) {
                    setState(() => _lunarMonth = value);
                    _refreshLunarPreview();
                  },
                  onDayChanged: (value) {
                    setState(() => _lunarDay = value);
                    _refreshLunarPreview();
                  },
                  onLeapChanged: (value) {
                    setState(() => _isLeapMonth = value);
                    _refreshLunarPreview();
                  },
                  onPolicyChanged: (value) {
                    setState(() => _recurrencePolicy = value);
                    _refreshLunarPreview();
                  },
                ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.pick(vi: 'Lặp lại hằng năm', en: 'Repeat annually'),
                ),
                value: _isAnnualRecurring,
                onChanged: (value) {
                  setState(() => _isAnnualRecurring = value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pick(
                  vi: 'Người nhận thông báo',
                  en: 'Notification recipients',
                ),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.pick(
                  vi: 'Chọn nhóm nhận để hệ thống gửi lời nhắc đúng đối tượng.',
                  en: 'Choose who should receive reminders for this event.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.isRecipientsLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _audienceMode = EventNotificationAudienceMode.clanAll;
                        _audienceBranchId = null;
                        _includeMemberIds.clear();
                      });
                    },
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.pick(vi: 'Toàn tộc', en: 'All clan')),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.branches.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _audienceMode =
                                  EventNotificationAudienceMode.branchAll;
                              _audienceBranchId =
                                  _audienceBranchId ?? widget.branches.first.id;
                              _includeMemberIds.clear();
                            });
                          },
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(l10n.pick(vi: 'Toàn chi', en: 'All branch')),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.members.isEmpty
                        ? null
                        : _applyLeaderViceQuickRecipients,
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      l10n.pick(vi: 'Trưởng + phó', en: 'Lead + deputy'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.members.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _audienceMode =
                                  EventNotificationAudienceMode.named;
                              _excludeMemberIds.clear();
                              _excludeRules.clear();
                            });
                          },
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text(l10n.pick(vi: 'Đích danh', en: 'Named only')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<EventNotificationAudienceMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: EventNotificationAudienceMode.clanAll,
                    label: Text(l10n.pick(vi: 'Toàn tộc', en: 'All clan')),
                  ),
                  ButtonSegment(
                    value: EventNotificationAudienceMode.branchAll,
                    label: Text(l10n.pick(vi: 'Toàn chi', en: 'All branch')),
                  ),
                  ButtonSegment(
                    value: EventNotificationAudienceMode.named,
                    label: Text(l10n.pick(vi: 'Đích danh', en: 'Named')),
                  ),
                ],
                selected: {_audienceMode},
                onSelectionChanged: (selection) {
                  final mode = selection.firstOrNull;
                  if (mode == null) {
                    return;
                  }
                  setState(() {
                    _audienceMode = mode;
                    if (_audienceMode !=
                        EventNotificationAudienceMode.branchAll) {
                      _audienceBranchId = null;
                    } else if (widget.branches.isNotEmpty) {
                      _audienceBranchId ??= widget.branches.first.id;
                    }
                  });
                },
              ),
              if (_audienceMode == EventNotificationAudienceMode.branchAll) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _audienceBranchId,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Chọn chi', en: 'Select branch'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final branch in widget.branches)
                      DropdownMenuItem<String?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _audienceBranchId = value);
                  },
                ),
              ],
              if (_audienceMode == EventNotificationAudienceMode.named) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: widget.members.isEmpty
                      ? null
                      : () => _pickMemberIds(
                          title: l10n.pick(
                            vi: 'Chọn người nhận đích danh',
                            en: 'Pick named recipients',
                          ),
                          initialSelected: _includeMemberIds,
                          onApplied: (picked) {
                            setState(() {
                              _includeMemberIds
                                ..clear()
                                ..addAll(picked);
                            });
                          },
                        ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    l10n.pick(vi: 'Chọn người nhận', en: 'Pick recipients'),
                  ),
                ),
                if (_includeMemberIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final memberId in _includeMemberIds.toList()..sort())
                        InputChip(
                          label: Text(_memberLabel(memberId)),
                          onDeleted: () {
                            setState(() {
                              _includeMemberIds.remove(memberId);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  l10n.pick(
                    vi: 'Loại trừ khỏi thông báo',
                    en: 'Exclude from notifications',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _excludeRules.contains(
                        EventNotificationAudienceExcludeRule.female,
                      ),
                      label: Text(
                        l10n.pick(vi: 'Trừ con gái', en: 'Exclude daughters'),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _excludeRules.add(
                              EventNotificationAudienceExcludeRule.female,
                            );
                          } else {
                            _excludeRules.remove(
                              EventNotificationAudienceExcludeRule.female,
                            );
                          }
                        });
                      },
                    ),
                    FilterChip(
                      selected: _excludeRules.contains(
                        EventNotificationAudienceExcludeRule.nonLeaderOrVice,
                      ),
                      label: Text(
                        l10n.pick(
                          vi: 'Chỉ trưởng/phó',
                          en: 'Leads/deputies only',
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _excludeRules.add(
                              EventNotificationAudienceExcludeRule
                                  .nonLeaderOrVice,
                            );
                          } else {
                            _excludeRules.remove(
                              EventNotificationAudienceExcludeRule
                                  .nonLeaderOrVice,
                            );
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.members.isEmpty
                      ? null
                      : () => _pickMemberIds(
                          title: l10n.pick(
                            vi: 'Chọn người loại trừ',
                            en: 'Pick excluded members',
                          ),
                          initialSelected: _excludeMemberIds,
                          onApplied: (picked) {
                            setState(() {
                              _excludeMemberIds
                                ..clear()
                                ..addAll(picked);
                            });
                          },
                        ),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(
                    l10n.pick(
                      vi: 'Loại trừ đích danh',
                      en: 'Exclude named members',
                    ),
                  ),
                ),
                if (_excludeMemberIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final memberId in _excludeMemberIds.toList()..sort())
                        InputChip(
                          label: Text(_memberLabel(memberId)),
                          onDeleted: () {
                            setState(() {
                              _excludeMemberIds.remove(memberId);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final recipients = _resolvedRecipientsPreview();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pick(
                            vi: 'Sẽ gửi cho ${recipients.length} thành viên',
                            en: 'Will notify ${recipients.length} members',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (recipients.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            recipients
                                .take(5)
                                .map((m) => m.fullName)
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pick(vi: 'Mốc lời nhắc', en: 'Reminder offsets'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final offset in _presetReminderOffsets)
                    FilterChip(
                      selected: _reminderOffsets.contains(offset),
                      label: Text(_offsetLabel(l10n, offset)),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _reminderOffsets.add(offset);
                          } else {
                            _reminderOffsets.remove(offset);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('calendar-event-save-button'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(
                        _isSubmitting
                            ? l10n.pick(vi: 'Đang lưu...', en: 'Saving...')
                            : l10n.pick(vi: 'Lưu', en: 'Save'),
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

  Future<void> _pickSolarDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDate: _solarDate,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _solarDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _solarDate.hour,
        _solarDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay,
    );
    if (picked == null) {
      return;
    }
    setState(() => _timeOfDay = picked);
  }

  Future<void> _refreshLunarPreview() async {
    final revision = ++_previewRevision;

    if (_dateMode != CalendarDateMode.lunar) {
      setState(() {
        _previewSolarDate = null;
        _previewError = null;
      });
      return;
    }

    final resolved = await widget.controller.resolveLunarToSolar(
      lunarDate: LunarDate(
        year: _lunarYear,
        month: _lunarMonth,
        day: _lunarDay,
        isLeapMonth: _isLeapMonth,
      ),
      policy: _recurrencePolicy,
      targetYear: _lunarYear,
    );

    if (!mounted || revision != _previewRevision) {
      return;
    }
    setState(() {
      _previewSolarDate = resolved;
      _previewError = resolved == null
          ? context.l10n.pick(
              vi: 'Ngày âm này không hợp lệ với chính sách tháng nhuận đã chọn.',
              en: 'This lunar date is invalid for the selected leap policy.',
            )
          : null;
    });
  }

  EventNotificationAudience _buildNotificationAudience() {
    final includeIds = _includeMemberIds.toList(growable: false)..sort();
    final excludeIds = _excludeMemberIds.toList(growable: false)..sort();
    final excludeRules = _excludeRules.toList(growable: false)
      ..sort((left, right) => left.wireName.compareTo(right.wireName));
    return EventNotificationAudience(
      mode: _audienceMode,
      branchId: _audienceMode == EventNotificationAudienceMode.branchAll
          ? _audienceBranchId
          : null,
      includeMemberIds: includeIds,
      excludeMemberIds: excludeIds,
      excludeRules: excludeRules,
    );
  }

  List<MemberProfile> _resolvedRecipientsPreview() {
    final audience = _buildNotificationAudience();
    return audience.resolveRecipients(
      members: widget.members,
      fallbackMembers: const [],
    );
  }

  String _memberLabel(String memberId) {
    for (final member in widget.members) {
      if (member.id == memberId) {
        return member.fullName;
      }
    }
    return memberId;
  }

  void _applyLeaderViceQuickRecipients() {
    final branchScoped =
        _audienceMode == EventNotificationAudienceMode.branchAll &&
        (_audienceBranchId ?? '').trim().isNotEmpty;
    final selectedIds = _leaderViceMemberIds(
      branchId: branchScoped ? _audienceBranchId : null,
    );
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Không tìm thấy trưởng/phó còn hoạt động để chọn nhanh.',
              en: 'No active lead/deputy members available for quick pick.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _audienceMode = EventNotificationAudienceMode.named;
      _includeMemberIds
        ..clear()
        ..addAll(selectedIds);
      _excludeMemberIds.clear();
      _excludeRules.clear();
    });
  }

  Set<String> _leaderViceMemberIds({String? branchId}) {
    final normalizedBranch = (branchId ?? '').trim();
    return widget.members
        .where((member) {
          if (!_isMemberAlive(member)) {
            return false;
          }
          if (!_isLeaderOrViceRole(member.primaryRole)) {
            return false;
          }
          if (normalizedBranch.isNotEmpty &&
              member.branchId.trim() != normalizedBranch) {
            return false;
          }
          return true;
        })
        .map((member) => member.id)
        .toSet();
  }

  bool _isLeaderOrViceRole(String? role) {
    final normalized = (role ?? '').trim().toUpperCase();
    return const <String>{
      'SUPER_ADMIN',
      'CLAN_ADMIN',
      'CLAN_OWNER',
      'CLAN_LEADER',
      'BRANCH_ADMIN',
      'VICE_LEADER',
    }.contains(normalized);
  }

  bool _isMemberAlive(MemberProfile member) {
    final deathDate = member.deathDate?.trim() ?? '';
    if (deathDate.isNotEmpty) {
      return false;
    }
    final normalizedStatus = member.status.trim().toLowerCase();
    return normalizedStatus != 'deceased' && normalizedStatus != 'dead';
  }

  Future<void> _pickMemberIds({
    required String title,
    required Set<String> initialSelected,
    required ValueChanged<Set<String>> onApplied,
  }) async {
    final selected = Set<String>.from(initialSelected);
    String query = '';
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredMembers = widget.members
                .where((member) {
                  if (query.trim().isEmpty) {
                    return true;
                  }
                  final normalized = query.trim().toLowerCase();
                  return member.fullName.toLowerCase().contains(normalized) ||
                      member.id.toLowerCase().contains(normalized);
                })
                .toList(growable: false);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.l10n.pick(
                          vi: 'Tìm thành viên...',
                          en: 'Search members...',
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredMembers.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.pick(
                                  vi: 'Không tìm thấy thành viên phù hợp.',
                                  en: 'No matching members found.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                final isChecked = selected.contains(member.id);
                                return CheckboxListTile(
                                  value: isChecked,
                                  title: Text(member.fullName),
                                  subtitle: member.branchId.trim().isEmpty
                                      ? null
                                      : Text('ID: ${member.id}'),
                                  onChanged: (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        selected.add(member.id);
                                      } else {
                                        selected.remove(member.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.l10n.pick(vi: 'Hủy', en: 'Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
                            child: Text(
                              context.l10n.pick(vi: 'Xong', en: 'Done'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }
    onApplied(result);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Tiêu đề là bắt buộc.',
              en: 'Title is required.',
            ),
          ),
        ),
      );
      return;
    }
    if (_eventType.isMemorial && _memorialForController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Vui lòng nhập người được giỗ.',
              en: 'Please provide who this memorial is for.',
            ),
          ),
        ),
      );
      return;
    }

    if (_audienceMode == EventNotificationAudienceMode.branchAll &&
        (_audienceBranchId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Vui lòng chọn chi nhận thông báo.',
              en: 'Please select the branch that should receive notifications.',
            ),
          ),
        ),
      );
      return;
    }

    if (_audienceMode == EventNotificationAudienceMode.named &&
        _includeMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Vui lòng chọn ít nhất 1 thành viên nhận thông báo.',
              en: 'Please pick at least one recipient.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      DateTime resolvedSolarDate;
      LunarDate? lunarDate;

      if (_dateMode == CalendarDateMode.solar) {
        resolvedSolarDate = DateTime(
          _solarDate.year,
          _solarDate.month,
          _solarDate.day,
          _timeOfDay.hour,
          _timeOfDay.minute,
        );
      } else {
        lunarDate = LunarDate(
          year: _lunarYear,
          month: _lunarMonth,
          day: _lunarDay,
          isLeapMonth: _isLeapMonth,
        );
        final resolved = await widget.controller.resolveLunarToSolar(
          lunarDate: lunarDate,
          policy: _recurrencePolicy,
          targetYear: _lunarYear,
        );
        if (resolved == null) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.pick(
                  vi: 'Không thể quy đổi ngày âm này sang ngày dương.',
                  en: 'Could not resolve this lunar date to a solar date.',
                ),
              ),
            ),
          );
          return;
        }

        resolvedSolarDate = DateTime(
          resolved.year,
          resolved.month,
          resolved.day,
          _timeOfDay.hour,
          _timeOfDay.minute,
        );
      }

      final source = widget.editingEvent;
      final now = DateTime.now();
      final notificationAudience = _buildNotificationAudience();
      final event = DualCalendarEvent(
        id: source?.id ?? '',
        title: title,
        description: _descriptionController.text.trim(),
        eventType: _eventType,
        memorialForName: _eventType.isMemorial
            ? _memorialForController.text.trim()
            : '',
        hostHousehold: _hostHouseholdController.text.trim(),
        locationAddress: _locationAddressController.text.trim(),
        dateMode: _dateMode,
        solarDate: resolvedSolarDate,
        lunarDate: lunarDate,
        isAnnualRecurring: _isAnnualRecurring,
        recurrencePolicy: _recurrencePolicy,
        reminderOffsetsMinutes: _reminderOffsets.toList(growable: false)
          ..sort((left, right) => right.compareTo(left)),
        notificationAudience: notificationAudience,
        timezone: source?.timezone ?? 'Asia/Ho_Chi_Minh',
        createdAt: source?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.controller.saveEvent(eventId: source?.id, event: event);
      if (!mounted) {
        return;
      }

      if (widget.controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.controller.errorMessage!)),
        );
        return;
      }

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _SolarDateEditor extends StatelessWidget {
  const _SolarDateEditor({
    required this.solarDate,
    required this.timeOfDay,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime solarDate;
  final TimeOfDay timeOfDay;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_formatDate(solarDate)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LunarDateEditor extends StatelessWidget {
  const _LunarDateEditor({
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
    required this.isLeapMonth,
    required this.recurrencePolicy,
    required this.previewSolarDate,
    required this.previewError,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onLeapChanged,
    required this.onPolicyChanged,
  });

  final int lunarYear;
  final int lunarMonth;
  final int lunarDay;
  final bool isLeapMonth;
  final LunarRecurrencePolicy recurrencePolicy;
  final DateTime? previewSolarDate;
  final String? previewError;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<bool> onLeapChanged;
  final ValueChanged<LunarRecurrencePolicy> onPolicyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final yearOptions = [
      for (
        var year = DateTime.now().year - 2;
        year <= DateTime.now().year + 5;
        year++
      )
        year,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberDropdown(
                label: l10n.pick(vi: 'Năm', en: 'Year'),
                value: lunarYear,
                values: yearOptions,
                onChanged: onYearChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: l10n.pick(vi: 'Tháng', en: 'Month'),
                value: lunarMonth,
                values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                onChanged: onMonthChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: l10n.pick(vi: 'Ngày', en: 'Day'),
                value: lunarDay,
                values: const [
                  1,
                  2,
                  3,
                  4,
                  5,
                  6,
                  7,
                  8,
                  9,
                  10,
                  11,
                  12,
                  13,
                  14,
                  15,
                  16,
                  17,
                  18,
                  19,
                  20,
                  21,
                  22,
                  23,
                  24,
                  25,
                  26,
                  27,
                  28,
                  29,
                  30,
                ],
                onChanged: onDayChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.pick(vi: 'Tháng nhuận', en: 'Leap month')),
          value: isLeapMonth,
          onChanged: onLeapChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LunarRecurrencePolicy>(
          initialValue: recurrencePolicy,
          decoration: InputDecoration(
            labelText: l10n.pick(
              vi: 'Chính sách tháng nhuận',
              en: 'Leap month policy',
            ),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final policy in LunarRecurrencePolicy.values)
              DropdownMenuItem<LunarRecurrencePolicy>(
                value: policy,
                child: Text(l10n.lunarRecurrencePolicyLabel(policy)),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              onPolicyChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),
        if (previewSolarDate != null)
          Text(
            l10n.pick(
              vi: 'Quy đổi ra ${_formatDate(previewSolarDate!)}',
              en: 'Resolves to ${_formatDate(previewSolarDate!)}',
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        if (previewError != null)
          Text(
            previewError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class _NumberDropdown extends StatelessWidget {
  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in values)
          DropdownMenuItem<int>(value: option, child: Text('$option')),
      ],
      onChanged: (changed) {
        if (changed != null) {
          onChanged(changed);
        }
      },
    );
  }
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

LunarDate? _anchorLunarDateForMonth(Map<int, LunarDate> monthLunarMap) {
  if (monthLunarMap.isEmpty) {
    return null;
  }
  final days = monthLunarMap.keys.toList()..sort();
  final anchorIndex = days.length ~/ 2;
  final anchorDay = days[anchorIndex];
  return monthLunarMap[anchorDay];
}

String _monthName(AppLocalizations l10n, int month) {
  if (l10n.localeName.toLowerCase().startsWith('vi')) {
    return 'Tháng $month';
  }
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

String _isoDay(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDateTime(DateTime value) {
  final date = _formatDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}

String _offsetLabel(AppLocalizations l10n, int minutes) {
  final isVietnamese = l10n.localeName.toLowerCase().startsWith('vi');
  if (minutes >= 10080 && minutes % 10080 == 0) {
    final value = minutes ~/ 10080;
    return isVietnamese ? '$value tuần' : '${value}w';
  }
  if (minutes >= 1440 && minutes % 1440 == 0) {
    final value = minutes ~/ 1440;
    return isVietnamese ? '$value ngày' : '${value}d';
  }
  if (minutes >= 60 && minutes % 60 == 0) {
    final value = minutes ~/ 60;
    return isVietnamese ? '$value giờ' : '${value}h';
  }
  return isVietnamese ? '$minutes phút' : '${minutes}m';
}

String _audienceSummaryLabel(
  AppLocalizations l10n,
  EventNotificationAudience audience,
) {
  final modeLabel = switch (audience.mode) {
    EventNotificationAudienceMode.clanAll => l10n.pick(
      vi: 'Toàn tộc',
      en: 'All clan',
    ),
    EventNotificationAudienceMode.branchAll => l10n.pick(
      vi: 'Toàn chi',
      en: 'All branch',
    ),
    EventNotificationAudienceMode.named => l10n.pick(
      vi: 'Đích danh',
      en: 'Named',
    ),
  };

  final hasExclusions =
      audience.excludeMemberIds.isNotEmpty || audience.excludeRules.isNotEmpty;
  if (audience.mode == EventNotificationAudienceMode.named) {
    return l10n.pick(
      vi: '$modeLabel (${audience.includeMemberIds.length} người)',
      en: '$modeLabel (${audience.includeMemberIds.length})',
    );
  }

  if (!hasExclusions) {
    return modeLabel;
  }

  return l10n.pick(
    vi: '$modeLabel (có loại trừ)',
    en: '$modeLabel (with exclusions)',
  );
}

String _formatReminderLeadTime(AppLocalizations l10n, int totalMinutes) {
  final isVietnamese = l10n.localeName.toLowerCase().startsWith('vi');
  if (totalMinutes <= 0) {
    return isVietnamese ? '0 phút' : '0 minutes';
  }

  var remaining = totalMinutes;
  const minuteInHour = 60;
  const minuteInDay = 24 * minuteInHour;
  const minuteInMonth = 30 * minuteInDay;
  const minuteInYear = 365 * minuteInDay;

  final years = remaining ~/ minuteInYear;
  remaining %= minuteInYear;
  final months = remaining ~/ minuteInMonth;
  remaining %= minuteInMonth;
  final days = remaining ~/ minuteInDay;
  remaining %= minuteInDay;
  final hours = remaining ~/ minuteInHour;
  remaining %= minuteInHour;
  final minutes = remaining;

  final parts = <String>[];
  if (years > 0) {
    parts.add(
      isVietnamese
          ? '$years ${years == 1 ? 'năm' : 'năm'}'
          : '$years ${years == 1 ? 'year' : 'years'}',
    );
  }
  if (months > 0) {
    parts.add(
      isVietnamese
          ? '$months ${months == 1 ? 'tháng' : 'tháng'}'
          : '$months ${months == 1 ? 'month' : 'months'}',
    );
  }
  if (days > 0) {
    parts.add(
      isVietnamese
          ? '$days ${days == 1 ? 'ngày' : 'ngày'}'
          : '$days ${days == 1 ? 'day' : 'days'}',
    );
  }
  if (hours > 0) {
    parts.add(
      isVietnamese
          ? '$hours ${hours == 1 ? 'giờ' : 'giờ'}'
          : '$hours ${hours == 1 ? 'hour' : 'hours'}',
    );
  }
  if (minutes > 0 || parts.isEmpty) {
    parts.add(
      isVietnamese
          ? '$minutes ${minutes == 1 ? 'phút' : 'phút'}'
          : '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
    );
  }
  return parts.join(' ');
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
