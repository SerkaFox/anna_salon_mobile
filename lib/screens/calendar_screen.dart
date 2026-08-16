import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'cashbox_screen.dart';
import 'clients_screen.dart';
import 'employees_screen.dart';
import 'services_screen.dart';
import 'shared.dart';

const _workStartHour = 9;
const _workEndHour = 20;
const _calendarPixelsPerMinute = 1.55;
const _calendarHeight =
    (_workEndHour - _workStartHour) * 60.0 * _calendarPixelsPerMinute;
const _desktopTimeRailWidth = 48.0;
const _mobileTimeRailWidth = 38.0;
const _columnGap = 6.0;
const _slotStepMinutes = 15;

enum _CalendarMode { days, team }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.api,
    this.canManageStaff = false,
    this.currentEmployeeId,
    this.activeDate,
    this.highlightBookingId,
    this.highlightToken = 0,
    this.onCreateFromSlot,
    super.key,
  });

  final AnnaApi api;
  final bool canManageStaff;
  final String? currentEmployeeId;
  final DateTime? activeDate;
  final String? highlightBookingId;
  final int highlightToken;
  final ValueChanged<CalendarSlotDraft>? onCreateFromSlot;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class CalendarSlotDraft {
  const CalendarSlotDraft({
    required this.startAt,
    this.employeeId,
  });

  final DateTime startAt;
  final String? employeeId;
}

class _BookingDropDraft {
  const _BookingDropDraft({
    required this.booking,
    required this.startAt,
    required this.employeeId,
  });

  final _BookingView booking;
  final DateTime startAt;
  final String? employeeId;
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _selectedEmployeesKey = 'anna_calendar_selected_employee_ids';
  static const _employeeColorsKey = 'anna_calendar_employee_colors';
  static const _serviceColorsKey = 'anna_calendar_service_colors';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  DateTime _startDate = DateTime.now();
  _CalendarMode _mode = _CalendarMode.days;
  Set<String>? _selectedEmployeeIds;
  Map<String, String> _cachedEmployeeColors = const {};
  Map<String, String> _cachedServiceColors = const {};
  String? _highlightBookingId;
  Timer? _highlightTimer;
  late Future<List<_CalendarDayData>> _future = _loadVisibleDays();

  List<DateTime> get _visibleDates {
    return [
      _dateOnly(_startDate),
      _dateOnly(_startDate.add(const Duration(days: 1))),
      _dateOnly(_startDate.add(const Duration(days: 2))),
    ];
  }

  @override
  void initState() {
    super.initState();
    final activeDate = widget.activeDate;
    if (activeDate != null) {
      _startDate = _dateOnly(activeDate);
      _future = _loadVisibleDays();
    }
    unawaited(_restoreSelectedEmployeeIds());
    unawaited(_restoreCalendarColorCache());
    _setHighlight(widget.highlightBookingId, notify: false);
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightToken == oldWidget.highlightToken) return;

    final activeDate = widget.activeDate;
    setState(() {
      if (activeDate != null) {
        _startDate = _dateOnly(activeDate);
      }
      _future = _loadVisibleDays();
    });
    _setHighlight(widget.highlightBookingId);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _setHighlight(String? bookingId, {bool notify = true}) {
    _highlightTimer?.cancel();
    if (notify) {
      setState(() => _highlightBookingId = bookingId);
    } else {
      _highlightBookingId = bookingId;
    }
    if (bookingId == null) return;
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightBookingId = null);
    });
  }

  Future<List<_CalendarDayData>> _loadVisibleDays() async {
    final results = await Future.wait(
      _visibleDates.map((date) async {
        final collection = await widget.api.calendarDay(date);
        return _CalendarDayData.fromCollection(
          collection,
          fallbackDate: date,
          employeeColorCache: _cachedEmployeeColors,
          serviceColorCache: _cachedServiceColors,
        );
      }),
    );
    unawaited(_saveCalendarColorCache(results));
    return results;
  }

  Future<void> _restoreCalendarColorCache() async {
    final employeeColors = await _readStringMap(_employeeColorsKey);
    final serviceColors = await _readStringMap(_serviceColorsKey);
    if (!mounted) return;
    final hasNewData = employeeColors.isNotEmpty || serviceColors.isNotEmpty;
    setState(() {
      _cachedEmployeeColors = employeeColors;
      _cachedServiceColors = serviceColors;
      if (hasNewData) {
        _future = _loadVisibleDays();
      }
    });
  }

  Future<Map<String, String>> _readStringMap(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } on FormatException {
      return const {};
    }
  }

  Future<void> _saveCalendarColorCache(List<_CalendarDayData> days) async {
    final employeeColors = Map<String, String>.from(_cachedEmployeeColors);
    final serviceColors = Map<String, String>.from(_cachedServiceColors);
    for (final day in days) {
      for (final employee in day.employees) {
        employeeColors[employee.id] = _colorToHex(employee.color);
      }
      for (final booking in day.bookings) {
        final employeeId = booking.employeeId;
        if (employeeId != null) {
          employeeColors[employeeId] = _colorToHex(booking.employeeColor);
        }
        final serviceId = booking.serviceId;
        final serviceColor = booking.serviceColor;
        if (serviceId != null && serviceColor != null) {
          serviceColors[serviceId] = serviceColor;
        }
      }
    }
    _cachedEmployeeColors = employeeColors;
    _cachedServiceColors = serviceColors;
    await Future.wait([
      _storage.write(
          key: _employeeColorsKey, value: jsonEncode(employeeColors)),
      _storage.write(key: _serviceColorsKey, value: jsonEncode(serviceColors)),
    ]);
  }

  Future<void> _refresh() async {
    final next = _loadVisibleDays();
    setState(() {
      _future = next;
    });
    await next;
  }

  void _reload() {
    final next = _loadVisibleDays();
    setState(() {
      _future = next;
    });
  }

  void _moveDays(int days) {
    setState(() {
      _startDate = _dateOnly(_startDate.add(Duration(days: days)));
      _future = _loadVisibleDays();
    });
  }

  void _goToday() {
    setState(() {
      _startDate = _dateOnly(DateTime.now());
      _future = _loadVisibleDays();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _startDate = _dateOnly(picked);
      _future = _loadVisibleDays();
    });
  }

  Future<void> _restoreSelectedEmployeeIds() async {
    final raw = await _storage.read(key: _selectedEmployeesKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final ids = decoded
        .whereType<Object>()
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (ids.isEmpty || !mounted) return;
    setState(() => _selectedEmployeeIds = ids);
  }

  Future<void> _saveSelectedEmployeeIds(Set<String>? ids) async {
    if (ids == null) {
      await _storage.delete(key: _selectedEmployeesKey);
      return;
    }
    await _storage.write(
      key: _selectedEmployeesKey,
      value: jsonEncode(ids.toList()..sort()),
    );
  }

  Set<String>? _effectiveSelectedEmployeeIds(
    List<_CalendarEmployee> employees,
  ) {
    final selected = _selectedEmployeeIds;
    if (selected == null) return null;
    final allIds = employees.map((employee) => employee.id).toSet();
    final valid = selected.where(allIds.contains).toSet();
    if (valid.isEmpty || valid.length == allIds.length) return null;
    return valid;
  }

  void _setSelectedEmployeeIds(Set<String>? ids) {
    setState(() => _selectedEmployeeIds = ids);
    unawaited(_saveSelectedEmployeeIds(ids));
  }

  void _toggleEmployee(String employeeId, List<_CalendarEmployee> employees) {
    final allIds = employees.map((employee) => employee.id).toSet();
    final current = _effectiveSelectedEmployeeIds(employees);
    final next = current == null ? {...allIds} : {...current};

    if (next.contains(employeeId)) {
      next.remove(employeeId);
    } else {
      next.add(employeeId);
    }

    _setSelectedEmployeeIds(next.length == allIds.length ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: FutureBuilder<List<_CalendarDayData>>(
        future: _future,
        builder: (context, snapshot) {
          final days = snapshot.data ?? const <_CalendarDayData>[];
          final employees = _mergeEmployees(days);
          final selectedIds = _effectiveSelectedEmployeeIds(employees);
          return Column(
            children: [
              _CalendarToolbar(
                mode: _mode,
                startDate: _startDate,
                employees: employees,
                selectedEmployeeIds: selectedIds,
                onModeToggle: () => setState(() {
                  _mode = _mode == _CalendarMode.days
                      ? _CalendarMode.team
                      : _CalendarMode.days;
                }),
                onPrevious: () =>
                    _moveDays(_mode == _CalendarMode.days ? -3 : -1),
                onNext: () => _moveDays(_mode == _CalendarMode.days ? 3 : 1),
                onPickDate: _pickDate,
                onRefresh: _reload,
                onAllEmployeesSelected: () => _setSelectedEmployeeIds(null),
                onEmployeeToggled: (id) => _toggleEmployee(id, employees),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ErrorState(
                          error: snapshot.error!, onRetry: _reload);
                    }

                    _debugCalendarData(days, employees);
                    final activeDay = days.isEmpty
                        ? null
                        : days.firstWhere(
                            (day) => _isSameDate(day.date, _startDate),
                            orElse: () => days.first,
                          );
                    final visibleDays = _mode == _CalendarMode.days
                        ? [
                            for (final day in days)
                              day.filteredByEmployees(selectedIds),
                          ]
                        : [
                            if (activeDay != null)
                              activeDay.filteredByEmployees(selectedIds),
                          ];

                    if (_mode == _CalendarMode.team && activeDay == null) {
                      return const EmptyState('Sin dia activo.');
                    }

                    return _ResponsiveCalendarGrid(
                      mode: _mode,
                      days: _mode == _CalendarMode.days
                          ? visibleDays
                          : [activeDay!],
                      employees: employees,
                      selectedEmployeeIds: selectedIds,
                      highlightBookingId: _highlightBookingId,
                      onToday: _goToday,
                      onBookingTap: (booking) => _openBookingActions(booking),
                      onTimeBlockTap: _openTimeBlockDetails,
                      onEmptySlotTap: _openCreateFromSlot,
                      onBookingDrop: _openDragReschedule,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openBookingActions(_BookingView booking) {
    _BookingActionsSheet.show(
      context,
      api: widget.api,
      canManageStaff: widget.canManageStaff,
      currentEmployeeId: widget.currentEmployeeId,
      booking: booking,
      onChanged: _refresh,
      onEdit: () => _BookingEditSheet.show(
        context,
        api: widget.api,
        booking: booking,
        onChanged: _refresh,
      ),
    );
  }

  void _openTimeBlockDetails(_TimeBlockView block) {
    _TimeBlockDetailsSheet.show(
      context,
      api: widget.api,
      block: block,
      onChanged: _refresh,
    );
  }

  Future<void> _openCreateFromSlot(CalendarSlotDraft draft) async {
    final action = await _SlotActionSheet.show(context, draft: draft);
    if (!mounted || action == null) return;
    switch (action) {
      case _SlotAction.booking:
        widget.onCreateFromSlot?.call(draft);
        break;
      case _SlotAction.timeBlock:
        _TimeBlockFormSheet.show(
          context,
          api: widget.api,
          draft: draft,
          onChanged: _refresh,
        );
        break;
    }
  }

  Future<void> _openDragReschedule(_BookingDropDraft draft) async {
    final booking = draft.booking;
    final bookingId = booking.id;
    final serviceId = booking.serviceId;
    final employeeId = draft.employeeId ?? booking.employeeId;
    if (bookingId == null || serviceId == null || employeeId == null) {
      _showCalendarMessage(
        context,
        'Faltan datos de la reserva para reprogramar.',
      );
      return;
    }

    final startAt = _formatApiDateTime(draft.startAt);
    final zoneId = booking.zoneId;
    final availabilityPayload = <String, dynamic>{
      'service': _coerceId(serviceId),
      'employee': _coerceId(employeeId),
      'start_at': startAt,
      'exclude_booking_id': _coerceId(bookingId),
      if (zoneId != null) 'zone': _coerceId(zoneId),
    };
    final reschedulePayload = <String, dynamic>{
      'service': _coerceId(serviceId),
      'employee': _coerceId(employeeId),
      'start_at': startAt,
      if (zoneId != null) 'zone': _coerceId(zoneId),
    };

    try {
      final availability =
          await widget.api.checkAvailability(availabilityPayload);
      final available = availability.data['available'];
      if (available == false) {
        if (!mounted) return;
        _showCalendarMessage(
          context,
          _textFromMap(availability.data, 'message') ??
              'Ese horario no esta disponible.',
        );
        return;
      }
      await widget.api.rescheduleBooking(bookingId, reschedulePayload);
      if (!mounted) return;
      final refreshed = _loadVisibleDays();
      setState(() {
        _future = refreshed;
      });
      final days = await refreshed;
      if (!mounted) return;
      final moved = _containsMovedBooking(
        days,
        bookingId: bookingId,
        startAt: draft.startAt,
        employeeId: employeeId,
      );
      _showCalendarMessage(
        context,
        moved
            ? AppLocalizations.of(context).tr('Reserva reprogramada.')
            : AppLocalizations.of(context).tr(
                'Reserva reprogramada. Actualiza el calendario si no aparece en el nuevo horario.',
              ),
      );
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      _showCalendarMessage(context, _apiErrorText(error));
    }
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.mode,
    required this.startDate,
    required this.employees,
    required this.selectedEmployeeIds,
    required this.onModeToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onRefresh,
    required this.onAllEmployeesSelected,
    required this.onEmployeeToggled,
  });

  final _CalendarMode mode;
  final DateTime startDate;
  final List<_CalendarEmployee> employees;
  final Set<String>? selectedEmployeeIds;
  final VoidCallback onModeToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;
  final VoidCallback onAllEmployeesSelected;
  final ValueChanged<String> onEmployeeToggled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCode = t.locale.languageCode;
    final endDate = startDate.add(const Duration(days: 2));
    final label = mode == _CalendarMode.days
        ? '${DateFormat('d MMM', localeCode).format(startDate)} - ${DateFormat('d MMM yyyy', localeCode).format(endDate)}'
        : DateFormat('EEEE, d MMM yyyy', localeCode).format(startDate);

    return PanelCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: mode == _CalendarMode.days
                    ? t.tr('Ver empleados')
                    : t.tr('Ver dias'),
                onPressed: onModeToggle,
                icon: Text(
                  mode == _CalendarMode.days
                      ? (t.isRussian ? 'Сотр.' : 'Empl')
                      : (t.isRussian ? 'Дни' : 'Day'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AnnaRadii.md),
                  onTap: onPickDate,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: t.refresh,
                onPressed: onRefresh,
                icon: Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: t.tr('Anterior'),
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: t.tr('Siguiente'),
                onPressed: onNext,
                icon: Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _EmployeeDropdownButton(
                    employees: employees,
                    selectedEmployeeIds: selectedEmployeeIds,
                    onAllSelected: onAllEmployeesSelected,
                    onEmployeeToggled: onEmployeeToggled,
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

class _EmployeeDropdownButton extends StatelessWidget {
  const _EmployeeDropdownButton({
    required this.employees,
    required this.selectedEmployeeIds,
    required this.onAllSelected,
    required this.onEmployeeToggled,
  });

  final List<_CalendarEmployee> employees;
  final Set<String>? selectedEmployeeIds;
  final VoidCallback onAllSelected;
  final ValueChanged<String> onEmployeeToggled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final allSelected = selectedEmployeeIds == null;
    final count = allSelected ? employees.length : selectedEmployeeIds!.length;
    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: Icon(Icons.groups_outlined),
          label: Text(allSelected ? t.tr('Todos') : '$count'),
        );
      },
      menuChildren: [
        CheckboxMenuButton(
          value: allSelected,
          onChanged: (_) => onAllSelected(),
          child: Text(t.tr('Todos')),
        ),
        for (final employee in employees)
          CheckboxMenuButton(
            value: allSelected || selectedEmployeeIds!.contains(employee.id),
            onChanged: (_) => onEmployeeToggled(employee.id),
            child: Text(employee.firstName ?? employee.name),
          ),
      ],
    );
  }
}

class _ResponsiveCalendarGrid extends StatelessWidget {
  const _ResponsiveCalendarGrid({
    required this.mode,
    required this.days,
    required this.employees,
    required this.selectedEmployeeIds,
    required this.highlightBookingId,
    required this.onToday,
    required this.onBookingTap,
    required this.onTimeBlockTap,
    required this.onEmptySlotTap,
    required this.onBookingDrop,
  });

  final _CalendarMode mode;
  final List<_CalendarDayData> days;
  final List<_CalendarEmployee> employees;
  final Set<String>? selectedEmployeeIds;
  final String? highlightBookingId;
  final VoidCallback onToday;
  final ValueChanged<_BookingView> onBookingTap;
  final ValueChanged<_TimeBlockView> onTimeBlockTap;
  final ValueChanged<CalendarSlotDraft> onEmptySlotTap;
  final ValueChanged<_BookingDropDraft> onBookingDrop;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final timeRailWidth =
              isMobile ? _mobileTimeRailWidth : _desktopTimeRailWidth;
          final columns = mode == _CalendarMode.days
              ? _dayColumns(context, Theme.of(context).colorScheme.primary)
              : _teamColumns(context, days.isEmpty ? null : days.first);
          if (columns.isEmpty) {
            return const EmptyState('Sin columnas visibles.');
          }

          final fitColumnCount = mode == _CalendarMode.team
              ? columns.length.clamp(1, 4)
              : columns.length;
          final gaps = _columnGap * (fitColumnCount - 1).clamp(0, 100);
          final available = constraints.maxWidth - timeRailWidth - gaps;
          final fittedWidth = available / fitColumnCount;
          final minWidth = isMobile ? 76.0 : 104.0;
          final columnWidth = fittedWidth.clamp(minWidth, 260.0).toDouble();
          final needsHorizontalScroll =
              mode == _CalendarMode.team && columns.length > 4 ||
                  timeRailWidth +
                          (columnWidth * columns.length) +
                          (_columnGap * (columns.length - 1)) >
                      constraints.maxWidth;
          final contentWidth = needsHorizontalScroll
              ? timeRailWidth +
                  (columnWidth * columns.length) +
                  (_columnGap * (columns.length - 1))
              : constraints.maxWidth;

          final grid = SizedBox(
              width: contentWidth,
              child: LayoutBuilder(
                builder: (context, gridConstraints) {
                  final bodyHeight =
                      (gridConstraints.maxHeight - 48).clamp(260.0, 2000.0);
                  return Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: timeRailWidth,
                            child: _TodayHeader(onTap: onToday),
                          ),
                          for (var i = 0; i < columns.length; i++) ...[
                            if (i > 0) const SizedBox(width: _columnGap),
                            _GridHeader(column: columns[i], width: columnWidth),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: bodyHeight,
                        child: SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TimeRail(width: timeRailWidth),
                              for (var i = 0; i < columns.length; i++) ...[
                                if (i > 0) const SizedBox(width: _columnGap),
                                _GridColumn(
                                  column: columns[i],
                                  width: columnWidth,
                                  onBookingTap: onBookingTap,
                                  highlightBookingId: highlightBookingId,
                                  onTimeBlockTap: onTimeBlockTap,
                                  onEmptySlotTap: onEmptySlotTap,
                                  onBookingDrop: onBookingDrop,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ));

          return needsHorizontalScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: grid)
              : grid;
        },
      ),
    );
  }

  List<_CalendarColumn> _dayColumns(BuildContext context, Color primary) {
    final localeCode = AppLocalizations.of(context).locale.languageCode;
    return [
      for (final day in days)
        _CalendarColumn(
          date: day.date,
          title: DateFormat('EEE', localeCode).format(day.date),
          subtitle: DateFormat('d/M', localeCode).format(day.date),
          color:
              _isSameDate(day.date, DateTime.now()) ? primary : AnnaColors.line,
          bookings: day.bookings,
          scheduleBlocks: [
            for (final employee in day.employees)
              for (final block in employee.blocks)
                if (block.kind != _TimeBlockKind.schedule) block,
          ],
        ),
    ];
  }

  List<_CalendarColumn> _teamColumns(
    BuildContext context,
    _CalendarDayData? day,
  ) {
    if (day == null) return const [];
    final t = AppLocalizations.of(context);
    final activeDayEmployees = _mergeEmployees([day]);
    final sourceEmployees = selectedEmployeeIds == null
        ? activeDayEmployees
        : activeDayEmployees
            .where((employee) => selectedEmployeeIds!.contains(employee.id))
            .toList();
    return [
      for (final employee in sourceEmployees)
        _CalendarColumn(
          date: day.date,
          employeeId: employee.id,
          hasSchedule: employee.hasSchedule,
          title: employee.firstName ?? employee.name,
          subtitle: employee.hasSchedule ? t.tr('Turno') : t.tr('Sin turno'),
          color: employee.color,
          bookings: day.bookings
              .where((booking) => booking.matchesEmployee(employee))
              .toList(),
          scheduleBlocks: employee.blocks,
        ),
    ];
  }
}

class _CalendarColumn {
  const _CalendarColumn({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bookings,
    this.employeeId,
    this.hasSchedule = true,
    this.scheduleBlocks = const [],
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final Color color;
  final String? employeeId;
  final bool hasSchedule;
  final List<_BookingView> bookings;
  final List<_TimeBlockView> scheduleBlocks;
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.column, required this.width});

  final _CalendarColumn column;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: column.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: column.color.withValues(alpha: 0.34)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            column.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AnnaColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            column.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AnnaColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SizedBox(
      height: 46,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          t.tr('Hoy'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _TimeRail extends StatelessWidget {
  const _TimeRail({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _calendarHeight,
      child: Stack(
        children: [
          for (var hour = _workStartHour; hour < _workEndHour; hour++)
            Positioned(
              top: ((hour - _workStartHour) * 60 * _calendarPixelsPerMinute)
                  .toDouble(),
              left: 0,
              right: 5,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  color: AnnaColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridColumn extends StatefulWidget {
  const _GridColumn({
    required this.column,
    required this.width,
    required this.onBookingTap,
    required this.highlightBookingId,
    required this.onTimeBlockTap,
    required this.onEmptySlotTap,
    required this.onBookingDrop,
  });

  final _CalendarColumn column;
  final double width;
  final ValueChanged<_BookingView> onBookingTap;
  final String? highlightBookingId;
  final ValueChanged<_TimeBlockView> onTimeBlockTap;
  final ValueChanged<CalendarSlotDraft> onEmptySlotTap;
  final ValueChanged<_BookingDropDraft> onBookingDrop;

  @override
  State<_GridColumn> createState() => _GridColumnState();
}

class _GridColumnState extends State<_GridColumn> {
  final _targetKey = GlobalKey();
  DateTime? _previewStartAt;
  _BookingView? _previewBooking;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_BookingView>(
      onMove: _handleDragMove,
      onLeave: (_) => setState(() {
        _previewStartAt = null;
        _previewBooking = null;
      }),
      onAcceptWithDetails: _handleDrop,
      builder: (context, candidateData, rejectedData) {
        return Container(
          key: _targetKey,
          width: widget.width,
          height: _calendarHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _previewBooking == null
                  ? AnnaColors.line
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.8),
            ),
            color: const Color(0x0FE8FFF1),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _handleEmptyTap(context, details.localPosition.dy),
                ),
              ),
              for (var minute = 0;
                  minute <= (_workEndHour - _workStartHour) * 60;
                  minute += _slotStepMinutes)
                Positioned(
                  left: 0,
                  right: 0,
                  top: minute * _calendarPixelsPerMinute,
                  child: Container(
                    height: minute % 60 == 0 ? 1.2 : 0.7,
                    color: minute % 60 == 0
                        ? const Color(0x348CE5B0)
                        : const Color(0x168CE5B0),
                  ),
                ),
              for (final block in widget.column.scheduleBlocks)
                if (block.kind == _TimeBlockKind.schedule)
                  _PositionedScheduleBlock(block: block)
                else
                  _PositionedTimeBlock(
                    block: block,
                    onTap: () => widget.onTimeBlockTap(block),
                  ),
              if (widget.column.bookings.isEmpty)
                Center(
                  child: Text(
                    AppLocalizations.of(context).tr('Sin reservas'),
                    style: TextStyle(color: AnnaColors.muted, fontSize: 12),
                  ),
                ),
              if (_previewStartAt != null && _previewBooking != null)
                _DropPreview(
                  booking: _previewBooking!,
                  startAt: _previewStartAt!,
                ),
              for (final booking in widget.column.bookings)
                _PositionedBookingCard(
                  booking: booking,
                  highlighted: booking.id != null &&
                      booking.id == widget.highlightBookingId,
                  onTap: () => widget.onBookingTap(booking),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleDragMove(DragTargetDetails<_BookingView> details) {
    final startAt = _startAtFromGlobalOffset(details.offset);
    if (startAt == null) return;
    setState(() {
      _previewStartAt = startAt;
      _previewBooking = details.data;
    });
  }

  void _handleDrop(DragTargetDetails<_BookingView> details) {
    final startAt = _startAtFromGlobalOffset(details.offset);
    setState(() {
      _previewStartAt = null;
      _previewBooking = null;
    });
    if (startAt == null) return;

    widget.onBookingDrop(
      _BookingDropDraft(
        booking: details.data,
        startAt: startAt,
        employeeId: widget.column.employeeId ?? details.data.employeeId,
      ),
    );
  }

  DateTime? _startAtFromGlobalOffset(Offset globalOffset) {
    final context = _targetKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    final local = box.globalToLocal(globalOffset);
    return _slotStartAt(widget.column.date, local.dy);
  }

  void _handleEmptyTap(BuildContext context, double dy) {
    final startAt = _slotStartAt(widget.column.date, dy);

    widget.onEmptySlotTap(
      CalendarSlotDraft(
        startAt: startAt,
        employeeId: widget.column.employeeId,
      ),
    );
  }
}

class _DropPreview extends StatelessWidget {
  const _DropPreview({
    required this.booking,
    required this.startAt,
  });

  final _BookingView booking;
  final DateTime startAt;

  @override
  Widget build(BuildContext context) {
    final top = _minutesFromWorkStart(startAt)
        .clamp(0, _calendarHeight - 30)
        .toDouble();
    final height = booking.height.clamp(30, _calendarHeight - top).toDouble();
    final color = _parseColor(booking.serviceColor) ?? booking.employeeColor;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              DateFormat('HH:mm').format(startAt),
              style: TextStyle(
                color: AnnaColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionedBookingCard extends StatelessWidget {
  const _PositionedBookingCard({
    required this.booking,
    required this.highlighted,
    required this.onTap,
  });

  final _BookingView booking;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = booking.top.clamp(0, _calendarHeight - 30).toDouble();
    final height = booking.height.clamp(30, _calendarHeight - top).toDouble();
    final serviceColor =
        _parseColor(booking.serviceColor) ?? booking.employeeColor;
    final card = _BookingCardSurface(
      booking: booking,
      highlighted: highlighted,
      serviceColor: serviceColor,
      onTap: onTap,
    );

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: LongPressDraggable<_BookingView>(
        data: booking,
        feedback: SizedBox(
          width: 190,
          height: height.clamp(44, 110).toDouble(),
          child: Opacity(
            opacity: 0.92,
            child: _BookingCardSurface(
              booking: booking,
              highlighted: true,
              serviceColor: serviceColor,
              onTap: null,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      ),
    );
  }
}

class _BookingCardSurface extends StatelessWidget {
  const _BookingCardSurface({
    required this.booking,
    required this.highlighted,
    required this.serviceColor,
    required this.onTap,
  });

  final _BookingView booking;
  final bool highlighted;
  final Color serviceColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final employeeColor = _calendarCardColor(booking.employeeColor);
    final textColor = highlighted
        ? const Color(0xFF2F2300)
        : _readableTextColor(employeeColor);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 7, 6),
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFFFFF7D8) : employeeColor,
              border: Border.all(
                color: highlighted
                    ? AnnaColors.warning
                    : booking.employeeColor.withValues(alpha: 0.95),
                width: highlighted ? 2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: highlighted
                      ? const Color(0x80D4A000)
                      : booking.employeeColor.withValues(alpha: 0.40),
                  blurRadius: highlighted ? 22 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _CompactBookingCardContent(
              booking: booking,
              serviceColor: serviceColor,
              textColor: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionedTimeBlock extends StatelessWidget {
  const _PositionedTimeBlock({
    required this.block,
    required this.onTap,
  });

  final _TimeBlockView block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = block.top.clamp(0, _calendarHeight - 18).toDouble();
    final height = block.height.clamp(18, _calendarHeight - top).toDouble();
    return Positioned(
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: block.color.withValues(alpha: 0.82),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                block.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionedScheduleBlock extends StatelessWidget {
  const _PositionedScheduleBlock({required this.block});

  final _TimeBlockView block;

  @override
  Widget build(BuildContext context) {
    final top = block.top.clamp(0, _calendarHeight - 18).toDouble();
    final height = block.height.clamp(18, _calendarHeight - top).toDouble();
    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: block.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: block.color.withValues(alpha: 0.22)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            block.startTime == null || block.endTime == null
                ? AppLocalizations.of(context).tr('Turno')
                : '${block.startTime} - ${block.endTime}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AnnaColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SlotAction { booking, timeBlock }

enum _BlockRecurrence {
  none('none', 'Solo este dia'),
  weekly('weekly', 'Cada semana este dia'),
  weekdays('weekdays', 'Todos los dias laborales');

  const _BlockRecurrence(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class _SlotActionSheet extends StatelessWidget {
  const _SlotActionSheet({required this.draft});

  final CalendarSlotDraft draft;

  static Future<_SlotAction?> show(
    BuildContext context, {
    required CalendarSlotDraft draft,
  }) {
    return showModalBottomSheet<_SlotAction>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SlotActionSheet(draft: draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCode = t.locale.languageCode;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tr('Nuevo en calendario'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              DateFormat('d MMM yyyy HH:mm', localeCode).format(draft.startAt),
              style: TextStyle(color: AnnaColors.muted),
            ),
            const SizedBox(height: 16),
            _SheetActionTile(
              icon: Icons.add_circle_outline,
              title: t.tr('Nueva reserva'),
              subtitle: t.tr('Crear reserva con este empleado y horario.'),
              onTap: () => Navigator.of(context).pop(_SlotAction.booking),
            ),
            const SizedBox(height: 10),
            _SheetActionTile(
              icon: Icons.block_outlined,
              title: t.tr('Nueva pausa / bloqueo'),
              subtitle: t.tr('Bloquear este tramo en el calendario.'),
              onTap: () => Navigator.of(context).pop(_SlotAction.timeBlock),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x14E8FFF1),
      borderRadius: BorderRadius.circular(AnnaRadii.md),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnnaRadii.md),
        ),
      ),
    );
  }
}

class _TimeBlockDetailsSheet extends StatelessWidget {
  const _TimeBlockDetailsSheet({
    required this.api,
    required this.block,
    required this.onChanged,
  });

  final AnnaApi api;
  final _TimeBlockView block;
  final Future<void> Function() onChanged;

  static void show(
    BuildContext context, {
    required AnnaApi api,
    required _TimeBlockView block,
    required Future<void> Function() onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TimeBlockDetailsSheet(
        api: api,
        block: block,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = block.editable ? t.tr('Bloqueo') : block.label;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _DetailGrid(
              rows: [
                _DetailRow(t.tr('Motivo'), block.label),
                _DetailRow(t.tr('Empleado'), block.employeeName),
                _DetailRow(t.tr('Fecha'), block.date),
                _DetailRow(t.tr('Inicio'), block.startTime),
                _DetailRow(t.tr('Fin'), block.endTime),
                _DetailRow('ID', block.id),
              ],
            ),
            const SizedBox(height: 14),
            if (!block.editable)
              _ErrorPanel(
                t.tr(
                    'Este bloque pertenece al horario del empleado. Editalo desde la configuracion del horario del empleado.'),
              ),
            const SizedBox(height: 18),
            if (block.editable)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _TimeBlockFormSheet.show(
                          context,
                          api: api,
                          block: block,
                          onChanged: onChanged,
                        );
                      },
                      icon: Icon(Icons.edit_outlined),
                      label: Text(t.tr('Editar')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AnnaColors.danger,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _DeleteTimeBlockSheet.show(
                          context,
                          api: api,
                          block: block,
                          onChanged: onChanged,
                        );
                      },
                      icon: Icon(Icons.delete_outline),
                      label: Text(t.tr('Borrar')),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.tr('Cerrar')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeleteTimeBlockSheet extends StatefulWidget {
  const _DeleteTimeBlockSheet({
    required this.api,
    required this.block,
    required this.onChanged,
  });

  final AnnaApi api;
  final _TimeBlockView block;
  final Future<void> Function() onChanged;

  static void show(
    BuildContext context, {
    required AnnaApi api,
    required _TimeBlockView block,
    required Future<void> Function() onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DeleteTimeBlockSheet(
        api: api,
        block: block,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_DeleteTimeBlockSheet> createState() => _DeleteTimeBlockSheetState();
}

class _DeleteTimeBlockSheetState extends State<_DeleteTimeBlockSheet> {
  bool _working = false;
  String? _error;

  Future<void> _delete() async {
    final id = widget.block.id;
    if (id == null) {
      setState(() => _error = AppLocalizations.of(context)
          .tr('No se encontro el identificador del bloqueo.'));
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.api.deleteTimeBlock(id);
      if (!mounted) return;
      final onChanged = widget.onChanged;
      Navigator.of(context).pop();
      await onChanged();
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tr('Borrar bloqueo'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              widget.block.label,
              style: TextStyle(color: AnnaColors.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorPanel(_error!),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _working ? null : () => Navigator.pop(context),
                    child: Text(t.tr('Cancelar')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AnnaColors.danger,
                    ),
                    onPressed: _working ? null : _delete,
                    child: _working
                        ? const _ButtonSpinner()
                        : Text(t.tr('Borrar')),
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

class _TimeBlockFormSheet extends StatefulWidget {
  const _TimeBlockFormSheet({
    required this.api,
    required this.onChanged,
    this.draft,
    this.block,
  });

  final AnnaApi api;
  final CalendarSlotDraft? draft;
  final _TimeBlockView? block;
  final Future<void> Function() onChanged;

  static void show(
    BuildContext context, {
    required AnnaApi api,
    required Future<void> Function() onChanged,
    CalendarSlotDraft? draft,
    _TimeBlockView? block,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TimeBlockFormSheet(
        api: api,
        draft: draft,
        block: block,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_TimeBlockFormSheet> createState() => _TimeBlockFormSheetState();
}

class _TimeBlockFormSheetState extends State<_TimeBlockFormSheet> {
  static const _pauseReasons = ['Reunion', 'Enfermedad', 'Comida'];

  final _formKey = GlobalKey<FormState>();
  late Future<ApiCollection> _employees = widget.api.employees();
  late DateTime _date = _initialDate();
  late TimeOfDay _startTime = _initialStartTime();
  late TimeOfDay _endTime = _initialEndTime();
  late String? _employeeId =
      widget.block?.employeeId ?? widget.draft?.employeeId;
  late String _reason = _initialReason();
  _BlockRecurrence _recurrence = _BlockRecurrence.none;
  DateTime? _repeatUntil;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.block != null;

  DateTime _initialDate() {
    final blockDate = _parseDate(widget.block?.date);
    if (blockDate != null) return blockDate;
    final draftDate = widget.draft?.startAt;
    if (draftDate != null) {
      return DateTime(draftDate.year, draftDate.month, draftDate.day);
    }
    return _dateOnly(DateTime.now());
  }

  TimeOfDay _initialStartTime() {
    final blockStart = _parseTimeOfDay(widget.block?.startTime);
    if (blockStart != null) return blockStart;
    final draftStart = widget.draft?.startAt;
    if (draftStart != null) return TimeOfDay.fromDateTime(draftStart);
    return TimeOfDay.now();
  }

  TimeOfDay _initialEndTime() {
    final blockEnd = _parseTimeOfDay(widget.block?.endTime);
    if (blockEnd != null) return blockEnd;
    final start = widget.draft?.startAt;
    if (start != null) {
      return TimeOfDay.fromDateTime(start.add(const Duration(minutes: 30)));
    }
    final now = DateTime.now().add(const Duration(minutes: 30));
    return TimeOfDay.fromDateTime(now);
  }

  String _initialReason() {
    final current = widget.block?.label.trim();
    if (current != null && _pauseReasons.contains(current)) return current;
    return _pauseReasons.first;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _date.add(const Duration(days: 28)),
      firstDate: _date,
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _repeatUntil = _dateOnly(picked));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_employeeId == null) {
      setState(() => _error = 'Selecciona un empleado.');
      return;
    }
    if (_minutesOfDay(_endTime) <= _minutesOfDay(_startTime)) {
      setState(() => _error = 'La hora de fin debe ser posterior al inicio.');
      return;
    }
    if (!_isEditing &&
        _recurrence != _BlockRecurrence.none &&
        _repeatUntil == null) {
      setState(() => _error = 'Indica hasta que fecha se repite.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final id = widget.block?.id;
      if (_isEditing && id == null) {
        setState(() => _error = 'No se encontro el identificador del bloqueo.');
        return;
      }
      if (_isEditing) {
        await widget.api.updateTimeBlock(id!, _editPayload(id));
      } else {
        for (final payload in _createPayloads()) {
          await widget.api.createTimeBlock(payload);
        }
      }
      if (!mounted) return;
      final onChanged = widget.onChanged;
      Navigator.of(context).pop();
      await onChanged();
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _editPayload(String id) {
    if (id.startsWith('recurring-')) {
      return {
        'employee': _coerceId(_employeeId),
        'recurring': true,
        'start_time': _formatTimeOfDay(_startTime),
        'end_time': _formatTimeOfDay(_endTime),
        'reason': _reason,
        'color': '#111111',
      };
    }
    return {
      'employee': _coerceId(_employeeId),
      'start_at': _dateTimeText(_date, _startTime),
      'end_at': _dateTimeText(_date, _endTime),
      'reason': _reason,
      'color': '#111111',
    };
  }

  List<Map<String, dynamic>> _createPayloads() {
    if (_recurrence == _BlockRecurrence.none) {
      return [
        {
          'employee': _coerceId(_employeeId),
          'start_at': _dateTimeText(_date, _startTime),
          'end_at': _dateTimeText(_date, _endTime),
          'reason': _reason,
          'color': '#111111',
        }
      ];
    }

    final weekdays = _recurrence == _BlockRecurrence.weekly
        ? [_date.weekday - 1]
        : [0, 1, 2, 3, 4];
    return [
      for (final weekday in weekdays)
        {
          'employee': _coerceId(_employeeId),
          'recurring': true,
          'weekday': weekday,
          'start_time': _formatTimeOfDay(_startTime),
          'end_time': _formatTimeOfDay(_endTime),
          'date_from': DateFormat('yyyy-MM-dd').format(_date),
          if (_repeatUntil != null)
            'date_to': DateFormat('yyyy-MM-dd').format(_repeatUntil!),
          'reason': _reason,
          'color': '#111111',
        }
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCode = t.locale.languageCode;
    final dateText = DateFormat('d MMM yyyy', localeCode).format(_date);
    final untilText = _repeatUntil == null
        ? t.tr('Seleccionar')
        : DateFormat('d MMM yyyy', localeCode).format(_repeatUntil!);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FutureBuilder<ApiCollection>(
          future: _employees,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                error: snapshot.error!,
                onRetry: () => setState(() {
                  _employees = widget.api.employees();
                }),
              );
            }
            final employees = _dedupeEmployeeOptions(
              snapshot.data!.items
                  .map(_EmployeeOption.fromRecord)
                  .whereType<_EmployeeOption>()
                  .toList(),
            );
            final validEmployee =
                employees.any((employee) => employee.id == _employeeId);
            final selectedEmployeeId = validEmployee ? _employeeId : null;

            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing
                        ? t.tr('Editar bloqueo')
                        : t.tr('Nueva pausa / bloqueo'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedEmployeeId,
                    isExpanded: true,
                    dropdownColor: AnnaColors.accentDeep,
                    decoration: InputDecoration(
                      labelText: t.tr('Empleado'),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(
                            employee.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? t.tr('Selecciona empleado') : null,
                    onChanged: (value) => setState(() => _employeeId = value),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetPickerField(
                          label: t.tr('Fecha'),
                          value: dateText,
                          icon: Icons.event_outlined,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SheetPickerField(
                          label: t.tr('Inicio'),
                          value: _startTime.format(context),
                          icon: Icons.schedule,
                          onTap: _pickStartTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SheetPickerField(
                    label: t.tr('Fin'),
                    value: _endTime.format(context),
                    icon: Icons.schedule_outlined,
                    onTap: _pickEndTime,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    isExpanded: true,
                    dropdownColor: AnnaColors.accentDeep,
                    decoration: InputDecoration(
                      labelText: t.tr('Motivo'),
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    items: [
                      for (final reason in _pauseReasons)
                        DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? t.tr('Selecciona un motivo') : null,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _reason = value);
                    },
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<_BlockRecurrence>(
                      initialValue: _recurrence,
                      isExpanded: true,
                      dropdownColor: AnnaColors.accentDeep,
                      decoration: InputDecoration(
                        labelText: t.tr('Recurrencia'),
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: [
                        for (final value in _BlockRecurrence.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(t.tr(value.label)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _recurrence = value;
                          if (value == _BlockRecurrence.none) {
                            _repeatUntil = null;
                          } else {
                            _repeatUntil ??=
                                _date.add(const Duration(days: 28));
                          }
                        });
                      },
                    ),
                    if (_recurrence != _BlockRecurrence.none) ...[
                      const SizedBox(height: 14),
                      _SheetPickerField(
                        label: t.tr('Hasta'),
                        value: untilText,
                        icon: Icons.event_repeat_outlined,
                        onTap: _pickRepeatUntil,
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorPanel(_error!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon:
                          _saving ? const _ButtonSpinner() : Icon(Icons.check),
                      label: Text(
                          _isEditing ? t.tr('Guardar') : t.tr('Crear bloqueo')),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmployeeOption {
  const _EmployeeOption({required this.id, required this.name});

  final String id;
  final String name;

  static _EmployeeOption? fromRecord(ApiRecord record) {
    final id = record.valueAsText('id') ?? record.valueAsText('pk');
    if (id == null) return null;
    final first = record.valueAsText('first_name') ?? '';
    final last = record.valueAsText('last_name') ?? '';
    final composed = '$first $last'.trim();
    final name = record.valueAsText('full_name') ??
        record.valueAsText('name') ??
        (composed.isNotEmpty ? composed : 'Empleado $id');
    return _EmployeeOption(id: id, name: name);
  }
}

List<_EmployeeOption> _dedupeEmployeeOptions(List<_EmployeeOption> options) {
  final byId = <String, _EmployeeOption>{};
  for (final option in options) {
    byId.putIfAbsent(option.id, () => option);
  }
  return byId.values.toList();
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

// ignore: unused_element
class _BookingCardContent extends StatelessWidget {
  const _BookingCardContent({required this.booking});

  final _BookingView booking;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    booking.timeRange ?? '',
                    style: TextStyle(
                      color: Color(0xFF1E5B3C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (booking.statusLabel != null)
                  _SmallStatusDot(label: booking.statusLabel!),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              booking.clientName ?? AppLocalizations.of(context).booking,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AnnaColors.bookingText,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (booking.serviceName != null)
              Text(
                booking.serviceName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF2F5C45),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 3),
            Text(
              [
                booking.employeeName,
                booking.zoneName,
                booking.statusLabel,
              ]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF567865),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactBookingCardContent extends StatelessWidget {
  const _CompactBookingCardContent({
    required this.booking,
    required this.serviceColor,
    required this.textColor,
  });

  final _BookingView booking;
  final Color serviceColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLines = (constraints.maxHeight / 12).floor().clamp(1, 6);
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (booking.timeRange != null && maxLines > 2)
                Text(
                  booking.timeRange!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.82),
                    fontSize: 9.5,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Row(
                children: [
                  _ServiceColorDot(color: serviceColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      booking.clientName ??
                          AppLocalizations.of(context).booking,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10.8,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (booking.serviceName != null && maxLines > 1)
                Text(
                  booking.serviceName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.90),
                    fontSize: 10,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (maxLines > 3)
                Text(
                  [
                    booking.zoneName,
                    booking.statusLabel,
                    booking.paymentStateLabel,
                  ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.78),
                    fontSize: 9,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceColorDot extends StatelessWidget {
  const _ServiceColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xF2FFFFFF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 5,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
    );
  }
}

Color _calendarCardColor(Color employeeColor) {
  if (employeeColor.computeLuminance() > 0.62) {
    return Color.lerp(employeeColor, const Color(0xFF1A2B22), 0.28)!;
  }
  return Color.lerp(employeeColor, const Color(0xFF101A16), 0.12)!;
}

Color _readableTextColor(Color background) {
  return background.computeLuminance() > 0.48
      ? const Color(0xFF102018)
      : Colors.white;
}

// ignore: unused_element
class _LegacyCompactBookingCardContent extends StatelessWidget {
  const _LegacyCompactBookingCardContent({required this.booking});

  final _BookingView booking;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLines = (constraints.maxHeight / 12).floor().clamp(1, 6);
        final text = [
          booking.timeRange,
          booking.clientName ?? AppLocalizations.of(context).booking,
          booking.serviceName,
          [
            booking.employeeName,
            booking.zoneName,
            booking.statusLabel,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
        ].whereType<String>().where((value) => value.isNotEmpty).join('\n');

        return ClipRect(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AnnaColors.bookingText,
              fontSize: 10.5,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }
}

class _SmallStatusDot extends StatelessWidget {
  const _SmallStatusDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF7E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color(0xFF17603A),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BookingEditSheet extends StatefulWidget {
  const _BookingEditSheet({
    required this.api,
    required this.booking,
    required this.onChanged,
  });

  final AnnaApi api;
  final _BookingView booking;
  final Future<void> Function() onChanged;

  static void show(
    BuildContext context, {
    required AnnaApi api,
    required _BookingView booking,
    required Future<void> Function() onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BookingEditSheet(
        api: api,
        booking: booking,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_BookingEditSheet> createState() => _BookingEditSheetState();
}

class _BookingEditSheetState extends State<_BookingEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  late Future<_BookingEditReferences> _references = _loadReferences();
  late DateTime _date =
      _parseDateTime(widget.booking.startAt) ?? DateTime.now();
  late TimeOfDay _time = TimeOfDay.fromDateTime(_date);
  String? _clientId;
  String? _serviceId;
  String? _employeeId;
  String? _zoneId;
  String _status = 'confirmed';
  String _source = 'manual';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    _clientId = booking.clientId;
    _serviceId = booking.serviceId;
    _employeeId = booking.employeeId;
    _zoneId = booking.zoneId;
    _status = booking.status ?? 'confirmed';
    _source = booking.source ?? 'manual';
    _notesController.text = booking.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<_BookingEditReferences> _loadReferences() async {
    final results = await Future.wait([
      widget.api.clients(),
      widget.api.services(),
      widget.api.employees(),
      widget.api.zones(),
      if (widget.booking.id != null)
        widget.api.bookingDetail(widget.booking.id!),
    ]);
    if (results.length == 5) {
      final detail = results[4] as ApiDocument;
      _syncDetail(detail.data);
    }
    return _BookingEditReferences(
      clients: results[0] as ApiCollection,
      services: results[1] as ApiCollection,
      employees: results[2] as ApiCollection,
      zones: results[3] as ApiCollection,
    );
  }

  void _syncDetail(Map<String, dynamic> data) {
    _clientId = _firstText([
          _textValue(data, 'client_id'),
          _nestedText(data['client'], 'id'),
        ]) ??
        _clientId;
    _serviceId = _firstText([
          _textValue(data, 'service_id'),
          _nestedText(data['service'], 'id'),
        ]) ??
        _serviceId;
    _employeeId = _firstText([
          _textValue(data, 'employee_id'),
          _nestedText(data['employee'], 'id'),
        ]) ??
        _employeeId;
    _zoneId = _firstText([
          _textValue(data, 'zone_id'),
          _nestedText(data['zone'], 'id'),
        ]) ??
        _zoneId;
    _status = _textValue(data, 'status') ?? _status;
    _source = _textValue(data, 'source') ?? _source;
    final start = DateTime.tryParse(_textValue(data, 'start_at') ?? '');
    if (start != null) {
      _date = start;
      _time = TimeOfDay.fromDateTime(start);
    }
    _notesController.text = _textValue(data, 'notes') ?? _notesController.text;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _time.hour,
        _time.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() {
      _time = picked;
      _date = DateTime(
          _date.year, _date.month, _date.day, picked.hour, picked.minute);
    });
  }

  _EditOption? _selectedService(_BookingEditReferences refs) {
    return refs.optionById(refs.serviceOptions, _serviceId);
  }

  _EditOption? _selectedEmployee(_BookingEditReferences refs) {
    return refs.optionById(refs.employeeOptions, _employeeId);
  }

  void _changeService(_BookingEditReferences refs, String? value) {
    setState(() {
      _serviceId = value;
      final service = _selectedService(refs);
      if (service == null) {
        _zoneId = null;
        return;
      }
      if (_employeeId != null &&
          !refs.employeeSupportsService(_employeeId, service)) {
        _employeeId = null;
      }
      if (!service.requiresZone ||
          !refs.zoneAllowedForService(_zoneId, service)) {
        _zoneId = null;
      }
      _error = null;
    });
  }

  void _changeEmployee(_BookingEditReferences refs, String? value) {
    setState(() {
      _employeeId = value;
      final employee = _selectedEmployee(refs);
      final service = _selectedService(refs);
      if (employee != null &&
          service != null &&
          !refs.employeeSupportsService(employee.id, service)) {
        _serviceId = null;
        _zoneId = null;
      }
      _error = null;
    });
  }

  bool _validateSelection(_BookingEditReferences refs) {
    final service = _selectedService(refs);
    final employee = _selectedEmployee(refs);
    if (service == null) {
      setState(() => _error = 'Selecciona un servicio valido.');
      return false;
    }
    if (employee == null) {
      setState(() => _error = 'Selecciona un empleado valido.');
      return false;
    }
    if (!refs.employeeSupportsService(employee.id, service)) {
      setState(
        () => _error = 'Este empleado no realiza el servicio seleccionado.',
      );
      return false;
    }
    if (!service.requiresZone && _zoneId != null && _zoneId!.isNotEmpty) {
      setState(() => _zoneId = null);
    }
    if (service.requiresZone &&
        _zoneId != null &&
        _zoneId!.isNotEmpty &&
        !refs.zoneAllowedForService(_zoneId, service)) {
      setState(
        () => _error =
            'La zona seleccionada no esta permitida para este servicio.',
      );
      return false;
    }
    return true;
  }

  Future<void> _save(_BookingEditReferences refs) async {
    final id = widget.booking.id;
    if (id == null) {
      setState(() => _error = 'No se encontro el identificador de la reserva.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateSelection(refs)) return;
    final startAt = _formatApiDateTime(_date);
    final zone =
        _zoneId == null || _zoneId!.isEmpty ? null : _coerceId(_zoneId);
    final payload = <String, dynamic>{
      'client': _coerceId(_clientId),
      'service': _coerceId(_serviceId),
      'employee': _coerceId(_employeeId),
      'zone': zone,
      'start_at': startAt,
      'status': _status,
      'source': _source,
      'notes': _notesController.text.trim(),
    };

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final availability = await widget.api.checkAvailability({
        'service': _coerceId(_serviceId),
        'employee': _coerceId(_employeeId),
        'start_at': startAt,
        'exclude_booking_id': _coerceId(id),
        if (zone != null) 'zone': zone,
      });
      if (availability.data['available'] == false) {
        setState(() {
          _error = _textFromMap(availability.data, 'message') ??
              'Ese horario no esta disponible.';
          _saving = false;
        });
        return;
      }
      final availableZone = _textFromMap(availability.data, 'zone');
      if (availableZone != null && zone == null) {
        payload['zone'] = _coerceId(availableZone);
      }
      await widget.api.updateBooking(id, payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).tr('Reserva actualizada.')),
        ),
      );
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCode = t.locale.languageCode;
    return SafeArea(
      child: FutureBuilder<_BookingEditReferences>(
        future: _references,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: ErrorState(
                  error: snapshot.error!,
                  onRetry: () {
                    setState(() => _references = _loadReferences());
                  }),
            );
          }
          final refs = snapshot.data!;
          final selectedEmployee = _selectedEmployee(refs);
          final selectedService = _selectedService(refs);
          final serviceOptions = selectedEmployee == null
              ? refs.serviceOptions
              : refs.servicesForEmployee(selectedEmployee);
          final employeeOptions = selectedService == null
              ? refs.employeeOptions
              : refs.employeesForService(selectedService);
          final zoneOptions = selectedService?.requiresZone == true
              ? refs.zonesForService(selectedService!)
              : const <_EditOption>[];
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.tr('Editar reserva'),
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Cliente'),
                    icon: Icons.person_outline,
                    value: _clientId,
                    options: refs.clientOptions,
                    onChanged: (value) => setState(() => _clientId = value),
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Servicio'),
                    icon: Icons.spa_outlined,
                    value: _serviceId,
                    options: serviceOptions,
                    onChanged: (value) => _changeService(refs, value),
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Empleado'),
                    icon: Icons.badge_outlined,
                    value: _employeeId,
                    options: employeeOptions,
                    onChanged: (value) => _changeEmployee(refs, value),
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Zona'),
                    icon: Icons.place_outlined,
                    value: _zoneId,
                    options: [
                      _EditOption('', t.tr('Zona automatica')),
                      ...zoneOptions,
                    ],
                    requiredField: false,
                    onChanged: (value) => setState(() => _zoneId = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetPickerField(
                          label: t.tr('Fecha'),
                          value: DateFormat('d MMM yyyy', localeCode)
                              .format(_date),
                          icon: Icons.event_outlined,
                          onTap: _saving ? null : _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SheetPickerField(
                          label: t.tr('Hora'),
                          value: _time.format(context),
                          icon: Icons.schedule,
                          onTap: _saving ? null : _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Estado'),
                    icon: Icons.flag_outlined,
                    value: _status,
                    options: _statusOptions,
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'confirmed'),
                  ),
                  const SizedBox(height: 12),
                  _EditDropdown(
                    label: t.tr('Origen'),
                    icon: Icons.campaign_outlined,
                    value: _source,
                    options: _sourceOptions,
                    onChanged: (value) =>
                        setState(() => _source = value ?? 'manual'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: t.tr('Notas'),
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorPanel(_error!),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(refs),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.save_outlined),
                      label: Text(t.tr('Guardar cambios')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingEditReferences {
  const _BookingEditReferences({
    required this.clients,
    required this.services,
    required this.employees,
    required this.zones,
  });

  final ApiCollection clients;
  final ApiCollection services;
  final ApiCollection employees;
  final ApiCollection zones;

  List<_EditOption> get clientOptions => _options(clients.items, (record) {
        return record.valueAsText('full_name') ??
            record.valueAsText('name') ??
            'Cliente ${record.valueAsText('id') ?? ''}';
      });

  List<_EditOption> get serviceOptions => _options(services.items, (record) {
        return record.valueAsText('name') ??
            'Servicio ${record.valueAsText('id') ?? ''}';
      });

  List<_EditOption> get employeeOptions => _options(employees.items, (record) {
        return record.valueAsText('full_name') ??
            record.valueAsText('name') ??
            'Empleado ${record.valueAsText('id') ?? ''}';
      });

  List<_EditOption> get zoneOptions => _options(zones.items, (record) {
        return record.valueAsText('name') ??
            'Zona ${record.valueAsText('id') ?? ''}';
      });

  _EditOption? optionById(List<_EditOption> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  List<_EditOption> zonesForService(_EditOption service) {
    if (!service.requiresZone || service.allowedZoneIds.isEmpty) {
      return const [];
    }
    return zoneOptions.where((zone) {
      return service.allowedZoneIds.contains(zone.id);
    }).toList();
  }

  List<_EditOption> employeesForService(_EditOption service) {
    final linkedEmployees = service.employeeIds;
    return employeeOptions.where((employee) {
      if (employee.serviceIds.contains(service.id)) return true;
      if (linkedEmployees.contains(employee.id)) return true;
      return employee.serviceIds.isEmpty && linkedEmployees.isEmpty;
    }).toList();
  }

  List<_EditOption> servicesForEmployee(_EditOption employee) {
    final linkedServices = employee.serviceIds;
    return serviceOptions.where((service) {
      if (linkedServices.contains(service.id)) return true;
      if (service.employeeIds.contains(employee.id)) return true;
      return linkedServices.isEmpty && service.employeeIds.isEmpty;
    }).toList();
  }

  bool employeeSupportsService(String? employeeId, _EditOption service) {
    if (employeeId == null) return false;
    return employeesForService(service).any((employee) {
      return employee.id == employeeId;
    });
  }

  bool zoneAllowedForService(String? zoneId, _EditOption service) {
    if (!service.requiresZone) return zoneId == null || zoneId.isEmpty;
    if (zoneId == null || zoneId.isEmpty) return true;
    return zonesForService(service).any((zone) => zone.id == zoneId);
  }

  static List<_EditOption> _options(
    List<ApiRecord> records,
    String Function(ApiRecord) labelBuilder,
  ) {
    final byId = <String, _EditOption>{};
    for (final record in records) {
      final id = record.valueAsText('id') ?? record.valueAsText('pk');
      if (id == null) continue;
      byId.putIfAbsent(
        id,
        () => _EditOption(
          id,
          labelBuilder(record),
          requiresZone:
              _boolValue(record, const ['requires_zone', 'zone_required']),
          allowedZoneIds: _idSet(
              record, const ['allowed_zone_ids', 'allowed_zones', 'zones']),
          serviceIds: _idSet(record, const ['service_ids', 'services']),
          employeeIds: _idSet(record, const ['employee_ids', 'employees']),
        ),
      );
    }
    return byId.values.toList();
  }

  static bool _boolValue(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final value = record.data[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
      }
    }
    return false;
  }

  static Set<String> _idSet(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final raw = record.data[key];
      if (raw is! List) continue;
      return raw
          .map((item) {
            if (item is Map) {
              return (item['id'] ?? item['pk'] ?? item['value'])?.toString();
            }
            return item?.toString();
          })
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet();
    }
    return const {};
  }
}

class _EditDropdown extends StatelessWidget {
  const _EditDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requiredField = true,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<_EditOption> options;
  final ValueChanged<String?> onChanged;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final byId = <String, _EditOption>{};
    for (final option in options) {
      byId.putIfAbsent(option.id, () => option);
    }
    final filtered = byId.values.toList();
    final selected =
        filtered.any((option) => option.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      dropdownColor: AnnaColors.accentDeep,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final option in filtered)
          DropdownMenuItem(
            value: option.id,
            child: Text(
              t.tr(option.label),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (value) => requiredField && (value == null || value.isEmpty)
          ? t.selectField(label)
          : null,
      onChanged: onChanged,
    );
  }
}

class _EditOption {
  const _EditOption(
    this.id,
    this.label, {
    this.requiresZone = false,
    this.allowedZoneIds = const {},
    this.serviceIds = const {},
    this.employeeIds = const {},
  });

  final String id;
  final String label;
  final bool requiresZone;
  final Set<String> allowedZoneIds;
  final Set<String> serviceIds;
  final Set<String> employeeIds;
}

const _statusOptions = [
  _EditOption('pending', 'Pendiente'),
  _EditOption('confirmed', 'Confirmada'),
  _EditOption('in_progress', 'En curso'),
  _EditOption('done', 'Hecha'),
  _EditOption('cancelled', 'Cancelada'),
  _EditOption('no_show', 'No asistio'),
];

const _sourceOptions = [
  _EditOption('manual', 'Manual'),
  _EditOption('whatsapp', 'WhatsApp'),
  _EditOption('website', 'Sitio web'),
  _EditOption('instagram', 'Instagram'),
  _EditOption('phone', 'Telefono'),
  _EditOption('walk_in', 'En el salon'),
  _EditOption('referral', 'Por recomendacion'),
  _EditOption('employee', 'Por empleado'),
  _EditOption('google', 'Google / Maps'),
  _EditOption('other', 'Otro'),
];

class _BookingActionsSheet extends StatefulWidget {
  const _BookingActionsSheet({
    required this.api,
    required this.canManageStaff,
    required this.currentEmployeeId,
    required this.booking,
    required this.onChanged,
    required this.onEdit,
  });

  final AnnaApi api;
  final bool canManageStaff;
  final String? currentEmployeeId;
  final _BookingView booking;
  final Future<void> Function() onChanged;
  final VoidCallback onEdit;

  static void show(
    BuildContext context, {
    required AnnaApi api,
    required bool canManageStaff,
    required String? currentEmployeeId,
    required _BookingView booking,
    required Future<void> Function() onChanged,
    required VoidCallback onEdit,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _BookingActionsSheet(
          api: api,
          canManageStaff: canManageStaff,
          currentEmployeeId: currentEmployeeId,
          booking: booking,
          onChanged: onChanged,
          onEdit: onEdit,
        );
      },
    );
  }

  @override
  State<_BookingActionsSheet> createState() => _BookingActionsSheetState();
}

class _BookingActionsSheetState extends State<_BookingActionsSheet> {
  _BookingView get booking => widget.booking;

  late DateTime _rescheduleDate =
      _parseDateTime(widget.booking.startAt) ?? DateTime.now();
  late TimeOfDay _rescheduleTime = TimeOfDay.fromDateTime(_rescheduleDate);
  bool _showReschedule = false;
  bool _working = false;
  String? _error;

  Future<void> _openScreen(Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DecoratedBox(
          decoration: annaBackgroundDecoration(context),
          child: SafeArea(child: screen),
        ),
      ),
    );
  }

  Future<void> _openClient() async {
    final id = booking.clientId;
    if (id == null) return;
    await showClientDetailSheet(
      context,
      api: widget.api,
      clientId: id,
      clientName: booking.clientName,
      canManagePhotos: widget.canManageStaff,
      onChanged: () => widget.onChanged(),
    );
  }

  Future<void> _openService() async {
    final id = booking.serviceId;
    if (id == null) return;
    await _openScreen(
      ServicesScreen(
        api: widget.api,
        canManageStaff: widget.canManageStaff,
        initialServiceId: id,
      ),
    );
  }

  Future<void> _openEmployee() async {
    final id = booking.employeeId;
    if (id == null) return;
    await showEmployeeDetailSheet(
      context,
      api: widget.api,
      employeeId: id,
      canManageStaff: widget.canManageStaff,
      currentEmployeeId: widget.currentEmployeeId,
      onChanged: () => widget.onChanged(),
    );
  }

  Future<void> _openCashbox() {
    return _openScreen(CashboxScreen(api: widget.api));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      final onChanged = widget.onChanged;
      Navigator.of(context).pop();
      await onChanged();
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final id = booking.id;
    if (id == null) {
      setState(() => _error = 'No se encontro el identificador de la reserva.');
      return;
    }
    await _runAction(() async {
      await widget.api.updateBookingStatus(id, status);
    });
  }

  Future<void> _updatePrepayment(bool required) async {
    final id = booking.id;
    if (id == null) {
      setState(() => _error = 'No se encontro el identificador de la reserva.');
      return;
    }
    await _runAction(() async {
      await widget.api.updateBookingPrepayment(id, required);
    });
  }

  Future<void> _openCheckoutDocument() async {
    final id = booking.id;
    if (id == null) {
      setState(() => _error = 'No se encontro el identificador de la reserva.');
      return;
    }
    final documentType = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) {
        final t = AppLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('Cobro y documento'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, 'receipt'),
                  child: Text(t.tr('Recibo')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, 'invoice'),
                  child: Text(t.tr('Factura')),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || documentType == null) return;
    setState(() => _working = true);
    try {
      final response = await widget.api.createCashDocument(
        id,
        {'document_type': documentType},
      );
      if (!mounted) return;
      await showCashDocumentSheet(
        context,
        api: widget.api,
        documentId: response.data['id'].toString(),
        onChanged: widget.onChanged,
      );
      await widget.onChanged();
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickRescheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rescheduleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _rescheduleDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _rescheduleTime.hour,
        _rescheduleTime.minute,
      );
    });
  }

  Future<void> _pickRescheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _rescheduleTime,
    );
    if (picked == null) return;
    setState(() {
      _rescheduleTime = picked;
      _rescheduleDate = DateTime(
        _rescheduleDate.year,
        _rescheduleDate.month,
        _rescheduleDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _reschedule() async {
    final id = booking.id;
    if (id == null) {
      setState(() => _error = 'No se encontro el identificador de la reserva.');
      return;
    }
    final serviceId = booking.serviceId;
    final employeeId = booking.employeeId;
    if (serviceId == null || employeeId == null) {
      setState(
        () => _error =
            'Faltan servicio o empleado para comprobar disponibilidad.',
      );
      return;
    }

    final startAt = _formatApiDateTime(_rescheduleDate);
    final availabilityPayload = <String, dynamic>{
      'service': _coerceId(serviceId),
      'employee': _coerceId(employeeId),
      'start_at': startAt,
      'exclude_booking_id': _coerceId(id),
    };
    if (booking.zoneId != null) {
      availabilityPayload['zone'] = _coerceId(booking.zoneId);
    }

    final reschedulePayload = <String, dynamic>{
      'start_at': startAt,
      'service': _coerceId(serviceId),
      'employee': _coerceId(employeeId),
    };
    if (booking.zoneId != null) {
      reschedulePayload['zone'] = _coerceId(booking.zoneId);
    }

    await _runAction(() async {
      await widget.api.checkAvailability(availabilityPayload);
      await widget.api.rescheduleBooking(id, reschedulePayload);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final currentStatus = (booking.status ?? '').trim().toLowerCase();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.clientName ?? AppLocalizations.of(context).booking,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              [
                booking.timeRange,
                booking.serviceName,
                booking.employeeName,
                booking.zoneName,
                booking.statusLabel,
              ]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              style: TextStyle(color: AnnaColors.muted),
            ),
            const SizedBox(height: 14),
            _DetailGrid(
              rows: [
                _DetailRow(t.tr('Cliente'), booking.clientName,
                    onTap: booking.clientId == null ? null : _openClient),
                _DetailRow(t.tr('Servicio'), booking.serviceName,
                    onTap: booking.serviceId == null ? null : _openService),
                _DetailRow(t.tr('Empleado'), booking.employeeName,
                    onTap: booking.employeeId == null ? null : _openEmployee),
                _DetailRow(t.tr('Zona'), booking.zoneName),
                _DetailRow(t.tr('Inicio'), _formatDateTime(booking.startAt)),
                _DetailRow(t.tr('Fin'), _formatDateTime(booking.endAt)),
                _DetailRow(t.tr('Estado'), booking.statusLabel),
                _DetailRow(t.tr('Pago'), booking.paymentStateLabel),
                _DetailRow(t.tr('Prepago'), booking.prepaymentStateLabel),
                _DetailRow(t.tr('Limite de prepago'),
                    _formatDateTime(booking.prepaymentDeadlineAt)),
                _DetailRow(t.tr('Origen'), booking.sourceLabel),
                _DetailRow(t.tr('Precio'), booking.priceSnapshot),
                _DetailRow(t.tr('Duracion'), booking.durationSnapshot),
                _DetailRow(t.tr('Notas'), booking.notes),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorPanel(_error!),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatusButton(
                  label: AppLocalizations.of(context).tr('Confirmar'),
                  icon: Icons.check_circle_outline,
                  selected: currentStatus == 'confirmed',
                  onPressed: _working || currentStatus == 'confirmed'
                      ? null
                      : () => _updateStatus('confirmed'),
                ),
                _StatusButton(
                  label: AppLocalizations.of(context).tr('Pendiente'),
                  icon: Icons.hourglass_bottom,
                  selected: currentStatus == 'pending',
                  onPressed: _working || currentStatus == 'pending'
                      ? null
                      : () => _updateStatus('pending'),
                ),
                _StatusButton(
                  label: AppLocalizations.of(context).tr('Cancelar'),
                  icon: Icons.cancel_outlined,
                  danger: true,
                  selected: currentStatus == 'cancelled',
                  onPressed: _working || currentStatus == 'cancelled'
                      ? null
                      : () => _updateStatus('cancelled'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: booking.prepaymentState == 'awaiting'
                  ? OutlinedButton.icon(
                      onPressed:
                          _working ? null : () => _updatePrepayment(false),
                      icon: Icon(Icons.money_off_outlined),
                      label:
                          Text(t.tr('No requerir prepago · pago en el salon')),
                    )
                  : FilledButton.tonalIcon(
                      onPressed:
                          _working ? null : () => _updatePrepayment(true),
                      icon: Icon(Icons.send_outlined),
                      label: Text(t.tr('Enviar enlace de prepago')),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _working ? null : _openCashbox,
                  icon: Icon(Icons.point_of_sale_outlined),
                  label: Text(t.tr('Caja')),
                ),
                FilledButton.tonalIcon(
                  onPressed: _working ? null : _openCheckoutDocument,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text(t.tr('Cobrar')),
                ),
                FilledButton.icon(
                  onPressed: _working
                      ? null
                      : () => setState(
                            () => _showReschedule = !_showReschedule,
                          ),
                  icon: Icon(Icons.schedule),
                  label: Text(t.tr('Reprogramar')),
                ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onEdit();
                        },
                  icon: Icon(Icons.edit_outlined),
                  label: Text(t.tr('Editar')),
                ),
              ],
            ),
            if (_showReschedule) ...[
              const SizedBox(height: 18),
              PanelCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.tr('Reprogramar'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetPickerField(
                            label: t.tr('Fecha'),
                            value:
                                DateFormat('d MMM yyyy', t.locale.languageCode)
                                    .format(_rescheduleDate),
                            icon: Icons.event_outlined,
                            onTap: _working ? null : _pickRescheduleDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SheetPickerField(
                            label: t.tr('Hora'),
                            value: _rescheduleTime.format(context),
                            icon: Icons.schedule,
                            onTap: _working ? null : _pickRescheduleTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _reschedule,
                        icon: _working
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.check),
                        label: Text(t.tr('Comprobar y reprogramar')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_working && !_showReschedule) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value, {this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows
        .where((row) => row.value != null && row.value!.trim().isNotEmpty)
        .toList();
    if (visibleRows.isEmpty) {
      return Text(
        AppLocalizations.of(context).tr('Sin datos adicionales.'),
        style: TextStyle(color: AnnaColors.muted),
      );
    }

    return Column(
      children: [
        for (final row in visibleRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: AnnaColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(child: _DetailValue(row: row)),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.row});

  final _DetailRow row;

  @override
  Widget build(BuildContext context) {
    if (row.onTap == null) {
      return Text(row.value!, style: TextStyle(fontWeight: FontWeight.w700));
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: row.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.value!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new,
                size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          selected
              ? '$label · ${AppLocalizations.of(context).isRussian ? 'Текущий' : 'Actual'}'
              : label,
        ),
      ],
    );
    if (selected) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: AnnaColors.text,
          disabledBackgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        child: child,
      );
    }
    if (danger) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD7CA),
          side: const BorderSide(color: Color(0x66D47D68)),
        ),
        child: child,
      );
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _SheetPickerField extends StatelessWidget {
  const _SheetPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AnnaRadii.md),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnnaErrorBanner(message);
  }
}

class _CalendarDayData {
  const _CalendarDayData({
    required this.date,
    required this.bookings,
    required this.employees,
  });

  final DateTime date;
  final List<_BookingView> bookings;
  final List<_CalendarEmployee> employees;

  factory _CalendarDayData.fromCollection(
    ApiCollection collection, {
    required DateTime fallbackDate,
    required Map<String, String> employeeColorCache,
    required Map<String, String> serviceColorCache,
  }) {
    final raw = collection.raw;
    final date = raw is Map<String, dynamic>
        ? _parseDate(_textFromMap(raw, 'date')) ?? fallbackDate
        : fallbackDate;
    final employeeItems = raw is Map<String, dynamic> ? raw['employees'] : null;
    final employees = employeeItems is List
        ? employeeItems
            .whereType<Map>()
            .map((item) => _CalendarEmployee.fromCalendarItem(
                  item,
                  employeeColorCache: employeeColorCache,
                ))
            .whereType<_CalendarEmployee>()
            .toList()
        : const <_CalendarEmployee>[];
    final employeeById = {
      for (final employee in employees) _normalizeKey(employee.id): employee
    };
    final bookings = collection.items
        .map((record) => _BookingView.fromRecord(
              record,
              employeeById,
              employeeColorCache,
              serviceColorCache,
            ))
        .toList()
      ..sort((a, b) => (a.startAt ?? '').compareTo(b.startAt ?? ''));

    return _CalendarDayData(
      date: date,
      bookings: bookings,
      employees: employees,
    );
  }

  _CalendarDayData filteredByEmployees(Set<String>? employeeIds) {
    if (employeeIds == null) return this;
    final selectedEmployees = employees
        .where((employee) => employeeIds.contains(employee.id))
        .toList();
    return _CalendarDayData(
      date: date,
      bookings: bookings
          .where((booking) => selectedEmployees
              .any((employee) => booking.matchesEmployee(employee)))
          .toList(),
      employees: selectedEmployees,
    );
  }
}

class _CalendarEmployee {
  const _CalendarEmployee({
    required this.id,
    required this.name,
    required this.color,
    required this.hasSchedule,
    required this.blocks,
    this.firstName,
  });

  final String id;
  final String name;
  final String? firstName;
  final Color color;
  final bool hasSchedule;
  final List<_TimeBlockView> blocks;

  static _CalendarEmployee? fromCalendarItem(
    Map item, {
    required Map<String, String> employeeColorCache,
  }) {
    final employee = item['employee'];
    final employeeMap = employee is Map ? employee : item;
    final id =
        _textFromMap(employeeMap, 'id') ?? _textFromMap(employeeMap, 'pk');
    if (id == null) return null;
    final firstName = _textFromMap(employeeMap, 'first_name');
    final lastName = _textFromMap(employeeMap, 'last_name');
    final composedName = [firstName, lastName]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    final name = _textFromMap(employeeMap, 'full_name') ??
        _textFromMap(employeeMap, 'name') ??
        (composedName.isNotEmpty ? composedName : null) ??
        'Empleado $id';
    final color = _parseColor(_textFromMap(employeeMap, 'calendar_color')) ??
        _parseColor(employeeColorCache[id]) ??
        const Color(0xFFC75C8B);

    return _CalendarEmployee(
      id: id,
      name: name,
      firstName: firstName,
      color: color,
      hasSchedule: item['schedule'] != null,
      blocks: _timeBlocksFromEmployeeItem(
        item,
        employeeId: id,
        employeeName: name,
      ),
    );
  }
}

class _TimeBlockView {
  const _TimeBlockView({
    required this.label,
    required this.color,
    required this.top,
    required this.height,
    required this.editable,
    required this.kind,
    this.id,
    this.employeeId,
    this.employeeName,
    this.date,
    this.startTime,
    this.endTime,
  });

  final String label;
  final Color color;
  final double top;
  final double height;
  final bool editable;
  final _TimeBlockKind kind;
  final String? id;
  final String? employeeId;
  final String? employeeName;
  final String? date;
  final String? startTime;
  final String? endTime;
}

enum _TimeBlockKind { schedule, breakBlock, timeBlock }

class _BookingView {
  const _BookingView({
    required this.record,
    required this.employeeColor,
    required this.employeeKeys,
    this.id,
    this.clientId,
    this.employeeId,
    this.serviceId,
    this.zoneId,
    this.startAt,
    this.endAt,
    this.clientName,
    this.serviceName,
    this.employeeName,
    this.zoneName,
    this.status,
    this.statusLabel,
    this.paymentState,
    this.paymentStateLabel,
    this.prepaymentState,
    this.prepaymentStateLabel,
    this.prepaymentDeadlineAt,
    this.source,
    this.sourceLabel,
    this.notes,
    this.priceSnapshot,
    this.durationSnapshot,
    this.serviceColor,
  });

  final ApiRecord record;
  final Set<String> employeeKeys;
  final String? id;
  final String? clientId;
  final String? employeeId;
  final String? serviceId;
  final String? zoneId;
  final String? startAt;
  final String? endAt;
  final String? clientName;
  final String? serviceName;
  final String? employeeName;
  final String? zoneName;
  final String? status;
  final String? statusLabel;
  final String? paymentState;
  final String? paymentStateLabel;
  final String? prepaymentState;
  final String? prepaymentStateLabel;
  final String? prepaymentDeadlineAt;
  final String? source;
  final String? sourceLabel;
  final String? notes;
  final String? priceSnapshot;
  final String? durationSnapshot;
  final String? serviceColor;
  final Color employeeColor;

  String? get timeRange {
    final start = _formatTime(startAt);
    final end = _formatTime(endAt);
    if (start == null && end == null) return null;
    if (start != null && end != null) return '$start - $end';
    return start ?? end;
  }

  bool matchesEmployeeId(String employeeId) {
    return employeeKeys.contains(_normalizeKey(employeeId));
  }

  bool matchesEmployee(_CalendarEmployee employee) {
    return matchesEmployeeId(employee.id) ||
        employeeKeys.contains(_normalizeKey(employee.name)) ||
        (employee.firstName != null &&
            employeeKeys.contains(_normalizeKey(employee.firstName!)));
  }

  double get top {
    final start = _parseDateTime(startAt);
    if (start == null) return 0;
    return _minutesFromWorkStart(start);
  }

  double get height {
    final start = _parseDateTime(startAt);
    final end = _parseDateTime(endAt);
    if (start == null || end == null) return 30;
    return (end.difference(start).inMinutes * _calendarPixelsPerMinute)
        .toDouble()
        .clamp(30, _calendarHeight);
  }

  factory _BookingView.fromRecord(
    ApiRecord record,
    Map<String, _CalendarEmployee> employeeById,
    Map<String, String> employeeColorCache,
    Map<String, String> serviceColorCache,
  ) {
    final clientValue = record.data['client'];
    final serviceValue = record.data['service'];
    final zoneValue = record.data['zone'];
    final employeeValue = record.data['employee'];
    final clientId = _firstText([
      record.valueAsText('client_id'),
      _nestedText(clientValue, 'id'),
      _nestedText(clientValue, 'pk'),
      if (clientValue is num) clientValue.toString(),
      if (clientValue is String && int.tryParse(clientValue) != null)
        clientValue,
    ]);
    final serviceId = _firstText([
      record.valueAsText('service_id'),
      _nestedText(serviceValue, 'id'),
      _nestedText(serviceValue, 'pk'),
      if (serviceValue is num) serviceValue.toString(),
      if (serviceValue is String && int.tryParse(serviceValue) != null)
        serviceValue,
    ]);
    final zoneId = _firstText([
      record.valueAsText('zone_id'),
      _nestedText(zoneValue, 'id'),
      _nestedText(zoneValue, 'pk'),
      if (zoneValue is num) zoneValue.toString(),
      if (zoneValue is String && int.tryParse(zoneValue) != null) zoneValue,
    ]);
    final employeeId = _firstText([
      record.valueAsText('employee_id'),
      _nestedText(employeeValue, 'id'),
      _nestedText(employeeValue, 'pk'),
      if (employeeValue is num) employeeValue.toString(),
      if (employeeValue is String && int.tryParse(employeeValue) != null)
        employeeValue,
    ]);
    final employeeName = _firstText([
      record.valueAsText('employee_name'),
      _nestedText(employeeValue, 'full_name'),
      _nestedText(employeeValue, 'name'),
      if (employeeValue is String && int.tryParse(employeeValue) == null)
        employeeValue,
    ]);
    final employee =
        employeeId == null ? null : employeeById[_normalizeKey(employeeId)];
    final employeeKeys = {
      if (employeeId != null) _normalizeKey(employeeId),
      if (employeeName != null) _normalizeKey(employeeName),
      if (employee != null) _normalizeKey(employee.name),
      if (employee?.firstName != null) _normalizeKey(employee!.firstName!),
    };
    final employeeColor =
        _parseColor(record.valueAsText('employee_calendar_color')) ??
            _parseColor(record.valueAsText('calendar_color')) ??
            (employeeId == null
                ? null
                : _parseColor(employeeColorCache[employeeId])) ??
            employee?.color ??
            const Color(0xFFC75C8B);

    return _BookingView(
      record: record,
      employeeKeys: employeeKeys,
      id: record.valueAsText('id') ?? record.valueAsText('pk'),
      clientId: clientId,
      employeeId: employeeId,
      serviceId: serviceId,
      zoneId: zoneId,
      startAt: record.valueAsText('start_at'),
      endAt: record.valueAsText('end_at'),
      clientName: record.valueAsText('client_name'),
      serviceName: record.valueAsText('service_name'),
      employeeName: employeeName ?? employee?.name,
      zoneName: record.valueAsText('zone_name'),
      status: record.valueAsText('status'),
      source: record.valueAsText('source'),
      statusLabel: record.valueAsText('status_label'),
      paymentState: record.valueAsText('payment_state'),
      paymentStateLabel: record.valueAsText('payment_state_label'),
      prepaymentState: record.valueAsText('prepayment_state'),
      prepaymentStateLabel: record.valueAsText('prepayment_state_label'),
      prepaymentDeadlineAt: record.valueAsText('prepayment_deadline_at'),
      sourceLabel: record.valueAsText('source_label'),
      notes: record.valueAsText('notes'),
      priceSnapshot: record.valueAsText('price_snapshot'),
      durationSnapshot: record.valueAsText('duration_snapshot'),
      serviceColor: record.valueAsText('service_color') ??
          (serviceId == null ? null : serviceColorCache[serviceId]),
      employeeColor: employeeColor,
    );
  }
}

List<_CalendarEmployee> _mergeEmployees(List<_CalendarDayData> days) {
  final byId = <String, _CalendarEmployee>{};
  for (final day in days) {
    for (final employee in day.employees) {
      byId[employee.id] = employee;
    }
    for (final booking in day.bookings) {
      final id = booking.employeeId;
      if (id == null || byId.containsKey(id)) continue;
      byId[id] = _CalendarEmployee(
        id: id,
        name: booking.employeeName ?? 'Empleado $id',
        color: booking.employeeColor,
        hasSchedule: false,
        blocks: const [],
      );
    }
  }
  final employees = byId.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return employees;
}

bool _containsMovedBooking(
  List<_CalendarDayData> days, {
  required String bookingId,
  required DateTime startAt,
  required String employeeId,
}) {
  final expectedStart = DateFormat("yyyy-MM-dd'T'HH:mm").format(startAt);
  for (final day in days) {
    for (final booking in day.bookings) {
      if (booking.id != bookingId) continue;
      final actualStart = booking.startAt;
      final sameStart =
          actualStart != null && actualStart.startsWith(expectedStart);
      final sameEmployee = booking.employeeId == employeeId ||
          booking.matchesEmployeeId(employeeId);
      return sameStart && sameEmployee;
    }
  }
  return false;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}

DateTime? _parseDateTime(String? value) {
  if (value == null) return null;
  final text = value.trim().replaceFirst(' ', 'T');
  if (text.length >= 16 && text[10] == 'T') {
    final date = text.substring(0, 10).split('-');
    final time = text.substring(11, 16).split(':');
    if (date.length == 3 && time.length == 2) {
      final year = int.tryParse(date[0]);
      final month = int.tryParse(date[1]);
      final day = int.tryParse(date[2]);
      final hour = int.tryParse(time[0]);
      final minute = int.tryParse(time[1]);
      if (year != null &&
          month != null &&
          day != null &&
          hour != null &&
          minute != null) {
        return DateTime(year, month, day, hour, minute);
      }
    }
  }
  return DateTime.tryParse(text);
}

String? _textFromMap(Map map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return value.toString();
}

String? _textValue(Map<String, dynamic> map, String key) {
  return _textFromMap(map, key);
}

String? _nestedText(Object? value, String key) {
  if (value is! Map) return null;
  return _textFromMap(value, key);
}

List<_TimeBlockView> _timeBlocksFromEmployeeItem(
  Map item, {
  required String employeeId,
  required String employeeName,
}) {
  final blocks = <_TimeBlockView>[];
  final schedule = item['schedule'];
  if (schedule is Map) {
    final start = _parseDateTime(_textFromMap(schedule, 'start_at'));
    final end = _parseDateTime(_textFromMap(schedule, 'end_at'));
    if (start != null && end != null) {
      blocks.add(
        _TimeBlockView(
          label: _textFromMap(schedule, 'label') ?? 'Turno',
          color: const Color(0xFF225F3E),
          top: _minutesFromWorkStart(start),
          height: (end.difference(start).inMinutes * _calendarPixelsPerMinute)
              .toDouble()
              .clamp(18, _calendarHeight),
          editable: false,
          kind: _TimeBlockKind.schedule,
          employeeId: employeeId,
          employeeName: employeeName,
          startTime: DateFormat('HH:mm').format(start),
          endTime: DateFormat('HH:mm').format(end),
        ),
      );
    }
    final breakStart = _parseDateTime(_textFromMap(schedule, 'break_start_at'));
    final breakEnd = _parseDateTime(_textFromMap(schedule, 'break_end_at'));
    if (breakStart != null && breakEnd != null) {
      blocks.add(
        _TimeBlockView(
          label: _textFromMap(schedule, 'break_label') ?? 'Pausa',
          color: const Color(0xFF2F2F2F),
          top: _minutesFromWorkStart(breakStart),
          height: (breakEnd.difference(breakStart).inMinutes *
                  _calendarPixelsPerMinute)
              .toDouble()
              .clamp(18, _calendarHeight),
          editable: false,
          kind: _TimeBlockKind.breakBlock,
          employeeId: employeeId,
          employeeName: employeeName,
          startTime: DateFormat('HH:mm').format(breakStart),
          endTime: DateFormat('HH:mm').format(breakEnd),
        ),
      );
    }
  }

  final timeBlocks = item['time_blocks'];
  if (timeBlocks is List) {
    for (final block in timeBlocks.whereType<Map>()) {
      final start = _parseDateTime(_textFromMap(block, 'start_at')) ??
          _parseTimeOnAnyDate(_textFromMap(block, 'start_time'));
      final end = _parseDateTime(_textFromMap(block, 'end_at')) ??
          _parseTimeOnAnyDate(_textFromMap(block, 'end_time'));
      if (start == null || end == null) continue;
      blocks.add(
        _TimeBlockView(
          id: _textFromMap(block, 'id') ?? _textFromMap(block, 'pk'),
          employeeId: _textFromMap(block, 'employee') ?? employeeId,
          employeeName: employeeName,
          date: _textFromMap(block, 'date'),
          startTime: _textFromMap(block, 'start_time'),
          endTime: _textFromMap(block, 'end_time'),
          label: _textFromMap(block, 'label') ?? 'Bloqueo',
          color: _parseColor(_textFromMap(block, 'color')) ??
              const Color(0xFF111111),
          top: _minutesFromWorkStart(start),
          height: (end.difference(start).inMinutes * _calendarPixelsPerMinute)
              .toDouble()
              .clamp(18, _calendarHeight),
          editable: true,
          kind: _TimeBlockKind.timeBlock,
        ),
      );
    }
  }
  return blocks;
}

DateTime? _parseTimeOnAnyDate(String? value) {
  if (value == null || value.length < 5) return null;
  final hour = int.tryParse(value.substring(0, 2));
  final minute = int.tryParse(value.substring(3, 5));
  if (hour == null || minute == null) return null;
  return DateTime(2000, 1, 1, hour, minute);
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null || value.length < 5) return null;
  final hour = int.tryParse(value.substring(0, 2));
  final minute = int.tryParse(value.substring(3, 5));
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

int _minutesOfDay(TimeOfDay value) {
  return value.hour * 60 + value.minute;
}

String _formatTimeOfDay(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _dateTimeText(DateTime date, TimeOfDay time) {
  return _formatApiDateTime(
    DateTime(date.year, date.month, date.day, time.hour, time.minute),
  );
}

String _formatApiDateTime(DateTime value) {
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value)}$sign$hours:$minutes';
}

double _minutesFromWorkStart(DateTime value) {
  return ((value.hour * 60 + value.minute) - (_workStartHour * 60)) *
      _calendarPixelsPerMinute;
}

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

String _colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String? _firstText(List<String?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

Object? _coerceId(String? value) {
  if (value == null) return null;
  return int.tryParse(value) ?? value;
}

String _normalizeKey(String value) {
  return value.trim().toLowerCase();
}

void _debugCalendarData(
  List<_CalendarDayData> days,
  List<_CalendarEmployee> employees,
) {
  if (!kDebugMode) return;

  final bookings = [
    for (final day in days) ...day.bookings,
  ];
  final bookingEmployeeIds = bookings
      .map((booking) => booking.employeeId)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
  final employeeIds = employees.map((employee) => employee.id).toList()..sort();
  final counts = {
    for (final employee in employees)
      employee.id:
          bookings.where((booking) => booking.matchesEmployee(employee)).length,
  };

  debugPrint('BRIMOON calendar total bookings loaded: ${bookings.length}');
  debugPrint(
      'BRIMOON calendar employee ids from bookings: $bookingEmployeeIds');
  debugPrint('BRIMOON calendar employee ids from employees: $employeeIds');
  debugPrint('BRIMOON calendar counts per employee: $counts');
}

String? _formatTime(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return DateFormat('HH:mm').format(parsed);
  if (value.length >= 16 && value[10] == 'T') return value.substring(11, 16);
  if (value.length >= 5 && value[2] == ':') return value.substring(0, 5);
  return value;
}

DateTime _slotStartAt(DateTime date, double dy) {
  final rawMinutes =
      dy.clamp(0, _calendarHeight).toDouble() / _calendarPixelsPerMinute;
  final snapped = (rawMinutes / _slotStepMinutes).round() * _slotStepMinutes;
  final minutesFromMidnight = (_workStartHour * 60) + snapped;
  return DateTime(
    date.year,
    date.month,
    date.day,
    minutesFromMidnight ~/ 60,
    minutesFromMidnight % 60,
  );
}

void _showCalendarMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String? _formatDateTime(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('d MMM yyyy HH:mm', 'es').format(parsed);
}

String _apiErrorText(AnnaApiException error) {
  return formatApiError(error);
}
