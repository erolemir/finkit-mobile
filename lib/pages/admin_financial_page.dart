import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminFinancialPage extends StatefulWidget {
  const AdminFinancialPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminFinancialPage> createState() => _AdminFinancialPageState();
}

class _AdminFinancialPageState extends State<AdminFinancialPage> {
  late Future<List<Map<String, dynamic>>> _data;
  int _tab = 0;
  int _page = 1;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = Future.wait([
      widget.api.adminGet('/admin/financial/summary'),
      widget.api.adminGet('/admin/financial/subscriptions'),
      widget.api.adminGet('/admin/financial/service-fees'),
    ]);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> body) =>
      (body['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  Future<void> _export(List<Map<String, dynamic>> rows) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final output = StringBuffer('\uFEFF');
      if (_tab == 0) {
        output.writeln('Ad Soyad,E-posta,Abonelik Durumu,Abonelik Bitiş');
        for (final row in rows) {
          output.writeln(
            [
              row['full_name'],
              row['email'],
              row['is_active'] == true ? 'Aktif' : 'Pasif',
              row['subscription_end_date'],
            ].map(_csvCell).join(','),
          );
        }
      } else {
        output.writeln('Müşavir,Ofis,Mükellef Sayısı');
        for (final row in rows) {
          output.writeln(
            [
              row['advisor_name'],
              row['office_name'],
              (row['clients'] as List? ?? const []).length,
            ].map(_csvCell).join(','),
          );
        }
      }
      final path = await FilePicker.saveFile(
        fileName: _tab == 0
            ? 'finans-abonelikler.csv'
            : 'finans-hizmet-ucretleri.csv',
        bytes: Uint8List.fromList(utf8.encode(output.toString())),
        mimeType: 'text/csv',
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('CSV kaydedildi.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('CSV kaydedilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvCell(Object? value) {
    final text = (value ?? '').toString();
    final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(text) ? "'$text" : text;
    return '"${safe.replaceAll('"', '""')}"';
  }

  void _showFees(Map<String, dynamic> advisor) {
    final clients = (advisor['clients'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${advisor['advisor_name'] ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final client in clients)
              Card(
                child: ListTile(
                  title: Text('${client['full_name'] ?? ''}'),
                  subtitle: Text(
                    '${client['payment_status'] ?? '—'} · ${client['last_payment_date'] ?? 'Son ödeme yok'}',
                  ),
                  trailing: Text(moneyText(client['monthly_fee'])),
                ),
              ),
            if (clients.isEmpty) const Text('Bağlı mükellef bulunamadı.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _data,
    builder: (context, snapshot) {
      final summary = snapshot.data?.first;
      final subscriptions = snapshot.hasData
          ? _items(snapshot.data![1])
          : <Map<String, dynamic>>[];
      final fees = snapshot.hasData
          ? _items(snapshot.data![2])
          : <Map<String, dynamic>>[];
      final rows = _tab == 0 ? subscriptions : fees;
      final visible = rows.skip((_page - 1) * 20).take(20).toList();
      final subscriptionRevenue =
          num.tryParse('${summary?['total_subscription_revenue']}') ?? 0;
      final serviceRevenue =
          num.tryParse('${summary?['total_service_fee_revenue']}') ?? 0;
      final monthly = (summary?['monthly_breakdown'] as List? ?? const [])
          .whereType<Map>();
      return RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await _data;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageTitle(
              title: 'Finansal Yönetim',
              subtitle: 'Gelir ve ödeme durumu',
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text(
                  'Finans verileri alınamadı: ${snapshot.error} · Tekrar dene',
                ),
              )
            else ...[
              for (final metric in [
                ('Toplam Gelir', subscriptionRevenue + serviceRevenue),
                ('Abonelik Geliri', subscriptionRevenue),
                ('Hizmet Ücreti', serviceRevenue),
              ])
                Card(
                  child: ListTile(
                    title: Text(metric.$1),
                    trailing: Text(moneyText(metric.$2)),
                  ),
                ),
              const SizedBox(height: 10),
              ExpansionTile(
                title: const Text('Aylık karşılaştırma'),
                children: [
                  for (final month in monthly)
                    ListTile(
                      title: Text('${month['month'] ?? ''}'),
                      subtitle: Text(
                        'Abonelik ${moneyText(month['subscription_revenue'])}',
                      ),
                      trailing: Text(moneyText(month['service_fee_revenue'])),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Abonelikler')),
                  ButtonSegment(value: 1, label: Text('Hizmet ücretleri')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() {
                  _tab = value.first;
                  _page = 1;
                }),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _exporting ? null : () => _export(rows),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('CSV indir'),
                ),
              ),
              if (rows.isEmpty)
                const EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'Kayıt bulunamadı',
                  description: 'Finansal kayıtlar burada görünecek.',
                ),
              for (final row in visible)
                Card(
                  child: ListTile(
                    title: Text(
                      '${_tab == 0 ? row['full_name'] : row['advisor_name'] ?? '—'}',
                    ),
                    subtitle: Text(
                      _tab == 0
                          ? '${row['email'] ?? ''} · ${row['is_active'] == true ? 'Aktif' : 'Pasif'} · ${row['subscription_end_date'] ?? 'Bitiş yok'}'
                          : '${row['office_name'] ?? ''} · ${(row['clients'] as List? ?? const []).length} mükellef',
                    ),
                    trailing: _tab == 1
                        ? const Icon(Icons.chevron_right_rounded)
                        : null,
                    onTap: _tab == 1 ? () => _showFees(row) : null,
                  ),
                ),
              if (rows.length > 20)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${rows.length} kayıt · $_page. sayfa'),
                    IconButton(
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      onPressed: _page * 20 < rows.length
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
            ],
          ],
        ),
      );
    },
  );
}
