import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../models/api_record.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

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
      await api.addCashDocumentPayment(document.valueAsText('id')!, {
        'entry_type': 'payment',
        'amount': due,
        'method': method,
      });
      if (!context.mounted) return;
      onChanged();
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
      await api.quickBookingPayment(
        booking.valueAsText('id')!,
        {'method': method},
      );
      if (!context.mounted) return;
      onChanged();
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AnnaBadge('${t.tr('Precio')}: ${data['total_amount']} EUR'),
                    AnnaBadge(
                        '${t.tr('Saldo pendiente')}: ${data['balance_due']} EUR'),
                  ],
                ),
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
                      onPressed: () => _showPayment(context, false),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(t.tr('Registrar pago')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPayment(context, true),
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
    await _CashLineFormSheet.show(
      context,
      api: widget.api,
      documentId: widget.documentId,
      onChanged: _reload,
    );
  }

  Future<void> _showPayment(BuildContext context, bool refund) async {
    await _CashPaymentFormSheet.show(
      context,
      api: widget.api,
      documentId: widget.documentId,
      refund: refund,
      onChanged: _reload,
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
  final _description = TextEditingController();
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _description,
            decoration: InputDecoration(labelText: t.tr('Concepto')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t.tr('Importe manual')),
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
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.addCashDocumentLine(widget.documentId, {
        'description': _description.text.trim(),
        'manual_amount': _amount.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
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
    required this.refund,
    required this.onChanged,
  });

  final AnnaApi api;
  final String documentId;
  final bool refund;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required AnnaApi api,
    required String documentId,
    required bool refund,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AnnaColors.bgSoft,
      builder: (context) => _CashPaymentFormSheet(
        api: api,
        documentId: documentId,
        refund: refund,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<_CashPaymentFormSheet> createState() => _CashPaymentFormSheetState();
}

class _CashPaymentFormSheetState extends State<_CashPaymentFormSheet> {
  final _amount = TextEditingController();
  String _method = 'cash';
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
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t.tr('Importe')),
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.addCashDocumentPayment(widget.documentId, {
        'entry_type': widget.refund ? 'refund' : 'payment',
        'amount': _amount.text.trim(),
        'method': _method,
      });
      if (!mounted) return;
      Navigator.pop(context);
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

double _decimal(String? value) {
  return double.tryParse((value ?? '0').replaceAll(',', '.')) ?? 0;
}
