import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../push_notifications.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({required this.api, super.key});

  final AnnaApi api;

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  late Future<Map<String, bool>> _future =
      PushNotifications.preferences(widget.api);
  Map<String, bool> _preferences = const {};
  final Set<String> _saving = {};

  void _reload() {
    setState(() {
      _preferences = const {};
      _future = PushNotifications.preferences(widget.api);
    });
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _preferences[key] ?? true;
    setState(() {
      _preferences = {..._preferences, key: value};
      _saving.add(key);
    });
    try {
      final updated = await PushNotifications.updatePreferences(
        widget.api,
        {key: value},
      );
      if (!mounted) return;
      setState(() => _preferences = updated);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _preferences = {..._preferences, key: previous});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final russian = t.isRussian;
    return Scaffold(
      body: DecoratedBox(
        decoration: annaBackgroundDecoration(context),
        child: SafeArea(
          child: ScreenScaffold(
            title: russian ? 'Пуш-уведомления' : 'Notificaciones push',
            action: IconButton(
              tooltip: russian ? 'Обновить' : 'Actualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            child: FutureBuilder<Map<String, bool>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    _preferences.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError && _preferences.isEmpty) {
                  return ErrorState(error: snapshot.error!, onRetry: _reload);
                }
                final preferences = _preferences.isEmpty
                    ? (snapshot.data ?? const <String, bool>{})
                    : _preferences;
                return Column(
                  children: [
                    PanelCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tune),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              russian
                                  ? 'Выберите, какие события должны появляться на этом телефоне. Настройки других устройств не изменятся.'
                                  : 'Elige qué eventos deben aparecer en este teléfono. Los ajustes de otros dispositivos no cambiarán.',
                              style: TextStyle(
                                color: AnnaColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final item in _items(russian)) ...[
                      PanelCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(item.icon),
                          title: Text(item.title),
                          subtitle: Text(item.description),
                          value: preferences[item.key] ?? true,
                          onChanged: _saving.contains(item.key)
                              ? null
                              : (value) => _toggle(item.key, value),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

List<_PushPreferenceItem> _items(bool russian) => [
      _PushPreferenceItem(
        key: 'new_booking',
        icon: Icons.add_task,
        title: russian ? 'Новая запись' : 'Nueva reserva',
        description: russian
            ? 'Клиент, дата, время и выбранные услуги.'
            : 'Cliente, fecha, hora y servicios elegidos.',
      ),
      _PushPreferenceItem(
        key: 'booking_cancelled',
        icon: Icons.event_busy_outlined,
        title: russian ? 'Отмена записи' : 'Cancelación de reserva',
        description: russian
            ? 'Сообщает, какое время освободилось.'
            : 'Avisa de qué horario ha quedado libre.',
      ),
      _PushPreferenceItem(
        key: 'booking_rescheduled',
        icon: Icons.event_repeat_outlined,
        title: russian ? 'Перенос записи' : 'Cambio de fecha u hora',
        description: russian
            ? 'Показывает прежнее и новое время.'
            : 'Muestra el horario anterior y el nuevo.',
      ),
      _PushPreferenceItem(
        key: 'employee_changed',
        icon: Icons.swap_horiz,
        title: russian ? 'Смена мастера' : 'Cambio de especialista',
        description: russian
            ? 'Уведомляет прежнего и нового сотрудника.'
            : 'Avisa al empleado anterior y al nuevo.',
      ),
      _PushPreferenceItem(
        key: 'prepayment_received',
        icon: Icons.payments_outlined,
        title: russian ? 'Предоплата получена' : 'Prepago recibido',
        description: russian
            ? 'Показывает клиента, запись и оплаченную сумму.'
            : 'Muestra cliente, reserva e importe pagado.',
      ),
      _PushPreferenceItem(
        key: 'reminder_24h',
        icon: Icons.today_outlined,
        title: russian ? 'Напоминание за 24 часа' : 'Recordatorio 24 horas',
        description: russian
            ? 'Напоминает о клиенте на следующий день.'
            : 'Recuerda la cita del día siguiente.',
      ),
      _PushPreferenceItem(
        key: 'reminder_2h',
        icon: Icons.schedule,
        title: russian ? 'Напоминание за 2 часа' : 'Recordatorio 2 horas',
        description: russian
            ? 'Предупреждает о ближайшем клиенте.'
            : 'Avisa del próximo cliente.',
      ),
    ];

class _PushPreferenceItem {
  const _PushPreferenceItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String key;
  final IconData icon;
  final String title;
  final String description;
}
