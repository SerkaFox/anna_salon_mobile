import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _createEntry() async {
    final created = await _WaitlistCreateSheet.show(context, api: widget.api);
    if (created == true && mounted) _reload();
  }

  Future<void> _setStatus(ApiRecord entry, String status) async {
    await widget.api.updateWaitlistStatus(entry.data['id']!, status);
    if (mounted) _reload();
  }

  Future<void> _offerViaWhatsApp(
    ApiRecord entry, {
    bool chooseAnotherDate = false,
  }) async {
    final rawPhone = entry.data['phone']?.toString() ?? '';
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9) digits = '34$digits';
    if (digits.isEmpty) return;
    var date = DateTime.tryParse(
      entry.data['desired_date']?.toString() ?? '',
    );
    if (chooseAnotherDate) {
      date = await showDatePicker(
        context: context,
        initialDate: date ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 120)),
      );
      if (date == null) return;
    }
    final dateText = DateFormat('dd/MM/yyyy').format(date ?? DateTime.now());
    final name = entry.data['name']?.toString() ?? '';
    final service = entry.data['service_name']?.toString() ?? '';
    final employee = entry.data['employee_name']?.toString() ?? '';
    final message = chooseAnotherDate
        ? 'Hola $name. Tenemos una posible alternativa para $service con '
            '$employee el $dateText. Te viene bien?'
        : 'Hola $name. Contactamos por tu solicitud en la lista de espera '
            'para $service con $employee el $dateText. '
            'Quieres que revisemos un hueco disponible?';
    final opened = await launchUrl(
      Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
    if (opened) await _setStatus(entry, 'notified');
  }

  String _tr(AppLocalizations t, String es, String ru) => t.isRussian ? ru : es;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: ScreenScaffold(
        title: _tr(t, 'Lista de espera', 'Очередь ожидания'),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _tr(t, 'Anadir persona', 'Добавить человека'),
              onPressed: _createEntry,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
            IconButton(
              tooltip: t.refresh,
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
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
                        onOffer: (anotherDate) => _offerViaWhatsApp(
                          entry,
                          chooseAnotherDate: anotherDate,
                        ),
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
      ),
    );
  }
}

class _WaitlistCreateSheet extends StatefulWidget {
  const _WaitlistCreateSheet({required this.api});

  final AnnaApi api;

  static Future<bool?> show(BuildContext context, {required AnnaApi api}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (_) => _WaitlistCreateSheet(api: api),
    );
  }

  @override
  State<_WaitlistCreateSheet> createState() => _WaitlistCreateSheetState();
}

class _WaitlistCreateSheetState extends State<_WaitlistCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  late final Future<List<ApiCollection>> _references = Future.wait([
    widget.api.clients(),
    widget.api.services(),
    widget.api.employees(),
  ]);
  String? _clientId;
  String? _serviceId;
  String? _employeeId;
  DateTime _dateFrom = DateTime.now();
  DateTime? _dateTo;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _id(ApiRecord item) => item.data['id'].toString();

  String _label(ApiRecord item) {
    final data = item.data;
    final full = data['full_name']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;
    final name = [data['first_name'], data['last_name']]
        .where((value) => value?.toString().trim().isNotEmpty == true)
        .join(' ');
    return name.isNotEmpty
        ? name
        : (data['name']?.toString() ?? '#${_id(item)}');
  }

  bool _employeeSupports(ApiRecord employee, String serviceId) {
    final raw = employee.data['service_ids'] ?? employee.data['services'];
    return raw is List &&
        raw.map((value) => value.toString()).contains(serviceId);
  }

  Future<void> _pickDate({required bool end}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_dateTo ?? _dateFrom) : _dateFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _dateTo = picked.isBefore(_dateFrom) ? _dateFrom : picked;
      } else {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'client': _clientId == null ? null : int.tryParse(_clientId!),
        'service': int.tryParse(_serviceId!),
        'employee': int.tryParse(_employeeId!),
        'desired_date': DateFormat('yyyy-MM-dd').format(_dateFrom),
        'desired_date_to':
            _dateTo == null ? null : DateFormat('yyyy-MM-dd').format(_dateTo!),
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'time_range': _timeController.text.trim(),
        'notes': _notesController.text.trim(),
      };
      payload.removeWhere((_, value) => value == null);
      await widget.api.createWaitlistEntry(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ru = t.isRussian;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FutureBuilder<List<ApiCollection>>(
          future: _references,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                error: snapshot.error!,
                onRetry: () => Navigator.pop(context),
              );
            }
            final clients = snapshot.data![0].items;
            final services = snapshot.data![1].items;
            final employees = snapshot.data![2].items.where((employee) {
              return _serviceId == null ||
                  _employeeSupports(employee, _serviceId!);
            }).toList();
            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ru
                                ? 'Добавить в лист ожидания'
                                : 'Anadir a la lista de espera',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _WaitlistSearchField(
                      label: ru
                          ? 'Клиент из базы (необязательно)'
                          : 'Cliente existente (opcional)',
                      searchHint: ru
                          ? 'Введите имя или телефон'
                          : 'Escribe nombre o telefono',
                      value: _clientId,
                      options: clients,
                      idOf: _id,
                      labelOf: _label,
                      icon: Icons.person_search_outlined,
                      allowClear: true,
                      onChanged: (value) => setState(() {
                        _clientId = value;
                        for (final client in clients) {
                          if (_id(client) != value) continue;
                          _nameController.text = _label(client);
                          final phone = client.data['phone']?.toString() ?? '';
                          if (phone.isNotEmpty) _phoneController.text = phone;
                          break;
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                          labelText: ru ? 'Имя звонившего' : 'Nombre'),
                      validator: (value) =>
                          _clientId == null && (value ?? '').trim().isEmpty
                              ? (ru
                                  ? 'Укажите имя или выберите клиента'
                                  : 'Indica nombre o cliente')
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                          labelText: ru ? 'Телефон' : 'Telefono'),
                      validator: (value) =>
                          _clientId == null && (value ?? '').trim().isEmpty
                              ? (ru ? 'Укажите телефон' : 'Indica telefono')
                              : null,
                    ),
                    const SizedBox(height: 10),
                    _WaitlistSearchField(
                      label: ru ? 'Услуга' : 'Servicio',
                      searchHint: ru
                          ? 'Введите название услуги'
                          : 'Escribe el nombre del servicio',
                      value: _serviceId,
                      options: services,
                      idOf: _id,
                      labelOf: _label,
                      icon: Icons.search,
                      requiredMessage:
                          ru ? 'Выберите услугу' : 'Selecciona servicio',
                      onChanged: (value) => setState(() {
                        _serviceId = value;
                        _employeeId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _WaitlistSearchField(
                      label: ru ? 'Сотрудник' : 'Empleado',
                      searchHint: ru
                          ? 'Введите имя сотрудника'
                          : 'Escribe el nombre del empleado',
                      value: _employeeId,
                      options: employees,
                      idOf: _id,
                      labelOf: _label,
                      icon: Icons.badge_outlined,
                      requiredMessage:
                          ru ? 'Выберите сотрудника' : 'Selecciona empleado',
                      onChanged: (value) => setState(() => _employeeId = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WaitlistDateButton(
                            label: ru ? 'С даты' : 'Desde',
                            date: _dateFrom,
                            onTap: () => _pickDate(end: false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WaitlistDateButton(
                            label: ru ? 'До даты' : 'Hasta',
                            date: _dateTo,
                            onTap: () => _pickDate(end: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _timeController,
                      decoration: InputDecoration(
                        labelText: ru ? 'Желаемое время' : 'Horario deseado',
                        hintText: ru
                            ? 'Например, 10:00–15:00 или любое'
                            : 'Ej. 10:00–15:00 o cualquiera',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: ru ? 'Комментарий' : 'Comentario',
                        hintText: ru
                            ? 'Позвонить, если кто-то отменит запись'
                            : 'Llamar si alguien cancela',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.playlist_add),
                        label: Text(ru ? 'Добавить' : 'Anadir'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaitlistSearchField extends StatelessWidget {
  const _WaitlistSearchField({
    required this.label,
    required this.searchHint,
    required this.value,
    required this.options,
    required this.idOf,
    required this.labelOf,
    required this.icon,
    required this.onChanged,
    this.requiredMessage,
    this.allowClear = false,
  });

  final String label;
  final String searchHint;
  final String? value;
  final List<ApiRecord> options;
  final String Function(ApiRecord) idOf;
  final String Function(ApiRecord) labelOf;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? requiredMessage;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final option in options) {
      if (idOf(option) == value) {
        selectedLabel = labelOf(option);
        break;
      }
    }
    return FormField<String>(
      key: ValueKey('$label|$value|${options.length}'),
      initialValue: value,
      validator: (current) => current == null ? requiredMessage : null,
      builder: (field) => InkWell(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        onTap: () async {
          final selected = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AnnaColors.bgSoft,
            builder: (_) => _WaitlistSearchSheet(
              title: label,
              searchHint: searchHint,
              options: options,
              idOf: idOf,
              labelOf: labelOf,
            ),
          );
          if (selected == null) return;
          field.didChange(selected);
          onChanged(selected);
        },
        child: InputDecorator(
          isEmpty: selectedLabel == null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            errorText: field.errorText,
            suffixIcon: value != null && allowClear
                ? IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: () {
                      field.didChange(null);
                      onChanged(null);
                    },
                    icon: const Icon(Icons.close),
                  )
                : const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            selectedLabel ?? searchHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectedLabel == null ? AnnaColors.muted : AnnaColors.text,
              fontWeight:
                  selectedLabel == null ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitlistSearchSheet extends StatefulWidget {
  const _WaitlistSearchSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.idOf,
    required this.labelOf,
  });

  final String title;
  final String searchHint;
  final List<ApiRecord> options;
  final String Function(ApiRecord) idOf;
  final String Function(ApiRecord) labelOf;

  @override
  State<_WaitlistSearchSheet> createState() => _WaitlistSearchSheetState();
}

class _WaitlistSearchSheetState extends State<_WaitlistSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _searchableText(ApiRecord option) {
    final data = option.data;
    return [
      widget.labelOf(option),
      data['phone'],
      data['email'],
      data['description'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((option) {
      return _query.isEmpty || _searchableText(option).contains(_query);
    }).toList();
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Нет результатов'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AnnaColors.line),
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            leading: const Icon(Icons.search_outlined),
                            title: Text(widget.labelOf(option)),
                            onTap: () =>
                                Navigator.pop(context, widget.idOf(option)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitlistDateButton extends StatelessWidget {
  const _WaitlistDateButton(
      {required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined),
      label: Text(
          '$label\n${date == null ? '—' : DateFormat('dd/MM/yyyy').format(date!)}'),
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard(
      {required this.entry,
      required this.t,
      required this.onStatus,
      required this.onOffer});

  final ApiRecord entry;
  final AppLocalizations t;
  final ValueChanged<String> onStatus;
  final ValueChanged<bool> onOffer;

  @override
  Widget build(BuildContext context) {
    final data = entry.data;
    final contact = [data['phone'], data['email']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · ');
    final notified = data['status'] == 'notified';
    final dateFrom = DateTime.tryParse(data['desired_date']?.toString() ?? '');
    final dateTo = DateTime.tryParse(data['desired_date_to']?.toString() ?? '');
    final dateText = dateFrom == null
        ? ''
        : dateTo == null || dateTo == dateFrom
            ? DateFormat('dd/MM/yyyy').format(dateFrom)
            : '${DateFormat('dd/MM/yyyy').format(dateFrom)}–${DateFormat('dd/MM/yyyy').format(dateTo)}';
    final notes = data['notes']?.toString().trim() ?? '';
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
            '$dateText · ${data['time_range']?.toString().isNotEmpty == true ? data['time_range'] : (t.isRussian ? 'Любое время' : 'Cualquier hora')}\n'
            '$contact${notes.isEmpty ? '' : '\n$notes'}',
            style: TextStyle(color: AnnaColors.muted),
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: t.isRussian ? 'Изменить статус' : 'Cambiar estado',
          onSelected: (value) {
            if (value == 'whatsapp') {
              onOffer(false);
            } else if (value == 'other_date') {
              onOffer(true);
            } else {
              onStatus(value);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'whatsapp',
              child: Text(
                t.isRussian ? 'Написать в WhatsApp' : 'Escribir por WhatsApp',
              ),
            ),
            PopupMenuItem(
              value: 'other_date',
              child: Text(
                t.isRussian ? 'Предложить другой день' : 'Proponer otro dia',
              ),
            ),
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
              child: Text(time, style: TextStyle(fontWeight: FontWeight.w800))),
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
