import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'color_palette_picker.dart';
import 'contact_actions.dart';
import 'shared.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({
    required this.api,
    required this.canManageStaff,
    required this.currentEmployeeId,
    super.key,
  });

  final AnnaApi api;
  final bool canManageStaff;
  final String? currentEmployeeId;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _queryController = TextEditingController();
  late Future<ApiCollection> _future = widget.api.employees();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reload() {
    final next = widget.api.employees();
    setState(() {
      _future = next;
    });
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: widget.canManageStaff ? t.tr('Empleados') : t.tr('Mi ficha'),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.canManageStaff)
            IconButton(
              onPressed: () async {
                final changed = await _EmployeeFormSheet.show(
                  context,
                  api: widget.api,
                  employee: null,
                  canManageStaff: widget.canManageStaff,
                );
                if (changed == true && context.mounted) _reload();
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      child: FutureBuilder<ApiCollection>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }

          final employees = (snapshot.data?.items ?? const <ApiRecord>[])
              .map(_EmployeeView.fromRecord)
              .whereType<_EmployeeView>()
              .toList();
          final filtered = employees.where((employee) {
            if (_query.isEmpty) return true;
            return employee.searchText.contains(_query);
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmployeeSearchCard(
                controller: _queryController,
                total: employees.length,
                visible: filtered.length,
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
                onClear: _clearSearch,
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                EmptyState(
                  employees.isEmpty
                      ? t.tr('No hay empleados todavia.')
                      : t.tr('No hay empleados para esta busqueda.'),
                )
              else
                for (final employee in filtered) ...[
                  _EmployeeCard(
                    api: widget.api,
                    employee: employee,
                    onChanged: _reload,
                    canManageStaff: widget.canManageStaff,
                    currentEmployeeId: widget.currentEmployeeId,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeSearchCard extends StatelessWidget {
  const _EmployeeSearchCard({
    required this.controller,
    required this.total,
    required this.visible,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final int total;
  final int visible;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: t.tr('Buscar empleado'),
              hintText: t.tr('Nombre, telefono, email o servicio'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnnaBadge(t.employeesCount(total)),
              if (visible != total) AnnaBadge(t.visibleCount(visible)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.api,
    required this.employee,
    required this.onChanged,
    required this.canManageStaff,
    required this.currentEmployeeId,
  });

  final AnnaApi api;
  final _EmployeeView employee;
  final VoidCallback onChanged;
  final bool canManageStaff;
  final String? currentEmployeeId;

  Future<void> _deleteEmployee(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.tr('Eliminar empleado')),
        content: Text(
          t.isRussian
              ? 'Удалить ${employee.name}? Если есть история, сотрудник будет скрыт из активного списка, а записи останутся.'
              : 'Quieres eliminar a ${employee.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.tr('Cancelar')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(t.tr('Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.deleteEmployee(employee.id);
      if (!context.mounted) return;
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Empleado eliminado.'))),
      );
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErrorText(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AnnaRadii.lg),
        onTap: () => _EmployeeDetailSheet.show(
          context,
          api: api,
          employee: employee,
          onChanged: onChanged,
          canManageStaff: canManageStaff,
          currentEmployeeId: currentEmployeeId,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AnnaColors.line),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      employee.initials,
                      style: const TextStyle(
                        color: AnnaColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: employee.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AnnaColors.bg, width: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnnaColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _EmployeeInfoLine(
                      icon: Icons.phone_outlined,
                      label: employee.phone ?? t.tr('Sin telefono'),
                      onTap: employee.phone == null
                          ? null
                          : () => showPhoneActions(
                                context,
                                phone: employee.phone!,
                              ),
                    ),
                    if (canManageStaff) ...[
                      const SizedBox(height: 6),
                      _EmployeeInfoLine(
                        icon: Icons.percent,
                        label: t.commission(employee.commissionPercent ?? '-'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnnaBadge(
                            employee.isActive
                                ? t.tr('Activo')
                                : t.tr('Inactivo'),
                            warning: !employee.isActive),
                        if (employee.username != null)
                          AnnaBadge('@${employee.username}'),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManageStaff && currentEmployeeId != employee.id)
                    IconButton(
                      tooltip: t.tr('Eliminar'),
                      onPressed: () => _deleteEmployee(context),
                      icon: const Icon(Icons.delete_outline),
                      color: AnnaColors.danger,
                    ),
                  const Icon(Icons.chevron_right, color: AnnaColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeInfoLine extends StatelessWidget {
  const _EmployeeInfoLine({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final content = Row(
      children: [
        Icon(icon, size: 18, color: onTap == null ? AnnaColors.muted : primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onTap == null ? AnnaColors.text : primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: content,
      ),
    );
  }
}

Future<void> showEmployeeDetailSheet(
  BuildContext context, {
  required AnnaApi api,
  required String employeeId,
  VoidCallback? onChanged,
  bool canManageStaff = false,
  String? currentEmployeeId,
}) {
  return _EmployeeDetailSheet.show(
    context,
    api: api,
    employee: _EmployeeView(
      id: employeeId,
      name: 'Empleado',
      color: const Color(0xFFC75C8B),
      isActive: true,
      serviceNames: const [],
      serviceIds: const [],
      zoneNames: const [],
      zoneIds: const [],
    ),
    onChanged: onChanged ?? () {},
    canManageStaff: canManageStaff,
    currentEmployeeId: currentEmployeeId,
  );
}

class _EmployeeDetailSheet extends StatefulWidget {
  const _EmployeeDetailSheet({
    required this.api,
    required this.employee,
    required this.onChanged,
    required this.canManageStaff,
    required this.currentEmployeeId,
  });

  final AnnaApi api;
  final _EmployeeView employee;
  final VoidCallback onChanged;
  final bool canManageStaff;
  final String? currentEmployeeId;

  static Future<void> show(
    BuildContext context, {
    required AnnaApi api,
    required _EmployeeView employee,
    required VoidCallback onChanged,
    required bool canManageStaff,
    required String? currentEmployeeId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _EmployeeDetailSheet(
        api: api,
        employee: employee,
        onChanged: onChanged,
        canManageStaff: canManageStaff,
        currentEmployeeId: currentEmployeeId,
      ),
    );
  }

  @override
  State<_EmployeeDetailSheet> createState() => _EmployeeDetailSheetState();
}

class _EmployeeDetailSheetState extends State<_EmployeeDetailSheet> {
  late _StatsRange _range = _StatsRange.thisMonth();

  AnnaApi get api => widget.api;
  _EmployeeView get employee => widget.employee;
  VoidCallback get onChanged => widget.onChanged;
  bool get canManageStaff => widget.canManageStaff;
  String? get currentEmployeeId => widget.currentEmployeeId;

  Future<void> _deleteEmployee(
    BuildContext context,
    _EmployeeView employee,
  ) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.tr('Eliminar empleado')),
        content: Text(
          t.isRussian
              ? 'Удалить ${employee.name}? Если есть история, сотрудник будет скрыт из активного списка, а записи останутся.'
              : 'Quieres eliminar a ${employee.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.tr('Cancelar')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(t.tr('Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.deleteEmployee(employee.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Empleado eliminado.'))),
      );
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErrorText(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.55,
      builder: (context, controller) {
        return FutureBuilder<ApiDocument>(
          future: api.employeeDetail(
            employee.id,
            dateFrom: _range.dateFrom,
            dateTo: _range.dateTo,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(18),
                child: ErrorState(error: snapshot.error!, onRetry: () {}),
              );
            }
            final detail = _EmployeeDetail.fromMap(snapshot.data?.data ?? {});
            final canEdit = canManageStaff ||
                (currentEmployeeId != null &&
                    currentEmployeeId == detail.employee.id);
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(detail.employee.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    if (canEdit)
                      IconButton(
                        onPressed: () async {
                          final changed = await _EmployeeFormSheet.show(
                            context,
                            api: api,
                            employee: detail.employee,
                            canManageStaff: canManageStaff,
                          );
                          if (changed == true && context.mounted) {
                            Navigator.pop(context);
                            onChanged();
                          }
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (canManageStaff &&
                        currentEmployeeId != detail.employee.id)
                      IconButton(
                        onPressed: () =>
                            _deleteEmployee(context, detail.employee),
                        icon: const Icon(Icons.delete_outline),
                        color: AnnaColors.danger,
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EmployeeStatsRangeSelector(
                  range: _range,
                  onChanged: (range) => setState(() => _range = range),
                ),
                const SizedBox(height: 12),
                _EmployeeStatsGrid(stats: detail.stats),
                const SizedBox(height: 14),
                _EmployeeDetailSection(
                  title: t.tr('Informacion'),
                  children: [
                    _EmployeeInfoLine(
                        icon: Icons.phone_outlined,
                        label: detail.employee.phone ?? t.tr('Sin telefono'),
                        onTap: detail.employee.phone == null
                            ? null
                            : () => showPhoneActions(
                                  context,
                                  phone: detail.employee.phone!,
                                )),
                    _EmployeeInfoLine(
                        icon: Icons.mail_outline,
                        label: detail.employee.email ?? t.tr('Sin email'),
                        onTap: detail.employee.email == null
                            ? null
                            : () => writeEmail(
                                  context,
                                  email: detail.employee.email!,
                                )),
                    if (canManageStaff)
                      _EmployeeInfoLine(
                          icon: Icons.percent,
                          label: t.commission(
                              detail.employee.commissionPercent ?? '-')),
                    _EmployeeInfoLine(
                        icon: Icons.person_outline,
                        label: detail.employee.username == null
                            ? t.tr('Sin usuario vinculado')
                            : '@${detail.employee.username}'),
                  ],
                ),
                if (canManageStaff) ...[
                  _EmployeeScheduleSummary(
                    api: api,
                    employeeId: detail.employee.id,
                    onEdit: () async {
                      final changed = await _EmployeeScheduleSheet.show(
                        context,
                        api: api,
                        employee: detail.employee,
                      );
                      if (changed == true && mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _EmployeeDetailSection(
                  title: t.isRussian ? 'Рабочие зоны' : 'Zonas de trabajo',
                  children: detail.employee.zoneNames.isEmpty
                      ? [
                          Text(
                            t.tr('No definidos.'),
                            style: const TextStyle(color: AnnaColors.muted),
                          ),
                        ]
                      : [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final zone in detail.employee.zoneNames)
                                AnnaBadge(zone),
                            ],
                          ),
                        ],
                ),
                _EmployeeDetailSection(
                  title: t.tr('Servicios'),
                  children: detail.employee.serviceNames.isEmpty
                      ? [
                          Text(t.tr('No definidos.'),
                              style: const TextStyle(color: AnnaColors.muted))
                        ]
                      : [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final service
                                  in detail.employee.serviceNames)
                                AnnaBadge(service),
                            ],
                          ),
                        ],
                ),
                _EmployeeCountListSection(
                    title: t.tr('Servicios mas realizados'),
                    items: detail.topServices),
                _EmployeeClientListSection(items: detail.topClients),
                _EmployeeBookingHistorySection(bookings: detail.bookings),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmployeeStatsGrid extends StatelessWidget {
  const _EmployeeStatsGrid({required this.stats});

  final Map<String, String> stats;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final entries = [
      (t.tr('Gana empleado'), '${stats['employee_earnings'] ?? '0.00'} EUR'),
      (t.tr('Facturado'), '${stats['client_revenue'] ?? '0.00'} EUR'),
      (t.tr('Salon'), '${stats['salon_revenue'] ?? '0.00'} EUR'),
      (t.tr('Visitas'), stats['bookings_count'] ?? '0'),
      (t.tr('Clientes'), stats['clients_count'] ?? '0'),
      (t.tr('Ticket medio'), '${stats['avg_ticket'] ?? '0.00'} EUR'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final entry in entries)
          PanelCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AnnaColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(entry.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmployeeScheduleSummary extends StatelessWidget {
  const _EmployeeScheduleSummary({
    required this.api,
    required this.employeeId,
    required this.onEdit,
  });

  final AnnaApi api;
  final String employeeId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<ApiDocument>(
      future: api.employeeSchedule(employeeId),
      builder: (context, snapshot) {
        final children = <Widget>[
          Row(
            children: [
              Expanded(
                child: Text(t.tr('Horario'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(t.tr('Editar horario')),
              ),
            ],
          ),
        ];
        if (snapshot.connectionState != ConnectionState.done) {
          children.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(),
          ));
        } else if (snapshot.hasData) {
          final schedule = _EmployeeSchedule.fromMap(snapshot.data!.data);
          children.add(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final shift in schedule.weekly)
                AnnaBadge(
                  '${_weekdayShort(context, shift.weekday)} ${shift.isDayOff ? t.tr('Dia libre') : '${shift.startTime}-${shift.endTime}'}',
                ),
            ],
          ));
        } else {
          children.add(AnnaErrorBanner(formatApiError(snapshot.error!)));
        }
        return PanelCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      },
    );
  }
}

class _EmployeeScheduleSheet extends StatefulWidget {
  const _EmployeeScheduleSheet({
    required this.api,
    required this.employee,
  });

  final AnnaApi api;
  final _EmployeeView employee;

  static Future<bool?> show(
    BuildContext context, {
    required AnnaApi api,
    required _EmployeeView employee,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EmployeeScheduleSheet(
        api: api,
        employee: employee,
      ),
    );
  }

  @override
  State<_EmployeeScheduleSheet> createState() => _EmployeeScheduleSheetState();
}

class _EmployeeScheduleSheetState extends State<_EmployeeScheduleSheet> {
  late Future<ApiDocument> _future = widget.api.employeeSchedule(
    widget.employee.id,
  );
  var _saving = false;
  String? _error;
  _EmployeeSchedule? _schedule;

  Future<void> _save() async {
    final schedule = _schedule;
    if (schedule == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateEmployeeSchedule(widget.employee.id, {
        'weekly_shifts': [
          for (final shift in schedule.weekly) shift.toPayload(),
        ],
        'overrides': [
          for (final override in schedule.overrides) override.toPayload(),
        ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).tr('Horario guardado.'))),
      );
      Navigator.pop(context, true);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: FutureBuilder<ApiDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error!,
              onRetry: () => setState(() {
                _future = widget.api.employeeSchedule(widget.employee.id);
              }),
            );
          }
          _schedule ??= _EmployeeSchedule.fromMap(snapshot.data?.data ?? {});
          final schedule = _schedule!;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.tr('Horario de trabajo'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final shift in schedule.weekly) ...[
                  _WeeklyShiftEditor(
                    shift: shift,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(t.tr('Dias especiales'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        schedule.overrides.add(_ScheduleOverride.empty());
                      }),
                      icon: const Icon(Icons.add),
                      label: Text(t.tr('Anadir dia especial')),
                    ),
                  ],
                ),
                if (schedule.overrides.isEmpty)
                  Text(t.tr('Sin dias especiales.'),
                      style: const TextStyle(color: AnnaColors.muted))
                else
                  for (final override in schedule.overrides) ...[
                    _ScheduleOverrideEditor(
                      scheduleOverride: override,
                      onDelete: () => setState(() {
                        override.delete = true;
                        schedule.overrides.remove(override);
                      }),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AnnaErrorBanner(_error!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(t.tr('Guardar horario')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeeklyShiftEditor extends StatelessWidget {
  const _WeeklyShiftEditor({
    required this.shift,
    required this.onChanged,
  });

  final _WeeklyShift shift;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_weekdayName(context, shift.weekday)),
            subtitle:
                Text(shift.isDayOff ? t.tr('Dia libre') : t.tr('Trabaja')),
            value: !shift.isDayOff,
            onChanged: (value) {
              shift.isDayOff = !value;
              onChanged();
            },
          ),
          if (!shift.isDayOff) ...[
            _TimeRow(
              firstLabel: t.tr('Desde'),
              firstValue: shift.startTime,
              onFirstChanged: (value) {
                shift.startTime = value;
                onChanged();
              },
              secondLabel: t.tr('Hasta'),
              secondValue: shift.endTime,
              onSecondChanged: (value) {
                shift.endTime = value;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            _TimeRow(
              firstLabel: t.tr('Pausa desde'),
              firstValue: shift.breakStart,
              onFirstChanged: (value) {
                shift.breakStart = value;
                onChanged();
              },
              secondLabel: t.tr('Pausa hasta'),
              secondValue: shift.breakEnd,
              onSecondChanged: (value) {
                shift.breakEnd = value;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: shift.note,
              decoration: InputDecoration(labelText: t.tr('Nota')),
              onChanged: (value) => shift.note = value,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleOverrideEditor extends StatelessWidget {
  const _ScheduleOverrideEditor({
    required this.scheduleOverride,
    required this.onChanged,
    required this.onDelete,
  });

  final _ScheduleOverride scheduleOverride;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: scheduleOverride.date,
                  decoration: InputDecoration(labelText: t.tr('Fecha')),
                  onChanged: (value) => scheduleOverride.date = value,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AnnaColors.danger,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.tr('Trabaja')),
            subtitle: Text(scheduleOverride.isDayOff ? t.tr('Dia libre') : ''),
            value: !scheduleOverride.isDayOff,
            onChanged: (value) {
              scheduleOverride.isDayOff = !value;
              onChanged();
            },
          ),
          if (!scheduleOverride.isDayOff) ...[
            _TimeRow(
              firstLabel: t.tr('Desde'),
              firstValue: scheduleOverride.startTime,
              onFirstChanged: (value) {
                scheduleOverride.startTime = value;
                onChanged();
              },
              secondLabel: t.tr('Hasta'),
              secondValue: scheduleOverride.endTime,
              onSecondChanged: (value) {
                scheduleOverride.endTime = value;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: scheduleOverride.label,
              decoration: InputDecoration(labelText: t.tr('Etiqueta')),
              onChanged: (value) => scheduleOverride.label = value,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.firstLabel,
    required this.firstValue,
    required this.onFirstChanged,
    required this.secondLabel,
    required this.secondValue,
    required this.onSecondChanged,
  });

  final String firstLabel;
  final String? firstValue;
  final ValueChanged<String?> onFirstChanged;
  final String secondLabel;
  final String? secondValue;
  final ValueChanged<String?> onSecondChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeButton(
            label: firstLabel,
            value: firstValue,
            onChanged: onFirstChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeButton(
            label: secondLabel,
            value: secondValue,
            onChanged: onSecondChanged,
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final current = _parseTime(value);
        final picked = await showTimePicker(
          context: context,
          initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked == null) return;
        onChanged(_formatTime(picked));
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: ${value ?? '--:--'}'),
      ),
    );
  }
}

class _EmployeeSchedule {
  _EmployeeSchedule({required this.weekly, required this.overrides});

  final List<_WeeklyShift> weekly;
  final List<_ScheduleOverride> overrides;

  factory _EmployeeSchedule.fromMap(Map<String, dynamic> data) {
    return _EmployeeSchedule(
      weekly: _mapList(data['weekly_shifts']).map(_WeeklyShift.fromMap).toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday)),
      overrides:
          _mapList(data['overrides']).map(_ScheduleOverride.fromMap).toList(),
    );
  }
}

class _WeeklyShift {
  _WeeklyShift({
    required this.weekday,
    required this.isDayOff,
    required this.startTime,
    required this.endTime,
    required this.breakStart,
    required this.breakEnd,
    required this.note,
  });

  final int weekday;
  bool isDayOff;
  String? startTime;
  String? endTime;
  String? breakStart;
  String? breakEnd;
  String note;

  factory _WeeklyShift.fromMap(Map<String, dynamic> data) {
    return _WeeklyShift(
      weekday: int.tryParse(data['weekday']?.toString() ?? '') ?? 0,
      isDayOff: data['is_day_off'] == true,
      startTime: _timeText(data['start_time']),
      endTime: _timeText(data['end_time']),
      breakStart: _timeText(data['break_start']),
      breakEnd: _timeText(data['break_end']),
      note: data['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() => {
        'weekday': weekday,
        'is_day_off': isDayOff,
        'start_time': isDayOff ? null : (startTime ?? '09:00'),
        'end_time': isDayOff ? null : (endTime ?? '18:00'),
        'break_start': isDayOff ? null : breakStart,
        'break_end': isDayOff ? null : breakEnd,
        'note': note,
      };
}

class _ScheduleOverride {
  _ScheduleOverride({
    required this.date,
    required this.isDayOff,
    required this.startTime,
    required this.endTime,
    required this.label,
    this.id,
  });

  String? id;
  String date;
  bool isDayOff;
  String? startTime;
  String? endTime;
  String label;
  bool delete = false;

  factory _ScheduleOverride.empty() {
    return _ScheduleOverride(
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      isDayOff: false,
      startTime: '09:00',
      endTime: '18:00',
      label: '',
    );
  }

  factory _ScheduleOverride.fromMap(Map<String, dynamic> data) {
    return _ScheduleOverride(
      id: data['id']?.toString(),
      date: data['date']?.toString() ?? '',
      isDayOff: data['is_day_off'] == true,
      startTime: _timeText(data['start_time']),
      endTime: _timeText(data['end_time']),
      label: data['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() => {
        if (id != null) 'id': id,
        'date': date,
        'is_day_off': isDayOff,
        'start_time': isDayOff ? null : (startTime ?? '09:00'),
        'end_time': isDayOff ? null : (endTime ?? '18:00'),
        'label': label,
        if (delete) 'delete': true,
      };
}

String _weekdayName(BuildContext context, int weekday) {
  final t = AppLocalizations.of(context);
  const es = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo'
  ];
  return t.tr(es[weekday.clamp(0, 6)]);
}

String _weekdayShort(BuildContext context, int weekday) {
  final t = AppLocalizations.of(context);
  const es = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa', 'Do'];
  return t.tr(es[weekday.clamp(0, 6)]);
}

String? _timeText(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text.length >= 5 ? text.substring(0, 5) : text;
}

TimeOfDay? _parseTime(String? value) {
  if (value == null || !value.contains(':')) return null;
  final parts = value.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _EmployeeStatsRangeSelector extends StatelessWidget {
  const _EmployeeStatsRangeSelector({
    required this.range,
    required this.onChanged,
  });

  final _StatsRange range;
  final ValueChanged<_StatsRange> onChanged;

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: range.dateFrom ?? DateTime(now.year, now.month, 1),
        end: range.dateTo ?? now,
      ),
    );
    if (picked == null) return;
    onChanged(_StatsRange.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.tr('Periodo de estadistica'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(t.tr('Este mes')),
                selected: range.kind == _StatsRangeKind.thisMonth,
                onSelected: (_) => onChanged(_StatsRange.thisMonth()),
              ),
              ChoiceChip(
                label: Text(t.tr('Mes pasado')),
                selected: range.kind == _StatsRangeKind.lastMonth,
                onSelected: (_) => onChanged(_StatsRange.lastMonth()),
              ),
              ChoiceChip(
                label: Text(t.tr('Todo')),
                selected: range.kind == _StatsRangeKind.all,
                onSelected: (_) => onChanged(_StatsRange.all()),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  range.kind == _StatsRangeKind.custom
                      ? range.label
                      : t.tr('Rango'),
                ),
                onPressed: () => _pickCustomRange(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StatsRangeKind { thisMonth, lastMonth, all, custom }

class _StatsRange {
  const _StatsRange({
    required this.kind,
    required this.label,
    this.dateFrom,
    this.dateTo,
  });

  final _StatsRangeKind kind;
  final String label;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  factory _StatsRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return _StatsRange(
      kind: _StatsRangeKind.thisMonth,
      label: DateFormat('MM/yyyy').format(start),
      dateFrom: start,
      dateTo: end,
    );
  }

  factory _StatsRange.lastMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 0);
    return _StatsRange(
      kind: _StatsRangeKind.lastMonth,
      label: DateFormat('MM/yyyy').format(start),
      dateFrom: start,
      dateTo: end,
    );
  }

  factory _StatsRange.all() {
    return const _StatsRange(
      kind: _StatsRangeKind.all,
      label: 'Todo el periodo',
    );
  }

  factory _StatsRange.custom(DateTime start, DateTime end) {
    return _StatsRange(
      kind: _StatsRangeKind.custom,
      label:
          '${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}',
      dateFrom: start,
      dateTo: end,
    );
  }
}

class _EmployeeDetailSection extends StatelessWidget {
  const _EmployeeDetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PanelCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final child in children) ...[
              child,
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeCountListSection extends StatelessWidget {
  const _EmployeeCountListSection({required this.title, required this.items});

  final String title;
  final List<_NamedCount> items;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _EmployeeDetailSection(
      title: title,
      children: items.isEmpty
          ? [
              Text(t.tr('Sin datos.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final item in items)
                Text('${item.name} (${item.count})',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
    );
  }
}

class _EmployeeClientListSection extends StatelessWidget {
  const _EmployeeClientListSection({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _EmployeeDetailSection(
      title: t.tr('Clientes habituales'),
      children: items.isEmpty
          ? [
              Text(t.tr('Sin datos.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final item in items)
                Text(
                  '${item['name']} (${item['count']}) · ${item['spent']} EUR',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
    );
  }
}

class _EmployeeBookingHistorySection extends StatelessWidget {
  const _EmployeeBookingHistorySection({required this.bookings});

  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _EmployeeDetailSection(
      title: t.tr('Reservas'),
      children: bookings.isEmpty
          ? [
              Text(t.tr('Sin reservas.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final booking in bookings)
                Text(
                  [
                    _dateTimeText(booking['start_at']?.toString()),
                    booking['client_name'],
                    booking['service_name'],
                    booking['status_label'],
                    booking['payment_state_label'],
                  ]
                      .whereType<Object>()
                      .map((value) => value.toString())
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
    );
  }
}

class _EmployeeFormSheet extends StatefulWidget {
  const _EmployeeFormSheet({
    required this.api,
    required this.employee,
    required this.canManageStaff,
  });

  final AnnaApi api;
  final _EmployeeView? employee;
  final bool canManageStaff;

  static Future<bool?> show(
    BuildContext context, {
    required AnnaApi api,
    required _EmployeeView? employee,
    required bool canManageStaff,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _EmployeeFormSheet(
        api: api,
        employee: employee,
        canManageStaff: canManageStaff,
      ),
    );
  }

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController =
      TextEditingController(text: widget.employee?.firstName ?? '');
  late final _lastNameController =
      TextEditingController(text: widget.employee?.lastName ?? '');
  late final _phoneController =
      TextEditingController(text: widget.employee?.phone ?? '');
  late final _emailController =
      TextEditingController(text: widget.employee?.email ?? '');
  late final _usernameController =
      TextEditingController(text: widget.employee?.username ?? '');
  final _passwordController = TextEditingController();
  late final _commissionController =
      TextEditingController(text: widget.employee?.commissionPercent ?? '');
  late String _color = widget.employee?.colorHex ?? '#C75C8B';
  late final _notesController =
      TextEditingController(text: widget.employee?.notes ?? '');
  late final Set<String> _serviceIds = {...?widget.employee?.serviceIds};
  late final Set<String> _zoneIds = {...?widget.employee?.zoneIds};
  late bool _isActive = widget.employee?.isActive ?? true;
  bool _saving = false;
  String? _error;

  bool get _hasExistingEmployeeAccess => widget.employee?.username != null;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _commissionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _save({bool closeSheet = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'calendar_color': _color,
      'services': _serviceIds.map((id) => int.tryParse(id) ?? id).toList(),
      if (widget.canManageStaff)
        'zones': _zoneIds.map((id) => int.tryParse(id) ?? id).toList(),
    };
    if (widget.canManageStaff) {
      payload.addAll({
        if (!_hasExistingEmployeeAccess)
          'username': _usernameController.text.trim(),
        if (_passwordController.text.isNotEmpty)
          'password': _passwordController.text,
        'commission_percent': _commissionController.text.trim().isEmpty
            ? '0'
            : _commissionController.text.trim(),
        'notes': _notesController.text.trim(),
        'is_active': _isActive,
      });
    }
    try {
      final employee = widget.employee;
      if (employee == null) {
        await widget.api.createEmployee(payload);
      } else {
        await widget.api.updateEmployee(employee.id, payload);
      }
      if (mounted && closeSheet) Navigator.pop(context, true);
      return true;
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final generated = List.generate(8, (index) {
      final position = (random + index * 37) % chars.length;
      return chars[position];
    }).join();
    setState(() => _passwordController.text = generated);
  }

  Future<void> _copyUsername() async {
    final t = AppLocalizations.of(context);
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: username));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.tr('Usuario copiado.'))),
    );
  }

  Future<void> _sendAccessByWhatsapp() async {
    final t = AppLocalizations.of(context);
    final phone = _normalizePhone(_phoneController.text);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (phone == null || username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(t.tr('Hace falta telefono, usuario y nueva contrasena.')),
        ),
      );
      return;
    }
    if (widget.employee != null) {
      final saved = await _save(closeSheet: false);
      if (!saved || !mounted) return;
    }
    final message = 'Hola! Tu acceso a BRIMOON Studio:\n\n'
        'Usuario: $username\n'
        'Contrasena: $password\n'
        'App: https://brimoon.es/app/';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.tr('No se pudo abrir WhatsApp.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: FutureBuilder<List<ApiCollection>>(
        future: Future.wait([
          widget.api.services(),
          widget.api.zones(),
        ]),
        builder: (context, snapshot) {
          final services = snapshot.data?[0].items ?? const <ApiRecord>[];
          final zones = snapshot.data?[1].items ?? const <ApiRecord>[];
          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.employee == null
                              ? t.tr('Nuevo empleado')
                              : widget.canManageStaff
                                  ? t.tr('Editar empleado')
                                  : t.tr('Mi perfil y servicios'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(labelText: t.tr('Nombre')),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? t.tr('Introduce el nombre')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _lastNameController,
                      decoration:
                          InputDecoration(labelText: t.tr('Apellidos'))),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: t.tr('Telefono'))),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  ColorPalettePicker(
                    label: t.tr('Color calendario'),
                    value: _color,
                    onChanged: (value) => setState(() => _color = value),
                  ),
                  const SizedBox(height: 12),
                  if (widget.canManageStaff) ...[
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_hasExistingEmployeeAccess,
                      decoration: InputDecoration(
                        labelText: t.tr('Usuario para entrar'),
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    if (_hasExistingEmployeeAccess) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _copyUsername,
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(t.tr('Copiar usuario')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _generatePassword,
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: Text(_hasExistingEmployeeAccess
                                ? t.tr('Generar nueva contrasena')
                                : t.tr('Generar contrasena')),
                          ),
                          OutlinedButton.icon(
                            onPressed: _sendAccessByWhatsapp,
                            icon: const Icon(Icons.chat_outlined),
                            label: const Text('WhatsApp'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: widget.employee == null
                            ? t.tr('Contrasena inicial')
                            : t.tr('Nueva contrasena'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        final username = _usernameController.text.trim();
                        if (widget.employee == null &&
                            username.isNotEmpty &&
                            password.isEmpty) {
                          return t.tr('Introduce una contrasena inicial');
                        }
                        if (username.isEmpty && password.isNotEmpty) {
                          return t.tr('Introduce un usuario');
                        }
                        if (password.isNotEmpty && password.length < 4) {
                          return t.tr('Minimo 4 caracteres');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: t.tr('Comision %')),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.tr('Activo')),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(t.tr('Servicios'),
                      style: Theme.of(context).textTheme.titleMedium),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  else
                    for (final service in services)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(service.valueAsText('name') ??
                            '${t.tr('Servicio')} ${service.valueAsText('id')}'),
                        value: _serviceIds.contains(service.valueAsText('id')),
                        onChanged: (value) {
                          final id = service.valueAsText('id');
                          if (id == null) return;
                          setState(() {
                            if (value == true) {
                              _serviceIds.add(id);
                            } else {
                              _serviceIds.remove(id);
                            }
                          });
                        },
                      ),
                  if (widget.canManageStaff) ...[
                    const SizedBox(height: 14),
                    Text(
                      t.isRussian ? 'Рабочие зоны' : 'Zonas de trabajo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.isRussian
                          ? 'Зона для записи будет выбрана автоматически.'
                          : 'La zona de la reserva se asignará automáticamente.',
                      style: const TextStyle(color: AnnaColors.muted),
                    ),
                    for (final zone in zones)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          zone.valueAsText('name') ??
                              '${t.tr('Zona')} ${zone.valueAsText('id')}',
                        ),
                        value: _zoneIds.contains(zone.valueAsText('id')),
                        onChanged: (value) {
                          final id = zone.valueAsText('id');
                          if (id == null) return;
                          setState(() {
                            if (value == true) {
                              _zoneIds.add(id);
                            } else {
                              _zoneIds.remove(id);
                            }
                          });
                        },
                      ),
                  ],
                  if (widget.canManageStaff)
                    TextFormField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: t.tr('Notas')),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AnnaErrorBanner(_error!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save(),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.employee == null
                              ? t.tr('Crear empleado')
                              : t.tr('Guardar')),
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

class _EmployeeDetail {
  const _EmployeeDetail({
    required this.employee,
    required this.stats,
    required this.topClients,
    required this.topServices,
    required this.bookings,
  });

  final _EmployeeView employee;
  final Map<String, String> stats;
  final List<Map<String, dynamic>> topClients;
  final List<_NamedCount> topServices;
  final List<Map<String, dynamic>> bookings;

  factory _EmployeeDetail.fromMap(Map<String, dynamic> data) {
    final employeeMap = data['employee'] is Map
        ? Map<String, dynamic>.from(data['employee'])
        : <String, dynamic>{};
    final statsMap = data['stats'] is Map
        ? Map<String, dynamic>.from(data['stats'])
        : <String, dynamic>{};
    return _EmployeeDetail(
      employee: _EmployeeView.fromRecord(ApiRecord(employeeMap)) ??
          const _EmployeeView(
            id: '',
            name: 'Empleado',
            color: Color(0xFFC75C8B),
            isActive: true,
            serviceNames: [],
            serviceIds: [],
            zoneNames: [],
            zoneIds: [],
          ),
      stats: {
        for (final entry in statsMap.entries)
          entry.key: entry.value?.toString() ?? '',
      },
      topClients: _mapList(data['top_clients']),
      topServices: _namedCounts(data['top_services']),
      bookings: _mapList(data['bookings']),
    );
  }
}

class _NamedCount {
  const _NamedCount(this.name, this.count);

  final String name;
  final String count;
}

class _EmployeeView {
  const _EmployeeView({
    required this.id,
    required this.name,
    required this.color,
    required this.isActive,
    required this.serviceNames,
    required this.serviceIds,
    required this.zoneNames,
    required this.zoneIds,
    this.phone,
    this.email,
    this.username,
    this.commissionPercent,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final Color color;
  final bool isActive;
  final List<String> serviceNames;
  final List<String> serviceIds;
  final List<String> zoneNames;
  final List<String> zoneIds;
  final String? phone;
  final String? email;
  final String? username;
  final String? commissionPercent;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  String get firstName {
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? name : parts.first;
  }

  String get lastName {
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return parts.length <= 1 ? '' : parts.skip(1).join(' ');
  }

  String get colorHex {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '#';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String get searchText {
    return [
      name,
      phone,
      email,
      username,
      ...serviceNames,
      ...zoneNames,
    ].whereType<String>().join(' ').toLowerCase();
  }

  String? get createdText => _dateText(createdAt);
  String? get updatedText => _dateText(updatedAt);

  static _EmployeeView? fromRecord(ApiRecord record) {
    final id = record.valueAsText('id') ?? record.valueAsText('pk');
    if (id == null) return null;
    final first = record.valueAsText('first_name') ?? '';
    final last = record.valueAsText('last_name') ?? '';
    final composed = '$first $last'.trim();
    final name = record.valueAsText('full_name') ??
        record.valueAsText('name') ??
        (composed.isNotEmpty ? composed : 'Empleado $id');
    return _EmployeeView(
      id: id,
      name: name,
      color: _parseColor(record.valueAsText('calendar_color')) ??
          const Color(0xFFC75C8B),
      isActive: _boolValue(record.data['is_active'], fallback: true),
      serviceNames: _stringList(record.data['service_names']),
      serviceIds: _stringList(record.data['service_ids']),
      zoneNames: _stringList(record.data['zone_names']),
      zoneIds: _stringList(record.data['zone_ids']),
      phone: _nonEmpty(record.valueAsText('phone')),
      email: _nonEmpty(record.valueAsText('email')),
      username: _nonEmpty(record.valueAsText('username')),
      commissionPercent: _nonEmpty(record.valueAsText('commission_percent')),
      notes: _nonEmpty(record.valueAsText('notes')),
      createdAt: _nonEmpty(record.valueAsText('created_at')),
      updatedAt: _nonEmpty(record.valueAsText('updated_at')),
    );
  }
}

String? _dateText(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('d/M/yyyy', 'es').format(parsed);
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}

String? _normalizePhone(String phone) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty) return null;
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final char = trimmed[i];
    if (i == 0 && char == '+') {
      buffer.write(char);
    } else if (RegExp(r'\d').hasMatch(char)) {
      buffer.write(char);
    }
  }
  final value = buffer.toString();
  if (value.isEmpty || value == '+') return null;
  return value.replaceFirst('+', '');
}

String _apiErrorText(AnnaApiException error) {
  return formatApiError(error);
}

bool _boolValue(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString())
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<_NamedCount> _namedCounts(Object? value) {
  return _mapList(value)
      .map((item) => _NamedCount(
            item['name']?.toString() ?? '',
            item['count']?.toString() ?? '0',
          ))
      .where((item) => item.name.isNotEmpty)
      .toList();
}

String _dateTimeText(String? value) {
  if (value == null) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd/MM/yyyy HH:mm', 'es').format(parsed);
}
