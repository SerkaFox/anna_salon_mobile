import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({required this.api, super.key});

  final AnnaApi api;

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  late Future<_WaitlistData> _future = _load();

  Future<_WaitlistData> _load() async {
    final entries = (await widget.api.waitlist()).items;
    final dates = entries
        .map((item) =>
            DateTime.tryParse(item.data['desired_date']?.toString() ?? ''))
        .whereType<DateTime>()
        .toSet()
        .toList()
      ..sort();
    final selectedDate = dates.isEmpty ? null : dates.first;
    final bookings = selectedDate == null
        ? <ApiRecord>[]
        : (await widget.api.bookings(date: selectedDate)).items;
    return _WaitlistData(entries, dates, selectedDate, bookings);
  }

  Future<_WaitlistData> _withDate(_WaitlistData data, DateTime date) async {
    final bookings = (await widget.api.bookings(date: date)).items;
    return _WaitlistData(data.entries, data.dates, date, bookings);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setStatus(ApiRecord entry, String status) async {
    await widget.api.updateWaitlistStatus(entry.data['id']!, status);
    if (mounted) _reload();
  }

  String _tr(AppLocalizations t, String es, String ru) => t.isRussian ? ru : es;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: _tr(t, 'Lista de espera', 'Очередь ожидания'),
      action: IconButton(
        tooltip: t.refresh,
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
      ),
      child: FutureBuilder<_WaitlistData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final data = snapshot.data!;
          if (data.entries.isEmpty) {
            return EmptyState(_tr(
              t,
              'No hay clientes esperando.',
              'Сейчас в очереди никто не ожидает.',
            ));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.dates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final date = data.dates[index];
                    final count = data.entries
                        .where((entry) =>
                            entry.data['desired_date'] ==
                            DateFormat('yyyy-MM-dd').format(date))
                        .length;
                    return ChoiceChip(
                      selected: date == data.selectedDate,
                      label: Text(
                          '${DateFormat('EEE d MMM', t.locale.languageCode).format(date)} · $count'),
                      onSelected: (_) =>
                          setState(() => _future = _withDate(data, date)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _tr(t, 'Personas esperando', 'Кто ожидает'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ...data.entriesForSelected.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WaitlistCard(
                      entry: entry,
                      t: t,
                      onStatus: (status) => _setStatus(entry, status),
                    ),
                  )),
              const SizedBox(height: 14),
              Text(
                _tr(t, 'Agenda del dia', 'Расписание на день'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (data.visibleBookings.isEmpty)
                EmptyState(_tr(t, 'No hay reservas este dia.',
                    'На этот день записей нет.'))
              else
                ...data.visibleBookings.map((booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BookingRow(booking: booking),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard(
      {required this.entry, required this.t, required this.onStatus});

  final ApiRecord entry;
  final AppLocalizations t;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final data = entry.data;
    final contact = [data['phone'], data['email']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · ');
    final notified = data['status'] == 'notified';
    return PanelCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: CircleAvatar(
          child: Text(
              (data['name']?.toString() ?? '?').characters.first.toUpperCase()),
        ),
        title: Text(data['name']?.toString() ?? ''),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${data['service_name']} · ${data['employee_name']}\n'
            '${data['time_range']?.toString().isNotEmpty == true ? data['time_range'] : (t.isRussian ? 'Любое время' : 'Cualquier hora')}\n$contact',
            style: const TextStyle(color: AnnaColors.muted),
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: t.isRussian ? 'Изменить статус' : 'Cambiar estado',
          onSelected: onStatus,
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'booked',
                child: Text(t.isRussian ? 'Записан' : 'Reserva creada')),
            PopupMenuItem(
                value: 'cancelled',
                child: Text(
                    t.isRussian ? 'Убрать из очереди' : 'Quitar de la lista')),
          ],
          icon: Icon(
              notified ? Icons.notifications_active_outlined : Icons.more_vert),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});
  final ApiRecord booking;

  @override
  Widget build(BuildContext context) {
    final data = booking.data;
    final start = DateTime.tryParse(data['start_at']?.toString() ?? '');
    final end = DateTime.tryParse(data['end_at']?.toString() ?? '');
    final time = start == null
        ? ''
        : '${DateFormat('HH:mm').format(start)}–${end == null ? '' : DateFormat('HH:mm').format(end)}';
    return PanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 92,
              child: Text(time,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(
            child: Text(
                '${data['client_name']}\n${data['service_name']} · ${data['employee_name']}'),
          ),
        ],
      ),
    );
  }
}

class _WaitlistData {
  const _WaitlistData(
      this.entries, this.dates, this.selectedDate, this.bookings);
  final List<ApiRecord> entries;
  final List<DateTime> dates;
  final DateTime? selectedDate;
  final List<ApiRecord> bookings;

  List<ApiRecord> get entriesForSelected {
    final key = selectedDate == null
        ? ''
        : DateFormat('yyyy-MM-dd').format(selectedDate!);
    return entries.where((entry) => entry.data['desired_date'] == key).toList();
  }

  List<ApiRecord> get visibleBookings => bookings.where((booking) {
        return !const ['cancelled', 'no_show'].contains(booking.data['status']);
      }).toList()
        ..sort((a, b) => (a.data['start_at'] ?? '')
            .toString()
            .compareTo((b.data['start_at'] ?? '').toString()));
}
