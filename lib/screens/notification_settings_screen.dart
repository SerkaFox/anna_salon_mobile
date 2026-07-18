import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({required this.api, super.key});

  final AnnaApi api;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late Future<ApiCollection> _future = widget.api.notifications();

  void _reload() {
    setState(() => _future = widget.api.notifications());
  }

  Future<void> _toggle(ApiRecord record, bool enabled) async {
    final kind = _text(record.data['kind']);
    if (kind.isEmpty) return;
    try {
      await widget.api.updateNotification(kind, {'enabled': enabled});
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'Plantilla activada.' : 'Plantilla pausada.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _openEditor(ApiRecord record) async {
    final changed = await NotificationTemplateSheet.show(
      context,
      api: widget.api,
      record: record,
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: annaBackgroundDecoration(context),
        child: SafeArea(
          child: ScreenScaffold(
            title: 'Notificaciones WhatsApp',
            action: IconButton(
              tooltip: 'Actualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            child: FutureBuilder<ApiCollection>(
              future: _future,
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
                  return ErrorState(error: snapshot.error!, onRetry: _reload);
                }
                final items = snapshot.data?.items ?? const <ApiRecord>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    'No hay plantillas de WhatsApp configuradas.',
                  );
                }
                return Column(
                  children: [
                    const _NotificationHelpCard(),
                    const SizedBox(height: 14),
                    for (final item in items) ...[
                      _NotificationTemplateCard(
                        record: item,
                        onToggle: (value) => _toggle(item, value),
                        onEdit: () => _openEditor(item),
                      ),
                      const SizedBox(height: 12),
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

class _NotificationHelpCard extends StatelessWidget {
  const _NotificationHelpCard();

  @override
  Widget build(BuildContext context) {
    return const PanelCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AnnaColors.muted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Gestiona las 7 plantillas automáticas de WhatsApp. '
              'Puedes activar, pausar, editar el texto y restaurar cada '
              'plantilla al valor por defecto.',
              style: TextStyle(color: AnnaColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTemplateCard extends StatelessWidget {
  const _NotificationTemplateCard({
    required this.record,
    required this.onToggle,
    required this.onEdit,
  });

  final ApiRecord record;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final data = record.data;
    final enabled = data['enabled'] == true;
    final name = _text(data['name'], fallback: _kindLabel(data['kind']));
    final kind = _text(data['kind']);
    final body = _text(data['body']);
    final variables = _variables(data['variables']);

    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.22)
                      : AnnaColors.line.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AnnaColors.line),
                ),
                child: Icon(
                  enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (kind.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        kind,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AnnaColors.muted, height: 1.35),
            ),
          ],
          if (variables.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final variable in variables) AnnaBadge(variable),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTemplateSheet extends StatefulWidget {
  const NotificationTemplateSheet({
    required this.api,
    required this.record,
    super.key,
  });

  final AnnaApi api;
  final ApiRecord record;

  static Future<bool?> show(
    BuildContext context, {
    required AnnaApi api,
    required ApiRecord record,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => NotificationTemplateSheet(
        api: api,
        record: record,
      ),
    );
  }

  @override
  State<NotificationTemplateSheet> createState() =>
      _NotificationTemplateSheetState();
}

class _NotificationTemplateSheetState extends State<NotificationTemplateSheet> {
  final _bodyController = TextEditingController();
  late bool _enabled = widget.record.data['enabled'] == true;
  bool _saving = false;
  bool _resetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bodyController.text = _text(widget.record.data['body']);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kind = _text(widget.record.data['kind']);
    if (kind.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateNotification(kind, {
        'enabled': _enabled,
        'body': _bodyController.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final kind = _text(widget.record.data['kind']);
    if (kind.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar plantilla'),
        content: const Text(
          'Se reemplazara el texto por defecto del servidor. '
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _resetting = true;
      _error = null;
    });
    try {
      await widget.api.resetNotification(kind);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _insertVariable(String variable) {
    final token = _variableToken(variable);
    final value = _bodyController.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final nextText = text.replaceRange(start, end, token);
    _bodyController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.record.data;
    final variables = _variables(data['variables']);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(data['name'], fallback: _kindLabel(data['kind'])),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: _saving || _resetting
                  ? null
                  : (value) => setState(() => _enabled = value),
              title: const Text('Plantilla activa'),
              subtitle: Text(_text(data['kind'])),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 7,
              maxLines: 12,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Texto del mensaje',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
            if (variables.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Variables disponibles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variable in variables)
                    _VariableInsertChip(
                      variable: variable,
                      enabled: !_saving && !_resetting,
                      onPressed: () => _insertVariable(variable),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pulsa una variable para insertarla donde esta el cursor.',
                style: TextStyle(color: AnnaColors.muted, height: 1.35),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              AnnaErrorBanner(_error!),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _resetting ? null : _reset,
                    icon: _resetting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore),
                    label: const Text('Restaurar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving || _resetting ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar'),
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

List<String> _variables(Object? value) {
  final rawItems = value is List
      ? value.map((item) => item.toString())
      : value == null
          ? const Iterable<String>.empty()
          : value.toString().split(RegExp(r'[\s,]+'));
  final variables = <String>[];
  for (final item in rawItems) {
    final variable = _variableName(item);
    if (variable.isNotEmpty && !variables.contains(variable)) {
      variables.add(variable);
    }
  }
  return variables;
}

String _variableName(Object? value) {
  return _text(value)
      .replaceAll(RegExp(r'^[{]+'), '')
      .replaceAll(RegExp(r'[}]+$'), '')
      .trim();
}

String _variableToken(String variable) => '{${_variableName(variable)}}';

String _variableLabel(String variable) {
  switch (_variableName(variable)) {
    case 'client_name':
      return 'NOMBRE';
    case 'salon_name':
      return 'SALON';
    case 'date':
      return 'FECHA';
    case 'time':
      return 'HORA';
    case 'service_name':
      return 'SERVICIO';
    case 'booking_url':
      return 'LINK RESERVA';
    case 'portal_url':
      return 'LINK PORTAL';
    case 'username':
      return 'USUARIO';
    case 'password':
      return 'CONTRASENA';
    case 'offer':
      return 'OFERTA';
    default:
      return _variableName(variable).replaceAll('_', ' ').toUpperCase();
  }
}

class _VariableInsertChip extends StatelessWidget {
  const _VariableInsertChip({
    required this.variable,
    required this.enabled,
    required this.onPressed,
  });

  final String variable;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add_circle_outline, size: 18),
      label: Text(_variableLabel(variable)),
      tooltip: _variableToken(variable),
      onPressed: enabled ? onPressed : null,
    );
  }
}

String _text(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String _kindLabel(Object? kind) {
  switch (_text(kind)) {
    case 'booking_confirmation':
      return 'Confirmacion de cita';
    case 'booking_cancelled':
      return 'Cita cancelada';
    case 'booking_rescheduled':
      return 'Cita reprogramada';
    case 'reminder_24h':
      return 'Recordatorio 24h';
    case 'reminder_2h':
      return 'Recordatorio 2h';
    case 'welcome_credentials':
      return 'Credenciales de bienvenida';
    case 'birthday_greeting':
      return 'Felicitacion de cumpleanos';
    default:
      return 'Plantilla WhatsApp';
  }
}
