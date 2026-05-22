import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

Future<void> showPhoneActions(
  BuildContext context, {
  required String phone,
}) async {
  final normalized = _normalizePhone(phone);
  if (normalized == null) return;
  final action = await showModalBottomSheet<_PhoneAction>(
    context: context,
    backgroundColor: AnnaColors.bgSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Escribir por WhatsApp'),
              subtitle: Text(phone),
              onTap: () => Navigator.pop(context, _PhoneAction.whatsapp),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Llamar'),
              subtitle: Text(phone),
              onTap: () => Navigator.pop(context, _PhoneAction.call),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final uri = action == _PhoneAction.whatsapp
      ? Uri.parse('https://wa.me/$normalized')
      : Uri(scheme: 'tel', path: normalized);
  await _launch(context, uri);
}

Future<void> writeEmail(
  BuildContext context, {
  required String email,
}) async {
  final value = email.trim();
  if (value.isEmpty) return;
  await _launch(context, Uri(scheme: 'mailto', path: value));
}

Future<void> _launch(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No se pudo abrir la aplicacion.')),
  );
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

enum _PhoneAction { whatsapp, call }
