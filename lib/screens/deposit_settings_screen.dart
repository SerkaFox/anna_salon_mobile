import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'shared.dart';

class DepositSettingsScreen extends StatefulWidget {
  const DepositSettingsScreen({required this.api, super.key});

  final AnnaApi api;

  @override
  State<DepositSettingsScreen> createState() => _DepositSettingsScreenState();
}

class _DepositSettingsScreenState extends State<DepositSettingsScreen> {
  final _percent = TextEditingController();
  final _minimum = TextEditingController();
  String _rounding = 'up_to_euro';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _percent.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.depositSettings();
      if (!mounted) return;
      setState(() {
        _percent.text = result.data['percent']?.toString() ?? '10.00';
        _minimum.text = result.data['minimum_amount']?.toString() ?? '2.00';
        _rounding = result.data['rounding']?.toString() ?? 'up_to_euro';
        _error = null;
      });
    } on AnnaApiException catch (error) {
      if (mounted) setState(() => _error = formatApiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await widget.api.updateDepositSettings({
        'percent': _percent.text.trim().replaceAll(',', '.'),
        'minimum_amount': _minimum.text.trim().replaceAll(',', '.'),
        'rounding': _rounding,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.isRussian
              ? 'Настройки предоплаты сохранены.'
              : 'Ajustes de prepago guardados.'),
        ),
      );
      await _load();
    } on AnnaApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _exampleDeposit(double total) {
    final percent = double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0;
    final minimum = double.tryParse(_minimum.text.replaceAll(',', '.')) ?? 0;
    var amount = total * percent / 100;
    if (_rounding == 'up_to_euro') amount = amount.ceilToDouble();
    return math.min(total, math.max(amount, minimum));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: t.isRussian ? 'Настройки предоплаты' : 'Ajustes de prepago',
      titleTextStyle: TextStyle(
        color: AnnaColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  PanelCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AnnaColors.danger),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PanelCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.isRussian
                            ? 'Общее правило для всех услуг'
                            : 'Regla global para todos los servicios',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.isRussian
                            ? 'Предоплата считается от итоговой стоимости заказа после скидок.'
                            : 'El prepago se calcula sobre el precio final de la reserva.',
                        style: TextStyle(
                          color: AnnaColors.muted,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _percent,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: t.isRussian
                              ? 'Процент предоплаты'
                              : 'Porcentaje de prepago',
                          suffixText: '%',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _minimum,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: t.isRussian
                              ? 'Минимальная предоплата'
                              : 'Prepago mínimo',
                          suffixText: 'EUR',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _rounding,
                        decoration: InputDecoration(
                          labelText: t.isRussian ? 'Округление' : 'Redondeo',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'up_to_euro',
                            child: Text(t.isRussian
                                ? 'Вверх до целого евро'
                                : 'Hacia arriba al euro'),
                          ),
                          DropdownMenuItem(
                            value: 'none',
                            child: Text(t.isRussian
                                ? 'Без округления'
                                : 'Sin redondeo'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                  () => _rounding = value ?? 'up_to_euro',
                                ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.save_outlined),
                        label: Text(t.tr('Guardar')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PanelCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.isRussian ? 'Примеры' : 'Ejemplos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      for (final price in const [12.0, 21.0, 50.0, 99.0])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${price.toStringAsFixed(0)} EUR → ${_exampleDeposit(price).toStringAsFixed(2)} EUR',
                            style: TextStyle(
                              color: AnnaColors.text,
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
