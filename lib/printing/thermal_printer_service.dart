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

  Future<bool> get isConnected async =>
      Platform.isAndroid && await PrintBluetoothThermal.connectionStatus;

  Future<List<ThermalPrinterDevice>> pairedDevices() async {
    _ensureAndroid();
    await _requestPermissions();
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ThermalPrinterException(
        'Activa Bluetooth y vuelve a intentarlo.',
      );
    }
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((device) => ThermalPrinterDevice(
              name: device.name.trim().isEmpty
                  ? 'Dispositivo Bluetooth'
                  : device.name,
              address: device.macAdress,
            ))
        .toList();
  }

  Future<void> connect(ThermalPrinterDevice device) async {
    _ensureAndroid();
    await _requestPermissions();
    if (await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.address,
    );
    if (!connected) {
      throw const ThermalPrinterException(
        'No se pudo conectar con la impresora.',
      );
    }
    await _storage.write(key: _addressKey, value: device.address);
    await _storage.write(key: _nameKey, value: device.name);
  }

  Future<void> disconnect() async {
    if (Platform.isAndroid && await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
  }

  Future<void> forget() async {
    await disconnect();
    await _storage.delete(key: _addressKey);
    await _storage.delete(key: _nameKey);
  }

  Future<void> printDocument(Map<String, dynamic> document) async {
    await _ensureConnected();
    final bytes = await const ReceiptBuilder().build(document);
    final printed = await PrintBluetoothThermal.writeBytes(bytes);
    if (!printed) {
      throw const ThermalPrinterException(
        'La impresora no ha aceptado el recibo.',
      );
    }
  }

  Future<void> printTest() async {
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
    });
  }

  Future<void> _ensureConnected() async {
    _ensureAndroid();
    await _requestPermissions();
    if (await PrintBluetoothThermal.connectionStatus) return;
    final device = await savedDevice();
    if (device == null) {
      throw const ThermalPrinterException(
        'Configura primero la impresora en Caja.',
      );
    }
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.address,
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
}
