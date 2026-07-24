import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:anna_salon_mobile/main.dart';
import 'package:anna_salon_mobile/api/anna_api.dart';
import 'package:anna_salon_mobile/l10n/app_localizations.dart';
import 'package:anna_salon_mobile/models/api_record.dart';
import 'package:anna_salon_mobile/screens/waitlist_screen.dart';
import 'package:anna_salon_mobile/theme/app_theme.dart';

class _FakeAnnaApi extends AnnaApi {
  @override
  Future<ApiCollection> waitlist() async => ApiCollection.fromJson([
        {
          'id': 2,
          'client': null,
          'service': 33,
          'service_name': 'Cortar y Limar Manos',
          'employee': 15,
          'employee_name': 'Daniela Mancilla',
          'desired_date': '2026-07-26',
          'time_range': 'all',
          'name': 'Sergei Svitkin',
          'phone': '607025851',
          'email': 'serkafox@gmail.com',
          'status': 'active',
        }
      ]);

  @override
  Future<ApiCollection> bookings({DateTime? date}) async {
    return ApiCollection.fromJson({'date': '2026-07-26', 'results': []});
  }
}

void main() {
  testWidgets('AnnaSalonApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const AnnaSalonApp());

    await tester.pump();
    expect(find.byType(AnnaSalonApp), findsOneWidget);
  });

  testWidgets('waitlist renders production payload', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAnnaTheme(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: WaitlistScreen(api: _FakeAnnaApi()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sergei Svitkin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
