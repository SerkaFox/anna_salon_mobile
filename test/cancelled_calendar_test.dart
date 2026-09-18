import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:anna_salon_mobile/api/anna_api.dart';
import 'package:anna_salon_mobile/models/api_record.dart';
import 'package:anna_salon_mobile/screens/calendar_screen.dart';
import 'package:anna_salon_mobile/l10n/app_localizations.dart';
import 'package:anna_salon_mobile/theme/app_theme.dart';

class CalendarApi extends AnnaApi {
  final calls = <String?>[];
  final dates = <DateTime>[];
  @override
  Future<ApiCollection> calendarDay(DateTime date, {String? cancelled}) async {
    calls.add(cancelled);
    dates.add(date);
    final start = DateTime(date.year, date.month, date.day, 10);
    return ApiCollection.fromJson({
      'date': date.toIso8601String(),
      'cancellation_dates': cancelled == null ? [] : [
        {'date': DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 31))), 'count': 1},
      ],
      'employees': [
        {
          'employee': {
            'id': 1,
            'full_name': 'Anna',
            'first_name': 'Anna',
            'color': '#008800'
          },
          'schedule': null,
          'time_blocks': []
        }
      ],
      'bookings': [
        {
          'id': date.day,
          'employee': 1,
          'employee_name': 'Anna',
          'client_name':
              cancelled == null ? 'Active client' : 'Cancelled client',
          'service_name': 'Manicura',
          'start_at': start.toIso8601String(),
          'end_at': start.add(const Duration(minutes: 60)).toIso8601String(),
          'status': cancelled == null ? 'confirmed' : 'cancelled',
          'status_label': cancelled == null ? 'Confirmada' : 'Cancelada',
          'cancellation_recorded_at': start.toIso8601String(),
        }
      ],
    });
  }
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting('es');
  });
  testWidgets(
      'Cancelled toggle filters and read-only cards do not alter live bookings',
      (tester) async {
    final api = CalendarApi();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildAnnaTheme(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: Scaffold(body: CalendarScreen(api: api, canManageStaff: true)),
    ));
    await tester.pumpAndSettle();
    expect(api.calls.last, isNull);
    await tester.tap(find.byTooltip('Reservas canceladas'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'all');
    expect(find.text('Modo de reservas canceladas'), findsOneWidget);
    expect(find.text('Active client'), findsNothing);
    await tester.tap(find.text('Fechas con canceladas'));
    await tester.pumpAndSettle();
    final future = DateTime.now().add(const Duration(days: 31));
    await tester.tap(find.text(DateFormat('dd.MM.yyyy').format(future)));
    await tester.pumpAndSettle();
    expect(api.dates.any((date) => date.year == future.year && date.month == future.month && date.day == future.day), isTrue);
    await tester.tap(find.text('Canceladas hoy'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'today');
    await tester.tap(find.text('Lista de canceladas en los días visibles'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Cancelled client').first);
    await tester.pumpAndSettle();
    expect(find.text('Fecha y hora original'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    await tester.ensureVisible(find.text('Cerrar'));
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reservas canceladas'));
    await tester.pumpAndSettle();
    expect(api.calls.last, isNull);
    expect(find.text('Modo de reservas canceladas'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
