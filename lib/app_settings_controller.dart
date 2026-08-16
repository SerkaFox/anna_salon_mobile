import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'screens/color_palette_picker.dart';
import 'theme/app_theme.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _colorKey = 'anna_app_primary_color';
  static const _fontScaleKey = 'anna_app_font_scale';
  static const _languageKey = 'anna_app_language_code';
  static const _lightThemeKey = 'anna_app_light_theme';

  Color _primaryColor = AnnaColors.accent2;
  double _fontScale = 1;
  String _languageCode = 'es';
  bool _lightTheme = false;

  Color get primaryColor => _primaryColor;
  double get fontScale => _fontScale;
  String get languageCode => _languageCode;
  bool get lightTheme => _lightTheme;
  Locale get locale => Locale(_languageCode);
  String get primaryColorHex => _colorToHex(_primaryColor);

  Future<void> load() async {
    final storedColor = await _storage.read(key: _colorKey);
    final storedScale = await _storage.read(key: _fontScaleKey);
    final storedLanguage = await _storage.read(key: _languageKey);
    final storedLightTheme = await _storage.read(key: _lightThemeKey);
    _primaryColor = parseHexColor(storedColor) ?? AnnaColors.accent2;
    _fontScale = _normalizeFontScale(double.tryParse(storedScale ?? ''));
    _languageCode = _normalizeLanguageCode(storedLanguage);
    _lightTheme = storedLightTheme == 'true';
    notifyListeners();
  }

  Future<void> setPrimaryColorHex(String value) async {
    final color = parseHexColor(value);
    if (color == null) return;
    _primaryColor = color;
    notifyListeners();
    await _storage.write(key: _colorKey, value: _colorToHex(color));
  }

  Future<void> setFontScale(double value) async {
    _fontScale = _normalizeFontScale(value);
    notifyListeners();
    await _storage.write(key: _fontScaleKey, value: _fontScale.toString());
  }

  Future<void> setLanguageCode(String value) async {
    final languageCode = _normalizeLanguageCode(value);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    notifyListeners();
    await _storage.write(key: _languageKey, value: languageCode);
  }

  Future<void> setLightTheme(bool value) async {
    if (_lightTheme == value) return;
    _lightTheme = value;
    notifyListeners();
    await _storage.write(key: _lightThemeKey, value: value.toString());
  }

  static double _normalizeFontScale(double? value) {
    if (value == null || value.isNaN) return 1;
    return value.clamp(0.9, 1.2);
  }

  static String _normalizeLanguageCode(String? value) {
    return value == 'ru' ? 'ru' : 'es';
  }

  static String _colorToHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
