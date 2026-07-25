import 'package:anna_salon_mobile/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('base text styles always have bounded font sizes', () {
    final theme = buildAnnaTheme();

    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodySmall?.fontSize, 12);
    expect(theme.textTheme.labelLarge?.fontSize, 14);
    expect(theme.textTheme.labelMedium?.fontSize, 12);
  });
}
