import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_settings_controller.dart';
import 'api/anna_api.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
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
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await _settings.load();
    final restored = await _api.restoreDevCredentials();
    if (!mounted) return;
    setState(() {
      _signedIn = restored;
      _checkingSession = false;
    });
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
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
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
