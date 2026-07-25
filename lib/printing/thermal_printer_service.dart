import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'receipt_builder.dart';

class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ThermalPrinterDevice {
  const ThermalPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

class ThermalPrinterService {
  ThermalPrinterService._();

  static final instance = ThermalPrinterService._();
  static const _addressKey = 'anna_thermal_printer_address';
  static const _nameKey = 'anna_thermal_printer_name';
  static const _storage = FlutterSecureStorage();

  Future<ThermalPrinterDevice?> savedDevice() async {
    final address = await _storage.read(key: _addressKey);
    if (address == null || address.isEmpty) return null;
    final name = await _storage.read(key: _nameKey);
    return ThermalPrinterDevice(
      name: name?.isNotEmpty == true ? name! : 'Impresora',
      address: address,
    );
  }

  Future<bool> get isConnected async {
    if (!Platform.isAndroid) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus.timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      return false;
    }
  }

  Future<List<ThermalPrinterDevice>> pairedDevices({
    void Function(String message)? onStatus,
  }) async {
    _ensureAndroid();
    onStatus?.call('Проверяю разрешение Bluetooth...');
    await _requestPermissions().timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ThermalPrinterException(
        'Android не ответил на запрос разрешения Bluetooth.',
      ),
    );
    onStatus?.call('Проверяю, включён ли Bluetooth...');
    final bluetoothEnabled =
        await PrintBluetoothThermal.bluetoothEnabled.timeout(
      const Duration(seconds: 6),
      onTimeout: () => throw const ThermalPrinterException(
        'Не удалось получить состояние Bluetooth за 6 секунд.',
      ),
    );
    if (!bluetoothEnabled) {
      throw const ThermalPrinterException(
        'Bluetooth выключен. Включите его в настройках Android.',
      );
    }
    onStatus?.call('Запрашиваю список спаренных устройств...');
    final devices = await PrintBluetoothThermal.pairedBluetooths.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ThermalPrinterException(
        'Android не вернул список устройств за 12 секунд.',
      ),
    );
    onStatus?.call('Получено устройств: ${devices.length}.');
    final mapped = devices.map((device) {
      final name = _safeDeviceValue(
        device.name,
        fallback: 'Dispositivo Bluetooth',
        maxLength: 80,
      );
      final address = _safeDeviceValue(
        device.macAdress,
        fallback: 'Sin direccion',
        maxLength: 40,
      );
      return ThermalPrinterDevice(name: name, address: address);
    }).toList();
    mapped.sort((left, right) {
      final priority =
          _printerPriority(left.name).compareTo(_printerPriority(right.name));
      return priority != 0
          ? priority
          : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return mapped;
  }

  Future<void> connect(
    ThermalPrinterDevice device, {
    void Function(String message)? onStatus,
  }) async {
    _ensureAndroid();
    onStatus?.call('Проверяю разрешение Bluetooth...');
    await _requestPermissions().timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ThermalPrinterException(
        'Android не ответил на запрос разрешения Bluetooth.',
      ),
    );
    onStatus?.call('Проверяю текущее соединение...');
    if (await isConnected) {
      onStatus?.call('Отключаю предыдущее соединение...');
      await PrintBluetoothThermal.disconnect.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    }
    onStatus?.call('Подключаюсь к ${device.name} (${device.address})...');
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.address,
    ).timeout(
      const Duration(seconds: 18),
      onTimeout: () => throw const ThermalPrinterException(
        'Принтер не ответил за 18 секунд. Выключите и включите его.',
      ),
    );
    if (!connected) {
      throw const ThermalPrinterException(
        'Android не смог подключиться к принтеру.',
      );
    }
    onStatus?.call('Соединение установлено, сохраняю принтер...');
    await _storage.write(key: _addressKey, value: device.address);
    await _storage.write(key: _nameKey, value: device.name);
    onStatus?.call('Принтер подключён и сохранён.');
  }

  Future<void> disconnect() async {
    if (Platform.isAndroid && await isConnected) {
      await PrintBluetoothThermal.disconnect.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    }
  }

  Future<void> forget() async {
    await disconnect();
    await _storage.delete(key: _addressKey);
    await _storage.delete(key: _nameKey);
  }

  Future<void> printDocument(
    Map<String, dynamic> document, {
    void Function(String message)? onStatus,
  }) async {
    await _ensureConnected(onStatus: onStatus);
    onStatus?.call('Формирую чек 58 мм...');
    final bytes = await const ReceiptBuilder().build(document);
    onStatus?.call('Отправляю ${bytes.length} байт на принтер...');
    final printed = await PrintBluetoothThermal.writeBytes(bytes).timeout(
      const Duration(seconds: 35),
      onTimeout: () => throw const ThermalPrinterException(
        'Принтер не принял данные за 35 секунд.',
      ),
    );
    if (!printed) {
      throw const ThermalPrinterException(
        'La impresora no ha aceptado el recibo.',
      );
    }
  }

  Future<void> printTest({
    void Function(String message)? onStatus,
  }) async {
    final now = DateTime.now();
    await printDocument({
      'document_type_label': 'Prueba de impresion',
      'number': 'PT210',
      'issue_date': now.toIso8601String(),
      'booking_start_at': now.toIso8601String(),
      'client_name': 'Cliente de prueba',
      'subtotal_amount': '10.00',
      'tax_amount': '0.00',
      'total_amount': '10.00',
      'payments_total': '10.00',
      'balance_due': '0.00',
      'business': const {
        'name': 'BRIMOON Studio',
        'website': 'https://brimoon.es',
      },
      'document_url': 'https://brimoon.es',
      'lines': const [
        {
          'description': 'Servicio de prueba',
          'quantity': '1',
          'unit_amount': '10.00',
          'total_amount': '10.00',
        },
      ],
      'payments': const [
        {
          'method_label': 'Efectivo',
          'signed_amount': '10.00',
        },
      ],
    }, onStatus: onStatus);
  }

  Future<void> _ensureConnected({
    void Function(String message)? onStatus,
  }) async {
    _ensureAndroid();
    onStatus?.call('Проверяю разрешение Bluetooth...');
    await _requestPermissions().timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ThermalPrinterException(
        'Android не ответил на запрос разрешения Bluetooth.',
      ),
    );
    onStatus?.call('Проверяю соединение с принтером...');
    if (await isConnected) {
      onStatus?.call('Принтер уже подключён.');
      return;
    }
    final device = await savedDevice();
    if (device == null) {
      throw const ThermalPrinterException(
        'Configura primero la impresora en Caja.',
      );
    }
    onStatus?.call('Переподключаюсь к ${device.name}...');
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.address,
    ).timeout(
      const Duration(seconds: 18),
      onTimeout: () => throw const ThermalPrinterException(
        'Сохранённый принтер не ответил за 18 секунд.',
      ),
    );
    if (!connected) {
      throw const ThermalPrinterException(
        'No se pudo reconectar con la impresora.',
      );
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final denied = statuses.values.any(
      (status) => status.isDenied || status.isPermanentlyDenied,
    );
    if (denied && !await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const ThermalPrinterException(
        'Permite el acceso a Bluetooth para buscar la impresora.',
      );
    }
  }

  void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw const ThermalPrinterException(
        'La impresion Bluetooth esta disponible en Android.',
      );
    }
  }

  int _printerPriority(String name) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (normalized.contains('pt210') || normalized.contains('goojprt')) {
      return 0;
    }
    if (normalized.contains('printer') ||
        normalized.contains('thermal') ||
        normalized.contains('pos')) {
      return 1;
    }
    return 2;
  }

  String _safeDeviceValue(
    String value, {
    required String fallback,
    required int maxLength,
  }) {
    final cleaned = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned.length <= maxLength
        ? cleaned
        : cleaned.substring(0, maxLength);
  }
}
