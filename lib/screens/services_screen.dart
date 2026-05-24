import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'color_palette_picker.dart';
import 'shared.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    required this.api,
    required this.canManageStaff,
    super.key,
  });

  final AnnaApi api;
  final bool canManageStaff;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<_ServiceReferences> _future = _load();

  Future<_ServiceReferences> _load() async {
    final result = await Future.wait([
      widget.api.services(),
      widget.api.zones(),
      widget.api.clientRewardRules(),
    ]);
    return _ServiceReferences(
      services: result[0],
      zones: result[1],
      rewards: result[2],
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Servicios',
      action: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      child: FutureBuilder<_ServiceReferences>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final refs = snapshot.data!;
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Servicios'),
                    Tab(text: 'Zonas'),
                    Tab(text: 'Premios'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.66,
                  child: TabBarView(
                    children: [
                      _ServicesTab(
                        api: widget.api,
                        refs: refs,
                        canManageStaff: widget.canManageStaff,
                        onChanged: _reload,
                      ),
                      _ZonesTab(
                        api: widget.api,
                        refs: refs,
                        canManageStaff: widget.canManageStaff,
                        onChanged: _reload,
                      ),
                      _RewardsTab(
                        api: widget.api,
                        refs: refs,
                        canManageStaff: widget.canManageStaff,
                        onChanged: _reload,
                      ),
                    ],
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

class _ServicesTab extends StatelessWidget {
  const _ServicesTab(
      {required this.api,
      required this.refs,
      required this.canManageStaff,
      required this.onChanged});

  final AnnaApi api;
  final _ServiceReferences refs;
  final bool canManageStaff;
  final VoidCallback onChanged;

  Future<void> _deleteService(BuildContext context, ApiRecord service) async {
    final id = service.valueAsText('id');
    final name = service.valueAsText('name') ?? 'Servicio';
    if (id == null) return;
    final confirmed = await _confirmDelete(
      context,
      title: 'Eliminar servicio',
      message:
          'Quieres eliminar $name? Si tiene historial, se desactivara sin borrar reservas anteriores.',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.deleteService(id);
      if (!context.mounted) return;
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio eliminado.')),
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
    return ListView(
      children: [
        if (canManageStaff) ...[
          FilledButton.icon(
            onPressed: () async {
              final changed = await _ServiceFormSheet.show(context,
                  api: api, refs: refs, service: null);
              if (changed == true && context.mounted) onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear servicio'),
          ),
          const SizedBox(height: 12),
        ],
        for (final service in refs.services.items) ...[
          _SalonListCard(
            icon: Icons.spa_outlined,
            color: parseHexColor(service.valueAsText('color')) ??
                Theme.of(context).colorScheme.primary,
            title: service.valueAsText('name') ?? 'Servicio',
            chips: [
              '${service.valueAsText('duration_minutes') ?? '-'} min',
              '${service.valueAsText('price') ?? '0.00'} EUR',
              if (_bool(service.data['requires_zone'], fallback: false))
                'Con zona',
            ],
            description: service.valueAsText('description'),
            onTap: canManageStaff
                ? () async {
                    final changed = await _ServiceFormSheet.show(context,
                        api: api, refs: refs, service: service);
                    if (changed == true && context.mounted) onChanged();
                  }
                : null,
            onDelete:
                canManageStaff ? () => _deleteService(context, service) : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ZonesTab extends StatelessWidget {
  const _ZonesTab(
      {required this.api,
      required this.refs,
      required this.canManageStaff,
      required this.onChanged});

  final AnnaApi api;
  final _ServiceReferences refs;
  final bool canManageStaff;
  final VoidCallback onChanged;

  Future<void> _deleteZone(BuildContext context, ApiRecord zone) async {
    final id = zone.valueAsText('id');
    final name = zone.valueAsText('name') ?? 'Zona';
    if (id == null) return;
    final confirmed = await _confirmDelete(
      context,
      title: 'Eliminar zona',
      message:
          'Quieres eliminar $name? Si tiene historial, se desactivara sin borrar reservas anteriores.',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await api.deleteZone(id);
      if (!context.mounted) return;
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zona eliminada.')),
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
    return ListView(
      children: [
        if (canManageStaff) ...[
          FilledButton.icon(
            onPressed: () async {
              final changed =
                  await _ZoneFormSheet.show(context, api: api, zone: null);
              if (changed == true && context.mounted) onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear zona'),
          ),
          const SizedBox(height: 12),
        ],
        for (final zone in refs.zones.items) ...[
          _SalonListCard(
            icon: Icons.place_outlined,
            color: parseHexColor(zone.valueAsText('color')) ??
                Theme.of(context).colorScheme.primary,
            title: zone.valueAsText('name') ?? 'Zona',
            chips: [
              zone.valueAsText('zone_type_label') ?? 'Otro',
              'Capacidad ${zone.valueAsText('capacity') ?? '1'}',
              _bool(zone.data['is_active'], fallback: true)
                  ? 'Activa'
                  : 'Inactiva',
            ],
            description: zone.valueAsText('notes'),
            onTap: canManageStaff
                ? () async {
                    final changed = await _ZoneFormSheet.show(context,
                        api: api, zone: zone);
                    if (changed == true && context.mounted) onChanged();
                  }
                : null,
            onDelete: canManageStaff ? () => _deleteZone(context, zone) : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({
    required this.api,
    required this.refs,
    required this.canManageStaff,
    required this.onChanged,
  });

  final AnnaApi api;
  final _ServiceReferences refs;
  final bool canManageStaff;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final reward in refs.rewards.items) ...[
          _SalonListCard(
            icon: _rewardIcon(reward.valueAsText('icon')),
            color: parseHexColor(reward.valueAsText('color')) ??
                Theme.of(context).colorScheme.primary,
            title: reward.valueAsText('name') ?? 'Premio',
            chips: [
              reward.valueAsText('reward_type_label') ?? 'Premio',
              'Meta ${reward.valueAsText('threshold') ?? '0'}',
              '${reward.valueAsText('discount_percent') ?? '0'}%',
              _bool(reward.data['is_active'], fallback: true)
                  ? 'Activa'
                  : 'Inactiva',
            ],
            description: _rewardDescription(reward),
            onTap: canManageStaff
                ? () async {
                    final changed = await _RewardFormSheet.show(
                      context,
                      api: api,
                      reward: reward,
                    );
                    if (changed == true && context.mounted) onChanged();
                  }
                : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _rewardDescription(ApiRecord reward) {
    final type = reward.valueAsText('reward_type');
    return switch (type) {
      'referrals' => 'Por clientes traidos que ya hicieron una visita.',
      'visits' => 'Por cantidad de visitas realizadas.',
      'spent' => 'Por dinero gastado acumulado.',
      _ => 'Premio para clientes.',
    };
  }
}

class _SalonListCard extends StatelessWidget {
  const _SalonListCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.chips,
    required this.onTap,
    this.description,
    this.onDelete,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> chips;
  final VoidCallback? onTap;
  final String? description;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AnnaRadii.lg),
        onTap: onTap,
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
                    Icon(icon, color: AnnaColors.text, size: 22),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnnaColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (description != null && description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AnnaColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final chip in chips)
                          AnnaBadge(chip, warning: chip == 'Inactiva'),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: onDelete,
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

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet(
      {required this.api, required this.refs, required this.service});

  final AnnaApi api;
  final _ServiceReferences refs;
  final ApiRecord? service;

  static Future<bool?> show(BuildContext context,
      {required AnnaApi api,
      required _ServiceReferences refs,
      required ApiRecord? service}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) =>
          _ServiceFormSheet(api: api, refs: refs, service: service),
    );
  }

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.service?.valueAsText('name') ?? '');
  late final _description = TextEditingController(
      text: widget.service?.valueAsText('description') ?? '');
  late final _duration = TextEditingController(
      text: widget.service?.valueAsText('duration_minutes') ?? '60');
  late final _price = TextEditingController(
      text: widget.service?.valueAsText('price') ?? '0.00');
  late String _color = widget.service?.valueAsText('color') ?? '#6FD29C';
  late bool _requiresZone =
      _bool(widget.service?.data['requires_zone'], fallback: false);
  late bool _isActive =
      _bool(widget.service?.data['is_active'], fallback: true);
  late final Set<String> _allowedZones =
      _ids(widget.service?.data['allowed_zone_ids']);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final activeZoneIds = widget.refs.zones.items
        .map((zone) => zone.valueAsText('id'))
        .whereType<String>()
        .toSet();
    final allowedZoneIds = _allowedZones.where(activeZoneIds.contains).toList()
      ..sort();
    if (_requiresZone && allowedZoneIds.isEmpty) {
      setState(
          () => _error = 'Selecciona al menos una zona para este servicio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'duration_minutes': int.tryParse(_duration.text.trim()) ?? 60,
      'price': _price.text.trim(),
      'color': _color,
      'requires_zone': _requiresZone,
      'allowed_zones': _requiresZone
          ? allowedZoneIds.map((id) => int.tryParse(id) ?? id).toList()
          : <Object>[],
      'is_active': _isActive,
    };
    try {
      final id = widget.service?.valueAsText('id');
      if (id == null) {
        await widget.api.createService(payload);
      } else {
        await widget.api.updateService(id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetTitle(
                  title: widget.service == null
                      ? 'Crear servicio'
                      : 'Editar servicio'),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _duration,
                  decoration: const InputDecoration(labelText: 'Duracion min'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              ColorPalettePicker(
                label: 'Color servicio',
                value: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requiere zona'),
                  value: _requiresZone,
                  onChanged: (v) => setState(() => _requiresZone = v)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v)),
              const SizedBox(height: 8),
              Text('Zonas permitidas',
                  style: Theme.of(context).textTheme.titleMedium),
              for (final zone in widget.refs.zones.items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(zone.valueAsText('name') ?? 'Zona'),
                  value: _allowedZones.contains(zone.valueAsText('id')),
                  onChanged: !_requiresZone
                      ? null
                      : (value) {
                          final id = zone.valueAsText('id');
                          if (id == null) return;
                          setState(() => value == true
                              ? _allowedZones.add(id)
                              : _allowedZones.remove(id));
                        },
                ),
              TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Descripcion')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AnnaErrorBanner(_error!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child:
                          Text(widget.service == null ? 'Crear' : 'Guardar'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneFormSheet extends StatefulWidget {
  const _ZoneFormSheet({required this.api, required this.zone});

  final AnnaApi api;
  final ApiRecord? zone;

  static Future<bool?> show(BuildContext context,
      {required AnnaApi api, required ApiRecord? zone}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _ZoneFormSheet(api: api, zone: zone),
    );
  }

  @override
  State<_ZoneFormSheet> createState() => _ZoneFormSheetState();
}

class _ZoneFormSheetState extends State<_ZoneFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.zone?.valueAsText('name') ?? '');
  late final _capacity =
      TextEditingController(text: widget.zone?.valueAsText('capacity') ?? '1');
  late String _color = widget.zone?.valueAsText('color') ?? '#e291b3';
  late final _notes =
      TextEditingController(text: widget.zone?.valueAsText('notes') ?? '');
  late String _type = widget.zone?.valueAsText('zone_type') ?? 'other';
  late bool _isActive = _bool(widget.zone?.data['is_active'], fallback: true);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = {
      'name': _name.text.trim(),
      'zone_type': _type,
      'capacity': int.tryParse(_capacity.text.trim()) ?? 1,
      'color': _color,
      'notes': _notes.text.trim(),
      'is_active': _isActive,
    };
    try {
      final id = widget.zone?.valueAsText('id');
      if (id == null) {
        await widget.api.createZone(payload);
      } else {
        await widget.api.updateZone(id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetTitle(
                  title: widget.zone == null ? 'Crear zona' : 'Editar zona'),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: _required),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'cabin', child: Text('Cabina')),
                  DropdownMenuItem(value: 'table', child: Text('Mesa')),
                  DropdownMenuItem(value: 'wash', child: Text('Lavacabezas')),
                  DropdownMenuItem(value: 'makeup', child: Text('Maquillaje')),
                  DropdownMenuItem(value: 'other', child: Text('Otro')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _capacity,
                  decoration: const InputDecoration(labelText: 'Capacidad'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              ColorPalettePicker(
                label: 'Color zona',
                value: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activa'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v)),
              TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notas')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AnnaErrorBanner(_error!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.zone == null ? 'Crear' : 'Guardar'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardFormSheet extends StatefulWidget {
  const _RewardFormSheet({required this.api, required this.reward});

  final AnnaApi api;
  final ApiRecord reward;

  static Future<bool?> show(
    BuildContext context, {
    required AnnaApi api,
    required ApiRecord reward,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _RewardFormSheet(api: api, reward: reward),
    );
  }

  @override
  State<_RewardFormSheet> createState() => _RewardFormSheetState();
}

class _RewardFormSheetState extends State<_RewardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.reward.valueAsText('name') ?? '');
  late final _threshold = TextEditingController(
      text: widget.reward.valueAsText('threshold') ?? '5');
  late final _discount = TextEditingController(
      text: widget.reward.valueAsText('discount_percent') ?? '10.00');
  late String _color = widget.reward.valueAsText('color') ?? '#6FD29C';
  late bool _isActive = _bool(widget.reward.data['is_active'], fallback: true);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    _discount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateClientRewardRule(
        widget.reward.valueAsText('id') ??
            widget.reward.valueAsText('pk') ??
            '',
        {
          'name': _name.text.trim(),
          'threshold': int.tryParse(_threshold.text.trim()) ?? 1,
          'discount_percent': _discount.text.trim(),
          'color': _color,
          'is_active': _isActive,
          'sort_order':
              int.tryParse(widget.reward.valueAsText('sort_order') ?? '') ?? 0,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetTitle(title: 'Editar premio'),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _threshold,
                decoration: const InputDecoration(labelText: 'Meta'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discount,
                decoration: const InputDecoration(labelText: 'Descuento %'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ColorPalettePicker(
                label: 'Color premio',
                value: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activa'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
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
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }
}

class _ServiceReferences {
  const _ServiceReferences({
    required this.services,
    required this.zones,
    required this.rewards,
  });

  final ApiCollection services;
  final ApiCollection zones;
  final ApiCollection rewards;
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Obligatorio' : null;

Future<bool?> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

Set<String> _ids(Object? value) {
  if (value is! List) return {};
  return value.map((item) => item?.toString()).whereType<String>().toSet();
}

IconData _rewardIcon(String? value) {
  return switch (value) {
    'groups' => Icons.groups_outlined,
    'star' => Icons.star_outline,
    'workspace_premium' => Icons.workspace_premium_outlined,
    _ => Icons.card_giftcard_outlined,
  };
}
