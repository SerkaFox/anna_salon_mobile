import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
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
                            'BRIMOON Studio',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accede a tu calendario y reservas.',
                          style: TextStyle(color: AnnaColors.muted),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Introduce usuario'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Introduce contrasena'
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
                                : const Text('Entrar'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: const Text('Olvide mi contraseña'),
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

  String get _message {
    final contact = _contactController.text.trim();
    return 'Hola, necesito recuperar el acceso a BRIMOON Studio.\n\n'
        'Usuario, email o telefono: $contact\n\n'
        'Por favor, enviadme mi usuario o una nueva contraseña.';
  }

  Future<void> _sendWhatsApp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = 'Introduce tu usuario, email o telefono.');
      return;
    }
    setState(() => _error = null);
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    setState(() => _error = 'No se pudo abrir WhatsApp.');
  }

  Future<void> _copyMessage() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = 'Introduce tu usuario, email o telefono.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _message));
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud copiada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recuperar contraseña',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enviaremos una solicitud por WhatsApp para que administracion te entregue un nuevo acceso.',
            style: TextStyle(color: AnnaColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'Usuario, email o telefono',
              prefixIcon: Icon(Icons.person_search_outlined),
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
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
