import 'package:anna_salon_mobile/printing/receipt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real receipt accepts Cyrillic names and emoji footer', () async {
    final bytes = await const ReceiptBuilder().build({
      'document_type_label': 'Recibo',
      'number': 'REC-2026-0001',
      'issue_date': '2026-07-25',
      'booking_start_at': '2026-07-25T16:00:00+02:00',
      'client_name': 'Анна Иванова',
      'subtotal_amount': '25.00',
      'tax_amount': '0.00',
      'total_amount': '25.00',
      'payments_total': '25.00',
      'balance_due': '0.00',
      'business': const {
        'name': 'BRIMOON Studio',
        'address': 'Bilbao',
        'footer': 'Спасибо за визит 😊 ❤️',
        'show_logo': false,
        'show_qr': false,
      },
      'lines': const [
        {
          'description': 'Маникюр',
          'quantity': '1',
          'unit_amount': '25.00',
          'total_amount': '25.00',
        },
      ],
      'payments': const [
        {
          'method_label': 'Tarjeta',
          'signed_amount': '25.00',
        },
      ],
    });

    expect(bytes, isNotEmpty);
  });
}
