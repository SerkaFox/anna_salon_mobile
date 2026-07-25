import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final List<String> _logs = [];
  ThermalPrinterDevice? _saved;
  List<ThermalPrinterDevice> _devices = const [];
  bool _connected = false;
  bool _busy = true;
  String? _workingAddress;
  String _stage = 'Проверяю сохранённый принтер...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    _log('Экран принтера открыт.');
    try {
      _log('Читаю сохранённый принтер...');
      final saved = await _printer.savedDevice();
      _log(saved == null
          ? 'Сохранённого принтера нет.'
          : 'Сохранён: ${saved.name}, ${saved.address}.');
      _setStage('Проверяю текущее Bluetooth-соединение...');
      final connected = await _printer.isConnected;
      _log(connected ? 'Соединение активно.' : 'Активного соединения нет.');
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _connected = connected;
        _stage = connected ? 'Принтер подключён' : 'Готово к поиску';
      });
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final russian = t.isRussian;
    return ScreenScaffold(
      title: russian ? 'Принтер чеков' : 'Impresora de recibos',
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      action: IconButton(
        tooltip: russian ? 'Обновить' : 'Actualizar',
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  _connected ? Icons.print : Icons.print_disabled_outlined,
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
                            ? (russian ? 'Подключён' : 'Conectada')
                            : (_saved?.address ??
                                (russian
                                    ? 'PT210 должен быть спарен в Bluetooth Android'
                                    : 'La PT210 debe estar vinculada en Bluetooth Android')),
                        style: const TextStyle(
                          color: AnnaColors.muted,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _OperationStatus(
            busy: _busy,
            stage: _stage,
            error: _error,
          ),
          const SizedBox(height: 8),
          _NextAction(
            text: _nextActionText(russian),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.bluetooth_searching),
                label:
                    Text(russian ? 'Найти устройства' : 'Buscar dispositivos'),
              ),
              OutlinedButton.icon(
                onPressed: _saved == null || _busy ? null : _testPrint,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(russian ? 'Пробная печать' : 'Impresion de prueba'),
              ),
              IconButton(
                tooltip:
                    russian ? 'Настройки разрешений' : 'Ajustes de permisos',
                onPressed: _busy ? null : openAppSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              if (_saved != null)
                IconButton(
                  tooltip: russian ? 'Забыть принтер' : 'Olvidar impresora',
                  onPressed: _busy ? null : _forgetPrinter,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (_devices.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              russian ? 'Спаренные устройства' : 'Dispositivos vinculados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final device in _devices) ...[
              PanelCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth),
                  title: Text(
                    device.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  subtitle: Text(
                    device.address,
                    style: const TextStyle(
                      color: AnnaColors.muted,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  trailing: _workingAddress == device.address
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _saved?.address == device.address && _connected
                          ? const Icon(Icons.check_circle_outline)
                          : FilledButton(
                              onPressed: _busy ? null : () => _connect(device),
                              child: Text(russian ? 'Подключить' : 'Conectar'),
                            ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  russian ? 'Журнал подключения' : 'Registro de conexion',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: russian ? 'Копировать журнал' : 'Copiar registro',
                onPressed: _logs.isEmpty ? null : _copyLog,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              border: Border.all(color: AnnaColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _logs.isEmpty ? '—' : _logs.join('\n'),
                style: const TextStyle(
                  color: AnnaColors.muted,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    _begin('Запускаю поиск спаренных устройств...');
    try {
      final devices = await _printer.pairedDevices(onStatus: _status);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _stage = devices.isEmpty
            ? 'Спаренные устройства не найдены'
            : 'Найдено устройств: ${devices.length}';
      });
      if (devices.isEmpty) {
        _showMessage(AppLocalizations.of(context).isRussian
            ? 'Откройте Bluetooth Android, спарьте PT210 и повторите поиск.'
            : 'Abre Bluetooth Android, vincula la PT210 y repite la busqueda.');
      }
    } catch (error) {
      _fail(error);
    } finally {
      _finish();
    }
  }

  Future<void> _connect(ThermalPrinterDevice device) async {
    _begin('Начинаю подключение к ${device.name}...', address: device.address);
    try {
      await _printer.connect(device, onStatus: _status);
      if (!mounted) return;
      setState(() {
        _saved = device;
        _connected = true;
        _stage = 'Принтер подключён';
      });
      _showMessage(AppLocalizations.of(context).isRussian
          ? 'Принтер подключён.'
          : 'Impresora conectada.');
    } catch (error) {
      _fail(error);
    } finally {
      _finish();
    }
  }

  Future<void> _testPrint() async {
    _begin('Начинаю пробную печать...', address: _saved!.address);
    try {
      await _printer.printTest(onStatus: _status);
      if (!mounted) return;
      setState(() {
        _connected = true;
        _stage = 'Пробный чек отправлен';
      });
      _log('Пробная печать завершена.');
      _showMessage(AppLocalizations.of(context).isRussian
          ? 'Пробный чек отправлен.'
          : 'Recibo de prueba enviado.');
    } catch (error) {
      _fail(error);
    } finally {
      _finish();
    }
  }

  Future<void> _forgetPrinter() async {
    _begin('Удаляю сохранённый принтер...', address: _saved!.address);
    try {
      await _printer.forget();
      if (!mounted) return;
      setState(() {
        _saved = null;
        _connected = false;
        _stage = 'Принтер удалён';
      });
      _log('Сохранённый принтер удалён.');
    } catch (error) {
      _fail(error);
    } finally {
      _finish();
    }
  }

  void _begin(String message, {String? address}) {
    setState(() {
      _busy = true;
      _workingAddress = address;
      _error = null;
      _stage = message;
    });
    _log(message);
  }

  void _finish() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _workingAddress = null;
    });
  }

  void _status(String message) {
    if (!mounted) return;
    setState(() => _stage = message);
    _log(message);
  }

  void _setStage(String message) {
    if (!mounted) return;
    setState(() => _stage = message);
    _log(message);
  }

  void _fail(Object error) {
    if (!mounted) return;
    final message = error.toString();
    setState(() {
      _error = message;
      _stage = 'Операция остановлена';
    });
    _log('ОШИБКА: $message');
    _showMessage(message);
  }

  void _log(String message) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    if (!mounted) return;
    setState(() => _logs.add('[$time] $message'));
  }

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    if (!mounted) return;
    _showMessage(AppLocalizations.of(context).isRussian
        ? 'Журнал скопирован.'
        : 'Registro copiado.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _nextActionText(bool russian) {
    if (_busy) {
      return russian
          ? 'Дождитесь завершения текущего этапа.'
          : 'Espera a que termine el paso actual.';
    }
    if (_saved != null && _connected) {
      return russian
          ? 'Принтер готов. Нажмите «Пробная печать».'
          : 'La impresora esta lista. Pulsa «Impresion de prueba».';
    }
    if (_devices.isNotEmpty) {
      return russian
          ? 'Найдите PT210 в списке ниже и нажмите «Подключить».'
          : 'Busca la PT210 abajo y pulsa «Conectar».';
    }
    return russian
        ? 'Включите PT210 и нажмите «Найти устройства».'
        : 'Enciende la PT210 y pulsa «Buscar dispositivos».';
  }
}

class _NextAction extends StatelessWidget {
  const _NextAction({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.arrow_forward,
          size: 18,
          color: AnnaColors.accent2,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AnnaColors.text,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OperationStatus extends StatelessWidget {
  const _OperationStatus({
    required this.busy,
    required this.stage,
    required this.error,
  });

  final bool busy;
  final String stage;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final color = error == null ? AnnaColors.line : AnnaColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error == null
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : AnnaColors.danger.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              error == null ? Icons.info_outline : Icons.error_outline,
              size: 20,
              color: error == null ? AnnaColors.muted : AnnaColors.danger,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error ?? stage,
              style: TextStyle(
                color: error == null ? AnnaColors.text : AnnaColors.danger,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
