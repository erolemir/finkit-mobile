import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';
import 'entry_forms.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.api,
    required this.productId,
    this.onChanged,
  });

  final FinkitApi api;
  final int productId;
  final VoidCallback? onChanged;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _tab = 'movements';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Future.wait([
      widget.api.product(widget.productId),
      widget.api.productStockDetail(widget.productId),
    ]);
  }

  Future<void> _edit(Map<String, dynamic> product) async {
    final updated = await showProductForm(
      context,
      widget.api,
      product: product,
    );
    if (updated && mounted) {
      widget.onChanged?.call();
      setState(_load);
    }
  }

  Future<void> _delete(Map<String, dynamic> product) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ürünü sil'),
        content: Text(
          '${product['name']} kartı listeden kaldırılacak. Geçmiş stok ve fatura kayıtları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await widget.api.deleteProduct(widget.productId);
      widget.onChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ürün silinemedi: $error')));
      }
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> detail, String key) =>
      (detail[key] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ürün / Hizmet Detayı')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: Text('Ürün yüklenemedi: ${snapshot.error} · Tekrar dene'),
            ),
          );
        }
        final product = snapshot.data![0];
        final detail = snapshot.data![1];
        final rows = _rows(detail, _tab);
        final salesPrice = double.tryParse('${product['sales_price']}') ?? 0;
        final vat = double.tryParse('${product['vat_rate']}') ?? 0;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_load);
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageTitle(
                title: '${product['name'] ?? 'Ürün'}',
                subtitle:
                    '${product['code'] ?? ''} · ${product['is_active'] == false ? 'Pasif' : 'Aktif'}',
              ),
              if ('${product['description'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${product['description']}'),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _edit(product),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Düzenle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _delete(product),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Sil'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DataRowCard(
                icon: Icons.sell_outlined,
                title: 'Satış fiyatı · KDV hariç',
                value: moneyText(salesPrice),
                subtitle:
                    'KDV dâhil ${moneyText(salesPrice * (1 + vat / 100))}',
              ),
              DataRowCard(
                icon: Icons.shopping_cart_outlined,
                title: 'Alış fiyatı',
                value: moneyText(product['purchase_price']),
                subtitle: 'Güncel maliyet ${moneyText(product['manual_cost'])}',
              ),
              DataRowCard(
                icon: Icons.inventory_outlined,
                title: 'Stok',
                value:
                    '${detail['current_quantity'] ?? 0} ${product['unit'] ?? 'ADET'}',
                subtitle:
                    'Minimum ${product['minimum_stock'] ?? 0} · KDV %${product['vat_rate'] ?? 0}',
              ),
              const SizedBox(height: 12),
              SectionHeader(title: 'Depo bakiyeleri'),
              for (final balance in _rows(detail, 'balances'))
                DataRowCard(
                  icon: Icons.warehouse_outlined,
                  title: '${balance['warehouse_name'] ?? 'Depo'}',
                  subtitle: 'Değer ${moneyText(balance['value'])}',
                  value:
                      '${balance['quantity'] ?? 0} ${product['unit'] ?? 'ADET'}',
                ),
              if (_rows(detail, 'balances').isEmpty)
                const Text('Depo bakiyesi yok.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final tab in const [
                    ('movements', 'Stok geçmişi'),
                    ('sales', 'Satışlar'),
                    ('purchases', 'Alışlar'),
                  ])
                    ChoiceChip(
                      label: Text(
                        '${tab.$2} (${_rows(detail, tab.$1).length})',
                      ),
                      selected: _tab == tab.$1,
                      onSelected: (_) => setState(() => _tab = tab.$1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty) const Text('Bu bölümde kayıt yok.'),
              for (final row in rows)
                DataRowCard(
                  icon: _tab == 'movements'
                      ? Icons.swap_vert_outlined
                      : Icons.receipt_long_outlined,
                  title: _tab == 'movements'
                      ? '${row['description'] ?? row['source_type'] ?? 'Stok hareketi'}'
                      : '${row['number'] ?? '#${row['invoice_id']}'}',
                  subtitle: _tab == 'movements'
                      ? '${row['movement_date'] ?? ''} · ${row['warehouse_name'] ?? ''}'
                      : '${row['issue_date'] ?? ''} · ${row['partner_name'] ?? ''} · ${row['status'] ?? ''}',
                  value: _tab == 'movements'
                      ? '${row['signed_quantity'] ?? 0} ${product['unit'] ?? 'ADET'}'
                      : '${row['quantity'] ?? 0} ${product['unit'] ?? 'ADET'}',
                  valueSubtitle: _tab == 'movements'
                      ? moneyText(row['total_cost'])
                      : moneyText(row['line_total']),
                ),
            ],
          ),
        );
      },
    ),
  );
}
