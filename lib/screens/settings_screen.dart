import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_settings_controller.dart';
import '../app_version.dart';
import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'color_palette_picker.dart';
import 'notification_settings_screen.dart';
import 'shared.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.api,
    required this.settings,
    required this.onSignOut,
    super.key,
  });

  final AnnaApi api;
  final AppSettingsController settings;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late Future<Map<String, dynamic>> _profile = _loadProfile();
  Object? _profileKey;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    return (await widget.api.me()).data;
  }

  void _reload() {
    setState(() {
      _profile = _loadProfile();
      _profileKey = null;
      _error = null;
    });
  }

  void _syncProfile(Map<String, dynamic> data) {
    final key = jsonEncode([
      data['id'],
      data['first_name'],
      data['last_name'],
      data['email'],
    ]);
    if (_profileKey == key) return;
    _profileKey = key;
    _firstNameController.text = _text(data['first_name']);
    _lastNameController.text = _text(data['last_name']);
    _emailController.text = _text(data['email']);
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
      };
      final newPassword = _newPasswordController.text;
      if (newPassword.isNotEmpty) {
        payload['current_password'] = _currentPasswordController.text;
        payload['new_password'] = newPassword;
      }
      final updated = await widget.api.updateMe(payload);
      if (!mounted) return;
      setState(() {
        _profile = Future.value(updated.data);
        _profileKey = null;
      });
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileUpdated)),
      );
    } on AnnaApiException catch (error) {
      setState(() => _error = _apiErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: t.settings,
      action: IconButton(
        tooltip: t.refresh,
        onPressed: _reload,
        icon: Icon(Icons.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppearanceCard(settings: widget.settings),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _profile,
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
              final profile = snapshot.data ?? const <String, dynamic>{};
              _syncProfile(profile);
              return Column(
                children: [
                  _ProfileCard(
                    formKey: _formKey,
                    profile: profile,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    emailController: _emailController,
                    currentPasswordController: _currentPasswordController,
                    newPasswordController: _newPasswordController,
                    confirmPasswordController: _confirmPasswordController,
                    saving: _saving,
                    error: _error,
                    onSave: _saveProfile,
                  ),
                  if (_canManageNotifications(profile)) ...[
                    const SizedBox(height: 16),
                    _WhatsAppConnectionCard(api: widget.api),
                    const SizedBox(height: 16),
                    _WhatsAppNotificationsCard(api: widget.api),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const _AppVersionCard(),
          const SizedBox(height: 16),
          PanelCard(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: Icon(Icons.logout),
                label: Text(t.signOut),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    final russian = AppLocalizations.of(context).isRussian;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.info_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      russian
                          ? 'Версия приложения'
                          : 'Version de la aplicacion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$appVersionName ($appVersionBuild)',
                      style: TextStyle(
                        color: AnnaColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              AnnaBadge('v$appVersionName'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showChangeLog(context),
              icon: const Icon(Icons.history),
              label: Text(
                russian ? 'История изменений' : 'Historial de cambios',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeLog(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (_) => const _ChangeLogSheet(),
    );
  }
}

class _ChangeLogSheet extends StatelessWidget {
  const _ChangeLogSheet();

  @override
  Widget build(BuildContext context) {
    final russian = AppLocalizations.of(context).isRussian;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      russian ? 'История изменений' : 'Historial de cambios',
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
              Expanded(
                child: ListView.separated(
                  itemCount: appChangeLog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final release = appChangeLog[index];
                    final changes =
                        russian ? release.changesRu : release.changesEs;
                    return PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'v${release.version}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 8),
                              AnnaBadge('${release.build}'),
                              if (index == 0) ...[
                                const SizedBox(width: 8),
                                AnnaBadge(russian ? 'Текущая' : 'Actual'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final change in changes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(Icons.check_circle_outline,
                                        size: 17),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(change)),
                                ],
                              ),
                            ),
                        ],
                      ),
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

class _WhatsAppConnectionCard extends StatefulWidget {
  const _WhatsAppConnectionCard({required this.api});

  final AnnaApi api;

  @override
  State<_WhatsAppConnectionCard> createState() =>
      _WhatsAppConnectionCardState();
}

class _WhatsAppConnectionCardState extends State<_WhatsAppConnectionCard> {
  late Future<Map<String, dynamic>> _status = _load();

  Future<Map<String, dynamic>> _load() async {
    return (await widget.api.whatsappStatus()).data;
  }

  void _reload() => setState(() => _status = _load());

  @override
  Widget build(BuildContext context) {
    final russian = AppLocalizations.of(context).isRussian;
    return FutureBuilder<Map<String, dynamic>>(
      future: _status,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final connected = data['connected'] == true;
        final loading = snapshot.connectionState != ConnectionState.done;
        final color =
            connected ? Colors.green : Theme.of(context).colorScheme.error;
        return PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(connected ? Icons.check_circle : Icons.error_outline,
                      color: loading ? AnnaColors.muted : color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('WhatsApp',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                      onPressed: loading ? null : _reload,
                      icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loading
                    ? (russian
                        ? 'Проверяем подключение…'
                        : 'Comprobando la conexion…')
                    : connected
                        ? (russian
                            ? 'Подключён и готов отправлять сообщения.'
                            : 'Conectado y listo para enviar mensajes.')
                        : (russian
                            ? 'Отключён. Сообщения клиентам не отправляются.'
                            : 'Desconectado. No se envian mensajes a clientes.'),
                style: TextStyle(color: loading ? AnnaColors.muted : color),
              ),
              if (!loading && !connected) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final raw = data['reconnect_url']?.toString() ?? '';
                      final uri = Uri.tryParse(raw);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(russian
                        ? 'Переподключить WhatsApp'
                        : 'Volver a conectar WhatsApp'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WhatsAppNotificationsCard extends StatelessWidget {
  const _WhatsAppNotificationsCard({required this.api});

  final AnnaApi api;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AnnaColors.line),
                ),
                child: Icon(Icons.mark_chat_unread_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones WhatsApp',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Activa, pausa y edita las plantillas automaticas.',
                      style: TextStyle(color: AnnaColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationSettingsScreen(api: api),
                  ),
                );
              },
              icon: Icon(Icons.chevron_right),
              label: const Text('Gestionar notificaciones'),
            ),
          ),
        ],
      ),
    );
  }
}

bool _canManageNotifications(Map<String, dynamic> profile) {
  final role = _text(profile['role']).toLowerCase();
  return role == 'owner' || role == 'admin';
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.appearance, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                value: settings.lightTheme,
                onChanged: settings.setLightTheme,
                contentPadding: EdgeInsets.zero,
                title: Text(t.lightTheme),
                subtitle: Text(t.lightThemeHelp),
                secondary: Icon(Icons.light_mode_outlined),
              ),
              const SizedBox(height: 10),
              ColorPalettePicker(
                label: t.appColor,
                value: settings.primaryColorHex,
                onChanged: settings.setPrimaryColorHex,
              ),
              const SizedBox(height: 16),
              Text(t.language, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'es',
                    icon: Icon(Icons.language),
                    label: Text(t.spanish),
                  ),
                  ButtonSegment(
                    value: 'ru',
                    icon: Icon(Icons.translate),
                    label: Text(t.russian),
                  ),
                ],
                selected: {settings.languageCode},
                onSelectionChanged: (values) {
                  settings.setLanguageCode(values.first);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.format_size, color: AnnaColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.textSize,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AnnaBadge('${(settings.fontScale * 100).round()}%'),
                ],
              ),
              Slider(
                value: settings.fontScale,
                min: 0.9,
                max: 1.2,
                divisions: 6,
                label: '${(settings.fontScale * 100).round()}%',
                onChanged: settings.setFontScale,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.formKey,
    required this.profile,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.saving,
    required this.onSave,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> profile;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final username = _text(profile['username']);
    final role = _text(profile['role']);
    final employeeName = _text(profile['employee_name']);

    return PanelCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.myAccount, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (username.isNotEmpty) AnnaBadge(username),
                if (role.isNotEmpty) AnnaBadge(role),
                if (employeeName.isNotEmpty) AnnaBadge(employeeName),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: firstNameController,
              decoration: InputDecoration(
                labelText: t.firstName,
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: lastNameController,
              decoration: InputDecoration(
                labelText: t.lastName,
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (!text.contains('@')) return t.invalidEmail;
                return null;
              },
            ),
            const SizedBox(height: 18),
            Text(t.changePassword,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.currentPassword,
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                final wantsPassword = newPasswordController.text.isNotEmpty ||
                    confirmPasswordController.text.isNotEmpty;
                if (wantsPassword && (value == null || value.isEmpty)) {
                  return t.enterCurrentPassword;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.newPassword,
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              validator: (value) {
                final text = value ?? '';
                final wantsPassword =
                    currentPasswordController.text.isNotEmpty ||
                        confirmPasswordController.text.isNotEmpty;
                if (!wantsPassword && text.isEmpty) return null;
                if (text.length < 4) return t.minFourChars;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.confirmNewPassword,
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              validator: (value) {
                if (newPasswordController.text.isEmpty &&
                    (value == null || value.isEmpty)) {
                  return null;
                }
                if (value != newPasswordController.text) {
                  return t.passwordsDontMatch;
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AnnaErrorBanner(error!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.save_outlined),
                label: Text(t.saveChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

String _apiErrorText(AnnaApiException error) {
  return formatApiError(error);
}
