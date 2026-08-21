import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../printing/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import 'printer_settings_screen.dart';
import 'shared.dart';

Future<void> showCashDocumentSheet(
  BuildContext context, {
  required AnnaApi api,
  required String documentId,
  required VoidCallback onChanged,
}) {
  return _CashDocumentSheet.show(
    context,
    api: api,
    documentId: documentId,
    onChanged: onChanged,
  );
}

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({required this.api, super.key});

  final AnnaApi api;

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  late DateTime _date = DateTime.now();
  int _rangeDays = 1;
  DateTimeRange? _customRange;
  String _methodFilter = 'all';
  late Future<_CashboxData> _future = _load();

  DateTime get _dateFrom =>
      _customRange?.start ?? _date.subtract(Duration(days: _rangeDays - 1));

  DateTime get _dateTo => _customRange?.end ?? _date;

  String? get _apiMethod => switch (_methodFilter) {
        'cash' => 'cash',
        'card' => 'card',
        'cash_card' => 'cash,card',
        _ => null,
      };

  Future<_CashboxData> _load() async {
    final result = await Future.wait([
      widget.api.cashbox(
        date: _dateTo,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        method: _apiMethod,
      ),
      widget.api.bookings(date: _date),
    ]);
    return _CashboxData(
      cashbox: result[0] as ApiDocument,
      bookings: result[1] as ApiCollection,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _customRange = null;
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _date = picked.end;
      _future = _load();
    });
  }

  void _setRangeDays(int days) {
    setState(() {
      _rangeDays = days;
      _customRange = null;
      _future = _load();
    });
  }

  void _setMethodFilter(String value) {
    setState(() {
      _methodFilter = value;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final localeCode = t.locale.languageCode;
    return ScreenScaffold(
      title: t.tr('Caja'),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _pickDate,
            icon: Icon(Icons.event_outlined),
          ),
          IconButton(
            onPressed: _reload,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      child: FutureBuilder<_CashboxData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final data = snapshot.data!;
          final cash = data.cashbox.data;
          final bookings = data.bookings.items
              .where((item) =>
                  _decimal(item.valueAsText('amount_due')) > 0 &&
                  item.valueAsText('status') != 'cancelled' &&
                  item.valueAsText('status') != 'no_show')
              .toList();
          final pendingDocs =
              ApiCollection.fromJson(cash['pending_documents']).items;
          final paidDocs = ApiCollection.fromJson(cash['paid_documents']).items;
          final payments = ApiCollection.fromJson(cash['payments']).items;
          final closure = cash['closure'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(cash['closure'])
              : null;
          final dateLabel = _dateFrom == _dateTo
              ? DateFormat('d MMM yyyy', localeCode).format(_dateTo)
              : '${DateFormat('d MMM', localeCode).format(_dateFrom)} — '
                  '${DateFormat('d MMM yyyy', localeCode).format(_dateTo)}';
          final totalsByMethod = cash['totals_by_method'] is Map
              ? Map<String, dynamic>.from(cash['totals_by_method'])
              : <String, dynamic>{};
          final canCloseCashbox =
              _dateFrom == _dateTo && _methodFilter == 'all';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        closure == null && canCloseCashbox
                            ? FilledButton.icon(
                                onPressed: () => _closeCashbox(context, cash),
                                icon: Icon(Icons.lock_outline),
                                label: Text(t.tr('Cerrar caja')),
                              )
                            : closure != null
                                ? FilledButton.tonalIcon(
                                    onPressed: () => _showClosureDetails(
                                      context,
                                      closure,
                                    ),
                                    icon: Icon(Icons.lock_clock_outlined),
                                    label: Text(t.isRussian
                                        ? 'Касса закрыта'
                                        : 'Caja cerrada'),
                                  )
                                : const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnnaBadge(
                          '${_dateFrom == _dateTo ? t.tr('Total del dia') : (t.isRussian ? 'Итого за период' : 'Total del periodo')}: ${cash['payments_total'] ?? '0.00'} EUR',
                        ),
                        AnnaBadge(
                          '${t.tr('Efectivo')}: ${totalsByMethod['cash'] ?? '0.00'} EUR',
                        ),
                        AnnaBadge(
                          '${t.tr('Tarjeta')}: ${totalsByMethod['card'] ?? '0.00'} EUR',
                        ),
                        AnnaBadge(
                          '${t.tr('Pagos del dia')}: ${cash['payments_count'] ?? '0'}',
                        ),
                        AnnaBadge(
                          '${t.tr('Documentos pendientes')}: ${pendingDocs.length}',
                        ),
                        if (closure != null)
                          AnnaBadge(
                            '${t.tr('Cerrar caja')}: ${closure['closure_date']}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _StripeBalanceCard(
                stripe: cash['stripe'] is Map
                    ? Map<String, dynamic>.from(cash['stripe'])
                    : const <String, dynamic>{},
                payouts: cash['stripe_payouts'] is List
                    ? List<Map<String, dynamic>>.from(
                        (cash['stripe_payouts'] as List)
                            .whereType<Map>()
                            .map(Map<String, dynamic>.from),
                      )
                    : const <Map<String, dynamic>>[],
                onPayout: (stripe) => _requestStripePayout(context, stripe),
              ),
              const SizedBox(height: 14),
              PanelCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.isRussian ? 'Период' : 'Periodo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(t.isRussian ? '1 день' : '1 día'),
                          selected: _customRange == null && _rangeDays == 1,
                          onSelected: (_) => _setRangeDays(1),
                        ),
                        ChoiceChip(
                          label: Text(t.isRussian ? '3 дня' : '3 días'),
                          selected: _customRange == null && _rangeDays == 3,
                          onSelected: (_) => _setRangeDays(3),
                        ),
                        ChoiceChip(
                          label: Text(t.isRussian ? 'Неделя' : 'Semana'),
                          selected: _customRange == null && _rangeDays == 7,
                          onSelected: (_) => _setRangeDays(7),
                        ),
                        ActionChip(
                          avatar: Icon(
                            Icons.date_range_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _customRange == null
                                ? (t.isRussian ? 'Диапазон' : 'Rango')
                                : dateLabel,
                          ),
                          onPressed: _pickCustomRange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t.isRussian ? 'Метод оплаты' : 'Método de pago',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(t.isRussian ? 'Все' : 'Todos'),
                          selected: _methodFilter == 'all',
                          onSelected: (_) => _setMethodFilter('all'),
                        ),
                        ChoiceChip(
                          label: Text(t.tr('Efectivo')),
                          selected: _methodFilter == 'cash',
                          onSelected: (_) => _setMethodFilter('cash'),
                        ),
                        ChoiceChip(
                          label: Text(t.tr('Tarjeta')),
                          selected: _methodFilter == 'card',
                          onSelected: (_) => _setMethodFilter('card'),
                        ),
                        ChoiceChip(
                          label: Text(
                            t.isRussian
                                ? 'Наличные + карта'
                                : 'Efectivo + tarjeta',
                          ),
                          selected: _methodFilter == 'cash_card',
                          onSelected: (_) => _setMethodFilter('cash_card'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PanelCard(
                padding: const EdgeInsets.all(14),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DecoratedBox(
                        decoration: annaBackgroundDecoration(context),
                        child: SafeArea(
                          child: PrinterSettingsScreen(api: widget.api),
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.isRussian
                                  ? 'Термопринтер чеков'
                                  : 'Impresora de recibos',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t.isRussian
                                  ? 'Подключение PT210 и пробная печать'
                                  : 'Conexion PT210 e impresion de prueba',
                              style: TextStyle(
                                color: AnnaColors.muted,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _CashSection(
                title: t.isRussian
                    ? 'Оплаченные документы'
                    : 'Documentos cobrados',
                child: paidDocs.isEmpty
                    ? EmptyState(t.isRussian
                        ? 'В этот день оплаченных документов нет.'
                        : 'No hay documentos cobrados este dia.')
                    : Column(
                        children: [
                          for (final document in paidDocs) ...[
                            _PaidDocumentCard(
                              api: widget.api,
                              document: document,
                              onChanged: _reload,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _CashSection(
                title: t.tr('Pagos del dia'),
                child: payments.isEmpty
                    ? EmptyState(t.tr('Sin pagos todavia.'))
                    : Column(
                        children: [
                          for (final payment in payments) ...[
                            _PaymentCard(
                              api: widget.api,
                              payment: payment,
                              onChanged: _reload,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _CashSection(
                title: t.tr('Documentos pendientes'),
                child: pendingDocs.isEmpty
                    ? EmptyState(t.tr('Sin documentos pendientes.'))
                    : Column(
                        children: [
                          for (final document in pendingDocs) ...[
                            _PendingDocumentCard(
                              api: widget.api,
                              document: document,
                              onChanged: _reload,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _CashSection(
                title: t.tr('Reservas'),
                child: bookings.isEmpty
                    ? EmptyState(t.tr('Sin reservas.'))
                    : Column(
                        children: [
                          for (final booking in bookings) ...[
                            _BookingDueCard(
                              api: widget.api,
                              booking: booking,
                              onChanged: _reload,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _closeCashbox(
    BuildContext context,
    Map<String, dynamic> cash,
  ) async {
    final t = AppLocalizations.of(context);
    final response = await _CashCloseSheet.show(
      context,
      api: widget.api,
      date: _date,
      cash: cash,
    );
    if (response == null || !context.mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.tr('Cierre guardado.'))),
    );
    await _showClosureDetails(context, response.data);
  }

  Future<void> _showClosureDetails(
    BuildContext context,
    Map<String, dynamic> closure,
  ) {
    final t = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.isRussian ? 'Касса закрыта' : 'Caja cerrada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClosureValue(
                label: t.isRussian ? 'Дата' : 'Fecha',
                value: closure['closure_date']?.toString() ?? '',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Всего' : 'Total',
                value: '${closure['total_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Наличные по системе' : 'Efectivo sistema',
                value: '${closure['cash_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Наличные посчитано' : 'Efectivo contado',
                value: '${closure['declared_cash_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Разница' : 'Diferencia',
                value: '${closure['cash_difference'] ?? '0.00'} EUR',
                emphasize: _money(
                      closure['cash_difference']?.toString(),
                    ) !=
                    0,
              ),
              _ClosureValue(
                label: t.isRussian ? 'Карта' : 'Tarjeta',
                value: '${closure['card_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: 'Bizum',
                value: '${closure['bizum_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Перевод' : 'Transferencia',
                value: '${closure['transfer_amount'] ?? '0.00'} EUR',
              ),
              _ClosureValue(
                label: t.isRussian ? 'Операций' : 'Movimientos',
                value: closure['payments_count']?.toString() ?? '0',
              ),
              if ((closure['notes']?.toString() ?? '').isNotEmpty)
                _ClosureValue(
                  label: t.isRussian ? 'Примечание' : 'Notas',
                  value: closure['notes'].toString(),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.isRussian ? 'Готово' : 'Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestStripePayout(
    BuildContext context,
    Map<String, dynamic> stripe,
  ) async {
    final result = await _StripePayoutDialog.show(context, stripe: stripe);
    if (result == null || !context.mounted) return;
    try {
      await widget.api.requestStripePayout({
        ...result,
        'request_id': const Uuid().v4(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).isRussian
              ? 'Выплата Stripe запрошена.'
              : 'Retirada Stripe solicitada.'),
        ),
      );
      _reload();
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }
}

class _StripeBalanceCard extends StatelessWidget {
  const _StripeBalanceCard({
    required this.stripe,
    required this.payouts,
    required this.onPayout,
  });

  final Map<String, dynamic> stripe;
  final List<Map<String, dynamic>> payouts;
  final ValueChanged<Map<String, dynamic>> onPayout;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final error = stripe['error']?.toString() ?? '';
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Stripe',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (stripe['livemode'] == true)
                AnnaBadge(t.isRussian ? 'Реальный счет' : 'Cuenta real'),
            ],
          ),
          const SizedBox(height: 12),
          if (error.isNotEmpty)
            Text(error, style: TextStyle(color: AnnaColors.danger))
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AnnaBadge(
                  '${t.isRussian ? 'Доступно' : 'Disponible'}: ${stripe['available_amount'] ?? '0.00'} EUR',
                ),
                AnnaBadge(
                  '${t.isRussian ? 'Ожидается' : 'Pendiente'}: ${stripe['pending_amount'] ?? '0.00'} EUR',
                ),
                AnnaBadge(
                  '${t.isRussian ? 'Мгновенно' : 'Instantáneo'}: ${stripe['instant_available_amount'] ?? '0.00'} EUR',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t.isRussian
                  ? 'Стандартная выплата поступит на IBAN, настроенный в Stripe.'
                  : 'La retirada estándar llegará al IBAN configurado en Stripe.',
              style: TextStyle(
                color: AnnaColors.muted,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  stripe['can_payout'] == true ? () => onPayout(stripe) : null,
              icon: Icon(Icons.payments_outlined),
              label: Text(t.isRussian ? 'Вывести средства' : 'Retirar fondos'),
            ),
            if (payouts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                t.isRussian ? 'Последние выплаты' : 'Últimas retiradas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final payout in payouts.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${payout['amount']} EUR · ${payout['method_label']} · ${payout['status_label']}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StripePayoutDialog extends StatefulWidget {
  const _StripePayoutDialog({required this.stripe});

  final Map<String, dynamic> stripe;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> stripe,
  }) =>
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _StripePayoutDialog(stripe: stripe),
      );

  @override
  State<_StripePayoutDialog> createState() => _StripePayoutDialogState();
}

class _StripePayoutDialogState extends State<_StripePayoutDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.stripe['available_amount']?.toString() ?? '0.00',
  );
  final TextEditingController _password = TextEditingController();
  String _method = 'standard';

  @override
  void dispose() {
    _amount.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
          t.isRussian ? 'Вывести средства Stripe' : 'Retirar fondos de Stripe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Importe', suffixText: 'EUR'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration:
                InputDecoration(labelText: t.isRussian ? 'Способ' : 'Método'),
            items: [
              DropdownMenuItem(
                value: 'standard',
                child: Text(
                    t.isRussian ? 'На IBAN из Stripe' : 'Al IBAN de Stripe'),
              ),
              if (widget.stripe['can_instant_payout'] == true)
                DropdownMenuItem(
                  value: 'instant',
                  child: Text(t.isRussian ? 'Мгновенно' : 'Instantánea'),
                ),
            ],
            onChanged: (value) => setState(() => _method = value ?? 'standard'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t.isRussian ? 'Пароль Анны' : 'Contraseña de Anna',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t.isRussian
                ? 'Это реальная финансовая операция. Повторное нажатие защищено уникальным номером запроса.'
                : 'Esta es una operación financiera real. La solicitud está protegida contra duplicados.',
            style: TextStyle(color: AnnaColors.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.tr('Cancelar')),
        ),
        FilledButton(
          onPressed: _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'amount': _amount.text.trim().replaceAll(',', '.'),
                    'method': _method,
                    'current_password': _password.text,
                  }),
          child:
              Text(t.isRussian ? 'Подтвердить выплату' : 'Confirmar retirada'),
        ),
      ],
    );
  }
}

class _CashCloseSheet extends StatefulWidget {
  const _CashCloseSheet({
    required this.api,
    required this.date,
    required this.cash,
  });

  final AnnaApi api;
  final DateTime date;
  final Map<String, dynamic> cash;

  static Future<ApiDocument?> show(
    BuildContext context, {
    required AnnaApi api,
    required DateTime date,
    required Map<String, dynamic> cash,
  }) {
    return showModalBottomSheet<ApiDocument>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _CashCloseSheet(
        api: api,
        date: date,
        cash: cash,
      ),
    );
  }

  @override
  State<_CashCloseSheet> createState() => _CashCloseSheetState();
}

class _CashCloseSheetState extends State<_CashCloseSheet> {
  late final Map<String, dynamic> _totals =
      widget.cash['totals_by_method'] is Map
          ? Map<String, dynamic>.from(widget.cash['totals_by_method'])
          : <String, dynamic>{};
  late final TextEditingController _declaredCash = TextEditingController(
    text: _totals['cash']?.toString() ?? '0.00',
  );
  final TextEditingController _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _declaredCash.addListener(_refreshDifference);
  }

  @override
  void dispose() {
    _declaredCash.removeListener(_refreshDifference);
    _declaredCash.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _refreshDifference() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = t.locale.languageCode;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final expectedCash = _money(_totals['cash']?.toString());
    final declaredCash = _money(_declaredCash.text);
    final difference = declaredCash - expectedCash;
    final pendingCount =
        ApiCollection.fromJson(widget.cash['pending_documents']).items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.isRussian ? 'Закрытие кассы' : 'Cierre de caja',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            Text(
              DateFormat('d MMMM yyyy', locale).format(widget.date),
              style: TextStyle(color: AnnaColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            PanelCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _ClosureValue(
                    label: t.isRussian ? 'Всего за день' : 'Total del dia',
                    value: '${widget.cash['payments_total'] ?? '0.00'} EUR',
                  ),
                  _ClosureValue(
                    label: t.isRussian ? 'Операций' : 'Movimientos',
                    value: widget.cash['payments_count']?.toString() ?? '0',
                  ),
                  _ClosureValue(
                    label: t.isRussian ? 'Наличные' : 'Efectivo',
                    value: '${_totals['cash'] ?? '0.00'} EUR',
                  ),
                  _ClosureValue(
                    label: t.isRussian ? 'Карта' : 'Tarjeta',
                    value: '${_totals['card'] ?? '0.00'} EUR',
                  ),
                  _ClosureValue(
                    label: 'Bizum',
                    value: '${_totals['bizum'] ?? '0.00'} EUR',
                  ),
                  _ClosureValue(
                    label: t.isRussian ? 'Перевод' : 'Transferencia',
                    value: '${_totals['transfer'] ?? '0.00'} EUR',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _declaredCash,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: t.isRussian
                    ? 'Наличные фактически посчитано'
                    : 'Efectivo contado',
                suffixText: 'EUR',
              ),
            ),
            const SizedBox(height: 8),
            _ClosureValue(
              label: t.isRussian ? 'Разница наличных' : 'Diferencia',
              value: '${_formatMoney(difference)} EUR',
              emphasize: difference != 0,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    t.isRussian ? 'Примечание к закрытию' : 'Notas del cierre',
              ),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AnnaColors.warning.withValues(alpha: 0.12),
                  border: Border.all(color: AnnaColors.warning),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.isRussian
                      ? 'Осталось неоплаченных документов: $pendingCount на сумму ${widget.cash['pending_total'] ?? '0.00'} EUR.'
                      : 'Quedan $pendingCount documentos pendientes por ${widget.cash['pending_total'] ?? '0.00'} EUR.',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              t.isRussian
                  ? 'После закрытия нельзя добавлять или изменять платежи этого дня.'
                  : 'Despues del cierre no se podran anadir ni modificar pagos de este dia.',
              style: TextStyle(
                color: AnnaColors.muted,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.lock_outline),
                label: Text(t.isRussian ? 'Закрыть кассу' : 'Cerrar caja'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final declaredValue = double.tryParse(
      _declaredCash.text.trim().replaceAll(',', '.'),
    );
    if (declaredValue == null || declaredValue < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.isRussian
              ? 'Укажите посчитанную сумму наличных.'
              : 'Indica el efectivo contado.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await widget.api.closeCashbox({
        'date': DateFormat('yyyy-MM-dd').format(widget.date),
        'declared_cash_amount': _declaredCash.text.trim().replaceAll(',', '.'),
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, response);
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
  }
}

class _ClosureValue extends StatelessWidget {
  const _ClosureValue({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AnnaColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: emphasize ? AnnaColors.warning : AnnaColors.text,
                fontSize: 14,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashboxData {
  const _CashboxData({required this.cashbox, required this.bookings});

  final ApiDocument cashbox;
  final ApiCollection bookings;
}

class _CashSection extends StatelessWidget {
  const _CashSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PaidDocumentCard extends StatelessWidget {
  const _PaidDocumentCard({
    required this.api,
    required this.document,
    required this.onChanged,
  });

  final AnnaApi api;
  final ApiRecord document;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _open(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${document.valueAsText('number') ?? t.tr('Recibo')} · '
                    '${document.valueAsText('client_name') ?? t.tr('Cliente')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      document.valueAsText('service_name'),
                      '${document.valueAsText('total_amount') ?? '0.00'} EUR',
                    ].whereType<String>().join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: t.isRussian ? 'Напечатать' : 'Imprimir',
            onPressed: () =>
                _DocumentPrintJobSheet.show(context, document.data),
            icon: Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: t.isRussian ? 'Открыть' : 'Abrir',
            onPressed: () => _open(context),
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    return _CashDocumentSheet.show(
      context,
      api: api,
      documentId: document.valueAsText('id')!,
      onChanged: onChanged,
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.api,
    required this.payment,
    required this.onChanged,
  });

  final AnnaApi api;
  final ApiRecord payment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openDocument(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.valueAsText('entry_type_label') ?? ''} · ${payment.valueAsText('method_label') ?? ''}',
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      payment.valueAsText('paid_at'),
                      payment.valueAsText('amount'),
                      payment.valueAsText('reference'),
                    ]
                        .whereType<String>()
                        .where((v) => v.isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AnnaColors.muted,
                        ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).isRussian
                ? 'Изменить способ оплаты'
                : 'Cambiar metodo',
            onPressed: () => _edit(context),
            icon: Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip:
                AppLocalizations.of(context).isRussian ? 'Открыть' : 'Abrir',
            onPressed: () => _openDocument(context),
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(BuildContext context) {
    return _CashDocumentSheet.show(
      context,
      api: api,
      documentId: payment.valueAsText('fiscal_document')!,
      onChanged: onChanged,
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await _PaymentMethodEditSheet.show(
      context,
      api: api,
      payment: payment,
    );
    if (updated != null) onChanged();
  }
}

class _PendingDocumentCard extends StatelessWidget {
  const _PendingDocumentCard({
    required this.api,
    required this.document,
    required this.onChanged,
  });

  final AnnaApi api;
  final ApiRecord document;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${document.valueAsText('document_type_label') ?? t.tr('Recibo')} ${document.valueAsText('number') ?? ''}',
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            [
              document.valueAsText('client_name'),
              document.valueAsText('service_name'),
              '${t.tr('Saldo pendiente')}: ${document.valueAsText('balance_due') ?? '0.00'} EUR',
            ].whereType<String>().join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AnnaColors.muted,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in const ['cash', 'card', 'bizum', 'transfer'])
                OutlinedButton(
                  onPressed: () => _registerPayment(context, method),
                  child: Text(_methodLabel(context, method)),
                ),
              FilledButton.tonal(
                onPressed: () => _openDocument(context),
                child: Text(t.tr('Abrir documento')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _registerPayment(BuildContext context, String method) async {
    final due = document.valueAsText('balance_due') ?? '0.00';
    try {
      final response =
          await api.addCashDocumentPayment(document.valueAsText('id')!, {
        'entry_type': 'payment',
        'amount': due,
        'method': method,
      });
      if (!context.mounted) return;
      onChanged();
      final updatedDocument = ApiRecord(response.data);
      if (_isPaid(updatedDocument)) {
        await _showShareSheet(context, api: api, document: updatedDocument);
      }
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    await _CashDocumentSheet.show(
      context,
      api: api,
      documentId: document.valueAsText('id')!,
      onChanged: onChanged,
    );
  }
}

class _BookingDueCard extends StatelessWidget {
  const _BookingDueCard({
    required this.api,
    required this.booking,
    required this.onChanged,
  });

  final AnnaApi api;
  final ApiRecord booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return PanelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.valueAsText('client_name') ?? t.tr('Cliente'),
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            [
              booking.valueAsText('start_at'),
              booking.valueAsText('service_name'),
              '${t.tr('Saldo pendiente')}: ${booking.valueAsText('amount_due') ?? '0.00'} EUR',
            ].whereType<String>().join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AnnaColors.muted,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _createDocument(context, 'receipt'),
                child: Text(t.tr('Crear recibo')),
              ),
              FilledButton.tonal(
                onPressed: () => _createDocument(context, 'invoice'),
                child: Text(t.tr('Crear factura')),
              ),
              for (final method in const ['cash', 'card', 'bizum', 'transfer'])
                OutlinedButton(
                  onPressed: () => _quickPay(context, method),
                  child: Text(_methodLabel(context, method)),
                ),
              OutlinedButton(
                onPressed: () => _stripe(context),
                child: const Text('Stripe'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createDocument(BuildContext context, String type) async {
    try {
      final response = await api.createCashDocument(
        booking.valueAsText('id')!,
        {'document_type': type},
      );
      if (!context.mounted) return;
      await _CashDocumentSheet.show(
        context,
        api: api,
        documentId: response.data['id'].toString(),
        onChanged: onChanged,
      );
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _quickPay(BuildContext context, String method) async {
    try {
      final response = await api.quickBookingPayment(
        booking.valueAsText('id')!,
        {'method': method},
      );
      if (!context.mounted) return;
      onChanged();
      final document = ApiRecord(response.data);
      if (_isPaid(document)) {
        await _showShareSheet(context, api: api, document: document);
      }
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _stripe(BuildContext context) async {
    try {
      final response =
          await api.bookingStripeCheckout(booking.valueAsText('id')!);
      final url = response.data['checkout_url']?.toString();
      if (url == null || url.isEmpty) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }
}

class _CashDocumentSheet extends StatefulWidget {
  const _CashDocumentSheet({
    required this.api,
    required this.documentId,
    required this.onChanged,
  });

  final AnnaApi api;
  final String documentId;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required AnnaApi api,
    required String documentId,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _CashDocumentSheet(
        api: api,
        documentId: documentId,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_CashDocumentSheet> createState() => _CashDocumentSheetState();
}

class _CashDocumentSheetState extends State<_CashDocumentSheet> {
  late Future<ApiDocument> _future =
      widget.api.cashDocumentDetail(widget.documentId);

  void _reload() {
    setState(() => _future = widget.api.cashDocumentDetail(widget.documentId));
    widget.onChanged();
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final data = snapshot.data!.data;
          final document = ApiRecord(data);
          final lines = ApiCollection.fromJson(data['lines']).items;
          final payments = ApiCollection.fromJson(data['payments']).items;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['number']?.toString() ?? t.tr('Recibo'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DocumentAmountSummary(document: document),
                if (!_isPaid(document)) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.tr(
                      'Puedes registrar varios pagos hasta completar el saldo pendiente.',
                    ),
                    style: TextStyle(color: AnnaColors.muted),
                  ),
                ],
                if (_isPaid(document)) ...[
                  const SizedBox(height: 8),
                  AnnaBadge(t.tr('Documento cobrado completo.')),
                ],
                if (_isPaid(document)) ...[
                  const SizedBox(height: 12),
                  _DocumentPrintButton(document: data),
                  const SizedBox(height: 10),
                  _DocumentShareActions(
                    api: widget.api,
                    document: document,
                  ),
                ],
                const SizedBox(height: 14),
                Text(t.tr('Concepto e importe'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final line in lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.valueAsText('description') ?? ''),
                    subtitle: Text(
                      '${line.valueAsText('quantity') ?? '1'} x ${line.valueAsText('unit_amount') ?? '0.00'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${line.valueAsText('total_amount') ?? '0.00'} EUR',
                        ),
                        IconButton(
                          tooltip:
                              t.isRussian ? 'Изменить цену' : 'Editar precio',
                          onPressed: () => _editLinePrice(context, line),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (lines.length > 1)
                          IconButton(
                            tooltip: t.isRussian
                                ? 'Удалить услугу'
                                : 'Eliminar servicio',
                            onPressed: () => _deleteLine(context, line),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddLine(context),
                      icon: Icon(Icons.add),
                      label: Text(t.tr('Anadir linea')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPayment(
                        context,
                        false,
                        initialAmount: document.valueAsText('balance_due'),
                        balanceDue: document.valueAsText('balance_due'),
                        paidAmount: document.valueAsText('payments_total'),
                        totalAmount: document.valueAsText('total_amount'),
                      ),
                      icon: Icon(Icons.payments_outlined),
                      label: Text(t.tr('Registrar pago')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPayment(
                        context,
                        true,
                        paidAmount: document.valueAsText('payments_total'),
                        totalAmount: document.valueAsText('total_amount'),
                      ),
                      icon: Icon(Icons.reply_outlined),
                      label: Text(t.tr('Devolucion')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(t.tr('Pagos del dia'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Text(t.tr('Sin pagos todavia.'),
                      style: TextStyle(color: AnnaColors.muted))
                else
                  for (final payment in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${payment.valueAsText('entry_type_label') ?? ''} · ${payment.valueAsText('method_label') ?? ''}',
                      ),
                      subtitle: Text(payment.valueAsText('paid_at') ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${payment.valueAsText('signed_amount') ?? '0.00'} EUR',
                          ),
                          IconButton(
                            tooltip: t.isRussian
                                ? 'Изменить способ оплаты'
                                : 'Cambiar metodo',
                            onPressed: () => _editPayment(context, payment),
                            icon: Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editLinePrice(
    BuildContext context,
    ApiRecord line,
  ) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: line.valueAsText('unit_amount') ?? '',
    );
    final amount = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.isRussian ? 'Изменить цену' : 'Editar precio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: t.isRussian ? 'Цена услуги' : 'Precio del servicio',
            suffixText: 'EUR',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.isRussian ? 'Отмена' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: Text(t.isRussian ? 'Сохранить' : 'Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount.isEmpty || !context.mounted) return;
    try {
      final response = await widget.api.updateCashDocumentLine(
        line.valueAsText('id')!,
        {'unit_amount': amount.replaceAll(',', '.')},
      );
      if (!mounted) return;
      setState(() => _future = Future.value(response));
      widget.onChanged();
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _deleteLine(BuildContext context, ApiRecord line) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title:
                Text(t.isRussian ? 'Удалить услугу?' : '¿Eliminar servicio?'),
            content: Text(line.valueAsText('description') ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t.isRussian ? 'Отмена' : 'Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(t.isRussian ? 'Удалить' : 'Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      final response = await widget.api.deleteCashDocumentLine(
        line.valueAsText('id')!,
      );
      if (!mounted) return;
      setState(() => _future = Future.value(response));
      widget.onChanged();
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _showAddLine(BuildContext context) async {
    final response = await _CashLineFormSheet.show(
      context,
      api: widget.api,
      documentId: widget.documentId,
      onChanged: _reload,
    );
    if (response == null || !context.mounted) return;
    setState(() => _future = Future.value(response));
    widget.onChanged();
  }

  Future<void> _showPayment(
    BuildContext context,
    bool refund, {
    String? initialAmount,
    String? initialMethod,
    String? balanceDue,
    String? paidAmount,
    String? totalAmount,
  }) async {
    final response = await _CashPaymentFormSheet.show(
      context,
      api: widget.api,
      documentId: widget.documentId,
      initialAmount: refund ? null : initialAmount,
      initialMethod: initialMethod,
      balanceDue: balanceDue,
      paidAmount: paidAmount,
      totalAmount: totalAmount,
      refund: refund,
      onChanged: _reload,
    );
    if (response == null || !context.mounted) return;
    setState(() => _future = Future.value(response));
    widget.onChanged();
    final document = ApiRecord(response.data);
    if (_isPaid(document) && !refund) {
      await _showShareSheet(context, api: widget.api, document: document);
    }
  }

  Future<void> _editPayment(
    BuildContext context,
    ApiRecord payment,
  ) async {
    final response = await _PaymentMethodEditSheet.show(
      context,
      api: widget.api,
      payment: payment,
    );
    if (response == null || !context.mounted) return;
    setState(() => _future = Future.value(response));
    widget.onChanged();
  }
}

class _DocumentAmountSummary extends StatelessWidget {
  const _DocumentAmountSummary({required this.document});

  final ApiRecord document;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final balance = _money(document.valueAsText('balance_due'));
    final paid = _money(document.valueAsText('payments_total'));
    final total = _money(document.valueAsText('total_amount'));
    final isPaid = balance <= 0;
    final balanceColor = isPaid ? AnnaColors.accent2 : AnnaColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: balanceColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AnnaRadii.md),
        border: Border.all(color: balanceColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.tr('Saldo pendiente'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMoney(balance)} EUR',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: balanceColor,
                  fontSize: 28,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnnaBadge('${t.tr('Precio')}: ${_formatMoney(total)} EUR'),
              AnnaBadge('${t.tr('Pagado')}: ${_formatMoney(paid)} EUR'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashLineFormSheet extends StatefulWidget {
  const _CashLineFormSheet({
    required this.api,
    required this.documentId,
    required this.onChanged,
  });

  final AnnaApi api;
  final String documentId;
  final VoidCallback onChanged;

  static Future<ApiDocument?> show(
    BuildContext context, {
    required AnnaApi api,
    required String documentId,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<ApiDocument>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _CashLineFormSheet(
        api: api,
        documentId: documentId,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_CashLineFormSheet> createState() => _CashLineFormSheetState();
}

class _CashLineFormSheetState extends State<_CashLineFormSheet> {
  late final Future<ApiCollection> _servicesFuture = widget.api.services();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  String _mode = 'custom';
  String? _serviceId;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: FutureBuilder<ApiCollection>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          final services = snapshot.data?.items ?? const <ApiRecord>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'custom',
                    label: Text(t.tr('Concepto manual')),
                    icon: Icon(Icons.edit_note_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'service',
                    label: Text(t.tr('Servicio extra')),
                    icon: Icon(Icons.spa_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 12),
              if (_mode == 'service')
                DropdownButtonFormField<String>(
                  initialValue: _serviceId,
                  decoration: InputDecoration(labelText: t.tr('Servicio')),
                  items: [
                    for (final service in services)
                      DropdownMenuItem(
                        value: service.valueAsText('id'),
                        child: Text(
                          service.valueAsText('name') ??
                              '${t.tr('Servicio')} ${service.valueAsText('id') ?? ''}',
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _serviceId = value),
                )
              else
                TextField(
                  controller: _description,
                  decoration: InputDecoration(labelText: t.tr('Concepto')),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: t.tr('Cantidad')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _mode == 'service'
                            ? t.tr('Precio unitario')
                            : t.tr('Importe manual'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(t.tr('Guardar')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'quantity': _quantity.text.trim().isEmpty ? '1' : _quantity.text.trim(),
      };
      if (_mode == 'service') {
        payload['service'] = _serviceId;
        if (_amount.text.trim().isNotEmpty) {
          payload['unit_amount'] = _amount.text.trim();
        }
      } else {
        payload['description'] = _description.text.trim();
        payload['manual_amount'] = _amount.text.trim();
      }
      final response = await widget.api.addCashDocumentLine(
        widget.documentId,
        payload,
      );
      if (!mounted) return;
      Navigator.pop(context, response);
      widget.onChanged();
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
  }
}

class _CashPaymentFormSheet extends StatefulWidget {
  const _CashPaymentFormSheet({
    required this.api,
    required this.documentId,
    this.initialAmount,
    this.initialMethod,
    this.balanceDue,
    this.paidAmount,
    this.totalAmount,
    required this.refund,
    required this.onChanged,
  });

  final AnnaApi api;
  final String documentId;
  final String? initialAmount;
  final String? initialMethod;
  final String? balanceDue;
  final String? paidAmount;
  final String? totalAmount;
  final bool refund;
  final VoidCallback onChanged;

  static Future<ApiDocument?> show(
    BuildContext context, {
    required AnnaApi api,
    required String documentId,
    String? initialAmount,
    String? initialMethod,
    String? balanceDue,
    String? paidAmount,
    String? totalAmount,
    required bool refund,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<ApiDocument>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _CashPaymentFormSheet(
        api: api,
        documentId: documentId,
        initialAmount: initialAmount,
        initialMethod: initialMethod,
        balanceDue: balanceDue,
        paidAmount: paidAmount,
        totalAmount: totalAmount,
        refund: refund,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_CashPaymentFormSheet> createState() => _CashPaymentFormSheetState();
}

class _CashPaymentFormSheetState extends State<_CashPaymentFormSheet> {
  late final _amount = TextEditingController(text: widget.initialAmount ?? '');
  late String _method = widget.initialMethod ?? 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final balance = _money(widget.balanceDue ?? widget.initialAmount);
    final paid = _money(widget.paidAmount);
    final total = _money(widget.totalAmount);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.refund ? t.tr('Devolucion') : t.tr('Registrar pago'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (!widget.refund) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AnnaColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AnnaRadii.md),
                border: Border.all(
                  color: AnnaColors.warning.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tr('Falta por pagar'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatMoney(balance)} EUR',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AnnaColors.warning,
                          fontSize: 28,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${t.tr('Total')}: ${_formatMoney(total)} EUR - ${t.tr('Pagado')}: ${_formatMoney(paid)} EUR',
                    style: TextStyle(color: AnnaColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.tr(
                'Puedes cobrar una parte ahora y el resto despues con otro metodo.',
              ),
              style: TextStyle(color: AnnaColors.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in const [
                  'cash',
                  'card',
                  'bizum',
                  'transfer',
                ])
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() => _method = method);
                            _save(amountOverride: _amount.text.trim());
                          },
                    child: Text(_methodLabel(context, method)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t.tr('Importe a registrar'),
              helperText: widget.refund
                  ? null
                  : t.tr('Por defecto se rellena con el saldo pendiente.'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(labelText: t.tr('Metodo')),
            items: [
              DropdownMenuItem(
                value: 'cash',
                child: Text(_methodLabel(context, 'cash')),
              ),
              DropdownMenuItem(
                value: 'card',
                child: Text(_methodLabel(context, 'card')),
              ),
              const DropdownMenuItem(value: 'bizum', child: Text('Bizum')),
              DropdownMenuItem(
                value: 'transfer',
                child: Text(_methodLabel(context, 'transfer')),
              ),
            ],
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                  widget.refund ? t.tr('Devolucion') : t.tr('Registrar pago')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save({String? amountOverride}) async {
    final amount = (amountOverride ?? _amount.text).trim();
    final fallbackAmount =
        (widget.balanceDue ?? widget.initialAmount ?? '').toString().trim();
    final finalAmount = amount.isEmpty ? fallbackAmount : amount;
    if (finalAmount.isEmpty || _money(finalAmount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).tr('Introduce importe.'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response =
          await widget.api.addCashDocumentPayment(widget.documentId, {
        'entry_type': widget.refund ? 'refund' : 'payment',
        'amount': finalAmount,
        'method': _method,
      });
      if (!mounted) return;
      Navigator.pop(context, response);
      widget.onChanged();
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
  }
}

class _PaymentMethodEditSheet extends StatefulWidget {
  const _PaymentMethodEditSheet({
    required this.api,
    required this.payment,
  });

  final AnnaApi api;
  final ApiRecord payment;

  static Future<ApiDocument?> show(
    BuildContext context, {
    required AnnaApi api,
    required ApiRecord payment,
  }) {
    return showModalBottomSheet<ApiDocument>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _PaymentMethodEditSheet(
        api: api,
        payment: payment,
      ),
    );
  }

  @override
  State<_PaymentMethodEditSheet> createState() =>
      _PaymentMethodEditSheetState();
}

class _PaymentMethodEditSheetState extends State<_PaymentMethodEditSheet> {
  late String _method = widget.payment.valueAsText('method') ?? 'cash';
  late final TextEditingController _reference = TextEditingController(
    text: widget.payment.valueAsText('reference') ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.payment.valueAsText('notes') ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.isRussian ? 'Способ оплаты' : 'Metodo de pago',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.payment.valueAsText('amount') ?? '0.00'} EUR',
            style: TextStyle(color: AnnaColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(
              labelText: t.isRussian ? 'Способ' : 'Metodo',
            ),
            items: [
              for (final method in const ['cash', 'card', 'bizum', 'transfer'])
                DropdownMenuItem(
                  value: method,
                  child: Text(_methodLabel(context, method)),
                ),
            ],
            onChanged: _saving ? null : (value) => _method = value ?? _method,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reference,
            decoration: InputDecoration(
              labelText: t.isRussian ? 'Ссылка или номер' : 'Referencia',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: t.isRussian ? 'Примечание' : 'Notas',
            ),
          ),
          const SizedBox(height: 16),
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
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final response = await widget.api.updateCashPayment(
        widget.payment.valueAsText('id')!,
        {
          'method': _method,
          'reference': _reference.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, response);
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
      setState(() => _saving = false);
    }
  }
}

class _DocumentShareActions extends StatefulWidget {
  const _DocumentShareActions({
    required this.api,
    required this.document,
  });

  final AnnaApi api;
  final ApiRecord document;

  @override
  State<_DocumentShareActions> createState() => _DocumentShareActionsState();
}

class _DocumentShareActionsState extends State<_DocumentShareActions> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.document.valueAsText('client_email') ?? '',
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.document.valueAsText('client_phone') ?? '',
  );
  late final bool _showEmailField =
      (widget.document.valueAsText('client_email') ?? '').trim().isEmpty;
  late final bool _showPhoneField =
      (widget.document.valueAsText('client_phone') ?? '').trim().isEmpty;
  String? _sending;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleContactChanged);
    _phoneController.addListener(_handleContactChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleContactChanged);
    _phoneController.removeListener(_handleContactChanged);
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleContactChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasEmail = _emailController.text.trim().isNotEmpty;
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final needsContact = !hasEmail && !hasPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          needsContact
              ? t.tr(
                  'Falta email o telefono de WhatsApp para enviar el documento.',
                )
              : t.tr('Elige como enviar el documento al cliente.'),
          style: TextStyle(color: AnnaColors.muted),
        ),
        const SizedBox(height: 10),
        if (_showEmailField) ...[
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: t.tr('Email')),
          ),
          const SizedBox(height: 10),
        ],
        if (_showPhoneField) ...[
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: t.tr('Telefono')),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _sending == null && hasEmail ? _sendEmail : null,
              icon: _sending == 'email'
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.mail_outline),
              label: Text(t.tr('Enviar por email')),
            ),
            OutlinedButton.icon(
              onPressed: _sending == null && hasPhone ? _sendWhatsApp : null,
              icon: _sending == 'whatsapp'
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sendEmail() async {
    final t = AppLocalizations.of(context);
    setState(() => _sending = 'email');
    try {
      await widget.api.shareCashDocument(
        widget.document.valueAsText('id')!,
        {
          'channel': 'email',
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Documento enviado por email.'))),
      );
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  Future<void> _sendWhatsApp() async {
    setState(() => _sending = 'whatsapp');
    try {
      final response = await widget.api.shareCashDocument(
        widget.document.valueAsText('id')!,
        {
          'channel': 'whatsapp',
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );
      final phone = response.data['phone']?.toString() ?? '';
      final message = response.data['message']?.toString() ?? '';
      if (!mounted) return;
      final url = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }
}

class _DocumentPrintButton extends StatelessWidget {
  const _DocumentPrintButton({required this.document});

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: () => _DocumentPrintJobSheet.show(context, document),
      icon: Icon(Icons.print_outlined),
      label: Text(t.isRussian ? 'Напечатать чек' : 'Imprimir recibo'),
    );
  }
}

class _DocumentPrintJobSheet extends StatefulWidget {
  const _DocumentPrintJobSheet({required this.document});

  final Map<String, dynamic> document;

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _DocumentPrintJobSheet(document: document),
    );
  }

  @override
  State<_DocumentPrintJobSheet> createState() => _DocumentPrintJobSheetState();
}

class _DocumentPrintJobSheetState extends State<_DocumentPrintJobSheet> {
  final List<String> _logs = [];
  bool _printing = true;
  bool _success = false;
  String _stage = 'Подготовка печати...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _print());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.isRussian ? 'Печать чека' : 'Imprimir recibo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _printing ? null : () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_printing)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _success ? Icons.check_circle_outline : Icons.error_outline,
                  color: _success ? AnnaColors.accent2 : AnnaColors.danger,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _stage,
                  style: TextStyle(fontSize: 14, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AnnaColors.line),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _logs.join('\n'),
                style: TextStyle(
                  color: AnnaColors.muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (!_printing) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _success
                  ? FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.isRussian ? 'Готово' : 'Listo'),
                    )
                  : FilledButton.icon(
                      onPressed: _retry,
                      icon: Icon(Icons.refresh),
                      label: Text(t.isRussian ? 'Повторить' : 'Reintentar'),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _print() async {
    _status('Проверяю сохранённый принтер...');
    try {
      await ThermalPrinterService.instance.printDocument(
        widget.document,
        onStatus: _status,
      );
      if (!mounted) return;
      setState(() {
        _printing = false;
        _success = true;
        _stage = AppLocalizations.of(context).isRussian
            ? 'Чек отправлен на принтер.'
            : 'Recibo enviado a la impresora.';
      });
      _log(_stage);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _printing = false;
        _success = false;
        _stage = error.toString();
      });
      _log('ОШИБКА: $error');
    }
  }

  void _retry() {
    setState(() {
      _printing = true;
      _success = false;
      _stage = 'Повторная попытка...';
    });
    _print();
  }

  void _status(String message) {
    if (!mounted) return;
    setState(() => _stage = message);
    _log(message);
  }

  void _log(String message) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    if (mounted) setState(() => _logs.add('[$time] $message'));
  }
}

Future<void> _showShareSheet(
  BuildContext context, {
  required AnnaApi api,
  required ApiRecord document,
}) {
  final t = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AnnaColors.bgSoft,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.tr('Enviar documento'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            document.valueAsText('number') ?? '',
            style: TextStyle(color: AnnaColors.muted),
          ),
          const SizedBox(height: 16),
          _DocumentPrintButton(document: document.data),
          const SizedBox(height: 10),
          _DocumentShareActions(api: api, document: document),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(t.isRussian ? 'Без чека' : 'Sin recibo'),
            ),
          ),
        ],
      ),
    ),
  );
}

bool _isPaid(ApiRecord document) {
  final value = document.data['is_paid'];
  if (value is bool) return value;
  return value?.toString() == 'true';
}

String _methodLabel(BuildContext context, String method) {
  final t = AppLocalizations.of(context);
  switch (method) {
    case 'cash':
      return t.tr('Efectivo');
    case 'card':
      return t.tr('Tarjeta');
    case 'bizum':
      return 'Bizum';
    case 'transfer':
      return t.tr('Transferencia');
    default:
      return method;
  }
}

double _money(String? value) {
  return double.tryParse((value ?? '0').replaceAll(',', '.')) ?? 0;
}

String _formatMoney(double value) {
  return value.toStringAsFixed(2);
}

double _decimal(String? value) {
  return double.tryParse((value ?? '0').replaceAll(',', '.')) ?? 0;
}
