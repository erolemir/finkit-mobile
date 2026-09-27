import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class PurchaseProcessingPage extends StatefulWidget {
  const PurchaseProcessingPage({
    super.key,
    required this.api,
    required this.invoice,
  });

  final FinkitApi api;
  final Map<String, dynamic> invoice;

  @override
  State<PurchaseProcessingPage> createState() => _PurchaseProcessingPageState();
}

class _PurchaseProcessingPageState extends State<PurchaseProcessingPage> {
  late Future<void> _loading;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _categories = [];
  final _action = <int, String>{};
  final _product = <int, int>{};
  final _warehouse = <int, int>{};
  int? _categoryId;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> get _remaining {
    final raw = widget.invoice['lines'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .where((line) => line['accounting_action'] == null)
        .toList();
  }

  int? _id(dynamic value) => int.tryParse('$value');

  @override
  void initState() {
    super.initState();
    for (final line in _remaining) {
      final id = _id(line['id']);
      if (id == null) continue;
      _action[id] = 'EXPENSE';
      final productId = _id(line['product_id']);
      if (productId != null) _product[id] = productId;
      final warehouseId = _id(line['warehouse_id']);
      if (warehouseId != null) _warehouse[id] = warehouseId;
    }
    _loading = _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.api.products(),
      widget.api.warehouses(),
      widget.api.expenseCategories(),
    ]);
    _products = results[0]
        .where(
          (item) =>
              item['product_type'] == 'PRODUCT' &&
              item['track_inventory'] == true &&
              item['is_active'] != false,
        )
        .toList();
    _warehouses = results[1]
        .where((item) => item['is_active'] != false)
        .toList();
    _categories = results[2]
        .where((item) => item['is_active'] != false)
        .toList();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final remaining = _remaining;
    if (remaining.isEmpty) return;
    final stock = <Map<String, dynamic>>[];
    final expense = <int>[];
    for (final line in remaining) {
      final id = _id(line['id']);
      if (id == null) {
        setState(() => _error = 'Fatura kalemi kimliği eksik.');
        return;
      }
      if (_action[id] == 'STOCK') {
        final selectedProduct = _product[id];
        if (selectedProduct == null) {
          setState(
            () => _error = '${line['description']} için stok ürünü seçin.',
          );
          return;
        }
        if (_warehouses.isEmpty || _warehouse[id] == null) {
          setState(() => _error = '${line['description']} için depo seçin.');
          return;
        }
        stock.add({
          'line_id': id,
          if (selectedProduct == -1) 'create_product': true,
          if (selectedProduct != -1) 'product_id': selectedProduct,
          'warehouse_id': _warehouse[id],
        });
      } else {
        expense.add(id);
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gelen Faturayı İşle'),
        content: Text(
          '${stock.length} kalem stoklaştırılacak, ${expense.length} kalem giderleştirilecek. Cari, stok ve gider kayıtları oluşabilir. Seçimleri kontrol ettiniz mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla ve İşle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final invoiceId = _id(widget.invoice['id'])!;
    try {
      if (stock.isNotEmpty) {
        await widget.api.stockifyPurchaseInvoice(invoiceId, stock);
      }
      if (expense.isNotEmpty) {
        await widget.api.expensifyPurchaseInvoice(
          invoiceId,
          expense,
          categoryId: _categoryId,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error =
              '$error. İşlenen kalemler kaydedilmiş olabilir; fatura detayını yenileyip kalan kalemleri kontrol edin.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fatura Kalemleri')),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: LoadingState());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _loading = _load()),
              child: Text('Tanımlar alınamadı: ${snapshot.error}'),
            ),
          );
        }
        final remaining = _remaining;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageTitle(
              title: 'Kalemleri İşle',
              subtitle: 'Her kalemi stoklaştırın veya giderleştirin.',
            ),
            if (remaining.isEmpty)
              const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'İşlenecek kalem yok',
                description: 'Bu faturanın bütün kalemleri işlenmiş.',
              ),
            for (final line in remaining) _lineCard(line),
            if (remaining.any((line) => _action[_id(line['id'])] == 'EXPENSE'))
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Gider kategorisi (isteğe bağlı)',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Satırın kategorisi'),
                  ),
                  for (final item in _categories)
                    if (_id(item['id']) case final int id)
                      DropdownMenuItem<int?>(
                        value: id,
                        child: Text('${item['name']}'),
                      ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || remaining.isEmpty ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_busy ? 'İşleniyor…' : 'Kalemleri İşle'),
            ),
          ],
        );
      },
    ),
  );

  Widget _lineCard(Map<String, dynamic> line) {
    final id = _id(line['id'])!;
    final stock = _action[id] == 'STOCK';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${line['description'] ?? 'Kalem $id'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Miktar: ${line['quantity'] ?? '—'} · Tutar: ${line['line_total'] ?? '—'}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Giderleştir'),
                  selected: !stock,
                  onSelected: (_) => setState(() => _action[id] = 'EXPENSE'),
                ),
                ChoiceChip(
                  label: const Text('Stoklaştır'),
                  selected: stock,
                  onSelected: (_) => setState(() => _action[id] = 'STOCK'),
                ),
              ],
            ),
            if (stock) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _product[id],
                decoration: const InputDecoration(labelText: 'Stok ürünü'),
                items: [
                  const DropdownMenuItem(
                    value: -1,
                    child: Text('Bu kalemden yeni ürün aç'),
                  ),
                  for (final item in _products)
                    if (_id(item['id']) case final int productId)
                      DropdownMenuItem(
                        value: productId,
                        child: Text('${item['name']}'),
                      ),
                ],
                onChanged: (value) =>
                    setState(() => _product[id] = value ?? -1),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _warehouse[id],
                decoration: const InputDecoration(labelText: 'Depo'),
                items: [
                  for (final item in _warehouses)
                    if (_id(item['id']) case final int warehouseId)
                      DropdownMenuItem(
                        value: warehouseId,
                        child: Text('${item['name']}'),
                      ),
                ],
                onChanged: (value) => setState(() {
                  if (value != null) _warehouse[id] = value;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
