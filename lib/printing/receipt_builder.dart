import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class ReceiptBuilder {
  const ReceiptBuilder();

  Future<List<int>> build(Map<String, dynamic> document) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final business = _map(document['business']);
    final lines = _maps(document['lines']);
    final payments = _maps(document['payments']);
    const normal = PosStyles(codeTable: 'CP1252');

    bytes.addAll(generator.reset());
    bytes.addAll(generator.setGlobalCodeTable('CP1252'));
    await _addLogo(bytes, generator);

    _addText(
      bytes,
      generator,
      _value(business['name'], fallback: 'BRIMOON Studio'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        codeTable: 'CP1252',
      ),
    );
    final legalName = _value(business['legal_name']);
    if (legalName.isNotEmpty && legalName != _value(business['name'])) {
      _addText(bytes, generator, legalName,
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'));
    }
    _centerIfPresent(
        bytes, generator, _prefixed('NIF/CIF: ', business['tax_id']));
    _centerIfPresent(bytes, generator, _value(business['address']));
    _centerIfPresent(bytes, generator, _prefixed('Tel: ', business['phone']));
    _centerIfPresent(bytes, generator, _value(business['email']));
    _centerIfPresent(bytes, generator, _value(business['website']));

    bytes.addAll(generator.hr(ch: '-'));
    _addText(
      bytes,
      generator,
      '${_value(document['document_type_label'], fallback: 'Recibo')} '
              '${_value(document['number'])}'
          .trim(),
      styles: const PosStyles(
          align: PosAlign.center, bold: true, codeTable: 'CP1252'),
    );
    _addKeyValue(
        bytes, generator, 'Fecha', _formatDate(document['issue_date']));
    _addKeyValue(bytes, generator, 'Cita',
        _formatDateTime(document['booking_start_at']));

    bytes.addAll(generator.hr(ch: '-'));
    _addText(bytes, generator,
        'Cliente: ${_value(document['client_name'], fallback: '-')}',
        styles: normal);
    _addOptional(bytes, generator, 'NIF/CIF', document['client_fiscal_id']);
    final fiscalAddress = [
      _value(document['client_fiscal_address']),
      [
        _value(document['client_fiscal_postcode']),
        _value(document['client_fiscal_city']),
      ].where((value) => value.isNotEmpty).join(' '),
    ].where((value) => value.isNotEmpty).join(', ');
    _addOptional(bytes, generator, 'Direccion', fiscalAddress);
    _addOptional(bytes, generator, 'Telefono', document['client_phone']);

    bytes.addAll(generator.hr(ch: '-'));
    for (final line in lines) {
      _addText(
        bytes,
        generator,
        _value(line['description'], fallback: 'Servicio'),
        styles: const PosStyles(bold: true, codeTable: 'CP1252'),
      );
      bytes.addAll(generator.row([
        PosColumn(
          text:
              '${_value(line['quantity'], fallback: '1')} x ${_money(line['unit_amount'])}',
          width: 8,
          styles: normal,
        ),
        PosColumn(
          text: _money(line['total_amount']),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]));
    }

    bytes.addAll(generator.hr(ch: '-'));
    _addMoneyRow(bytes, generator, 'Subtotal', document['subtotal_amount']);
    final tax = double.tryParse(_value(document['tax_amount'])) ?? 0;
    if (tax > 0) {
      _addMoneyRow(
        bytes,
        generator,
        'IVA ${_plainNumber(document['tax_rate'])}%',
        document['tax_amount'],
      );
    }
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          codeTable: 'CP1252',
        ),
      ),
      PosColumn(
        text: _money(document['total_amount']),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          codeTable: 'CP1252',
        ),
      ),
    ]));

    if (payments.isNotEmpty) {
      bytes.addAll(generator.hr(ch: '-'));
      _addText(bytes, generator, 'Pagos',
          styles: const PosStyles(bold: true, codeTable: 'CP1252'));
      for (final payment in payments) {
        _addMoneyRow(
          bytes,
          generator,
          _value(payment['method_label'], fallback: 'Pago'),
          payment['signed_amount'] ?? payment['amount'],
        );
      }
      _addMoneyRow(bytes, generator, 'Pagado', document['payments_total']);
      final balance = double.tryParse(_value(document['balance_due'])) ?? 0;
      if (balance > 0) {
        _addMoneyRow(bytes, generator, 'Pendiente', document['balance_due']);
      }
    }

    final notes = _value(document['notes']);
    if (notes.isNotEmpty) {
      bytes.addAll(generator.hr(ch: '-'));
      _addText(bytes, generator, notes, styles: normal);
    }

    final documentUrl =
        _value(document['document_url'], fallback: _value(business['website']));
    if (documentUrl.isNotEmpty) {
      bytes.addAll(generator.feed(1));
      _addText(bytes, generator, 'Consulta tu documento',
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'));
      bytes.addAll(generator.qrcode(documentUrl, size: QRSize.size5));
    }
    _addText(bytes, generator, 'Gracias por tu visita',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, codeTable: 'CP1252'));
    bytes.addAll(generator.feed(4));
    return bytes;
  }

  Future<void> _addLogo(List<int> bytes, Generator generator) async {
    try {
      final data = await rootBundle.load('logo.png');
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) return;
      final resized = img.copyResize(decoded, width: 220);
      bytes.addAll(generator.imageRaster(
        resized,
        align: PosAlign.center,
        imageFn: PosImageFn.bitImageRaster,
      ));
    } catch (_) {
      // A missing logo must not prevent the receipt from printing.
    }
  }

  void _addMoneyRow(
      List<int> bytes, Generator generator, String label, Object? value) {
    bytes.addAll(generator.row([
      PosColumn(
        text: label,
        width: 7,
        styles: const PosStyles(codeTable: 'CP1252'),
      ),
      PosColumn(
        text: '${_money(value)} EUR',
        width: 5,
        styles: const PosStyles(align: PosAlign.right, codeTable: 'CP1252'),
      ),
    ]));
  }

  void _addKeyValue(
      List<int> bytes, Generator generator, String key, String value) {
    if (value.isEmpty) return;
    _addText(bytes, generator, '$key: $value',
        styles: const PosStyles(codeTable: 'CP1252'));
  }

  void _addOptional(
      List<int> bytes, Generator generator, String key, Object? value) {
    final text = _value(value);
    if (text.isNotEmpty) _addKeyValue(bytes, generator, key, text);
  }

  void _centerIfPresent(List<int> bytes, Generator generator, String value) {
    if (value.isEmpty) return;
    _addText(bytes, generator, value,
        styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'));
  }

  void _addText(
    List<int> bytes,
    Generator generator,
    String value, {
    required PosStyles styles,
  }) {
    final safe = value
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .trim();
    if (safe.isNotEmpty) bytes.addAll(generator.text(safe, styles: styles));
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  List<Map<String, dynamic>> _maps(Object? value) {
    if (value is Map && value['results'] is List) value = value['results'];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  String _value(Object? value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  String _prefixed(String prefix, Object? value) {
    final text = _value(value);
    return text.isEmpty ? '' : '$prefix$text';
  }

  String _money(Object? value) {
    final parsed = double.tryParse(_value(value).replaceAll(',', '.')) ?? 0;
    return parsed.toStringAsFixed(2);
  }

  String _plainNumber(Object? value) {
    final parsed = double.tryParse(_value(value).replaceAll(',', '.'));
    if (parsed == null) return _value(value);
    return parsed == parsed.roundToDouble()
        ? parsed.toInt().toString()
        : parsed.toString();
  }

  String _formatDate(Object? value) {
    final parsed = DateTime.tryParse(_value(value));
    if (parsed == null) return _value(value);
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _formatDateTime(Object? value) {
    final parsed = DateTime.tryParse(_value(value));
    if (parsed == null) return _value(value);
    final local = parsed.toLocal();
    return '${_formatDate(local.toIso8601String())} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
