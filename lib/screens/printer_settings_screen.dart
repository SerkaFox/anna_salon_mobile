import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../printing/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({required this.api, super.key});

  final AnnaApi api;

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
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      action: IconButton(
        tooltip: russian ? 'Обновить' : 'Actualizar',
        onPressed: _busy ? null : _scan,
        icon: Icon(Icons.refresh),
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
                        style: TextStyle(
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
                icon: Icon(Icons.bluetooth_searching),
                label:
                    Text(russian ? 'Найти устройства' : 'Buscar dispositivos'),
              ),
              OutlinedButton.icon(
                onPressed: _saved == null || _busy ? null : _testPrint,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text(russian ? 'Пробная печать' : 'Impresion de prueba'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _ReceiptTemplateSheet.show(
                          context,
                          api: widget.api,
                        ),
                icon: Icon(Icons.edit_note_outlined),
                label: Text(
                  russian ? 'Шаблон чека' : 'Plantilla del recibo',
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : openAppSettings,
                icon: Icon(Icons.admin_panel_settings_outlined),
                label: Text(
                  russian ? 'Разрешения Android' : 'Permisos Android',
                ),
              ),
              if (_saved != null)
                TextButton.icon(
                  onPressed: _busy ? null : _confirmForgetPrinter,
                  icon: Icon(Icons.link_off),
                  label: Text(
                    russian ? 'Сменить принтер' : 'Cambiar impresora',
                  ),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 32,
                      child: Icon(Icons.bluetooth, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AnnaColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            device.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AnnaColors.muted,
                              fontSize: 12,
                              height: 1.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_workingAddress == device.address)
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_saved?.address == device.address && _connected)
                      Icon(Icons.check_circle_outline)
                    else
                      IconButton(
                        tooltip: russian ? 'Подключить' : 'Conectar',
                        onPressed: _busy ? null : () => _connect(device),
                        icon: Icon(Icons.link),
                      ),
                  ],
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
                icon: Icon(Icons.copy_outlined),
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
                style: TextStyle(
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

  Future<void> _confirmForgetPrinter() async {
    final russian = AppLocalizations.of(context).isRussian;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(russian ? 'Сменить принтер?' : 'Cambiar impresora?'),
        content: Text(
          russian
              ? 'Текущая привязка будет удалена. После этого выберите другой принтер из списка.'
              : 'Se eliminara la vinculacion actual. Despues elige otra impresora de la lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(russian ? 'Отмена' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(russian ? 'Сменить' : 'Cambiar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _forgetPrinter();
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
        Icon(
          Icons.arrow_forward,
          size: 18,
          color: AnnaColors.accent2,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
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

class _ReceiptTemplateSheet extends StatefulWidget {
  const _ReceiptTemplateSheet({required this.api});

  final AnnaApi api;

  static Future<void> show(
    BuildContext context, {
    required AnnaApi api,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _ReceiptTemplateSheet(api: api),
    );
  }

  @override
  State<_ReceiptTemplateSheet> createState() => _ReceiptTemplateSheetState();
}

class _ReceiptTemplateSheetState extends State<_ReceiptTemplateSheet> {
  late Future<ApiDocument> _future = widget.api.receiptTemplate();
  final _businessName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _footer = TextEditingController();
  bool _showLogo = true;
  bool _showQr = true;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _businessName.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: FutureBuilder<ApiDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 260,
              child: ErrorState(
                error: snapshot.error!,
                onRetry: () => setState(
                  () => _future = widget.api.receiptTemplate(),
                ),
              ),
            );
          }
          _initialize(snapshot.data!.data);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.isRussian ? 'Шаблон чека' : 'Plantilla del recibo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  _businessName,
                  t.isRussian ? 'Название фирмы' : 'Nombre del negocio',
                ),
                _field(
                  _address,
                  t.isRussian ? 'Адрес' : 'Direccion',
                  maxLines: 2,
                ),
                _field(_phone, t.isRussian ? 'Телефон' : 'Telefono'),
                _field(_email, 'Email'),
                _field(_website, t.isRussian ? 'Сайт' : 'Web'),
                _field(
                  _footer,
                  t.isRussian
                      ? 'Поздравление или финальная строка'
                      : 'Mensaje final',
                  maxLines: 3,
                  helper: t.isRussian
                      ? 'Например: Спасибо за визит 😊. Emoji преобразуются в символы, понятные принтеру.'
                      : 'Ejemplo: Gracias por tu visita 😊. Los emoji se adaptan a simbolos imprimibles.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.isRussian ? 'Печатать логотип' : 'Imprimir logotipo',
                  ),
                  value: _showLogo,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showLogo = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.isRussian ? 'Печатать QR-код' : 'Imprimir codigo QR',
                  ),
                  value: _showQr,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showQr = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _confirmReset,
                    icon: Icon(Icons.restore),
                    label: Text(
                      t.isRussian
                          ? 'Сбросить к стандартному шаблону'
                          : 'Restablecer plantilla',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.save_outlined),
                    label: Text(t.tr('Guardar')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
        ),
      ),
    );
  }

  void _initialize(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;
    _applyData(data);
  }

  void _applyData(Map<String, dynamic> data) {
    _businessName.text = data['receipt_business_name']?.toString() ?? '';
    _address.text = data['receipt_address']?.toString() ?? '';
    _phone.text = data['receipt_phone']?.toString() ?? '';
    _email.text = data['receipt_email']?.toString() ?? '';
    _website.text = data['receipt_website']?.toString() ?? '';
    _footer.text = data['receipt_footer']?.toString() ?? '';
    _showLogo = data['receipt_show_logo'] != false;
    _showQr = data['receipt_show_qr'] != false;
  }

  Future<void> _confirmReset() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t.isRussian ? 'Сбросить шаблон?' : 'Restablecer plantilla?',
        ),
        content: Text(
          t.isRussian
              ? 'Название, адрес, контакты, поздравление и параметры логотипа/QR вернутся к исходным значениям.'
              : 'El nombre, direccion, contactos, mensaje y opciones de logotipo/QR volveran a sus valores iniciales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.isRussian ? 'Сбросить' : 'Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final response = await widget.api.resetReceiptTemplate();
      if (!mounted) return;
      setState(() {
        _applyData(response.data);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.isRussian
              ? 'Стандартный шаблон восстановлен.'
              : 'Plantilla restablecida.'),
        ),
      );
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.updateReceiptTemplate({
        'receipt_business_name': _businessName.text.trim(),
        'receipt_address': _address.text.trim(),
        'receipt_phone': _phone.text.trim(),
        'receipt_email': _email.text.trim(),
        'receipt_website': _website.text.trim(),
        'receipt_footer': _footer.text.trim(),
        'receipt_show_logo': _showLogo,
        'receipt_show_qr': _showQr,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              t.isRussian ? 'Шаблон чека сохранён.' : 'Plantilla guardada.'),
        ),
      );
      Navigator.pop(context);
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
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
