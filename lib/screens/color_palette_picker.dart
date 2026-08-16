import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const annaColorPalette = [
  '#6FD29C',
  '#2E8F5C',
  '#E291B3',
  '#C75C8B',
  '#7AA7FF',
  '#54C6D8',
  '#F0B35A',
  '#D47D68',
  '#A78BFA',
  '#8BC34A',
  '#F06292',
  '#9E9E9E',
];

class ColorPalettePicker extends StatelessWidget {
  const ColorPalettePicker({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final hex in annaColorPalette)
            _ColorDot(
              hex: hex,
              selected: _normalizeHex(value) == hex.toUpperCase(),
              onTap: () => onChanged(hex),
            ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(hex) ?? AnnaColors.accent2;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AnnaColors.text : AnnaColors.line,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(Icons.check, size: 18, color: Color(0xFF071611))
            : null,
      ),
    );
  }
}

Color? parseHexColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

String _normalizeHex(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.startsWith('#') ? normalized : '#$normalized';
}
