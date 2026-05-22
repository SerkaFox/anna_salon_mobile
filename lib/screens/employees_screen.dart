import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
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
    return ScreenScaffold(
      title: widget.canManageStaff ? 'Empleados' : 'Mi ficha',
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
                      ? 'No hay empleados todavia.'
                      : 'No hay empleados para esta busqueda.',
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
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Buscar empleado',
              hintText: 'Nombre, telefono, email o servicio',
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
              AnnaBadge('$total empleados'),
              if (visible != total) AnnaBadge('$visible visibles'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          'Quieres eliminar a ${employee.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
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
        const SnackBar(content: Text('Empleado eliminado.')),
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
                      label: employee.phone ?? 'Sin telefono',
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
                        label: 'Comision ${employee.commissionPercent ?? '-'}%',
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnnaBadge(employee.isActive ? 'Activo' : 'Inactivo',
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
                      tooltip: 'Eliminar',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          'Quieres eliminar a ${employee.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
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
        const SnackBar(content: Text('Empleado eliminado.')),
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
                  title: 'Informacion',
                  children: [
                    _EmployeeInfoLine(
                        icon: Icons.phone_outlined,
                        label: detail.employee.phone ?? 'Sin telefono',
                        onTap: detail.employee.phone == null
                            ? null
                            : () => showPhoneActions(
                                  context,
                                  phone: detail.employee.phone!,
                                )),
                    _EmployeeInfoLine(
                        icon: Icons.mail_outline,
                        label: detail.employee.email ?? 'Sin email',
                        onTap: detail.employee.email == null
                            ? null
                            : () => writeEmail(
                                  context,
                                  email: detail.employee.email!,
                                )),
                    if (canManageStaff)
                      _EmployeeInfoLine(
                          icon: Icons.percent,
                          label:
                              'Comision ${detail.employee.commissionPercent ?? '-'}%'),
                    _EmployeeInfoLine(
                        icon: Icons.person_outline,
                        label: detail.employee.username == null
                            ? 'Sin usuario vinculado'
                            : '@${detail.employee.username}'),
                  ],
                ),
                _EmployeeDetailSection(
                  title: 'Servicios',
                  children: detail.employee.serviceNames.isEmpty
                      ? const [
                          Text('No definidos.',
                              style: TextStyle(color: AnnaColors.muted))
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
                    title: 'Servicios mas realizados',
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
    final entries = [
      ('Gana empleado', '${stats['employee_earnings'] ?? '0.00'} EUR'),
      ('Facturado', '${stats['client_revenue'] ?? '0.00'} EUR'),
      ('Salon', '${stats['salon_revenue'] ?? '0.00'} EUR'),
      ('Visitas', stats['bookings_count'] ?? '0'),
      ('Clientes', stats['clients_count'] ?? '0'),
      ('Ticket medio', '${stats['avg_ticket'] ?? '0.00'} EUR'),
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
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Periodo de estadistica',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Este mes'),
                selected: range.kind == _StatsRangeKind.thisMonth,
                onSelected: (_) => onChanged(_StatsRange.thisMonth()),
              ),
              ChoiceChip(
                label: const Text('Mes pasado'),
                selected: range.kind == _StatsRangeKind.lastMonth,
                onSelected: (_) => onChanged(_StatsRange.lastMonth()),
              ),
              ChoiceChip(
                label: const Text('Todo'),
                selected: range.kind == _StatsRangeKind.all,
                onSelected: (_) => onChanged(_StatsRange.all()),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  range.kind == _StatsRangeKind.custom ? range.label : 'Rango',
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
    return _EmployeeDetailSection(
      title: title,
      children: items.isEmpty
          ? const [
              Text('Sin datos.', style: TextStyle(color: AnnaColors.muted))
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
    return _EmployeeDetailSection(
      title: 'Clientes habituales',
      children: items.isEmpty
          ? const [
              Text('Sin datos.', style: TextStyle(color: AnnaColors.muted))
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
    return _EmployeeDetailSection(
      title: 'Reservas',
      children: bookings.isEmpty
          ? const [
              Text('Sin reservas.', style: TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final booking in bookings)
                Text(
                  [
                    _dateTimeText(booking['start_at']?.toString()),
                    booking['client_name'],
                    booking['service_name'],
                    booking['status_label'],
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      if (mounted) Navigator.pop(context, true);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
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
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: username));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario copiado.')),
    );
  }

  Future<void> _sendAccessByWhatsapp() async {
    final phone = _normalizePhone(_phoneController.text);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (phone == null || username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hace falta telefono, usuario y nueva contrasena.'),
        ),
      );
      return;
    }
    final message = 'Hola! Tu acceso a BRIMOON Studio:\n\n'
        'Usuario: $username\n'
        'Contrasena: $password\n'
        'App: https://brimoon-studio.example/app';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: FutureBuilder<ApiCollection>(
        future: widget.api.services(),
        builder: (context, snapshot) {
          final services = snapshot.data?.items ?? const <ApiRecord>[];
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
                              ? 'Nuevo empleado'
                              : widget.canManageStaff
                                  ? 'Editar empleado'
                                  : 'Mi perfil y servicios',
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
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Introduce el nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _lastNameController,
                      decoration:
                          const InputDecoration(labelText: 'Apellidos')),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Telefono')),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  ColorPalettePicker(
                    label: 'Color calendario',
                    value: _color,
                    onChanged: (value) => setState(() => _color = value),
                  ),
                  const SizedBox(height: 12),
                  if (widget.canManageStaff) ...[
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_hasExistingEmployeeAccess,
                      decoration: const InputDecoration(
                        labelText: 'Usuario para entrar',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    if (_hasExistingEmployeeAccess) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _copyUsername,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copiar usuario'),
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
                                ? 'Generar nueva contrasena'
                                : 'Generar contrasena'),
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
                            ? 'Contrasena inicial'
                            : 'Nueva contrasena',
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        final username = _usernameController.text.trim();
                        if (widget.employee == null &&
                            username.isNotEmpty &&
                            password.isEmpty) {
                          return 'Introduce una contrasena inicial';
                        }
                        if (username.isEmpty && password.isNotEmpty) {
                          return 'Introduce un usuario';
                        }
                        if (password.isNotEmpty && password.length < 4) {
                          return 'Minimo 4 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Comision %'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text('Servicios',
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
                            'Servicio ${service.valueAsText('id')}'),
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
                  if (widget.canManageStaff)
                    TextFormField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AnnaErrorBanner(_error!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.employee == null
                              ? 'Crear empleado'
                              : 'Guardar'),
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
