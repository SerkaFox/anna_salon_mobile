import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class ClientFormSheet extends StatefulWidget {
  const ClientFormSheet({
    required this.api,
    this.client,
    super.key,
  });

  final AnnaApi api;
  final ApiRecord? client;

  static Future<ApiRecord?> show(
    BuildContext context, {
    required AnnaApi api,
    ApiRecord? client,
  }) {
    return showModalBottomSheet<ApiRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => ClientFormSheet(api: api, client: client),
    );
  }

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  static const _demoAppLink = 'https://brimoon.es/app/';

  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(
      text: widget.client?.valueAsText('first_name') ?? '');
  late final _lastNameController = TextEditingController(
      text: widget.client?.valueAsText('last_name') ?? '');
  late final _phoneController =
      TextEditingController(text: widget.client?.valueAsText('phone') ?? '');
  late final _emailController =
      TextEditingController(text: widget.client?.valueAsText('email') ?? '');
  late final _birthDateController = TextEditingController(
      text: widget.client?.valueAsText('birth_date') ?? '');
  late final _notesController =
      TextEditingController(text: widget.client?.valueAsText('notes') ?? '');
  late final _usernameController =
      TextEditingController(text: widget.client?.valueAsText('username') ?? '');
  final _passwordController = TextEditingController();
  late bool _isBlacklisted = _boolValue(widget.client?.data['is_blacklisted']);
  late bool _prepaymentExempt =
      _boolValue(widget.client?.data['prepayment_exempt']);
  bool _saving = false;
  String? _error;

  bool get _hasExistingClientAccess =>
      widget.client?.valueAsText('username') != null;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _notesController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'birth_date': _emptyToNull(_birthDateController),
        'notes': _notesController.text.trim(),
        'is_blacklisted': _isBlacklisted,
        'prepayment_exempt': _prepaymentExempt,
      };
      var username = _usernameController.text.trim();
      var password = _passwordController.text;
      if (username.isEmpty && !_hasExistingClientAccess) {
        username = _suggestUsername();
        _usernameController.text = username;
      }
      if (username.isNotEmpty &&
          password.isEmpty &&
          !_hasExistingClientAccess) {
        password = _generatePassword();
        _passwordController.text = password;
      }
      if (username.isNotEmpty && !_hasExistingClientAccess) {
        payload['username'] = username;
      }
      if (password.isNotEmpty) payload['password'] = password;
      final id =
          widget.client?.valueAsText('id') ?? widget.client?.valueAsText('pk');
      final response = id == null
          ? await widget.api.createClient(payload)
          : await widget.api.updateClient(id, payload);
      final record = ApiRecord(response.data);
      if (!mounted) return;
      if (username.isNotEmpty && password.isNotEmpty) {
        await _showAccessCreatedSheet(username: username, password: password);
        if (!mounted) return;
      }
      Navigator.of(context).pop(record);
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _generateClientAccess() {
    setState(() {
      if (!_hasExistingClientAccess &&
          _usernameController.text.trim().isEmpty) {
        _usernameController.text = _suggestUsername();
      }
      _passwordController.text = _generatePassword();
      _error = null;
    });
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

  String _suggestUsername() {
    final phoneDigits = _digitsOnly(_phoneController.text);
    if (phoneDigits.length >= 6) {
      return 'client_${phoneDigits.substring(phoneDigits.length - 6)}';
    }
    final email = _emailController.text.trim();
    final emailName = email.split('@').first.trim();
    if (emailName.isNotEmpty) {
      return _sanitizeUsername(emailName);
    }
    final name =
        '${_firstNameController.text}_${_lastNameController.text}'.trim();
    final sanitized = _sanitizeUsername(name);
    return sanitized.isEmpty
        ? 'client_${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _showAccessCreatedSheet({
    required String username,
    required String password,
  }) async {
    final t = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
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
              Text(t.tr('Acceso cliente creado'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              SelectableText(
                _accessMessage(username: username, password: password),
                style: const TextStyle(color: AnnaColors.text, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: Text(t.tr('Listo')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _sendAccessByWhatsapp(
                        context,
                        username: username,
                        password: password,
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAccessByWhatsapp(
    BuildContext context, {
    required String username,
    required String password,
  }) async {
    final t = AppLocalizations.of(context);
    final phone = _normalizePhone(_phoneController.text);
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Este cliente no tiene telefono valido.'))),
      );
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(_accessMessage(username: username, password: password))}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.tr('No se pudo abrir WhatsApp.'))),
    );
  }

  String _accessMessage({
    required String username,
    required String password,
  }) {
    final t = AppLocalizations.of(context);
    return '${t.tr('Acceso cliente creado')}\n\n'
        '${t.username}: $username\n'
        '${t.password}: $password\n'
        'App: $_demoAppLink';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: SingleChildScrollView(
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
                      widget.client == null
                          ? t.tr('Nuevo cliente')
                          : t.tr('Editar cliente'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.tr('Nombre'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? t.tr('Introduce el nombre')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.tr('Apellidos'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.tr('Telefono'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthDateController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: t.tr('Fecha de nacimiento'),
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: const Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: t.tr('Notas'),
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _isBlacklisted,
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _isBlacklisted = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  t.isRussian ? 'Заблокировать клиента' : 'Bloquear cliente',
                ),
                subtitle: Text(
                  t.isRussian
                      ? 'Клиент появится в фильтре «Чёрный список».'
                      : 'El cliente aparecera en el filtro «Lista negra».',
                ),
              ),
              CheckboxListTile(
                value: _prepaymentExempt,
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _prepaymentExempt = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(t.tr('Sin prepago · pago en el salon')),
                subtitle: Text(t.tr(
                  'Usar para clientes que no pueden pagar mediante el enlace.',
                )),
              ),
              const SizedBox(height: 14),
              Text(t.tr('Acceso cliente'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _generateClientAccess,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(t.tr('Generar acceso')),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                enabled: !_hasExistingClientAccess,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.tr('Usuario para cliente'),
                  prefixIcon: const Icon(Icons.account_circle_outlined),
                ),
              ),
              if (_hasExistingClientAccess) ...[
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
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.client == null
                      ? t.tr('Contrasena inicial')
                      : t.newPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  return value.length < 4 ? t.tr('Minimo 4 caracteres') : null;
                },
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
                      : Text(widget.client == null
                          ? t.tr('Crear cliente')
                          : t.tr('Guardar')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _emptyToNull(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _digitsOnly(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    if (RegExp(r'\d').hasMatch(char)) buffer.write(char);
  }
  return buffer.toString();
}

String _sanitizeUsername(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  final sanitized = normalized.replaceAll(RegExp(r'[^a-z0-9_.+-]'), '');
  return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
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
