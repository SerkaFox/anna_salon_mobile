import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';

BoxDecoration annaBackgroundDecoration([BuildContext? context]) {
  final primary = context == null
      ? AnnaColors.accent2
      : Theme.of(context).colorScheme.primary;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(AnnaColors.bg, primary, 0.08)!,
        Color.lerp(AnnaColors.bgSoft, primary, 0.14)!,
        Color.lerp(AnnaColors.bgSoft, primary, 0.22)!,
      ],
    ),
  );
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.title,
    required this.child,
    this.action,
    this.titleTextStyle,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final TextStyle? titleTextStyle;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(
          color: AnnaColors.text,
          fontSize: 14,
          height: 1.3,
        );
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title, style: titleTextStyle),
          actions: action == null ? null : [action!],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          sliver: SliverToBoxAdapter(
            child: DefaultTextStyle(
              style: bodyStyle.copyWith(fontSize: 14, height: 1.3),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class AnnaLogo extends StatelessWidget {
  const AnnaLogo({this.size = 52, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0x33DBFFE9)),
        boxShadow: AnnaShadows.panel,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AnnaColors.bgSoft,
          alignment: Alignment.center,
          child: Text(
            'B',
            style: TextStyle(
              color: AnnaColors.text,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  const PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AnnaRadii.lg),
        border: Border.all(color: Color.lerp(AnnaColors.line, primary, 0.35)!),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: 0.14),
            Color.lerp(AnnaColors.bgSoft, primary, 0.18)!
                .withValues(alpha: 0.5),
          ],
        ),
        boxShadow: AnnaShadows.panel,
      ),
      child: child,
    );
  }
}

class AnnaBadge extends StatelessWidget {
  const AnnaBadge(this.label, {this.warning = false, super.key});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color:
            warning ? const Color(0x29D4A000) : primary.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: warning
              ? const Color(0x57D4A000)
              : primary.withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AnnaColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AnnaColors.muted,
            ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = formatApiError(error);

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No se pudo cargar',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AnnaColors.muted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class AnnaErrorBanner extends StatefulWidget {
  const AnnaErrorBanner(this.message, {super.key});

  final String message;

  @override
  State<AnnaErrorBanner> createState() => _AnnaErrorBannerState();
}

class _AnnaErrorBannerState extends State<AnnaErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _controller.stop();
    });
  }

  @override
  void didUpdateWidget(covariant AnnaErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message == widget.message) return;
    _controller
      ..reset()
      ..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _controller.stop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0x8059221A),
              const Color(0xB56B1E17),
              _pulse.value,
            ),
            borderRadius: BorderRadius.circular(AnnaRadii.md),
            border: Border.all(
              color: Color.lerp(
                const Color(0x80D47D68),
                const Color(0xFFFFA391),
                _pulse.value,
              )!,
            ),
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFD7CA), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Color(0xFFFFD7CA),
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatApiError(Object error) {
  if (error is AnnaApiException) {
    return _formatApiException(error);
  }
  return _cleanErrorText(error.toString());
}

String _formatApiException(AnnaApiException error) {
  final body = error.body;
  if (body == null || body.trim().isEmpty) {
    return _cleanErrorText(error.message);
  }
  final decoded = _tryDecodeJson(body);
  if (decoded != null) {
    final extracted = _extractErrorMessages(decoded).join('\n');
    if (extracted.trim().isNotEmpty) return _cleanErrorText(extracted);
  }
  return _cleanErrorText(body);
}

Object? _tryDecodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

List<String> _extractErrorMessages(Object? value) {
  if (value == null) return const [];
  if (value is String) return [_cleanErrorText(value)];
  if (value is num || value is bool) return [value.toString()];
  if (value is List) {
    return [
      for (final item in value) ..._extractErrorMessages(item),
    ];
  }
  if (value is Map) {
    final entries = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final messages = _extractErrorMessages(entry.value);
      if (messages.isEmpty) continue;
      if (_isGenericErrorKey(key)) {
        entries.addAll(messages);
      } else {
        entries.add('${_humanizeErrorKey(key)}: ${messages.join(', ')}');
      }
    }
    return entries;
  }
  return [_cleanErrorText(value.toString())];
}

bool _isGenericErrorKey(String key) {
  return const {
    'detail',
    'non_field_errors',
    'error',
    'message',
  }.contains(key);
}

String _humanizeErrorKey(String key) {
  const labels = {
    'username': 'Usuario',
    'password': 'Contrasena',
    'new_password': 'Nueva contrasena',
    'current_password': 'Contrasena actual',
    'email': 'Email',
    'phone': 'Telefono',
    'first_name': 'Nombre',
    'last_name': 'Apellido',
  };
  return labels[key] ??
      key
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
}

String _cleanErrorText(String value) {
  var text = value.trim();
  if (text.isEmpty) return 'Ha ocurrido un error.';
  text = text
      .replaceAll('Г±', 'ñ')
      .replaceAll('contrasena', 'contraseña')
      .replaceAll('Contrasena', 'Contraseña')
      .replaceAll(RegExp(r'^[{(\["\s]+'), '')
      .replaceAll(RegExp(r'[})\]"\s]+$'), '')
      .replaceAll(RegExp(r'"\s*:\s*"?'), ': ')
      .replaceAll(RegExp(r'[,;]\s*'), '\n');
  text = text.replaceFirst(
    RegExp(r'^(detail|error|message|non field errors)\s*:\s*',
        caseSensitive: false),
    '',
  );
  return text.trim().isEmpty ? 'Ha ocurrido un error.' : text.trim();
}

class RecordCard extends StatelessWidget {
  const RecordCard({required this.record, this.leadingIcon, super.key});

  final ApiRecord record;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final entries = record.displayEntries.take(8).toList();

    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AnnaColors.line),
              ),
              child: Icon(leadingIcon, color: AnnaColors.text),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _KeyValue(label: entry.key, value: entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JsonBlock extends StatelessWidget {
  const JsonBlock(this.data, {super.key});

  final Object? data;

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC04110A),
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        border: Border.all(color: AnnaColors.line),
      ),
      child: Text(
        encoder.convert(data),
        style: const TextStyle(
          color: AnnaColors.text,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final text =
        value is Map || value is List ? jsonEncode(value) : value.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AnnaColors.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
