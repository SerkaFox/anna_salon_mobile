import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_settings_controller.dart';
import '../api/anna_api.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'api_cached_image.dart';
import 'photo_viewer.dart';
import 'settings_screen.dart';
import 'shared.dart';

class ClientPortalShell extends StatefulWidget {
  const ClientPortalShell({
    required this.api,
    required this.settings,
    required this.profile,
    required this.onSignOut,
    super.key,
  });

  final AnnaApi api;
  final AppSettingsController settings;
  final Map<String, dynamic> profile;
  final VoidCallback onSignOut;

  @override
  State<ClientPortalShell> createState() => _ClientPortalShellState();
}

class _ClientPortalShellState extends State<ClientPortalShell> {
  int _index = 0;
  int _refreshToken = 0;

  void _refreshHome() {
    setState(() {
      _refreshToken++;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ClientHomeScreen(
        api: widget.api,
        profile: widget.profile,
        refreshToken: _refreshToken,
      ),
      ClientBookingScreen(
        api: widget.api,
        profile: widget.profile,
        onCreated: _refreshHome,
      ),
      SettingsScreen(
        api: widget.api,
        settings: widget.settings,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: annaBackgroundDecoration(context),
        child: SafeArea(child: screens[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi ficha',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Reservar',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    required this.api,
    required this.profile,
    required this.refreshToken,
    super.key,
  });

  final AnnaApi api;
  final Map<String, dynamic> profile;
  final int refreshToken;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _imagePicker = ImagePicker();
  late Future<Map<String, dynamic>> _detail = _loadDetail();

  @override
  void didUpdateWidget(covariant ClientHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _detail = _loadDetail();
    }
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    final clientId = widget.profile['client_id'];
    if (clientId != null) {
      return (await widget.api.clientDetail(clientId)).data;
    }
    final clients = await widget.api.clients();
    if (clients.items.isEmpty) {
      throw AnnaApiException('Tu cuenta no tiene cliente vinculado.');
    }
    final id = clients.items.first.valueAsText('id');
    if (id == null) {
      throw AnnaApiException('No se pudo leer tu ficha de cliente.');
    }
    return (await widget.api.clientDetail(id)).data;
  }

  Future<void> _pickAvatar(Object? clientId) async {
    if (clientId == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: const Text('Camara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await _imagePicker.pickImage(source: source, imageQuality: 82);
    if (picked == null) return;
    try {
      await widget.api.uploadClientAvatar(
        clientId: clientId,
        imagePath: picked.path,
      );
      await ApiCachedImage.evict(widget.api, 'clients/$clientId/avatar/');
      if (!mounted) return;
      setState(() => _detail = _loadDetail());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar actualizado.')),
      );
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'BRIMOON Studio',
      action: IconButton(
        onPressed: () => setState(() => _detail = _loadDetail()),
        icon: Icon(Icons.refresh),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error!,
              onRetry: () => setState(() => _detail = _loadDetail()),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final client = _map(data['client']);
          final bookings = _mapList(data['bookings']);
          final photos = _mapList(data['photo_history']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientSummaryCard(
                api: widget.api,
                data: data,
                client: client,
                onAvatarTap: () => _pickAvatar(client['id']),
              ),
              const SizedBox(height: 14),
              _ClientBookingsCard(bookings: bookings),
              const SizedBox(height: 14),
              _ClientPhotosCard(api: widget.api, photos: photos),
            ],
          );
        },
      ),
    );
  }
}

class _ClientSummaryCard extends StatelessWidget {
  const _ClientSummaryCard({
    required this.api,
    required this.data,
    required this.client,
    required this.onAvatarTap,
  });

  final AnnaApi api;
  final Map<String, dynamic> data;
  final Map<String, dynamic> client;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final stats = _map(data['stats']);
    final name =
        _text(client['full_name']) ?? _text(client['first_name']) ?? 'Cliente';
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _PortalClientAvatar(
                      api: api,
                      avatarUrl: _text(client['avatar_url']),
                      name: name,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AnnaColors.bgSoft),
                        ),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 13,
                          color: Colors.white,
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
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _text(client['phone']),
                        _text(client['email']),
                      ].whereType<String>().join(' · '),
                      style: TextStyle(color: AnnaColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnnaBadge('${_text(stats['total_visits']) ?? '0'} visitas'),
              AnnaBadge('${_money(stats['total_spent'])} EUR gastado'),
              AnnaBadge('${_text(data['available_rewards']) ?? '0'} premios'),
            ],
          ),
          const SizedBox(height: 12),
          _RewardProgressSection(rewards: _mapList(data['rewards'])),
        ],
      ),
    );
  }
}

class _RewardProgressSection extends StatelessWidget {
  const _RewardProgressSection({required this.rewards});

  final List<Map<String, dynamic>> rewards;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Premios', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final reward in rewards) ...[
          _RewardProgressCard(reward: reward),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RewardProgressCard extends StatelessWidget {
  const _RewardProgressCard({required this.reward});

  final Map<String, dynamic> reward;

  @override
  Widget build(BuildContext context) {
    final available = _intValue(reward['available']);
    final current = _intValue(reward['current']);
    final threshold = _intValue(reward['threshold']).clamp(1, 999999);
    final remaining = _intValue(reward['remaining']);
    final progress = (current / threshold).clamp(0.0, 1.0);
    final color = _parseRewardColor(_text(reward['color'])) ??
        Theme.of(context).colorScheme.primary;
    final name = _text(reward['name']) ?? 'Premio';
    final discount = _text(reward['discount_percent']) ?? '0';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        onTap: () => _showRewardInfo(context, reward),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: available > 0 ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(AnnaRadii.md),
            border: Border.all(
              color: color.withValues(alpha: available > 0 ? 0.70 : 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.70)),
                ),
                child: Icon(_rewardIcon(_text(reward['icon'])), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AnnaColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        AnnaBadge(
                          available > 0 ? 'Disponible' : '$discount%',
                          warning: available == 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: const Color(0x33000000),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      available > 0
                          ? 'Tienes $available premio${available == 1 ? '' : 's'} para activar.'
                          : _remainingRewardText(reward, remaining),
                      style: TextStyle(
                        color: AnnaColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.info_outline, color: AnnaColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

void _showRewardInfo(BuildContext context, Map<String, dynamic> reward) {
  final name = _text(reward['name']) ?? 'Premio';
  final discount = _text(reward['discount_percent']) ?? '0';
  final current = _intValue(reward['current']);
  final threshold = _intValue(reward['threshold']).clamp(1, 999999);
  final remaining = _intValue(reward['remaining']);
  final available = _intValue(reward['available']);
  final color = _parseRewardColor(_text(reward['color'])) ??
      Theme.of(context).colorScheme.primary;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AnnaColors.bgSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.70)),
                  ),
                  child: Icon(_rewardIcon(_text(reward['icon'])), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _rewardExplanation(reward),
              style: TextStyle(color: AnnaColors.text, height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AnnaBadge('$discount% descuento'),
                AnnaBadge('$current / $threshold'),
                AnnaBadge(
                  available > 0 ? '$available disponible' : 'Faltan $remaining',
                  warning: available == 0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _rewardExplanation(Map<String, dynamic> reward) {
  final name = _text(reward['name']) ?? 'este premio';
  final discount = _text(reward['discount_percent']) ?? '0';
  final remaining = _intValue(reward['remaining']);
  final available = _intValue(reward['available']);
  final current = _intValue(reward['current']);
  final threshold = _intValue(reward['threshold']);
  final type = _text(reward['reward_type']);
  if (available > 0) {
    return 'Ya puedes activar $name al crear una reserva y recibir $discount% de descuento. '
        'Cada premio disponible se puede usar una sola vez.';
  }
  final action = switch (type) {
    'referrals' =>
      'invitar $remaining cliente${remaining == 1 ? '' : 's'} mas que completen una visita',
    'visits' => 'completar $remaining visita${remaining == 1 ? '' : 's'} mas',
    'spent' => 'acumular $remaining EUR mas en servicios',
    _ => 'sumar $remaining punto${remaining == 1 ? '' : 's'} mas',
  };
  return 'Para conseguir $name y recibir $discount% de descuento necesitas $action. '
      'Tu progreso actual es $current de $threshold.';
}

String _remainingRewardText(Map<String, dynamic> reward, int remaining) {
  final type = _text(reward['reward_type']);
  return switch (type) {
    'referrals' =>
      'Faltan $remaining cliente${remaining == 1 ? '' : 's'} invitado${remaining == 1 ? '' : 's'}.',
    'visits' => 'Faltan $remaining visita${remaining == 1 ? '' : 's'}.',
    'spent' => 'Faltan $remaining EUR acumulados.',
    _ => 'Faltan $remaining puntos.',
  };
}

IconData _rewardIcon(String? value) {
  return switch (value) {
    'groups' => Icons.groups_outlined,
    'star' => Icons.star_outline,
    'workspace_premium' => Icons.workspace_premium_outlined,
    _ => Icons.card_giftcard_outlined,
  };
}

Color? _parseRewardColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class _PortalClientAvatar extends StatelessWidget {
  const _PortalClientAvatar({
    required this.api,
    required this.avatarUrl,
    required this.name,
  });

  final AnnaApi api;
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AnnaColors.line),
      ),
      child: url == null
          ? Center(
              child: Text(
                _initials(name),
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : ApiCachedImage(
              api: api,
              url: url,
              fit: BoxFit.cover,
              width: 54,
              height: 54,
            ),
    );
  }
}

class _ClientBookingsCard extends StatelessWidget {
  const _ClientBookingsCard({required this.bookings});

  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    final upcoming = bookings.where(_isUpcomingBooking).toList();
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mis reservas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (bookings.isEmpty)
            Text('Todavia no tienes reservas.',
                style: TextStyle(color: AnnaColors.muted))
          else ...[
            if (upcoming.isNotEmpty) ...[
              Text('Proximas', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final booking in upcoming.take(3))
                _ClientBookingRow(booking: booking),
              const SizedBox(height: 12),
            ],
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final booking in bookings.take(8))
              _ClientBookingRow(booking: booking),
          ],
        ],
      ),
    );
  }
}

class _ClientBookingRow extends StatelessWidget {
  const _ClientBookingRow({required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        border: Border.all(color: AnnaColors.line),
        color: const Color(0x1CE8FFF1),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, color: AnnaColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(booking['service_name']) ?? 'Servicio',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_bookingDateText(booking)} · ${_text(booking['employee_name']) ?? 'Empleado'}',
                  style: TextStyle(color: AnnaColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          AnnaBadge(
              _text(booking['status_label']) ?? _text(booking['status']) ?? ''),
        ],
      ),
    );
  }
}

class _ClientPhotosCard extends StatelessWidget {
  const _ClientPhotosCard({required this.api, required this.photos});

  final AnnaApi api;
  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mis fotos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Text('Todavia no hay fotos guardadas.',
                style: TextStyle(color: AnnaColors.muted))
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final photo in photos.take(8))
                  InkWell(
                    onTap: () => AnnaPhotoViewer.showNetwork(
                      context,
                      title: _text(photo['photo_type_label']) ?? 'Foto',
                      url: photo['image_url'].toString(),
                      api: api,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AnnaRadii.md),
                      child: ApiCachedImage(
                        api: api,
                        url: photo['image_url'].toString(),
                        fit: BoxFit.cover,
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

class ClientBookingScreen extends StatefulWidget {
  const ClientBookingScreen({
    required this.api,
    required this.profile,
    required this.onCreated,
    super.key,
  });

  final AnnaApi api;
  final Map<String, dynamic> profile;
  final VoidCallback onCreated;

  @override
  State<ClientBookingScreen> createState() => _ClientBookingScreenState();
}

class _ClientBookingScreenState extends State<ClientBookingScreen> {
  final _notesController = TextEditingController();
  late Future<_ClientBookingRefs> _refs = _loadRefs();
  DateTime _date = DateTime.now();
  String? _serviceId;
  String? _employeeId;
  String? _zoneId;
  String? _rewardRuleId;
  String? _slotValue;
  Future<ApiDocument>? _slotsFuture;
  String? _slotsKey;
  Future<ApiCollection>? _rewardsFuture;
  Object? _rewardsClientId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<_ClientBookingRefs> _loadRefs() async {
    final results = await Future.wait([
      widget.api.services(),
      widget.api.employees(),
      widget.api.zones(),
    ]);
    return _ClientBookingRefs(
      services: results[0],
      employees: results[1],
      zones: results[2],
    );
  }

  void _resetSlots() {
    _slotValue = null;
    _slotsKey = null;
    _slotsFuture = null;
    _error = null;
  }

  void _syncSlots(_ClientBookingRefs refs) {
    if (_serviceId == null) {
      _slotsFuture = null;
      _slotsKey = null;
      return;
    }
    final service = refs.optionById(refs.serviceOptions, _serviceId);
    if (service == null) return;
    final key = [
      DateFormat('yyyy-MM-dd').format(_date),
      _serviceId,
    ].join('|');
    if (key == _slotsKey) return;
    _slotsKey = key;
    _slotsFuture = widget.api.availabilitySlots({
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'service': _serviceId!,
    });
  }

  void _syncRewards() {
    final clientId = widget.profile['client_id'];
    if (clientId == null) {
      _rewardsFuture = null;
      _rewardsClientId = null;
      return;
    }
    if (_rewardsClientId == clientId) return;
    _rewardsClientId = clientId;
    _rewardsFuture = widget.api.clientRewards(clientId);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _resetSlots();
    });
  }

  Future<void> _save(_ClientBookingRefs refs) async {
    final service = refs.optionById(refs.serviceOptions, _serviceId);
    if (service == null || _employeeId == null || _slotValue == null) {
      setState(() => _error = 'Selecciona servicio, empleado y horario.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await widget.api.createBooking({
        'service': int.tryParse(_serviceId!) ?? _serviceId,
        'employee': int.tryParse(_employeeId!) ?? _employeeId,
        if (_zoneId != null) 'zone': int.tryParse(_zoneId!) ?? _zoneId,
        'start_at': _formatApiDateTime(_slotValue!),
        'notes': _notesController.text.trim(),
        if (_rewardRuleId != null)
          'reward_rule': int.tryParse(_rewardRuleId!) ?? _rewardRuleId,
      });
      if (!mounted) return;
      final bookingId = response.data['id'];
      final checkoutUrl =
          response.data['prepayment_checkout_url']?.toString() ?? '';
      _notesController.clear();
      setState(() {
        _serviceId = null;
        _employeeId = null;
        _zoneId = null;
        _rewardRuleId = null;
        _rewardsClientId = null;
        _resetSlots();
      });
      widget.onCreated();
      await _showRequiredPrepayment(bookingId, checkoutUrl);
    } on AnnaApiException catch (error) {
      setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showRequiredPrepayment(Object? bookingId, String checkoutUrl) {
    var sending = false;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.lock_clock_outlined,
                size: 54, color: AnnaColors.warning),
            title: const Text(
              'La reserva todavía no está confirmada',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Para fijar la fecha y la hora debes realizar el prepago obligatorio. '
              'Si no pagas en 30 minutos, la reserva no se formalizará y otra persona podrá ocupar ese horario.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 1.45),
            ),
            actions: [
              FilledButton.icon(
                onPressed: checkoutUrl.isEmpty
                    ? null
                    : () async {
                        final opened = await launchUrl(
                          Uri.parse(checkoutUrl),
                          mode: LaunchMode.externalApplication,
                        );
                        if (opened && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                icon: const Icon(Icons.payment),
                label: const Text('Pagar ahora'),
              ),
              OutlinedButton.icon(
                onPressed: sending || bookingId == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(this.context);
                        setDialogState(() => sending = true);
                        try {
                          await widget.api
                              .updateBookingPrepayment(bookingId, true);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          messenger.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Enlace de pago enviado por WhatsApp.'),
                            ),
                          );
                        } on AnnaApiException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => sending = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(formatApiError(error))),
                          );
                        }
                      },
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_outlined),
                label: const Text('Recibir enlace por WhatsApp'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Reservar',
      child: FutureBuilder<_ClientBookingRefs>(
        future: _refs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error!,
              onRetry: () => setState(() => _refs = _loadRefs()),
            );
          }
          final refs = snapshot.data!;
          _syncSlots(refs);
          _syncRewards();
          final service = refs.optionById(refs.serviceOptions, _serviceId);
          return PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva reserva',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _ClientDropdown(
                  label: 'Servicio',
                  value: _serviceId,
                  options: refs.serviceOptions,
                  icon: Icons.spa_outlined,
                  onChanged: (value) => setState(() {
                    _serviceId = value;
                    final selected =
                        refs.optionById(refs.serviceOptions, value);
                    if (selected == null ||
                        !refs.employeeSupportsService(_employeeId, selected)) {
                      _employeeId = null;
                    }
                    _zoneId = null;
                    _resetSlots();
                  }),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(AnnaRadii.md),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(DateFormat('d MMM yyyy', 'es').format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                _ClientSlotDropdown(
                  future: _slotsFuture,
                  value: _slotValue,
                  enabled: service != null,
                  onChanged: (value) => setState(() {
                    _slotValue = value;
                    _employeeId = null;
                    _zoneId = null;
                  }),
                ),
                const SizedBox(height: 12),
                _ClientEmployeeAvailabilityDropdown(
                  future: _slotsFuture,
                  refs: refs,
                  slotValue: _slotValue,
                  employeeId: _employeeId,
                  onChanged: (selection) => setState(() {
                    _employeeId = selection.employeeId;
                    _zoneId = selection.zoneId;
                    if (selection.slotValue != null) {
                      _slotValue = selection.slotValue;
                    }
                  }),
                ),
                const SizedBox(height: 12),
                _ClientRewardSelector(
                  future: _rewardsFuture,
                  value: _rewardRuleId,
                  onChanged: (value) => setState(() => _rewardRuleId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Comentario',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AnnaErrorBanner(_error!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(refs),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Solicitar reserva'),
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

class _ClientDropdown extends StatelessWidget {
  const _ClientDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_ClientBookingOption> options;
  final IconData icon;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.any((option) => option.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      dropdownColor: AnnaColors.accentDeep,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ClientSlotDropdown extends StatelessWidget {
  const _ClientSlotDropdown({
    required this.future,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Future<ApiDocument>? future;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return InputDecorator(
        decoration: InputDecoration(
            labelText: 'Hora', prefixIcon: Icon(Icons.schedule)),
        child: Text('Selecciona servicio, empleado y zona',
            style: TextStyle(color: AnnaColors.muted)),
      );
    }
    final slotsFuture = future;
    if (slotsFuture == null) {
      return InputDecorator(
        decoration: InputDecoration(
            labelText: 'Hora', prefixIcon: Icon(Icons.schedule)),
        child: Text('Sin datos de disponibilidad',
            style: TextStyle(color: AnnaColors.muted)),
      );
    }
    return FutureBuilder<ApiDocument>(
      future: slotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return InputDecorator(
            decoration: InputDecoration(
                labelText: 'Hora', prefixIcon: Icon(Icons.schedule)),
            child: Text('Buscando horarios...'),
          );
        }
        if (snapshot.hasError) {
          return InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Hora', prefixIcon: Icon(Icons.schedule)),
            child: Text(formatApiError(snapshot.error!),
                style: TextStyle(color: AnnaColors.danger)),
          );
        }
        final slots = _slotOptions(snapshot.data?.data['slots']);
        final selected = slots.any((slot) => slot.id == value) ? value : null;
        if (slots.isEmpty) {
          return InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Hora', prefixIcon: Icon(Icons.schedule)),
            child: Text('No hay horarios disponibles',
                style: TextStyle(color: AnnaColors.muted)),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: AnnaColors.accentDeep,
          decoration: const InputDecoration(
              labelText: 'Hora disponible', prefixIcon: Icon(Icons.schedule)),
          items: [
            for (final slot in slots)
              DropdownMenuItem(
                value: slot.id,
                child: Text(slot.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _ClientEmployeeSelection {
  const _ClientEmployeeSelection({
    required this.employeeId,
    this.zoneId,
    this.slotValue,
  });

  final String employeeId;
  final String? zoneId;
  final String? slotValue;
}

class _ClientEmployeeAvailabilityDropdown extends StatelessWidget {
  const _ClientEmployeeAvailabilityDropdown({
    required this.future,
    required this.refs,
    required this.slotValue,
    required this.employeeId,
    required this.onChanged,
  });

  final Future<ApiDocument>? future;
  final _ClientBookingRefs refs;
  final String? slotValue;
  final String? employeeId;
  final ValueChanged<_ClientEmployeeSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final slotsFuture = future;
    if (slotsFuture == null) {
      return const _ClientHint(
          'Selecciona servicio y fecha para ver maestros.');
    }
    if (slotValue == null) {
      return const _ClientHint(
          'Selecciona un horario para ver maestros libres.');
    }
    return FutureBuilder<ApiDocument>(
      future: slotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ClientHint('Buscando maestros libres...');
        }
        if (snapshot.hasError) {
          return Text(
            formatApiError(snapshot.error!),
            style: TextStyle(color: AnnaColors.danger),
          );
        }
        final data = snapshot.data?.data ?? const <String, dynamic>{};
        final slots = _teamSlotItems(data['slots']);
        final selectedSlot = slots[slotValue];
        final slotEmployeeIds = selectedSlot?.employees.keys.toSet() ?? {};
        final employees = _teamEmployeeItems(data['employees'])
            .where((employee) =>
                slotEmployeeIds.contains(employee.id) ||
                employee.nextStartAt != null)
            .toList();
        if (employees.isEmpty) {
          return const _ClientHint(
              'No hay maestros disponibles para esta fecha.');
        }
        final selected = employees.any((employee) => employee.id == employeeId)
            ? employeeId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: AnnaColors.accentDeep,
          decoration: const InputDecoration(
            labelText: 'Maestro',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: [
            for (final employee in employees)
              DropdownMenuItem(
                value: employee.id,
                child: Text(
                  slotEmployeeIds.contains(employee.id)
                      ? employee.name
                      : employee.nextLabel == null
                          ? '${employee.name} (sin hueco)'
                          : '${employee.name} (prox. ${employee.nextLabel})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: (value) => value == null ? 'Selecciona maestro' : null,
          onChanged: (value) {
            if (value == null) return;
            final employee = employees.firstWhere((item) => item.id == value);
            final currentSlotEmployee = selectedSlot?.employees[value];
            if (currentSlotEmployee != null) {
              onChanged(
                _ClientEmployeeSelection(
                  employeeId: value,
                  zoneId: currentSlotEmployee.zoneId,
                ),
              );
              return;
            }
            final nextSlotValue = employee.nextStartAt == null
                ? null
                : _normalizeSlot(employee.nextStartAt!);
            final nextSlotEmployee = nextSlotValue == null
                ? null
                : slots[nextSlotValue]?.employees[value];
            onChanged(
              _ClientEmployeeSelection(
                employeeId: value,
                zoneId: nextSlotEmployee?.zoneId,
                slotValue: nextSlotValue,
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamSlotItem {
  const _TeamSlotItem({required this.employees});

  final Map<String, _TeamSlotEmployee> employees;
}

class _TeamSlotEmployee {
  const _TeamSlotEmployee({required this.zoneId});

  final String? zoneId;
}

class _TeamEmployeeItem {
  const _TeamEmployeeItem({
    required this.id,
    required this.name,
    required this.nextStartAt,
    required this.nextLabel,
  });

  final String id;
  final String name;
  final String? nextStartAt;
  final String? nextLabel;
}

Map<String, _TeamSlotItem> _teamSlotItems(Object? raw) {
  if (raw is! List) return const {};
  final result = <String, _TeamSlotItem>{};
  for (final item in raw.whereType<Map>()) {
    final start = _text(item['start_at']);
    if (start == null) continue;
    final employees = <String, _TeamSlotEmployee>{};
    final rawEmployees = item['employees'];
    if (rawEmployees is List) {
      for (final employee in rawEmployees.whereType<Map>()) {
        final id = _text(employee['id']);
        if (id == null) continue;
        employees[id] = _TeamSlotEmployee(zoneId: _text(employee['zone']));
      }
    }
    result[_normalizeSlot(start)] = _TeamSlotItem(employees: employees);
  }
  return result;
}

List<_TeamEmployeeItem> _teamEmployeeItems(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw.whereType<Map>())
      if (_text(item['id']) != null)
        _TeamEmployeeItem(
          id: _text(item['id'])!,
          name: _text(item['name']) ?? 'Maestro',
          nextStartAt: _text(item['next_start_at']),
          nextLabel: _text(item['next_label']),
        ),
  ];
}

class _ClientRewardSelector extends StatelessWidget {
  const _ClientRewardSelector({
    required this.future,
    required this.value,
    required this.onChanged,
  });

  final Future<ApiCollection>? future;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final rewardsFuture = future;
    if (rewardsFuture == null) {
      return const _ClientHint(
          'Entra con tu cuenta de cliente para usar premios.');
    }
    return FutureBuilder<ApiCollection>(
      future: rewardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ClientHint('Cargando premios...');
        }
        if (snapshot.hasError) {
          return Text(
            formatApiError(snapshot.error!),
            style: TextStyle(color: AnnaColors.danger),
          );
        }
        final rewards = (snapshot.data?.items ?? const <ApiRecord>[])
            .where((record) => _intFromRecord(record, 'available') > 0)
            .toList();
        if (rewards.isEmpty) {
          return const _ClientHint(
              'Todavia no tienes premios disponibles para esta reserva.');
        }
        final selected =
            rewards.any((reward) => reward.valueAsText('id') == value)
                ? value
                : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: AnnaColors.accentDeep,
          decoration: const InputDecoration(
            labelText: 'Activar premio',
            prefixIcon: Icon(Icons.card_giftcard_outlined),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('No activar premio'),
            ),
            for (final reward in rewards)
              DropdownMenuItem(
                value: reward.valueAsText('id'),
                child: Text(
                  '${reward.valueAsText('name') ?? 'Premio'} · ${reward.valueAsText('discount_percent') ?? '0'}%',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _ClientHint extends StatelessWidget {
  const _ClientHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: AnnaColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ClientBookingRefs {
  const _ClientBookingRefs({
    required this.services,
    required this.employees,
    required this.zones,
  });

  final ApiCollection services;
  final ApiCollection employees;
  final ApiCollection zones;

  List<_ClientBookingOption> get serviceOptions =>
      _options(services.items, _serviceLabel);
  List<_ClientBookingOption> get employeeOptions =>
      _options(employees.items, _employeeLabel);
  List<_ClientBookingOption> get zoneOptions =>
      _options(zones.items, _zoneLabel);

  _ClientBookingOption? optionById(
      List<_ClientBookingOption> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  List<_ClientBookingOption> employeesForService(_ClientBookingOption service) {
    return employeeOptions.where((employee) {
      if (employee.serviceIds.contains(service.id)) return true;
      if (service.employeeIds.contains(employee.id)) return true;
      return employee.serviceIds.isEmpty && service.employeeIds.isEmpty;
    }).toList();
  }

  bool employeeSupportsService(
      String? employeeId, _ClientBookingOption service) {
    return employeesForService(service)
        .any((employee) => employee.id == employeeId);
  }

  List<_ClientBookingOption> zonesForService(_ClientBookingOption service) {
    if (!service.requiresZone) return const [];
    return zoneOptions
        .where((zone) => service.allowedZoneIds.contains(zone.id))
        .toList();
  }

  static List<_ClientBookingOption> _options(
    List<ApiRecord> records,
    String Function(ApiRecord) labelBuilder,
  ) {
    final byId = <String, _ClientBookingOption>{};
    for (final record in records) {
      final id = record.valueAsText('id') ?? record.valueAsText('pk');
      if (id == null) continue;
      byId.putIfAbsent(
        id,
        () => _ClientBookingOption(
          id: id,
          label: labelBuilder(record),
          requiresZone: _bool(record.data['requires_zone']),
          allowedZoneIds: _ids(record.data['allowed_zone_ids']),
          serviceIds: _ids(record.data['service_ids']),
          employeeIds: _ids(record.data['employee_ids']),
        ),
      );
    }
    return byId.values.toList();
  }
}

class _ClientBookingOption {
  const _ClientBookingOption({
    required this.id,
    required this.label,
    required this.requiresZone,
    required this.allowedZoneIds,
    required this.serviceIds,
    required this.employeeIds,
  });

  final String id;
  final String label;
  final bool requiresZone;
  final Set<String> allowedZoneIds;
  final Set<String> serviceIds;
  final Set<String> employeeIds;
}

List<_ClientBookingOption> _slotOptions(dynamic raw) {
  if (raw is! List) return const [];
  final byId = <String, _ClientBookingOption>{};
  for (final item in raw.whereType<Map>()) {
    final start = _text(item['start_at']);
    if (start == null) continue;
    final id = _normalizeSlot(start);
    byId.putIfAbsent(
      id,
      () => _ClientBookingOption(
        id: id,
        label: _text(item['label']) ?? id.substring(11, 16),
        requiresZone: false,
        allowedZoneIds: const {},
        serviceIds: const {},
        employeeIds: const {},
      ),
    );
  }
  return byId.values.toList();
}

String _serviceLabel(ApiRecord record) =>
    record.valueAsText('name') ?? 'Servicio';

String _employeeLabel(ApiRecord record) {
  return record.valueAsText('full_name') ??
      '${record.valueAsText('first_name') ?? ''} ${record.valueAsText('last_name') ?? ''}'
          .trim();
}

String _zoneLabel(ApiRecord record) => record.valueAsText('name') ?? 'Zona';

Set<String> _ids(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
  return const {};
}

bool _bool(dynamic value) =>
    value == true || value == 'true' || value == 1 || value == '1';

int _intFromRecord(ApiRecord record, String key) {
  final value = record.data[key];
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '#';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  return number == null ? '0.00' : number.toStringAsFixed(2);
}

bool _isUpcomingBooking(Map<String, dynamic> booking) {
  final parsed = DateTime.tryParse(
      (_text(booking['start_at']) ?? '').replaceFirst(' ', 'T'));
  if (parsed == null) return false;
  final status = _text(booking['status']);
  return parsed.isAfter(DateTime.now()) && status != 'cancelled';
}

String _bookingDateText(Map<String, dynamic> booking) {
  final raw = _text(booking['start_at']);
  if (raw == null) return '';
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw;
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
}

String _normalizeSlot(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  if (normalized.length >= 16 && normalized[10] == 'T') {
    return normalized.substring(0, 16);
  }
  return normalized;
}

String _formatApiDateTime(String slotValue) {
  final parsed = DateTime.parse(slotValue);
  final offset = parsed.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(parsed)}$sign$hours:$minutes';
}
