import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../printing/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printer = ThermalPrinterService.instance;
  ThermalPrinterDevice? _saved;
  List<ThermalPrinterDevice> _devices = const [];
  bool _connected = false;
  bool _loading = true;
  String? _workingAddress;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final saved = await _printer.savedDevice();
    final connected = await _printer.isConnected;
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _connected = connected;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final russian = t.isRussian;
    return ScreenScaffold(
      title: russian ? 'Термопринтер' : 'Impresora termica',
      action: IconButton(
        tooltip: russian ? 'Обновить' : 'Actualizar',
        onPressed: _loading ? null : _scan,
        icon: const Icon(Icons.refresh),
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        _connected
                            ? Icons.print
                            : Icons.print_disabled_outlined,
                        color: _connected
                            ? Theme.of(context).colorScheme.primary
                            : AnnaColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _saved?.name ??
                                  (russian
                                      ? 'Принтер не выбран'
                                      : 'Sin impresora seleccionada'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _connected
                                  ? (russian ? 'Подключен' : 'Conectada')
                                  : (_saved?.address ??
                                      (russian
                                          ? 'Сначала подключите PT210 в настройках Bluetooth Android'
                                          : 'Vincula primero la PT210 en los ajustes Bluetooth de Android')),
                              style: const TextStyle(color: AnnaColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: Text(
                          russian ? 'Найти спаренные' : 'Buscar vinculadas'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saved == null || _workingAddress != null
                          ? null
                          : _testPrint,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                          russian ? 'Пробная печать' : 'Impresion de prueba'),
                    ),
                    if (_saved != null)
                      IconButton(
                        tooltip:
                            russian ? 'Забыть принтер' : 'Olvidar impresora',
                        onPressed:
                            _workingAddress == null ? _forgetPrinter : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                if (_devices.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    russian
                        ? 'Спаренные устройства'
                        : 'Dispositivos vinculados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final device in _devices) ...[
                    PanelCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text(device.address),
                        trailing: _workingAddress == device.address
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _saved?.address == device.address && _connected
                                ? const Icon(Icons.check_circle_outline)
                                : FilledButton(
                                    onPressed: () => _connect(device),
                                    child: Text(
                                        russian ? 'Подключить' : 'Conectar'),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
    );
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    try {
      final devices = await _printer.pairedDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
      if (devices.isEmpty) {
        _showMessage(AppLocalizations.of(context).isRussian
            ? 'Спаренных устройств нет. Откройте настройки Bluetooth Android и подключите PT210.'
            : 'No hay dispositivos vinculados. Abre los ajustes Bluetooth de Android y vincula la PT210.');
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(ThermalPrinterDevice device) async {
    setState(() => _workingAddress = device.address);
    try {
      await _printer.connect(device);
      if (!mounted) return;
      setState(() {
        _saved = device;
        _connected = true;
      });
      _showMessage(AppLocalizations.of(context).isRussian
          ? 'Принтер подключен.'
          : 'Impresora conectada.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _workingAddress = null);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _workingAddress = _saved!.address);
    try {
      await _printer.printTest();
      if (mounted) {
        setState(() => _connected = true);
        _showMessage(AppLocalizations.of(context).isRussian
            ? 'Пробный чек отправлен.'
            : 'Recibo de prueba enviado.');
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _workingAddress = null);
    }
  }

  Future<void> _forgetPrinter() async {
    setState(() => _workingAddress = _saved!.address);
    await _printer.forget();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _connected = false;
      _workingAddress = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
