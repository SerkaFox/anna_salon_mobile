import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late Future<_CashboxData> _future = _load();

  Future<_CashboxData> _load() async {
    final result = await Future.wait([
      widget.api.cashbox(date: _date),
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
            icon: const Icon(Icons.event_outlined),
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
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
          final payments = ApiCollection.fromJson(cash['payments']).items;
          final closure = cash['closure'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(cash['closure'])
              : null;
          final dateLabel = DateFormat('d MMM yyyy', localeCode).format(_date);

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
                        FilledButton.icon(
                          onPressed: () => _closeCashbox(context),
                          icon: const Icon(Icons.lock_outline),
                          label: Text(t.tr('Cerrar caja')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnnaBadge(
                          '${t.tr('Total del dia')}: ${cash['payments_total'] ?? '0.00'} EUR',
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
              PanelCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.percent_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.isRussian
                                ? 'Процент предоплаты'
                                : 'Porcentaje de prepago',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${cash['deposit_percent'] ?? '10'}%',
                            style: const TextStyle(
                              color: AnnaColors.muted,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.tr('Editar'),
                      onPressed: () => _editDepositPercent(
                        context,
                        cash['deposit_percent']?.toString() ?? '10',
                      ),
                      icon: const Icon(Icons.edit_outlined),
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
                        child: const SafeArea(
                          child: PrinterSettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print_outlined),
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
                              style: const TextStyle(
                                color: AnnaColors.muted,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
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
                            _PaymentCard(payment: payment),
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

  Future<void> _closeCashbox(BuildContext context) async {
    final t = AppLocalizations.of(context);
    try {
      await widget.api.closeCashbox({
        'date': DateFormat('yyyy-MM-dd').format(_date),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('Cierre guardado.'))),
      );
      _reload();
    } on AnnaApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    }
  }

  Future<void> _editDepositPercent(
    BuildContext context,
    String currentValue,
  ) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          t.isRussian ? 'Процент предоплаты' : 'Porcentaje de prepago',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: '%',
            hintText: '10',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(t.tr('Guardar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !context.mounted) return;
    try {
      await widget.api.updateDepositPercent(value);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isRussian
                ? 'Процент предоплаты сохранен.'
                : 'Porcentaje de prepago guardado.',
          ),
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final ApiRecord payment;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return PanelCard(
      padding: const EdgeInsets.all(14),
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
            ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AnnaColors.muted,
                ),
          ),
        ],
      ),
    );
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
                      icon: const Icon(Icons.close),
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
                    style: const TextStyle(color: AnnaColors.muted),
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
                    trailing: Text(
                        '${line.valueAsText('total_amount') ?? '0.00'} EUR'),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddLine(context),
                      icon: const Icon(Icons.add),
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
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(t.tr('Registrar pago')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPayment(
                        context,
                        true,
                        paidAmount: document.valueAsText('payments_total'),
                        totalAmount: document.valueAsText('total_amount'),
                      ),
                      icon: const Icon(Icons.reply_outlined),
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
                      style: const TextStyle(color: AnnaColors.muted))
                else
                  for (final payment in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${payment.valueAsText('entry_type_label') ?? ''} · ${payment.valueAsText('method_label') ?? ''}',
                      ),
                      subtitle: Text(payment.valueAsText('paid_at') ?? ''),
                      trailing: Text(
                          '${payment.valueAsText('signed_amount') ?? '0.00'} EUR'),
                    ),
              ],
            ),
          );
        },
      ),
    );
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
                    icon: const Icon(Icons.edit_note_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'service',
                    label: Text(t.tr('Servicio extra')),
                    icon: const Icon(Icons.spa_outlined),
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
                    style: const TextStyle(color: AnnaColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.tr(
                'Puedes cobrar una parte ahora y el resto despues con otro metodo.',
              ),
              style: const TextStyle(color: AnnaColors.muted),
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
          style: const TextStyle(color: AnnaColors.muted),
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
                  : const Icon(Icons.mail_outline),
              label: Text(t.tr('Enviar por email')),
            ),
            OutlinedButton.icon(
              onPressed: _sending == null && hasPhone ? _sendWhatsApp : null,
              icon: _sending == 'whatsapp'
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_outlined),
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

class _DocumentPrintButton extends StatefulWidget {
  const _DocumentPrintButton({required this.document});

  final Map<String, dynamic> document;

  @override
  State<_DocumentPrintButton> createState() => _DocumentPrintButtonState();
}

class _DocumentPrintButtonState extends State<_DocumentPrintButton> {
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: _printing ? null : _print,
      icon: _printing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
      label: Text(t.isRussian ? 'Напечатать чек' : 'Imprimir recibo'),
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await ThermalPrinterService.instance.printDocument(widget.document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).isRussian
              ? 'Чек отправлен на принтер.'
              : 'Recibo enviado a la impresora.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
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
            style: const TextStyle(color: AnnaColors.muted),
          ),
          const SizedBox(height: 16),
          _DocumentPrintButton(document: document.data),
          const SizedBox(height: 10),
          _DocumentShareActions(api: api, document: document),
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
