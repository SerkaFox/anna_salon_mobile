import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_settings_controller.dart';
import 'api/anna_api.dart';
import 'l10n/app_localizations.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintTextLayoutBoxes = false;
  ErrorWidget.builder = (details) => ColoredBox(
        color: AnnaColors.bgSoft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Ошибка интерфейса:\n${details.exceptionAsString()}',
            style: const TextStyle(
              color: AnnaColors.danger,
              fontSize: 12,
              height: 1.3,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
  await initializeDateFormatting('es');
  await initializeDateFormatting('ru');
  runApp(const AnnaSalonApp());
}

class AnnaSalonApp extends StatefulWidget {
  const AnnaSalonApp({super.key});

  @override
  State<AnnaSalonApp> createState() => _AnnaSalonAppState();
}

class _AnnaSalonAppState extends State<AnnaSalonApp> {
  final AnnaApi _api = AnnaApi();
  final AppSettingsController _settings = AppSettingsController();
  bool _checkingSession = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_syncApiLanguage);
    _restoreSession();
  }

  void _syncApiLanguage() {
    _api.languageCode = _settings.languageCode;
  }

  Future<void> _restoreSession() async {
    await _settings.load();
    _syncApiLanguage();
    final restored = await _api.restoreDevCredentials();
    if (!mounted) return;
    setState(() {
      _signedIn = restored;
      _checkingSession = false;
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_syncApiLanguage);
    super.dispose();
  }

  Future<void> _handleSignedIn() async {
    setState(() => _signedIn = true);
  }

  Future<void> _handleSignOut() async {
    await _api.clearDevCredentials();
    if (!mounted) return;
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'BRIMOON Studio',
          debugShowCheckedModeBanner: false,
          theme: buildAnnaTheme(primary: _settings.primaryColor),
          builder: (context, child) {
            final media = MediaQuery.maybeOf(context);
            if (media == null || child == null) {
              return child ?? const SizedBox();
            }
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(_settings.fontScale),
              ),
              child: child,
            );
          },
          locale: _settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _checkingSession
              ? const _Splash()
              : _signedIn
                  ? AppShell(
                      api: _api,
                      settings: _settings,
                      onSignOut: _handleSignOut,
                    )
                  : LoginScreen(api: _api, onSignedIn: _handleSignedIn),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
