import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.api,
    required this.onSignedIn,
    super.key,
  });

  final AnnaApi api;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.loginWithBasicAuth(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        storeForDev: true,
      );
      if (!mounted) return;
      widget.onSignedIn();
    } on AnnaApiException catch (error) {
      setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ForgotPasswordSheet(
        initialValue: _usernameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: annaBackgroundDecoration(context),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: PanelCard(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(child: AnnaLogo(size: 132)),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            t.appTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.loginSubtitle,
                          style: const TextStyle(color: AnnaColors.muted),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: t.username,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? t.enterUsername
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: t.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => value == null || value.isEmpty
                              ? t.enterPassword
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          AnnaErrorBanner(_error!),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(t.signIn),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: Text(t.forgotPassword),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _contactController =
      TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsApp() async {
    final t = AppLocalizations.of(context);
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = t.enterRecoveryContact);
      return;
    }
    setState(() => _error = null);
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(t.recoveryMessage(contact))}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    setState(() => _error = t.cantOpenWhatsApp);
  }

  Future<void> _copyMessage() async {
    final t = AppLocalizations.of(context);
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = t.enterRecoveryContact);
      return;
    }
    await Clipboard.setData(ClipboardData(text: t.recoveryMessage(contact)));
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.accessRequestCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.recoverPassword,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t.recoverPasswordHelp,
            style: const TextStyle(color: AnnaColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactController,
            decoration: InputDecoration(
              labelText: t.usernameEmailPhone,
              prefixIcon: const Icon(Icons.person_search_outlined),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendWhatsApp(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AnnaErrorBanner(_error!),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyMessage,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(t.copy),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(t.whatsapp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
