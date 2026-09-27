import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class ExchangeRatesSection extends StatefulWidget {
  const ExchangeRatesSection({super.key, required this.api});
  final FinkitApi api;

  @override
  State<ExchangeRatesSection> createState() => _ExchangeRatesSectionState();
}

class _ExchangeRatesSectionState extends State<ExchangeRatesSection> {
  late Future<List<Map<String, dynamic>>> _future;
  late DateTime _date;
  String _currency = 'USD';
  bool _fetching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _load();
  }

  void _load() {
    _future = widget.api.exchangeRates();
  }

  String get _dateText =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    setState(() {
      _fetching = true;
      _message = null;
    });
    try {
      final result = await widget.api.fetchTcmbRates(_dateText);
      if (!mounted) return;
      final items = result['items'] as List? ?? const [];
      setState(() {
        _message = '${items.length} TCMB kuru alındı.';
        _load();
      });
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(title: 'Döviz Kurları'),
      const Text('Belge ve ödemelerde TCMB satış kuru kullanılır.'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _chooseDate,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('Kur tarihi: $_dateText'),
      ),
      DropdownButtonFormField<String>(
        initialValue: _currency,
        decoration: const InputDecoration(labelText: 'Döviz'),
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('USD')),
          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
          DropdownMenuItem(value: 'GBP', child: Text('GBP')),
        ],
        onChanged: (value) => setState(() => _currency = value ?? _currency),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _fetching ? null : _fetch,
        icon: const Icon(Icons.sync),
        label: Text(_fetching ? 'TCMB bekleniyor…' : 'TCMB’den Getir'),
      ),
      if (_message != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(_load),
              child: Text(
                'Kurlar yüklenemedi: ${snapshot.error} · Tekrar dene',
              ),
            );
          }
          final rows = snapshot.data!
              .where((item) => '${item['currency']}' == _currency)
              .toList();
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.currency_exchange,
              title: 'Kur kaydı yok',
              description: 'TCMB’den kur getirin.',
            );
          }
          return Column(
            children: [
              for (final item in rows)
                DataRowCard(
                  icon: Icons.currency_exchange,
                  title: '${item['currency']} · ${item['rate_date']}',
                  subtitle: '${item['source'] ?? 'TCMB'}',
                  value: '${item['rate']}',
                ),
            ],
          );
        },
      ),
    ],
  );
}
