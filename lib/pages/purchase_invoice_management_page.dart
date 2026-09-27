import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';
import 'entry_forms.dart';
import 'invoice_detail_page.dart';

class PurchaseInvoiceManagementPage extends StatefulWidget {
  const PurchaseInvoiceManagementPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });
  final FinkitApi api;
  final int refreshKey;

  @override
  State<PurchaseInvoiceManagementPage> createState() =>
      _PurchaseInvoiceManagementPageState();
}

class _PurchaseInvoiceManagementPageState
    extends State<PurchaseInvoiceManagementPage> {
  final _search = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _status = '';
  String _paymentStatus = '';
  int? _supplierId;
  int _page = 1;
  bool _syncing = false;
  late Future<Map<String, dynamic>> _future;
  late Future<List<Map<String, dynamic>>> _suppliers;

  @override
  void initState() {
    super.initState();
    _reload();
    _suppliers = widget.api.partners(type: 'SUPPLIER');
  }

  @override
  void didUpdateWidget(covariant PurchaseInvoiceManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.purchaseInvoicePage(
      page: _page,
      search: _search.text.trim(),
      status: _status,
      paymentStatus: _paymentStatus,
      supplierId: _supplierId,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
    );
  }

  void _filter() {
    bool valid(String text) {
      if (text.isEmpty) return true;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return false;
      final date = DateTime.tryParse(text);
      return date != null && date.toIso8601String().substring(0, 10) == text;
    }

    final start = _start.text.trim(), end = _end.text.trim();
    if (!valid(start) ||
        !valid(end) ||
        (start.isNotEmpty && end.isNotEmpty && start.compareTo(end) > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tarih aralığı girin.')),
      );
      return;
    }
    setState(() {
      _page = 1;
      _reload();
    });
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await widget.api.syncPurchaseInbox();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['inserted'] ?? 0} yeni fatura alındı, ${result['skipped'] ?? 0} kayıt atlandı.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _create() async {
    final created = await showPurchaseInvoiceForm(context, widget.api);
    if (created && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(
          title: 'Gelen Faturalar',
          subtitle: 'Tedarikçi faturalarını eşleştirip stoklaştırın veya giderleştirin.',
          trailing: IconButton.filled(
            tooltip: 'Yeni gelen fatura',
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _syncing ? null : _sync,
          icon: const Icon(Icons.sync),
          label: Text(
            _syncing ? 'Senkronize ediliyor…' : 'Gelen kutusunu senkronize et',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          decoration: const InputDecoration(labelText: 'Fatura numarası ara'),
          onSubmitted: (_) => _filter(),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Belge durumu'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'DRAFT', child: Text('Taslak')),
            DropdownMenuItem(
              value: 'NEEDS_MATCH',
              child: Text('Eşleşme bekliyor'),
            ),
            DropdownMenuItem(value: 'POSTED', child: Text('Kaydedildi')),
            DropdownMenuItem(value: 'CANCELLED', child: Text('İptal')),
          ],
          onChanged: (value) => setState(() {
            _status = value ?? '';
            _page = 1;
            _reload();
          }),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _paymentStatus,
          decoration: const InputDecoration(labelText: 'Ödeme durumu'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'UNPAID', child: Text('Ödenmedi')),
            DropdownMenuItem(value: 'PARTIAL', child: Text('Kısmi ödeme')),
            DropdownMenuItem(value: 'PAID', child: Text('Ödendi')),
            DropdownMenuItem(value: 'OVERDUE', child: Text('Gecikti')),
          ],
          onChanged: (value) => setState(() {
            _paymentStatus = value ?? '';
            _page = 1;
            _reload();
          }),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _suppliers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Tedarikçiler yüklenemedi: ${snapshot.error}');
            }
            return DropdownButtonFormField<int?>(
              initialValue: _supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tedarikçi'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tümü')),
                for (final supplier
                    in snapshot.data ?? <Map<String, dynamic>>[])
                  DropdownMenuItem<int?>(
                    value: (supplier['id'] as num).toInt(),
                    child: Text(
                      '${supplier['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _supplierId = value;
                _page = 1;
                _reload();
              }),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _start,
                decoration: const InputDecoration(
                  labelText: 'Başlangıç YYYY-AA-GG',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _end,
                decoration: const InputDecoration(
                  labelText: 'Bitiş YYYY-AA-GG',
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _filter,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Filtrele'),
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const LoadingState();
            }
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () => setState(_reload),
                child: Text('Faturalar yüklenemedi: ${snapshot.error}'),
              );
            }
            final items = (snapshot.data?['items'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            final total =
                int.tryParse('${snapshot.data?['total']}') ?? items.length;
            return Column(
              children: [
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Gelen fatura yok',
                    description: 'Bu filtreye uygun fatura bulunmuyor.',
                  ),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      document: item,
                      icon: Icons.receipt_long_outlined,
                      title:
                          item['number']?.toString() ?? 'Taslak Alış Faturası',
                      subtitle:
                          '${dateText(item['issue_date'])} · ${statusLabel(item['status']?.toString())}',
                      value: moneyText(item['gross_amount']),
                      valueSubtitle: statusLabel(
                        item['payment_status']?.toString(),
                      ),
                      status: item['status']?.toString(),
                      onTap: () async {
                        await openInvoiceDetail(
                          context,
                          widget.api,
                          item,
                          purchase: true,
                        );
                        if (mounted) setState(_reload);
                      },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(child: Text('$total kayıt · $_page. sayfa')),
                    IconButton(
                      tooltip: 'Önceki sayfa',
                      onPressed: _page <= 1
                          ? null
                          : () => setState(() {
                              _page--;
                              _reload();
                            }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Sonraki sayfa',
                      onPressed: _page * 25 >= total
                          ? null
                          : () => setState(() {
                              _page++;
                              _reload();
                            }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
