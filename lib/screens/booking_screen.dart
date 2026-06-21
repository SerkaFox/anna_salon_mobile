import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'client_form_sheet.dart';
import 'photo_viewer.dart';
import 'shared.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    required this.api,
    this.onBookingCreated,
    this.draft,
    this.draftToken = 0,
    super.key,
  });

  final AnnaApi api;
  final ValueChanged<CreatedBooking>? onBookingCreated;
  final BookingDraft? draft;
  final int draftToken;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class CreatedBooking {
  const CreatedBooking({
    required this.id,
    required this.startAt,
  });

  final String? id;
  final DateTime? startAt;

  DateTime? get date {
    final value = startAt;
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  factory CreatedBooking.fromResponse(Map<String, dynamic> response) {
    final data = _bookingResponseMap(response);
    return CreatedBooking(
      id: _textValueFromMap(data, const ['id', 'pk']),
      startAt: _parseApiWallDateTime(
        _textValueFromMap(data, const ['start_at', 'start']),
      ),
    );
  }
}

class BookingDraft {
  const BookingDraft({
    required this.startAt,
    this.employeeId,
  });

  final DateTime startAt;
  final String? employeeId;
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  late Future<_BookingReferences> _references = _loadReferences();
  final List<ApiRecord> _createdClientRecords = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Future<_AvailabilitySlotsData>? _slotsFuture;
  String? _slotsSignature;
  String? _selectedSlotValue;
  String? _clientId;
  String? _serviceId;
  String? _employeeId;
  String? _zoneId;
  String? _rewardRuleId;
  Future<ApiCollection>? _clientRewardsFuture;
  String? _clientRewardsClientId;
  String _source = 'manual';
  String? _error;
  bool _creating = false;
  XFile? _beforePhoto;
  XFile? _afterPhoto;

  @override
  void initState() {
    super.initState();
    _applyDraft(widget.draft);
  }

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draftToken != oldWidget.draftToken) {
      setState(() => _applyDraft(widget.draft));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _applyDraft(BookingDraft? draft) {
    if (draft == null) return;
    _selectedDate = DateTime(
      draft.startAt.year,
      draft.startAt.month,
      draft.startAt.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(draft.startAt);
    _employeeId = draft.employeeId;
    _selectedSlotValue = _startAtSlotValue();
    _resetSlots(keepSelectedSlot: true);
  }

  Future<_BookingReferences> _loadReferences() async {
    final results = await Future.wait([
      widget.api.clients(),
      widget.api.services(),
      widget.api.employees(),
      widget.api.zones(),
    ]);
    final clientItemsById = <String, ApiRecord>{};
    for (final record in [
      ..._createdClientRecords,
      ...results[0].items,
    ]) {
      final id = _textValueFromMap(record.data, const ['id', 'pk']);
      if (id == null) continue;
      clientItemsById.putIfAbsent(id, () => record);
    }
    return _BookingReferences(
      clients:
          ApiCollection(clientItemsById.values.toList(), raw: results[0].raw),
      services: results[1],
      employees: results[2],
      zones: results[3],
    );
  }

  void _reloadReferences() {
    setState(() => _references = _loadReferences());
  }

  Future<void> _createClientFromForm() async {
    final created = await ClientFormSheet.show(context, api: widget.api);
    if (created == null || !mounted) return;
    final id = _textValueFromMap(created.data, const ['id', 'pk']);
    setState(() {
      _createdClientRecords.removeWhere((record) {
        final recordId = _textValueFromMap(record.data, const ['id', 'pk']);
        return recordId != null && recordId == id;
      });
      _createdClientRecords.insert(0, created);
      _clientId = id;
      _references = _loadReferences();
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _resetSlots(keepSelectedSlot: _selectedSlotValue != null);
    });
  }

  Future<void> _createBooking(_BookingReferences refs) async {
    if (!_validate(refs)) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final response = await widget.api.createBooking(_createPayload(refs));
      final created = CreatedBooking.fromResponse(response.data);
      if (created.id != null) {
        if (_beforePhoto != null) {
          await widget.api.uploadBookingPhoto(
            bookingId: created.id!,
            imagePath: _beforePhoto!.path,
            photoType: 'before',
          );
        }
        if (_afterPhoto != null) {
          await widget.api.uploadBookingPhoto(
            bookingId: created.id!,
            imagePath: _afterPhoto!.path,
            photoType: 'after',
          );
        }
      }
      if (!mounted) return;
      widget.onBookingCreated?.call(created);
    } on AnnaApiException catch (error) {
      setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _resetSlots({bool keepSelectedSlot = false}) {
    final selectedSlotValue = keepSelectedSlot && _selectedSlotValue != null
        ? _startAtSlotValue()
        : null;
    _slotsSignature = null;
    _slotsFuture = null;
    _selectedSlotValue = selectedSlotValue;
    _error = null;
  }

  bool _validate(_BookingReferences refs, {bool includeClient = true}) {
    final t = AppLocalizations.of(context);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;
    final service = _selectedService(refs);
    final needsZone = service?.requiresZone ?? false;
    if (service == null) {
      setState(() => _error = t.tr('Selecciona primero un servicio.'));
      return false;
    }
    if (_employeeId == null) {
      setState(() => _error = t.tr('Selecciona un empleado.'));
      return false;
    }
    if (!refs.employeeSupportsService(_employeeId, service)) {
      setState(() =>
          _error = t.tr('Este empleado no realiza el servicio seleccionado.'));
      return false;
    }
    if (needsZone && _zoneId == null) {
      setState(() => _error = t.tr('Selecciona una zona para este servicio.'));
      return false;
    }
    if (needsZone && !refs.zoneAllowedForService(_zoneId, service)) {
      setState(() => _error =
          t.tr('La zona seleccionada no esta permitida para este servicio.'));
      return false;
    }
    if (_selectedSlotValue == null) {
      setState(() => _error = t.tr('Selecciona un horario disponible.'));
      return false;
    }
    if (includeClient && _clientId == null) {
      setState(() => _error = t.tr('Selecciona un cliente.'));
      return false;
    }
    return true;
  }

  Map<String, dynamic> _createPayload(_BookingReferences refs) {
    final payload = <String, dynamic>{
      'client': _coerceId(_clientId),
      'service': _coerceId(_serviceId),
      'employee': _coerceId(_employeeId),
      'start_at': _startAtText(),
      'zone': _coerceId(_zoneId),
      'source': _source,
    };
    if (_rewardRuleId != null) {
      payload['reward_rule'] = _coerceId(_rewardRuleId);
    }
    final endAt = _endAtText(refs);
    if (endAt != null) payload['end_at'] = endAt;
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) payload['notes'] = notes;
    return payload;
  }

  Object? _coerceId(String? value) {
    if (value == null) return null;
    return int.tryParse(value) ?? value;
  }

  String _startAtText() {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return _formatApiDateTime(start);
  }

  String _startAtSlotValue() {
    return _normalizeSlotValue(_startAtText());
  }

  String? _endAtText(_BookingReferences refs) {
    final duration = _selectedService(refs)?.durationMinutes;
    if (duration == null) return null;
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return _formatApiDateTime(start.add(Duration(minutes: duration)));
  }

  _BookingOption? _selectedService(_BookingReferences refs) {
    for (final option in refs.serviceOptions) {
      if (option.id == _serviceId) return option;
    }
    return null;
  }

  String? _slotsStateKey(_BookingReferences refs) {
    final service = _selectedService(refs);
    if (service == null || _employeeId == null) return null;
    if (!refs.employeeSupportsService(_employeeId, service)) return null;
    if (service.requiresZone && _zoneId == null) return null;
    if (service.requiresZone && !refs.zoneAllowedForService(_zoneId, service)) {
      return null;
    }
    return [
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      _employeeId,
      _serviceId,
      _zoneId ?? '',
    ].join('|');
  }

  Future<_AvailabilitySlotsData> _loadAvailableSlots(
    _BookingReferences refs,
  ) async {
    final query = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'employee': _employeeId!,
      'service': _serviceId!,
    };
    if (_zoneId != null) query['zone'] = _zoneId!;
    final response = await widget.api.availabilitySlots(query);
    return _AvailabilitySlotsData.fromResponse(response.data);
  }

  void _syncSlotsFuture(_BookingReferences refs) {
    final signature = _slotsStateKey(refs);
    if (signature == _slotsSignature) return;
    _slotsSignature = signature;
    _slotsFuture = signature == null ? null : _loadAvailableSlots(refs);
  }

  void _syncClientRewardsFuture() {
    if (_clientId == null) {
      _clientRewardsFuture = null;
      _clientRewardsClientId = null;
      return;
    }
    if (_clientRewardsClientId == _clientId) return;
    _clientRewardsClientId = _clientId;
    _clientRewardsFuture = widget.api.clientRewards(_clientId!);
  }

  void _selectSlot(String? value) {
    if (value == null) return;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return;
    setState(() {
      _selectedSlotValue = value;
      _selectedDate = DateTime(parsed.year, parsed.month, parsed.day);
      _selectedTime = TimeOfDay.fromDateTime(parsed);
      _error = null;
    });
  }

  Future<void> _pickBookingPhoto(String type) async {
    final t = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.tr('Camara')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.tr('Galeria')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (type == 'before') {
        _beforePhoto = picked;
      } else {
        _afterPhoto = picked;
      }
    });
  }

  void _openBookingPhoto(String type) {
    final photo = type == 'before' ? _beforePhoto : _afterPhoto;
    if (photo == null) return;
    AnnaPhotoViewer.showLocal(
      context,
      title: type == 'before' ? 'Foto antes' : 'Foto despues',
      path: photo.path,
      onDelete: () {
        if (!mounted) return;
        setState(() {
          if (type == 'before') {
            _beforePhoto = null;
          } else {
            _afterPhoto = null;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: AppLocalizations.of(context).tr('Nueva reserva'),
      action: IconButton(
          onPressed: _reloadReferences, icon: const Icon(Icons.refresh)),
      child: FutureBuilder<_BookingReferences>(
        future: _references,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(
                error: snapshot.error!, onRetry: _reloadReferences);
          }
          final refs = snapshot.data!;
          _syncSlotsFuture(refs);
          _syncClientRewardsFuture();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookingFormCard(
                formKey: _formKey,
                refs: refs,
                selectedDate: _selectedDate,
                clientId: _clientId,
                serviceId: _serviceId,
                employeeId: _employeeId,
                zoneId: _zoneId,
                source: _source,
                rewardRuleId: _rewardRuleId,
                clientRewardsFuture: _clientRewardsFuture,
                slotsFuture: _slotsFuture,
                selectedSlotValue: _selectedSlotValue,
                notesController: _notesController,
                error: _error,
                creating: _creating,
                onClientChanged: (value) => setState(() {
                  _clientId = value;
                  _rewardRuleId = null;
                  _clientRewardsClientId = null;
                }),
                onServiceChanged: (value) {
                  setState(() {
                    _serviceId = value;
                    final service = _selectedService(refs);
                    if (!refs.employeeSupportsService(_employeeId, service)) {
                      _employeeId = null;
                    }
                    if (service?.requiresZone != true ||
                        !refs.zoneAllowedForService(_zoneId, service)) {
                      _zoneId = null;
                    }
                    _error = null;
                    _resetSlots(keepSelectedSlot: _selectedSlotValue != null);
                  });
                },
                onEmployeeChanged: (value) => setState(() {
                  _employeeId = value;
                  final service = _selectedService(refs);
                  if (!refs.employeeSupportsService(value, service)) {
                    _serviceId = null;
                    _zoneId = null;
                  }
                  _resetSlots(keepSelectedSlot: _selectedSlotValue != null);
                }),
                onZoneChanged: (value) => setState(() {
                  _zoneId = value;
                  _resetSlots(keepSelectedSlot: _selectedSlotValue != null);
                }),
                onSourceChanged: (value) => setState(() {
                  _source = value ?? 'manual';
                }),
                onRewardChanged: (value) => setState(() {
                  _rewardRuleId = value;
                }),
                onCreateClient: _createClientFromForm,
                onPickDate: _pickDate,
                onSlotChanged: _selectSlot,
                beforePhotoPath: _beforePhoto?.path,
                afterPhotoPath: _afterPhoto?.path,
                onPickBeforePhoto: () => _pickBookingPhoto('before'),
                onPickAfterPhoto: () => _pickBookingPhoto('after'),
                onOpenBeforePhoto: () => _openBookingPhoto('before'),
                onOpenAfterPhoto: () => _openBookingPhoto('after'),
                onCreateBooking: () => _createBooking(refs),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingFormCard extends StatelessWidget {
  const _BookingFormCard({
    required this.formKey,
    required this.refs,
    required this.selectedDate,
    required this.clientId,
    required this.serviceId,
    required this.employeeId,
    required this.zoneId,
    required this.source,
    required this.rewardRuleId,
    required this.clientRewardsFuture,
    required this.slotsFuture,
    required this.selectedSlotValue,
    required this.notesController,
    required this.creating,
    required this.onClientChanged,
    required this.onServiceChanged,
    required this.onEmployeeChanged,
    required this.onZoneChanged,
    required this.onSourceChanged,
    required this.onRewardChanged,
    required this.onCreateClient,
    required this.onPickDate,
    required this.onSlotChanged,
    required this.beforePhotoPath,
    required this.afterPhotoPath,
    required this.onPickBeforePhoto,
    required this.onPickAfterPhoto,
    required this.onOpenBeforePhoto,
    required this.onOpenAfterPhoto,
    required this.onCreateBooking,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final _BookingReferences refs;
  final DateTime selectedDate;
  final String? clientId;
  final String? serviceId;
  final String? employeeId;
  final String? zoneId;
  final String source;
  final String? rewardRuleId;
  final Future<ApiCollection>? clientRewardsFuture;
  final Future<_AvailabilitySlotsData>? slotsFuture;
  final String? selectedSlotValue;
  final TextEditingController notesController;
  final String? error;
  final bool creating;
  final ValueChanged<String?> onClientChanged;
  final ValueChanged<String?> onServiceChanged;
  final ValueChanged<String?> onEmployeeChanged;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onRewardChanged;
  final VoidCallback onCreateClient;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onSlotChanged;
  final String? beforePhotoPath;
  final String? afterPhotoPath;
  final VoidCallback onPickBeforePhoto;
  final VoidCallback onPickAfterPhoto;
  final VoidCallback onOpenBeforePhoto;
  final VoidCallback onOpenAfterPhoto;
  final VoidCallback onCreateBooking;

  @override
  Widget build(BuildContext context) {
    final selectedEmployee = refs.optionById(refs.employeeOptions, employeeId);
    final serviceOptions = selectedEmployee == null
        ? refs.serviceOptions
        : refs.servicesForEmployee(selectedEmployee);
    final service = refs.optionById(serviceOptions, serviceId);
    final zoneNeeded = service?.requiresZone ?? false;
    final employeeOptions = service == null
        ? refs.employeeOptions
        : refs.employeesForService(service);
    final zoneOptions =
        zoneNeeded ? refs.zonesForService(service) : const <_BookingOption>[];
    final hasValidEmployee =
        refs.optionById(employeeOptions, employeeId) != null;
    final hasValidZone =
        !zoneNeeded || refs.optionById(zoneOptions, zoneId) != null;
    final canCreate = service != null &&
        hasValidEmployee &&
        hasValidZone &&
        clientId != null &&
        !creating;
    final dateText = DateFormat('d MMM yyyy', 'es').format(selectedDate);
    final t = AppLocalizations.of(context);

    return PanelCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tr('Datos de la reserva'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              t.tr('Selecciona cliente, empleado, servicio y horario.'),
              style: const TextStyle(color: AnnaColors.muted),
            ),
            const SizedBox(height: 18),
            _SearchableDropdownField(
              label: t.tr('Cliente'),
              value: clientId,
              options: refs.clientOptions,
              icon: Icons.person_outline,
              onChanged: onClientChanged,
              searchHint: t.tr('Nombre, apellido, telefono, email o login'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: creating ? null : onCreateClient,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(t.tr('Crear cliente')),
              ),
            ),
            const SizedBox(height: 14),
            _SourceDropdownField(
              value: source,
              onChanged: onSourceChanged,
            ),
            const SizedBox(height: 14),
            _RewardSelector(
              rewardsFuture: clientRewardsFuture,
              value: rewardRuleId,
              onChanged: onRewardChanged,
            ),
            const SizedBox(height: 14),
            if (selectedEmployee != null && serviceOptions.isEmpty) ...[
              _HelperText(t.tr('Este empleado no tiene servicios disponibles')),
              const SizedBox(height: 10),
            ],
            _SearchableDropdownField(
              label: t.tr('Servicio'),
              value: serviceId,
              options: serviceOptions,
              icon: Icons.spa_outlined,
              onChanged: serviceOptions.isEmpty ? null : onServiceChanged,
              searchHint: t.tr('Nombre o descripcion del servicio'),
            ),
            if (service != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (service.durationMinutes != null)
                    AnnaBadge('${service.durationMinutes} min'),
                  if (service.price != null) AnnaBadge('${service.price} EUR'),
                  AnnaBadge(
                      zoneNeeded ? t.tr('Zona requerida') : t.tr('Sin zona')),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (service != null && employeeOptions.isEmpty) ...[
              _HelperText(t.tr('Este servicio no tiene empleados disponibles')),
              const SizedBox(height: 10),
            ],
            _DropdownField(
              label: t.tr('Empleado'),
              value: employeeId,
              options: employeeOptions,
              icon: Icons.badge_outlined,
              onChanged: employeeOptions.isEmpty ? null : onEmployeeChanged,
            ),
            if (zoneNeeded) ...[
              const SizedBox(height: 14),
              _HelperText(t.tr('Este servicio requiere zona')),
              const SizedBox(height: 10),
              _DropdownField(
                label: t.tr('Zona'),
                value: zoneId,
                options: zoneOptions,
                icon: Icons.place_outlined,
                onChanged: zoneOptions.isEmpty ? null : onZoneChanged,
              ),
            ],
            const SizedBox(height: 14),
            _PickerField(
              label: t.tr('Fecha'),
              value: dateText,
              icon: Icons.event_outlined,
              onTap: onPickDate,
            ),
            const SizedBox(height: 14),
            _AvailableSlotField(
              slotsFuture: slotsFuture,
              selectedValue: selectedSlotValue,
              enabled: service != null && hasValidEmployee && hasValidZone,
              onChanged: onSlotChanged,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t.tr('Notas'),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BookingPhotoField(
                    label: t.tr('Foto antes'),
                    path: beforePhotoPath,
                    icon: Icons.photo_camera_outlined,
                    onPick: creating ? null : onPickBeforePhoto,
                    onOpen: onOpenBeforePhoto,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BookingPhotoField(
                    label: t.tr('Foto despues'),
                    path: afterPhotoPath,
                    icon: Icons.photo_library_outlined,
                    onPick: creating ? null : onPickAfterPhoto,
                    onOpen: onOpenAfterPhoto,
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x8059221A),
                  borderRadius: BorderRadius.circular(AnnaRadii.md),
                  border: Border.all(color: const Color(0x3DE4987F)),
                ),
                child: Text(error!,
                    style: const TextStyle(color: Color(0xFFFFD7CA))),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canCreate ? onCreateBooking : null,
                child: creating ? const _ButtonSpinner() : Text(t.tr('Crear')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_BookingOption> options;
  final IconData icon;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _dedupeBookingOptions(options);
    final selectedValue =
        filteredOptions.any((option) => option.id == value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      dropdownColor: AnnaColors.accentDeep,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final option in filteredOptions)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (value) => value == null
          ? AppLocalizations.of(context).selectField(label)
          : null,
      onChanged: onChanged,
    );
  }
}

class _SearchableDropdownField extends StatelessWidget {
  const _SearchableDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
    required this.searchHint,
  });

  final String label;
  final String? value;
  final List<_BookingOption> options;
  final IconData icon;
  final ValueChanged<String?>? onChanged;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final filteredOptions = _dedupeBookingOptions(options);
    _BookingOption? selected;
    for (final option in filteredOptions) {
      if (option.id == value) {
        selected = option;
        break;
      }
    }
    final enabled = onChanged != null && filteredOptions.isNotEmpty;
    final display = selected?.label ?? t.selectField(label);

    return InkWell(
      borderRadius: BorderRadius.circular(AnnaRadii.md),
      onTap: enabled
          ? () async {
              final picked = await _SearchableOptionsSheet.show(
                context,
                title: label,
                searchHint: searchHint,
                options: filteredOptions,
                selectedId: selected?.id,
              );
              if (picked != null) onChanged?.call(picked.id);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.search),
          enabled: enabled,
        ),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null ? AnnaColors.muted : AnnaColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SearchableOptionsSheet extends StatefulWidget {
  const _SearchableOptionsSheet({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedId,
  });

  final String title;
  final String searchHint;
  final List<_BookingOption> options;
  final String? selectedId;

  static Future<_BookingOption?> show(
    BuildContext context, {
    required String title,
    required String searchHint,
    required List<_BookingOption> options,
    required String? selectedId,
  }) {
    return showModalBottomSheet<_BookingOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (_) => _SearchableOptionsSheet(
        title: title,
        searchHint: searchHint,
        options: options,
        selectedId: selectedId,
      ),
    );
  }

  @override
  State<_SearchableOptionsSheet> createState() =>
      _SearchableOptionsSheetState();
}

class _SearchableOptionsSheetState extends State<_SearchableOptionsSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final query = _normalizeSearch(_query);
    final visible = query.isEmpty
        ? widget.options
        : widget.options
            .where((option) => option.searchText.contains(query))
            .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t.tr('Buscar'),
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(t.tr('No hay resultados.'))
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final selected = option.id == widget.selectedId;
                        return PanelCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            title: Text(
                              option.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AnnaColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                    color: AnnaColors.muted,
                                  ),
                            onTap: () => Navigator.pop(context, option),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceDropdownField extends StatelessWidget {
  const _SourceDropdownField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  static const _options = [
    _SourceOption('manual', 'Manual'),
    _SourceOption('whatsapp', 'WhatsApp'),
    _SourceOption('website', 'Sitio web'),
    _SourceOption('instagram', 'Instagram'),
    _SourceOption('phone', 'Telefono'),
    _SourceOption('walk_in', 'En el salon'),
    _SourceOption('referral', 'Por recomendacion'),
    _SourceOption('employee', 'Por empleado'),
    _SourceOption('google', 'Google / Maps'),
    _SourceOption('other', 'Otro'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final byId = <String, _SourceOption>{};
    for (final option in _options) {
      byId.putIfAbsent(option.id, () => option);
    }
    final options = byId.values.toList();
    final selected = options.any((option) => option.id == value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      dropdownColor: AnnaColors.accentDeep,
      decoration: InputDecoration(
        labelText: t.tr('Origen de la reserva'),
        prefixIcon: const Icon(Icons.campaign_outlined),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(t.tr(option.label), overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (value) =>
          value == null ? t.selectField(t.tr('Origen de la reserva')) : null,
      onChanged: onChanged,
    );
  }
}

class _SourceOption {
  const _SourceOption(this.id, this.label);

  final String id;
  final String label;
}

class _RewardSelector extends StatelessWidget {
  const _RewardSelector({
    required this.rewardsFuture,
    required this.value,
    required this.onChanged,
  });

  final Future<ApiCollection>? rewardsFuture;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final future = rewardsFuture;
    if (future == null) {
      return _HelperText(t.tr('Selecciona cliente para ver premios.'));
    }
    return FutureBuilder<ApiCollection>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _HelperText(t.tr('Cargando premios...'));
        }
        if (snapshot.hasError) {
          return Text(
            formatApiError(snapshot.error!),
            style: const TextStyle(color: AnnaColors.danger),
          );
        }
        final rewards = (snapshot.data?.items ?? const <ApiRecord>[])
            .where((record) => _intFromRecord(record, 'available') > 0)
            .toList();
        if (rewards.isEmpty) {
          return _HelperText(
              t.tr('Este cliente aun no tiene premios disponibles.'));
        }
        final selected =
            rewards.any((record) => record.valueAsText('id') == value)
                ? value
                : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: AnnaColors.accentDeep,
          decoration: InputDecoration(
            labelText: t.tr('Premio del cliente'),
            prefixIcon: const Icon(Icons.card_giftcard_outlined),
          ),
          items: [
            DropdownMenuItem(
                value: null, child: Text(t.tr('No aplicar premio'))),
            for (final reward in rewards)
              DropdownMenuItem(
                value: reward.valueAsText('id'),
                child: Text(
                  '${reward.valueAsText('name') ?? t.tr('Premio')} · ${reward.valueAsText('discount_percent') ?? '0'}%',
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

class _HelperText extends StatelessWidget {
  const _HelperText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AnnaColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

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

class _BookingPhotoField extends StatelessWidget {
  const _BookingPhotoField({
    required this.label,
    required this.path,
    required this.icon,
    required this.onPick,
    required this.onOpen,
  });

  final String label;
  final String? path;
  final IconData icon;
  final VoidCallback? onPick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final imagePath = path;
    if (imagePath == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AnnaRadii.md),
      onTap: onOpen,
      child: Container(
        height: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AnnaRadii.md),
          border: Border.all(color: AnnaColors.line),
          image: DecorationImage(
            image: FileImage(File(imagePath)),
            fit: BoxFit.cover,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnnaRadii.md),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xB3000000)],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(icon, color: AnnaColors.text, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnnaColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_full,
                    color: AnnaColors.text,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailableSlotField extends StatelessWidget {
  const _AvailableSlotField({
    required this.slotsFuture,
    required this.selectedValue,
    required this.enabled,
    required this.onChanged,
  });

  final Future<_AvailabilitySlotsData>? slotsFuture;
  final String? selectedValue;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final normalizedSelected =
        selectedValue == null ? null : _normalizeSlotValue(selectedValue!);
    final selectedLabel =
        normalizedSelected == null ? null : _slotLabel(normalizedSelected);

    if (!enabled) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: t.tr('Hora'),
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          selectedLabel ?? t.tr('Selecciona servicio, empleado y zona'),
          style: TextStyle(
            color: selectedLabel == null ? AnnaColors.muted : AnnaColors.text,
            fontWeight:
                selectedLabel == null ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
      );
    }

    final future = slotsFuture;
    if (future == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: t.tr('Hora'),
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          t.tr('Sin datos de disponibilidad'),
          style: const TextStyle(color: AnnaColors.muted),
        ),
      );
    }

    return FutureBuilder<_AvailabilitySlotsData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: t.tr('Hora'),
              prefixIcon: const Icon(Icons.schedule),
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(t.tr('Buscando horarios...')),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: t.tr('Hora'),
              prefixIcon: const Icon(Icons.schedule),
            ),
            child: Text(
              formatApiError(snapshot.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final slots = _dedupeSlots(snapshot.data?.slots ?? const []);
        final value = slots.any((slot) => slot.value == normalizedSelected)
            ? normalizedSelected
            : null;
        if (slots.isEmpty) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: t.tr('Hora'),
              prefixIcon: const Icon(Icons.schedule),
            ),
            child: Text(
              t.tr('No hay horarios disponibles'),
              style: const TextStyle(color: AnnaColors.muted),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AnnaColors.accentDeep,
          decoration: InputDecoration(
            labelText: t.tr('Hora disponible'),
            prefixIcon: const Icon(Icons.schedule),
          ),
          items: [
            for (final slot in slots)
              DropdownMenuItem(
                value: slot.value,
                child: Text(slot.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          validator: (value) =>
              value == null ? t.selectField(t.tr('Hora disponible')) : null,
          onChanged: onChanged,
        );
      },
    );
  }
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

class _AvailabilitySlotsData {
  const _AvailabilitySlotsData({required this.slots});

  final List<_AvailableSlot> slots;

  factory _AvailabilitySlotsData.fromResponse(Map<String, dynamic> response) {
    final rawSlots = response['slots'];
    final slots = rawSlots is List
        ? rawSlots
            .whereType<Map>()
            .map(_AvailableSlot.fromMap)
            .whereType<_AvailableSlot>()
            .toList()
        : const <_AvailableSlot>[];
    return _AvailabilitySlotsData(slots: slots);
  }
}

class _AvailableSlot {
  const _AvailableSlot({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  static _AvailableSlot? fromMap(Map item) {
    final startAt = _textFromMap(item, 'start_at');
    if (startAt == null) return null;
    final label = _textFromMap(item, 'label') ?? _slotLabel(startAt);
    return _AvailableSlot(value: _normalizeSlotValue(startAt), label: label);
  }
}

List<_AvailableSlot> _dedupeSlots(List<_AvailableSlot> slots) {
  final byValue = <String, _AvailableSlot>{};
  for (final slot in slots) {
    byValue.putIfAbsent(slot.value, () => slot);
  }
  return byValue.values.toList();
}

class _BookingReferences {
  const _BookingReferences({
    required this.clients,
    required this.services,
    required this.employees,
    required this.zones,
  });

  final ApiCollection clients;
  final ApiCollection services;
  final ApiCollection employees;
  final ApiCollection zones;

  List<_BookingOption> get clientOptions =>
      _options(clients.items, _clientLabel);
  List<_BookingOption> get serviceOptions =>
      _options(services.items, _serviceLabel);
  List<_BookingOption> get employeeOptions =>
      _options(employees.items, _employeeLabel);
  List<_BookingOption> get zoneOptions => _options(zones.items, _zoneLabel);

  _BookingOption? optionById(List<_BookingOption> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  List<_BookingOption> zonesForService(_BookingOption? service) {
    if (service == null || !service.requiresZone) return const [];
    final allowed = service.allowedZoneIds;
    if (allowed.isEmpty) return const [];
    return zoneOptions.where((zone) => allowed.contains(zone.id)).toList();
  }

  List<_BookingOption> employeesForService(_BookingOption service) {
    final serviceEmployees = service.employeeIds;
    return employeeOptions.where((employee) {
      if (employee.serviceIds.contains(service.id)) return true;
      if (serviceEmployees.contains(employee.id)) return true;
      return employee.serviceIds.isEmpty && serviceEmployees.isEmpty;
    }).toList();
  }

  List<_BookingOption> servicesForEmployee(_BookingOption employee) {
    final employeeServices = employee.serviceIds;
    return serviceOptions.where((service) {
      if (employeeServices.contains(service.id)) return true;
      if (service.employeeIds.contains(employee.id)) return true;
      return employeeServices.isEmpty && service.employeeIds.isEmpty;
    }).toList();
  }

  bool employeeSupportsService(String? employeeId, _BookingOption? service) {
    if (employeeId == null || service == null) return false;
    return employeesForService(service)
        .any((employee) => employee.id == employeeId);
  }

  bool zoneAllowedForService(String? zoneId, _BookingOption? service) {
    if (service == null) return false;
    if (!service.requiresZone) return zoneId == null;
    if (zoneId == null) return false;
    return zonesForService(service).any((zone) => zone.id == zoneId);
  }

  static List<_BookingOption> _options(
    List<ApiRecord> records,
    String Function(ApiRecord) labelBuilder,
  ) {
    final options = records
        .map((record) {
          final id = _id(record);
          if (id == null) return null;
          return _BookingOption(
            id: id,
            label: labelBuilder(record),
            searchText: _searchText(record, labelBuilder(record)),
            record: record,
            durationMinutes:
                _intValue(record, const ['duration_minutes', 'duration']),
            price:
                _textValue(record, const ['price', 'client_price', 'amount']),
            requiresZone:
                _boolValue(record, const ['requires_zone', 'zone_required']),
            allowedZoneIds: _allowedZoneIds(record),
            serviceIds: _serviceIds(record),
            employeeIds: _employeeIds(record),
          );
        })
        .whereType<_BookingOption>()
        .toList();
    return _dedupeBookingOptions(options);
  }

  static String? _id(ApiRecord record) {
    return _textValue(record, const ['id', 'pk', 'uuid', 'value']);
  }

  static String _clientLabel(ApiRecord record) {
    final full =
        _textValue(record, const ['full_name', 'name', 'display_name']);
    if (full != null) return full;
    final first = _textValue(record, const ['first_name']) ?? '';
    final last = _textValue(record, const ['last_name']) ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : 'Cliente ${_id(record)}';
  }

  static String _serviceLabel(ApiRecord record) {
    return _textValue(record, const ['name', 'title', 'display_name']) ??
        'Servicio ${_id(record)}';
  }

  static String _employeeLabel(ApiRecord record) {
    final full =
        _textValue(record, const ['full_name', 'name', 'display_name']);
    if (full != null) return full;
    final first = _textValue(record, const ['first_name']) ?? '';
    final last = _textValue(record, const ['last_name']) ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : 'Empleado ${_id(record)}';
  }

  static String _zoneLabel(ApiRecord record) {
    return _textValue(record, const ['name', 'title', 'display_name']) ??
        'Zona ${_id(record)}';
  }

  static String _searchText(ApiRecord record, String label) {
    final values = <String>[label];
    void collect(Object? value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        values.add(value.toString());
        return;
      }
      if (value is Map) {
        for (final nested in value.values) {
          collect(nested);
        }
        return;
      }
      if (value is List) {
        for (final nested in value) {
          collect(nested);
        }
      }
    }

    collect(record.data);
    return _normalizeSearch(values.join(' '));
  }

  static String? _textValue(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final value = record.data[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value.toString();
    }
    return null;
  }

  static int? _intValue(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final value = record.data[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool _boolValue(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final value = record.data[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
      }
      if (value is num && value != 0) return true;
    }
    return false;
  }

  static Set<String> _allowedZoneIds(ApiRecord record) {
    return _idSet(record,
        const ['allowed_zone_ids', 'allowed_zones', 'zone_ids', 'zones']);
  }

  static Set<String> _serviceIds(ApiRecord record) {
    return _idSet(record, const ['service_ids', 'services']);
  }

  static Set<String> _employeeIds(ApiRecord record) {
    return _idSet(record, const ['employee_ids', 'employees']);
  }

  static Set<String> _idSet(ApiRecord record, List<String> keys) {
    for (final key in keys) {
      final raw = record.data[key];
      if (raw is! List) continue;
      return raw
          .map((item) {
            if (item is Map) {
              final id = item['id'] ?? item['pk'] ?? item['value'];
              return id?.toString();
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

List<_BookingOption> _dedupeBookingOptions(List<_BookingOption> options) {
  final byId = <String, _BookingOption>{};
  for (final option in options) {
    byId.putIfAbsent(option.id, () => option);
  }
  return byId.values.toList();
}

String _normalizeSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

class _BookingOption {
  const _BookingOption({
    required this.id,
    required this.label,
    required this.searchText,
    required this.record,
    required this.durationMinutes,
    required this.price,
    required this.requiresZone,
    required this.allowedZoneIds,
    required this.serviceIds,
    required this.employeeIds,
  });

  final String id;
  final String label;
  final String searchText;
  final ApiRecord record;
  final int? durationMinutes;
  final String? price;
  final bool requiresZone;
  final Set<String> allowedZoneIds;
  final Set<String> serviceIds;
  final Set<String> employeeIds;
}

String _apiErrorText(AnnaApiException error) {
  return formatApiError(error);
}

Map<String, dynamic> _bookingResponseMap(Map<String, dynamic> response) {
  for (final key in const ['booking', 'data', 'result', 'object']) {
    final nested = response[key];
    if (nested is Map) return Map<String, dynamic>.from(nested);
  }
  return response;
}

String? _textValueFromMap(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value.toString();
  }
  return null;
}

int _intFromRecord(ApiRecord record, String key) {
  final value = record.data[key];
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String? _textFromMap(Map data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return value.toString();
}

DateTime? _parseApiWallDateTime(String? value) {
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

String _normalizeSlotValue(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  if (normalized.length >= 16 && normalized[10] == 'T') {
    return normalized.substring(0, 16);
  }
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized;
  return DateFormat("yyyy-MM-dd'T'HH:mm").format(parsed);
}

String _formatApiDateTime(DateTime value) {
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value)}$sign$hours:$minutes';
}

String _slotLabel(String value) {
  final normalized = _normalizeSlotValue(value);
  if (normalized.length >= 16 && normalized[10] == 'T') {
    return normalized.substring(11, 16);
  }
  return value;
}
