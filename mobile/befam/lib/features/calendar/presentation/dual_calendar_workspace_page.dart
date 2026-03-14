import 'dart:async';

import 'package:flutter/material.dart';

import '../models/calendar_date_mode.dart';
import '../models/calendar_display_mode.dart';
import '../models/calendar_region.dart';
import '../models/dual_calendar_event.dart';
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
    this.controller,
    this.eventStore,
    this.holidayRepository,
    this.settingsStore,
  });

  final DualCalendarController? controller;
  final DualCalendarEventStore? eventStore;
  final LunarHolidayRepository? holidayRepository;
  final CalendarSettingsStore? settingsStore;

  @override
  State<DualCalendarWorkspacePage> createState() =>
      _DualCalendarWorkspacePageState();
}

class _DualCalendarWorkspacePageState extends State<DualCalendarWorkspacePage> {
  late final DualCalendarController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _buildDefaultController();
    unawaited(_controller.initialize());
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('calendar-add-event-button'),
            onPressed: _controller.isSaving ? null : _openCreateEventSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _controller.refreshAll,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        if (_controller.errorMessage case final message?) ...[
                          _InfoBanner(
                            icon: Icons.error_outline,
                            title: 'Calendar sync issue',
                            description: message,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _SettingsCard(
                          controller: _controller,
                          onCreateEvent: _openCreateEventSheet,
                        ),
                        const SizedBox(height: 16),
                        _MonthHeader(
                          focusedMonth: _controller.focusedMonth,
                          onPreviousMonth: _controller.goToPreviousMonth,
                          onNextMonth: _controller.goToNextMonth,
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
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventEditorSheet(
          controller: _controller,
          initialDate: _controller.selectedDay,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event saved successfully.')),
      );
    }
  }

  Future<void> _openEditEventSheet(DualCalendarEvent event) async {
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
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully.')),
      );
    }
  }

  Future<void> _deleteEvent(DualCalendarEvent event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: Text('Remove "${event.title}" from your calendar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event deleted.')));
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
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.controller, required this.onCreateEvent});

  final DualCalendarController controller;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dual calendar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Plan events with solar and Asian lunar dates. Works without login.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<CalendarRegion>(
                value: controller.region,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (final region in CalendarRegion.values)
                    DropdownMenuItem<CalendarRegion>(
                      value: region,
                      child: Text(region.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  controller.setRegion(value);
                },
              ),
              SegmentedButton<CalendarDisplayMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in CalendarDisplayMode.values)
                    ButtonSegment<CalendarDisplayMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                ],
                selected: {controller.displayMode},
                onSelectionChanged: (selection) {
                  final mode = selection.firstOrNull;
                  if (mode == null) {
                    return;
                  }
                  controller.setDisplayMode(mode);
                },
              ),
              OutlinedButton.icon(
                onPressed: onCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Create event'),
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
    required this.focusedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  final DateTime focusedMonth;
  final Future<void> Function() onPreviousMonth;
  final Future<void> Function() onNextMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label = '${_monthName(focusedMonth.month)} ${focusedMonth.year}';
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => unawaited(onPreviousMonth()),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: () => unawaited(onNextMonth()),
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onToday, child: const Text('Today')),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final focusedMonth = controller.focusedMonth;
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final offset = firstOfMonth.weekday - 1;
    final gridStart = firstOfMonth.subtract(Duration(days: offset));

    return Column(
      children: [
        Row(
          children: const [
            _WeekdayLabel('Mon'),
            _WeekdayLabel('Tue'),
            _WeekdayLabel('Wed'),
            _WeekdayLabel('Thu'),
            _WeekdayLabel('Fri'),
            _WeekdayLabel('Sat'),
            _WeekdayLabel('Sun'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: 42,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.9,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final day = gridStart.add(Duration(days: index));
            final isCurrentMonth = day.month == focusedMonth.month;
            final isSelected = _sameDay(day, controller.selectedDay);
            final isToday = _sameDay(day, DateTime.now());

            final lunarDate = isCurrentMonth
                ? controller.lunarDateForDay(day)
                : null;
            final eventCount = controller.eventCountForDay(day);
            final isHoliday = isCurrentMonth && controller.isHolidayDay(day);

            return InkWell(
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
    final lunarDate = controller.lunarDateForDay(day);
    final holidays = controller.holidaysForDay(day);
    final occurrences = controller.occurrencesForDay(day);
    final timeLabel = '${_monthName(day.month)} ${day.day}, ${day.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected day: $timeLabel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              lunarDate == null
                  ? 'Lunar date unavailable for this day.'
                  : 'Lunar ${lunarDate.displayLabel}${lunarDate.isLeapMonth ? ' (Leap month)' : ''}',
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
              occurrences.isEmpty ? 'No events for this day.' : 'Events',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (occurrences.isEmpty)
              const Text('Create a lunar or solar event to get started.')
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming reminders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (reminders.isEmpty)
              const Text('No reminders scheduled in the current window.')
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
                              '${_formatDateTime(reminder.reminderAt)} · ${reminder.offsetMinutes} min before',
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
    final event = occurrence.event;
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
        subtitle: Text(
          '${_formatDateTime(occurrence.occurrenceDate)} · ${event.dateMode.label}${event.isAnnualRecurring ? ' · yearly' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    final background = switch ((isSelected, isToday, isHoliday)) {
      (true, _, _) => colorScheme.primaryContainer,
      (false, true, _) => colorScheme.secondaryContainer,
      (false, false, true) => colorScheme.tertiaryContainer,
      _ => colorScheme.surfaceContainerLow,
    };
    final foreground = isCurrentMonth
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.35);

    final solarLabel = '${day.day}';
    final lunarLabel = lunarDate == null
        ? '--'
        : '${lunarDate!.day}/${lunarDate!.month}${lunarDate!.isLeapMonth ? 'L' : ''}';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayMode != CalendarDisplayMode.lunarOnly)
            Text(
              solarLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          if (displayMode == CalendarDisplayMode.dual) ...[
            const SizedBox(height: 2),
            Text(
              'Lunar $lunarLabel',
              style: TextStyle(fontSize: 11, color: foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (displayMode == CalendarDisplayMode.lunarOnly)
            Text(
              lunarLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          const Spacer(),
          if (eventCount > 0)
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$eventCount',
                    style: TextStyle(
                      fontSize: 11,
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.controller,
    required this.initialDate,
    this.editingEvent,
  });

  final DualCalendarController controller;
  final DateTime initialDate;
  final DualCalendarEvent? editingEvent;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  static const _presetReminderOffsets = [10, 30, 120, 1440, 10080];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
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
  bool _isSubmitting = false;
  DateTime? _previewSolarDate;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    final event = widget.editingEvent;
    final initialDate = widget.initialDate;

    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
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

    _refreshLunarPreview();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
                widget.editingEvent == null ? 'Create event' : 'Edit event',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('calendar-event-title-field'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CalendarDateMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in CalendarDateMode.values)
                    ButtonSegment<CalendarDateMode>(
                      value: mode,
                      label: Text(mode.label),
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
                title: const Text('Repeat annually'),
                value: _isAnnualRecurring,
                onChanged: (value) {
                  setState(() => _isAnnualRecurring = value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Reminder offsets',
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
                      label: Text(_offsetLabel(offset)),
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('calendar-event-save-button'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(_isSubmitting ? 'Saving...' : 'Save'),
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

    if (!mounted) {
      return;
    }
    setState(() {
      _previewSolarDate = resolved;
      _previewError = resolved == null
          ? 'This lunar date is invalid for the selected leap policy.'
          : null;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
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
            const SnackBar(
              content: Text(
                'Could not resolve this lunar date to a solar date.',
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
      final event = DualCalendarEvent(
        id: source?.id ?? '',
        title: title,
        description: _descriptionController.text.trim(),
        dateMode: _dateMode,
        solarDate: resolvedSolarDate,
        lunarDate: lunarDate,
        isAnnualRecurring: _isAnnualRecurring,
        recurrencePolicy: _recurrencePolicy,
        reminderOffsetsMinutes: _reminderOffsets.toList(growable: false)
          ..sort((left, right) => right.compareTo(left)),
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
                label: 'Year',
                value: lunarYear,
                values: yearOptions,
                onChanged: onYearChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: 'Month',
                value: lunarMonth,
                values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                onChanged: onMonthChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: 'Day',
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
          title: const Text('Leap month'),
          value: isLeapMonth,
          onChanged: onLeapChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LunarRecurrencePolicy>(
          initialValue: recurrencePolicy,
          decoration: const InputDecoration(
            labelText: 'Leap month policy',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final policy in LunarRecurrencePolicy.values)
              DropdownMenuItem<LunarRecurrencePolicy>(
                value: policy,
                child: Text(policy.label),
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
            'Resolves to ${_formatDate(previewSolarDate!)}',
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

String _monthName(int month) {
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

String _offsetLabel(int minutes) {
  if (minutes >= 10080 && minutes % 10080 == 0) {
    return '${minutes ~/ 10080}w';
  }
  if (minutes >= 1440 && minutes % 1440 == 0) {
    return '${minutes ~/ 1440}d';
  }
  if (minutes >= 60 && minutes % 60 == 0) {
    return '${minutes ~/ 60}h';
  }
  return '${minutes}m';
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
