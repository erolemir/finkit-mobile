import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class VatCalculationPage extends StatefulWidget {
  const VatCalculationPage({super.key, required this.api});

  final FinkitApi api;

  @override
  State<VatCalculationPage> createState() => _VatCalculationPageState();
}

class _VatCalculationPageState extends State<VatCalculationPage> {
  String _preset = 'month';
  late DateTime _start;
  late DateTime _end;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _selectPreset('month');
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _selectPreset(String preset) {
    final today = DateTime.now();
    _preset = preset;
    _end = DateTime(today.year, today.month, today.day);
    _start = switch (preset) {
      'previous' => DateTime(today.year, today.month - 1),
      'quarter' => DateTime(today.year, ((today.month - 1) ~/ 3) * 3 + 1),
      'year' => DateTime(today.year),
      _ => DateTime(today.year, today.month),
    };
    if (preset == 'previous') _end = DateTime(today.year, today.month, 0);
    _load();
  }

  void _load() {
    _future = widget.api.vatCalculation(
      startDate: _date(_start),
      endDate: _date(_end),
    );
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final nextStart = start ? selected : _start;
    final nextEnd = start ? _end : selected;
    if (nextStart.isAfter(nextEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlangıç bitişten sonra olamaz.')),
      );
      return;
    }
    setState(() {
      _preset = 'custom';
      _start = nextStart;
      _end = nextEnd;
      _load();
    });
  }

  Widget _amount(String title, Object? value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            moneyText(value),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('KDV Hesaplama')),
    body: RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageTitle(
            title: 'KDV Hesaplama',
            subtitle:
                'Gelen, ön muhasebe ve e-belge faturalarını birlikte izleyin.',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(_preset),
            initialValue: _preset,
            decoration: const InputDecoration(labelText: 'Dönem'),
            items: const [
              DropdownMenuItem(value: 'month', child: Text('Bu ay')),
              DropdownMenuItem(value: 'previous', child: Text('Geçen ay')),
              DropdownMenuItem(value: 'quarter', child: Text('Bu çeyrek')),
              DropdownMenuItem(value: 'year', child: Text('Bu yıl')),
              DropdownMenuItem(value: 'custom', child: Text('Özel tarih')),
            ],
            onChanged: (value) {
              if (value == null || value == 'custom') return;
              setState(() => _selectPreset(value));
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _pickDate(true),
                child: Text('Başlangıç: ${_date(_start)}'),
              ),
              TextButton(
                onPressed: () => _pickDate(false),
                child: Text('Bitiş: ${_date(_end)}'),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingState();
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_load),
                  child: Text(
                    'KDV bilgisi alınamadı: ${snapshot.error} · Tekrar dene',
                  ),
                );
              }
              final data = snapshot.data!;
              final incoming = (data['incoming_by_rate'] as List? ?? const []);
              final outgoing = (data['outgoing_by_rate'] as List? ?? const []);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data['einvoice_sync_warning'] != null)
                    Card(
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${data['einvoice_sync_warning']}'),
                      ),
                    ),
                  _amount('Gelen fatura KDV', data['incoming_vat']),
                  _amount('Giden faturadan KDV', data['outgoing_vat']),
                  _amount('Tahmini KDV borcu', data['payable_vat']),
                  _amount('Devreden KDV alacağı', data['carried_vat']),
                  const SectionHeader(title: 'KDV türü / oran kırılımı'),
                  for (final raw in incoming)
                    if (raw is Map)
                      ListTile(
                        title: const Text('Gelen fatura KDV'),
                        subtitle: Text('%${raw['rate']}'),
                        trailing: Text(moneyText(raw['vat'])),
                      ),
                  for (final raw in outgoing)
                    if (raw is Map)
                      ListTile(
                        title: const Text('Ön muhasebe satış faturası'),
                        subtitle: Text('%${raw['rate']}'),
                        trailing: Text(moneyText(raw['vat'])),
                      ),
                  if ((int.tryParse('${data['einvoice_outgoing_count']}') ??
                          0) >
                      0)
                    ListTile(
                      title: Text(
                        'E-Fatura / E-Arşiv (${data['einvoice_outgoing_count']})',
                      ),
                      trailing: Text(moneyText(data['einvoice_outgoing_vat'])),
                    ),
                  if (incoming.isEmpty &&
                      outgoing.isEmpty &&
                      (int.tryParse('${data['einvoice_outgoing_count']}') ??
                              0) ==
                          0)
                    const EmptyState(
                      icon: Icons.percent_rounded,
                      title: 'KDV kaydı yok',
                      description: 'Seçilen dönemde fatura KDV’si bulunamadı.',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
