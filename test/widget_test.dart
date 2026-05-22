import 'package:flutter_test/flutter_test.dart';

import 'package:anna_salon_mobile/main.dart';

void main() {
  testWidgets('AnnaSalonApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const AnnaSalonApp());

    await tester.pump();
    expect(find.byType(AnnaSalonApp), findsOneWidget);
  });
}
