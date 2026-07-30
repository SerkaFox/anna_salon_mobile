import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'api_cached_image.dart';
import 'client_form_sheet.dart';
import 'contact_actions.dart';
import 'employees_screen.dart';
import 'photo_viewer.dart';
import 'shared.dart';

enum _ClientFilter { all, blacklisted, online }

enum _ClientSort { name, orders, spent }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({
    required this.api,
    required this.canManagePhotos,
    super.key,
  });

  final AnnaApi api;
  final bool canManagePhotos;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _queryController = TextEditingController();
  late Future<ApiCollection> _future = widget.api.clients();
  final List<ApiRecord> _createdClientRecords = [];
  String _query = '';
  _ClientFilter _filter = _ClientFilter.all;
  _ClientSort _sort = _ClientSort.name;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reload() {
    final next = _loadClients();
    setState(() {
      _future = next;
    });
  }

  Future<ApiCollection> _loadClients() async {
    final response = await widget.api.clients();
    final byId = <String, ApiRecord>{};
    for (final record in [
      ..._createdClientRecords,
      ...response.items,
    ]) {
      final id = record.valueAsText('id') ?? record.valueAsText('pk');
      if (id == null) continue;
      byId.putIfAbsent(id, () => record);
    }
    return ApiCollection(
      byId.values.toList(),
      raw: response.raw,
    );
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() => _query = '');
  }

  Future<void> _createClient() async {
    final created = await ClientFormSheet.show(context, api: widget.api);
    if (created == null || !mounted) return;
    final id = created.valueAsText('id') ?? created.valueAsText('pk');
    _createdClientRecords.removeWhere((record) {
      final recordId = record.valueAsText('id') ?? record.valueAsText('pk');
      return id != null && recordId == id;
    });
    _createdClientRecords.insert(0, created);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: t.tr('Clientes'),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _createClient,
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

          final clients = (snapshot.data?.items ?? const <ApiRecord>[])
              .map(_ClientView.fromRecord)
              .whereType<_ClientView>()
              .toList();
          final filtered = clients.where((client) {
            if (_query.isNotEmpty && !client.searchText.contains(_query)) {
              return false;
            }
            return switch (_filter) {
              _ClientFilter.all => true,
              _ClientFilter.blacklisted => client.isBlacklisted,
              _ClientFilter.online => client.isOnlineClient,
            };
          }).toList()
            ..sort((left, right) => switch (_sort) {
                  _ClientSort.name => left.name.compareTo(right.name),
                  _ClientSort.orders =>
                    right.totalOrders.compareTo(left.totalOrders),
                  _ClientSort.spent =>
                    right.totalSpent.compareTo(left.totalSpent),
                });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientSearchCard(
                controller: _queryController,
                total: clients.length,
                visible: filtered.length,
                filter: _filter,
                sort: _sort,
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
                onClear: _clearSearch,
                onFilterChanged: (value) => setState(() => _filter = value),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                EmptyState(
                  clients.isEmpty
                      ? t.tr('No hay clientes todavia.')
                      : t.tr('No hay clientes para esta busqueda.'),
                )
              else
                for (final client in filtered) ...[
                  _ClientCard(
                    api: widget.api,
                    client: client,
                    canManagePhotos: widget.canManagePhotos,
                    onChanged: _reload,
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

class _ClientSearchCard extends StatelessWidget {
  const _ClientSearchCard({
    required this.controller,
    required this.total,
    required this.visible,
    required this.filter,
    required this.sort,
    required this.onChanged,
    required this.onClear,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final int total;
  final int visible;
  final _ClientFilter filter;
  final _ClientSort sort;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_ClientFilter> onFilterChanged;
  final ValueChanged<_ClientSort> onSortChanged;

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
              labelText: t.tr('Buscar cliente'),
              hintText: t.tr('Nombre, telefono o email'),
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
              FilterChip(
                label: Text(t.isRussian ? 'Все' : 'Todos'),
                selected: filter == _ClientFilter.all,
                onSelected: (_) => onFilterChanged(_ClientFilter.all),
              ),
              FilterChip(
                label: Text(t.isRussian ? 'Чёрный список' : 'Lista negra'),
                selected: filter == _ClientFilter.blacklisted,
                onSelected: (_) => onFilterChanged(_ClientFilter.blacklisted),
              ),
              FilterChip(
                label: Text(t.isRussian ? 'Онлайн' : 'Online'),
                selected: filter == _ClientFilter.online,
                onSelected: (_) => onFilterChanged(_ClientFilter.online),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_ClientSort>(
            initialValue: sort,
            decoration: InputDecoration(
              labelText: t.isRussian ? 'Сортировка' : 'Ordenar',
              prefixIcon: const Icon(Icons.sort),
            ),
            items: [
              DropdownMenuItem(
                value: _ClientSort.name,
                child: Text(t.isRussian ? 'По имени' : 'Por nombre'),
              ),
              DropdownMenuItem(
                value: _ClientSort.orders,
                child: Text(t.isRussian ? 'По заказам' : 'Por reservas'),
              ),
              DropdownMenuItem(
                value: _ClientSort.spent,
                child:
                    Text(t.isRussian ? 'По принесённым деньгам' : 'Por gasto'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnnaBadge(t.clientsCount(total)),
              if (visible != total) AnnaBadge(t.visibleCount(visible)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.api,
    required this.client,
    required this.canManagePhotos,
    required this.onChanged,
  });

  final AnnaApi api;
  final _ClientView client;
  final bool canManagePhotos;
  final VoidCallback onChanged;

  Future<void> _deleteClient(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.tr('Eliminar cliente')),
        content: Text(
          t.isRussian
              ? 'Удалить ${client.name}? Если есть история, клиент будет скрыт из активного списка, а записи останутся.'
              : 'Quieres eliminar a ${client.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
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
      await api.deleteClient(client.id);
      if (!context.mounted) return;
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Cliente eliminado.'))),
      );
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final initials = client.initials;
    return PanelCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AnnaRadii.lg),
        onTap: () => _ClientDetailSheet.show(
          context,
          api: api,
          client: client,
          canManagePhotos: canManagePhotos,
          onChanged: onChanged,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientAvatar(
                api: api,
                avatarUrl: client.avatarUrl,
                initials: initials,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _ClientInfoLine(
                      icon: Icons.phone_outlined,
                      label: client.phone ?? t.tr('Sin telefono'),
                      onTap: client.phone == null
                          ? null
                          : () => showPhoneActions(
                                context,
                                phone: client.phone!,
                              ),
                    ),
                    const SizedBox(height: 6),
                    _ClientInfoLine(
                      icon: Icons.mail_outline,
                      label: client.email ?? t.tr('Sin email'),
                      onTap: client.email == null
                          ? null
                          : () => writeEmail(context, email: client.email!),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnnaBadge(
                            client.isActive ? t.tr('Activo') : t.tr('Inactivo'),
                            warning: !client.isActive),
                        if (client.isBlacklisted)
                          AnnaBadge(
                            t.isRussian ? 'Чёрный список' : 'Lista negra',
                            warning: true,
                          ),
                        AnnaBadge(
                          t.isRussian
                              ? 'Заказов: ${client.totalOrders}'
                              : 'Reservas: ${client.totalOrders}',
                        ),
                        AnnaBadge(
                          '${client.totalSpent.toStringAsFixed(2)} €',
                        ),
                        if (client.isOnlineClient)
                          AnnaBadge(t.isRussian ? 'Онлайн' : 'Online'),
                        if (client.createdText != null)
                          AnnaBadge('${t.tr('Creado')} ${client.createdText}'),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManagePhotos)
                    IconButton(
                      tooltip: t.tr('Eliminar'),
                      onPressed: () => _deleteClient(context),
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

class _ClientInfoLine extends StatelessWidget {
  const _ClientInfoLine({
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
              fontWeight: FontWeight.w700,
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

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({
    required this.api,
    required this.avatarUrl,
    required this.initials,
    required this.size,
  });

  final AnnaApi api;
  final String? avatarUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
        shape: BoxShape.circle,
        border: Border.all(color: AnnaColors.line),
      ),
      child: url == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
              ),
            )
          : ApiCachedImage(
              api: api,
              url: url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorWidget: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _ClientDetailSheet extends StatelessWidget {
  const _ClientDetailSheet({
    required this.api,
    required this.client,
    required this.canManagePhotos,
    required this.onChanged,
  });

  final AnnaApi api;
  final _ClientView client;
  final bool canManagePhotos;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required AnnaApi api,
    required _ClientView client,
    required bool canManagePhotos,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _ClientDetailSheet(
        api: api,
        client: client,
        canManagePhotos: canManagePhotos,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _deleteClient(BuildContext context, _ClientView client) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.tr('Eliminar cliente')),
        content: Text(
          t.isRussian
              ? 'Удалить ${client.name}? Если есть история, клиент будет скрыт из активного списка, а записи останутся.'
              : 'Quieres eliminar a ${client.name}? Si tiene historial, se ocultara de la lista activa sin borrar sus reservas.',
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
      await api.deleteClient(client.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Cliente eliminado.'))),
      );
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.55,
      builder: (context, controller) {
        return FutureBuilder<ApiDocument>(
          future: api.clientDetail(client.id),
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
            final detail = _ClientDetail.fromMap(snapshot.data?.data ?? {});
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    _ClientAvatar(
                      api: api,
                      avatarUrl: detail.client.avatarUrl,
                      initials: detail.client.initials,
                      size: 58,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        detail.client.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final updated = await ClientFormSheet.show(
                          context,
                          api: api,
                          client: ApiRecord(detail.client.rawData),
                        );
                        if (updated != null && context.mounted) {
                          Navigator.pop(context);
                          onChanged();
                          _ClientDetailSheet.show(
                            context,
                            api: api,
                            client: _ClientView.fromRecord(updated) ?? client,
                            canManagePhotos: canManagePhotos,
                            onChanged: onChanged,
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (canManagePhotos)
                      IconButton(
                        onPressed: () => _deleteClient(context, detail.client),
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
                _StatsGrid(stats: detail.stats),
                const SizedBox(height: 14),
                _DetailSection(
                  title: t.tr('Informacion'),
                  children: [
                    _ClientInfoLine(
                        icon: Icons.person_outline, label: detail.client.name),
                    _ClientInfoLine(
                        icon: Icons.phone_outlined,
                        label: detail.client.phone ?? t.tr('Sin telefono'),
                        onTap: detail.client.phone == null
                            ? null
                            : () => showPhoneActions(
                                  context,
                                  phone: detail.client.phone!,
                                )),
                    _ClientInfoLine(
                        icon: Icons.mail_outline,
                        label: detail.client.email ?? t.tr('Sin email'),
                        onTap: detail.client.email == null
                            ? null
                            : () => writeEmail(
                                  context,
                                  email: detail.client.email!,
                                )),
                    _ClientInfoLine(
                        icon: Icons.cake_outlined,
                        label: detail.client.birthDate ??
                            t.tr('Sin fecha de nacimiento')),
                    _ClientInfoLine(
                        icon: Icons.group_add_outlined,
                        label: detail.client.referredByName ??
                            t.tr('Sin recomendado por')),
                  ],
                ),
                _DetailSection(
                  title: t.tr('Actividad'),
                  children: [
                    _ClientInfoLine(
                        icon: Icons.history,
                        label:
                            '${t.tr('Ultima visita')}: ${detail.lastVisitText(context)}'),
                    _ClientInfoLine(
                        icon: Icons.event_available_outlined,
                        label:
                            '${t.tr('Proxima cita')}: ${detail.nextBookingText(context)}'),
                    _ClientInfoLine(
                        icon: Icons.card_giftcard,
                        label:
                            '${t.tr('Para proximo premio')}: ${detail.rewardText(context)}'),
                  ],
                ),
                _CountListSection(
                    title: t.tr('Servicios favoritos'),
                    items: detail.topServices),
                _CountListSection(
                  title: t.tr('Empleados habituales'),
                  items: detail.topEmployees,
                  onTap: (item) {
                    if (item.id == null) return;
                    showEmployeeDetailSheet(context,
                        api: api, employeeId: item.id!);
                  },
                ),
                _ClickableClientListSection(
                  title: t.tr('Clientes referidos'),
                  items: detail.referredClients,
                  onClientTap: (client) {
                    Navigator.pop(context);
                    _ClientDetailSheet.show(
                      context,
                      api: api,
                      client: client,
                      canManagePhotos: canManagePhotos,
                      onChanged: onChanged,
                    );
                  },
                ),
                _ReferralTreeSection(
                  root: detail.referralTree,
                  onClientTap: (node) {
                    Navigator.pop(context);
                    _ClientDetailSheet.show(
                      context,
                      api: api,
                      client: _ClientView(
                        id: node.id,
                        name: node.name,
                        isActive: true,
                        referralRewardsUsed: '0',
                      ),
                      canManagePhotos: canManagePhotos,
                      onChanged: onChanged,
                    );
                  },
                ),
                _ClickableBookingHistorySection(
                  bookings: detail.bookings,
                  onBookingTap: (booking) =>
                      _BookingDetailSheet.show(context, booking: booking),
                ),
                _PhotoHistorySection(
                  api: api,
                  photos: detail.photoHistory,
                  canManagePhotos: canManagePhotos,
                  onChanged: () {},
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, String> stats;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final entries = [
      (t.tr('Visitas hechas'), stats['total_visits'] ?? '0'),
      (t.tr('Gastado total'), '${stats['total_spent'] ?? '0.00'} EUR'),
      (t.tr('Ticket medio'), '${stats['avg_ticket'] ?? '0.00'} EUR'),
      (t.tr('Clientes traidos'), stats['referred_clients_count'] ?? '0'),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

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

class _CountListSection extends StatelessWidget {
  const _CountListSection({
    required this.title,
    required this.items,
    this.onTap,
  });

  final String title;
  final List<_NamedCount> items;
  final ValueChanged<_NamedCount>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSection(
      title: title,
      children: items.isEmpty
          ? [
              Text(t.tr('Sin datos.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.name} (${item.count})',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing:
                      onTap == null ? null : const Icon(Icons.chevron_right),
                  onTap: onTap == null ? null : () => onTap!(item),
                ),
            ],
    );
  }
}

// ignore: unused_element
class _BookingHistorySection extends StatelessWidget {
  const _BookingHistorySection({required this.bookings});

  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSection(
      title: t.tr('Historial de reservas'),
      children: bookings.isEmpty
          ? [
              Text(t.tr('Sin reservas.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final booking in bookings)
                Text(
                  [
                    _bookingDate(booking['start_at']),
                    booking['service_name'],
                    booking['employee_name'],
                    booking['zone_name'],
                    booking['status_label'],
                    booking['client_price_snapshot'],
                  ]
                      .whereType<Object>()
                      .map((value) => value.toString())
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
    );
  }
}

class _ClickableClientListSection extends StatelessWidget {
  const _ClickableClientListSection({
    required this.title,
    required this.items,
    required this.onClientTap,
  });

  final String title;
  final List<_ClientView> items;
  final ValueChanged<_ClientView> onClientTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSection(
      title: title,
      children: items.isEmpty
          ? [
              Text(t.tr('Sin referidos.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle:
                      Text(item.phone ?? item.email ?? t.tr('Sin telefono')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onClientTap(item),
                ),
            ],
    );
  }
}

class _ClickableBookingHistorySection extends StatelessWidget {
  const _ClickableBookingHistorySection({
    required this.bookings,
    required this.onBookingTap,
  });

  final List<Map<String, dynamic>> bookings;
  final ValueChanged<Map<String, dynamic>> onBookingTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSection(
      title: t.tr('Historial de reservas'),
      children: bookings.isEmpty
          ? [
              Text(t.tr('Sin reservas.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [
              for (final booking in bookings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      _bookingDate(booking['start_at']),
                      booking['service_name'],
                    ]
                        .whereType<Object>()
                        .map((value) => value.toString())
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      booking['employee_name'],
                      booking['zone_name'],
                      booking['status_label'],
                      booking['client_price_snapshot'],
                    ]
                        .whereType<Object>()
                        .map((value) => value.toString())
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onBookingTap(booking),
                ),
            ],
    );
  }
}

class _ReferralTreeSection extends StatelessWidget {
  const _ReferralTreeSection({
    required this.root,
    required this.onClientTap,
  });

  final _ReferralNode? root;
  final ValueChanged<_ReferralNode> onClientTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final node = root;
    return _DetailSection(
      title: t.tr('Piramide de recomendaciones'),
      children: node == null
          ? [
              Text(t.tr('Sin referidos.'),
                  style: const TextStyle(color: AnnaColors.muted))
            ]
          : [_ReferralTreeNode(node: node, depth: 0, onClientTap: onClientTap)],
    );
  }
}

class _ReferralTreeNode extends StatelessWidget {
  const _ReferralTreeNode({
    required this.node,
    required this.depth,
    required this.onClientTap,
  });

  final _ReferralNode node;
  final int depth;
  final ValueChanged<_ReferralNode> onClientTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AnnaRadii.md),
            onTap: () => onClientTap(node),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: depth == 0
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.20)
                    : const Color(0x14E8FFF1),
                borderRadius: BorderRadius.circular(AnnaRadii.md),
                border: Border.all(color: AnnaColors.line),
              ),
              child: Row(
                children: [
                  Icon(
                    depth == 0
                        ? Icons.account_tree_outlined
                        : Icons.person_outline,
                    size: 18,
                    color: AnnaColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(node.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  AnnaBadge(
                    '${node.children.length} ${AppLocalizations.of(context).tr('referidos')}',
                  ),
                ],
              ),
            ),
          ),
          for (final child in node.children)
            _ReferralTreeNode(
              node: child,
              depth: depth + 1,
              onClientTap: onClientTap,
            ),
        ],
      ),
    );
  }
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking});

  final Map<String, dynamic> booking;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> booking,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _BookingDetailSheet(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.booking,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 12),
          _ClientInfoLine(
              icon: Icons.event_outlined,
              label: _bookingDate(booking['start_at'])),
          const SizedBox(height: 8),
          _ClientInfoLine(
              icon: Icons.spa_outlined,
              label:
                  booking['service_name']?.toString() ?? t.tr('Sin servicio')),
          const SizedBox(height: 8),
          _ClientInfoLine(
              icon: Icons.badge_outlined,
              label:
                  booking['employee_name']?.toString() ?? t.tr('Sin empleado')),
          const SizedBox(height: 8),
          _ClientInfoLine(
              icon: Icons.place_outlined,
              label: booking['zone_name']?.toString() ?? t.tr('Sin zona')),
          const SizedBox(height: 8),
          _ClientInfoLine(
              icon: Icons.sell_outlined,
              label:
                  '${booking['status_label'] ?? ''} · ${booking['client_price_snapshot'] ?? ''}'),
          if ((booking['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(booking['notes'].toString(),
                style: const TextStyle(color: AnnaColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _PhotoHistorySection extends StatefulWidget {
  const _PhotoHistorySection({
    required this.api,
    required this.photos,
    required this.canManagePhotos,
    required this.onChanged,
  });

  final AnnaApi api;
  final List<Map<String, dynamic>> photos;
  final bool canManagePhotos;
  final VoidCallback onChanged;

  @override
  State<_PhotoHistorySection> createState() => _PhotoHistorySectionState();
}

class _PhotoHistorySectionState extends State<_PhotoHistorySection> {
  final Set<String> _updating = {};

  Future<void> _toggleVisibility(Map<String, dynamic> photo) async {
    final id = photo['id']?.toString();
    if (id == null || id.isEmpty) return;
    final current = _boolValue(photo['is_visible_to_client'], fallback: false);
    setState(() => _updating.add(id));
    try {
      await widget.api.updateBookingPhotoVisibility(
        photoId: id,
        isVisibleToClient: !current,
      );
      if (!mounted) return;
      setState(() => photo['is_visible_to_client'] = !current);
      widget.onChanged();
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSection(
      title: t.tr('Historial visual'),
      children: widget.photos.isEmpty
          ? [
              Text(
                t.tr('Todavia no hay fotos guardadas para este cliente.'),
                style: const TextStyle(color: AnnaColors.muted),
              )
            ]
          : [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final photo in widget.photos)
                    InkWell(
                      borderRadius: BorderRadius.circular(AnnaRadii.md),
                      onTap: () => AnnaPhotoViewer.showNetwork(
                        context,
                        title: _photoTitle(photo),
                        url: photo['image_url'].toString(),
                        api: widget.api,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AnnaRadii.md),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ApiCachedImage(
                              api: widget.api,
                              url: photo['image_url'].toString(),
                              fit: BoxFit.cover,
                            ),
                            const Positioned(
                              right: 8,
                              top: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.open_in_full,
                                    color: AnnaColors.text,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.canManagePhotos)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _PhotoVisibilityButton(
                                  visible: _boolValue(
                                      photo['is_visible_to_client'],
                                      fallback: false),
                                  loading: _updating
                                      .contains(photo['id']?.toString() ?? ''),
                                  onTap: () => _toggleVisibility(photo),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
    );
  }

  String _photoTitle(Map<String, dynamic> photo) {
    final t = AppLocalizations.of(context);
    final type = photo['photo_type']?.toString();
    return switch (type) {
      'before' => t.tr('Foto antes'),
      'after' => t.tr('Foto despues'),
      _ => t.tr('Foto'),
    };
  }
}

class _PhotoVisibilityButton extends StatelessWidget {
  const _PhotoVisibilityButton({
    required this.visible,
    required this.loading,
    required this.onTap,
  });

  final bool visible;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: visible ? const Color(0xCC1E6B47) : const Color(0xCC331F1A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox.square(
          dimension: 32,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AnnaColors.text,
                  size: 18,
                ),
        ),
      ),
    );
  }
}

class _ClientDetail {
  const _ClientDetail({
    required this.client,
    required this.stats,
    required this.lastVisit,
    required this.nextBooking,
    required this.topServices,
    required this.topEmployees,
    required this.referredClients,
    required this.referralTree,
    required this.bookings,
    required this.photoHistory,
    required this.availableRewards,
    required this.remainingForNextReward,
  });

  final _ClientView client;
  final Map<String, String> stats;
  final Map<String, dynamic>? lastVisit;
  final Map<String, dynamic>? nextBooking;
  final List<_NamedCount> topServices;
  final List<_NamedCount> topEmployees;
  final List<_ClientView> referredClients;
  final _ReferralNode? referralTree;
  final List<Map<String, dynamic>> bookings;
  final List<Map<String, dynamic>> photoHistory;
  final int availableRewards;
  final int remainingForNextReward;

  String lastVisitText(BuildContext context) =>
      _bookingSummary(context, lastVisit);
  String nextBookingText(BuildContext context) =>
      _bookingSummary(context, nextBooking);
  String rewardText(BuildContext context) {
    final t = AppLocalizations.of(context);
    return availableRewards > 0
        ? t.tr('Ya disponible')
        : '$remainingForNextReward ${t.tr('visitas')}';
  }

  factory _ClientDetail.fromMap(Map<String, dynamic> data) {
    final clientRecord = data['client'] is Map
        ? ApiRecord(Map<String, dynamic>.from(data['client'] as Map))
        : ApiRecord({});
    final statsRaw = data['stats'] is Map
        ? Map<String, dynamic>.from(data['stats'] as Map)
        : <String, dynamic>{};
    final referredRaw = data['referred_clients'] is List
        ? data['referred_clients'] as List
        : const [];
    return _ClientDetail(
      client: _ClientView.fromRecord(clientRecord) ??
          const _ClientView(
              id: '',
              name: 'Cliente',
              isActive: true,
              referralRewardsUsed: '0'),
      stats: {
        for (final entry in statsRaw.entries)
          entry.key: entry.value?.toString() ?? '',
        'referred_clients_count':
            data['referred_clients_count']?.toString() ?? '0',
      },
      lastVisit: _mapOrNull(data['last_visit']),
      nextBooking: _mapOrNull(data['next_booking']),
      topServices: _namedCounts(data['top_services']),
      topEmployees: _namedCounts(data['top_employees']),
      referredClients: referredRaw
          .whereType<Map>()
          .map((item) => _ClientView.fromRecord(
              ApiRecord(Map<String, dynamic>.from(item))))
          .whereType<_ClientView>()
          .toList(),
      referralTree: _ReferralNode.fromObject(data['referral_tree']),
      bookings: _mapList(data['bookings']),
      photoHistory: _mapList(data['photo_history']),
      availableRewards:
          int.tryParse(data['available_rewards']?.toString() ?? '') ?? 0,
      remainingForNextReward:
          int.tryParse(data['remaining_for_next_reward']?.toString() ?? '') ??
              0,
    );
  }
}

class _NamedCount {
  const _NamedCount(this.name, this.count, {this.id});

  final String name;
  final String count;
  final String? id;
}

class _ReferralNode {
  const _ReferralNode({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<_ReferralNode> children;

  static _ReferralNode? fromObject(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    final name = value['name']?.toString();
    if (id == null || name == null || name.isEmpty) return null;
    final rawChildren = value['children'];
    return _ReferralNode(
      id: id,
      name: name,
      children: rawChildren is List
          ? rawChildren
              .map(_ReferralNode.fromObject)
              .whereType<_ReferralNode>()
              .toList()
          : const [],
    );
  }
}

class _ClientView {
  const _ClientView({
    required this.id,
    required this.name,
    required this.isActive,
    this.isBlacklisted = false,
    this.isOnlineClient = false,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.phone,
    this.email,
    this.birthDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.referredByName,
    this.avatarUrl,
    required this.referralRewardsUsed,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? birthDate;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final String? referredByName;
  final String? avatarUrl;
  final String referralRewardsUsed;
  final bool isActive;
  final bool isBlacklisted;
  final bool isOnlineClient;
  final int totalOrders;
  final double totalSpent;

  Map<String, dynamic> get rawData => {
        'id': id,
        'full_name': name,
        'first_name': name.split(' ').isEmpty ? name : name.split(' ').first,
        'last_name': name.split(' ').length <= 1
            ? ''
            : name.split(' ').skip(1).join(' '),
        'phone': phone,
        'email': email,
        'birth_date': birthDate,
        'notes': notes,
        'is_active': isActive,
        'is_blacklisted': isBlacklisted,
        'is_online_client': isOnlineClient,
        'total_orders': totalOrders,
        'total_spent': totalSpent,
        'referred_by_name': referredByName,
        'avatar_url': avatarUrl,
        'referral_rewards_used': referralRewardsUsed,
      };

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
    ].whereType<String>().join(' ').toLowerCase();
  }

  String? get createdText {
    return _dateText(createdAt);
  }

  String? get updatedText {
    return _dateText(updatedAt);
  }

  static String? _dateText(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('d/M/yyyy', 'es').format(parsed);
  }

  static _ClientView? fromRecord(ApiRecord record) {
    final id = record.valueAsText('id') ?? record.valueAsText('pk');
    if (id == null) return null;
    final first = record.valueAsText('first_name') ?? '';
    final last = record.valueAsText('last_name') ?? '';
    final composed = '$first $last'.trim();
    final name = record.valueAsText('full_name') ??
        record.valueAsText('name') ??
        (composed.isNotEmpty ? composed : 'Cliente $id');
    return _ClientView(
      id: id,
      name: name,
      phone: _nonEmpty(record.valueAsText('phone')),
      email: _nonEmpty(record.valueAsText('email')),
      birthDate: _nonEmpty(record.valueAsText('birth_date')),
      notes: _nonEmpty(record.valueAsText('notes')),
      createdAt: _nonEmpty(record.valueAsText('created_at')),
      updatedAt: _nonEmpty(record.valueAsText('updated_at')),
      referredByName: _nonEmpty(record.valueAsText('referred_by_name')),
      avatarUrl: _nonEmpty(record.valueAsText('avatar_url')),
      referralRewardsUsed: record.valueAsText('referral_rewards_used') ?? '0',
      isActive: _boolValue(record.data['is_active'], fallback: true),
      isBlacklisted: _boolValue(record.data['is_blacklisted'], fallback: false),
      isOnlineClient:
          _boolValue(record.data['is_online_client'], fallback: false),
      totalOrders: int.tryParse(record.valueAsText('total_orders') ?? '') ?? 0,
      totalSpent: double.tryParse(record.valueAsText('total_spent') ?? '') ?? 0,
    );
  }
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
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

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
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
            id: item['id']?.toString(),
          ))
      .where((item) => item.name.isNotEmpty)
      .toList();
}

String _bookingSummary(BuildContext context, Map<String, dynamic>? booking) {
  final t = AppLocalizations.of(context);
  if (booking == null) return t.tr('Sin datos.');
  final date = _bookingDate(booking['start_at']);
  final service = booking['service_name']?.toString() ?? '';
  final employee = booking['employee_name']?.toString() ?? '';
  return [date, service, employee]
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

String _bookingDate(Object? value) {
  if (value == null) return '';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('dd/MM/yyyy HH:mm', 'es').format(parsed);
}
