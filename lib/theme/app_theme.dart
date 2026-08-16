import 'package:flutter/material.dart';

class AnnaColors {
  const AnnaColors._();

  static bool lightMode = false;

  static Color get bg => lightMode ? Colors.white : const Color(0xFF071611);
  static Color get bgSoft =>
      lightMode ? const Color(0xFFF7F8F8) : const Color(0xFF10261D);
  static Color get panel => lightMode ? Colors.white : const Color(0x1FDCF5E7);
  static Color get line =>
      lightMode ? const Color(0xFFD7DEDA) : const Color(0x2EABE4C3);
  static Color get text =>
      lightMode ? const Color(0xFF17211C) : const Color(0xFFE7FFF0);
  static Color get muted =>
      lightMode ? const Color(0xFF607068) : const Color(0xFF9CC7AD);
  static const accent = Color(0xFF2E8F5C);
  static const accent2 = Color(0xFF6FD29C);
  static Color get accentDeep =>
      lightMode ? const Color(0xFFE5F3EA) : const Color(0xFF123827);
  static const danger = Color(0xFFD47D68);
  static const warning = Color(0xFFD4A000);
  static const bookingCard = Color(0xFFEFFFF4);
  static const bookingText = Color(0xFF0B291A);
}

class AnnaRadii {
  const AnnaRadii._();

  static const xl = 28.0;
  static const lg = 20.0;
  static const md = 14.0;
}

class AnnaShadows {
  const AnnaShadows._();

  static const panel = [
    BoxShadow(
      color: Color(0x5702100A),
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
  ];
}

ThemeData buildAnnaTheme({
  Color primary = AnnaColors.accent2,
  bool lightMode = false,
}) {
  AnnaColors.lightMode = lightMode;
  final primaryOnDark = primary.computeLuminance() > 0.55
      ? const Color(0xFF072113)
      : AnnaColors.text;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: lightMode ? Brightness.light : Brightness.dark,
    primary: primary,
    secondary: AnnaColors.accent,
    surface: AnnaColors.bgSoft,
    onSurface: AnnaColors.text,
    error: AnnaColors.danger,
  );
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final baseTextTheme = (lightMode ? typography.black : typography.white).apply(
    bodyColor: AnnaColors.text,
    displayColor: AnnaColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AnnaColors.bg,
    textTheme: baseTextTheme.copyWith(
      headlineMedium: TextStyle(
        color: AnnaColors.text,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: AnnaColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AnnaColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: AnnaColors.text,
        fontSize: 16,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: AnnaColors.text,
        fontSize: 14,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: AnnaColors.muted,
        fontSize: 12,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: AnnaColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: AnnaColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        color: AnnaColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: lightMode ? Colors.white : const Color(0xF0071611),
      foregroundColor: AnnaColors.text,
      titleTextStyle: TextStyle(
        color: AnnaColors.text,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: AnnaColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnnaRadii.lg),
        side: BorderSide(color: AnnaColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x14E8FFF1),
      labelStyle: TextStyle(color: AnnaColors.muted),
      hintStyle: TextStyle(color: AnnaColors.muted),
      prefixIconColor: AnnaColors.muted,
      suffixIconColor: AnnaColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        borderSide: BorderSide(color: AnnaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        borderSide: BorderSide(color: AnnaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        borderSide: const BorderSide(color: AnnaColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: primaryOnDark,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        shape: const StadiumBorder(),
        disabledBackgroundColor: AnnaColors.line,
        disabledForegroundColor: AnnaColors.muted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AnnaColors.text,
        side: BorderSide(color: AnnaColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AnnaColors.text,
        backgroundColor: const Color(0x14E8FFF1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AnnaColors.line),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightMode ? Colors.white : const Color(0xF00A1D16),
      indicatorColor: primary.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AnnaColors.text,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primary
              : AnnaColors.muted,
        );
      }),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AnnaColors.bgSoft,
      headerBackgroundColor: AnnaColors.accentDeep,
      headerForegroundColor: AnnaColors.text,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AnnaColors.bgSoft,
      dialBackgroundColor: AnnaColors.accentDeep,
    ),
  );
}
