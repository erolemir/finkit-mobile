import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'data_pages.dart' show SalesPage, SummaryGrid, SummaryItem;
import 'entry_forms.dart';
import 'product_detail_page.dart';
import 'collection_management_page.dart';
import 'supplier_payment_management_page.dart';
import 'quote_form_page.dart';
import 'purchase_invoice_management_page.dart';

/// Liste + arama + isteğe bağlı "yeni kayıt" düğmesi olan ortak sayfa.
/// Kayıt oluşturulduğunda liste kendini yeniler.
class AccountingListPage extends StatefulWidget {
  const AccountingListPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    required this.itemBuilder,
    this.refreshKey = 0,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Kayıt bulunamadı',
    this.emptyDescription = 'Bu bölümde gösterilecek kayıt yok.',
    this.onCreate,
    this.createIcon = Icons.add_rounded,
    this.searchHint,
    this.searchText,
    this.summaryBuilder,
  });

  final String title;
  final String subtitle;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
  itemBuilder;
  final int refreshKey;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;
  final Future<bool> Function(BuildContext context)? onCreate;
  final IconData createIcon;
  final String? searchHint;
  final String Function(Map<String, dynamic> item)? searchText;
  final Widget Function(List<Map<String, dynamic>> items)? summaryBuilder;

  @override
  State<AccountingListPage> createState() => _AccountingListPageState();
}

class _AccountingListPageState extends State<AccountingListPage> {
  int _localRefresh = 0;
  bool _creating = false;

  Future<void> _create() async {
    if (_creating || widget.onCreate == null) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreate!(context);
      if (created && mounted) setState(() => _localRefresh++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            action: SnackBarAction(label: 'Tekrar Dene', onPressed: _create),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApiListPage(
      title: widget.title,
      subtitle: widget.subtitle,
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.loader,
      itemBuilder: widget.itemBuilder,
      emptyIcon: widget.emptyIcon,
      emptyTitle: widget.emptyTitle,
      emptyDescription: widget.emptyDescription,
      searchHint: widget.searchHint,
      searchText: widget.searchText,
      summaryBuilder: widget.summaryBuilder,
      trailing: widget.onCreate == null
          ? null
          : IconButton.filled(
              tooltip: 'Yeni kayıt',
              style: IconButton.styleFrom(
                backgroundColor: FinkitColors.ink,
                foregroundColor: Colors.white,
              ),
              onPressed: _creating ? null : _create,
              icon: Icon(widget.createIcon),
            ),
    );
  }
}

/// Ürün ve hizmet kartları.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int _localRefresh = 0;

  Future<void> _openProduct(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          api: widget.api,
          productId: id,
          onChanged: () {
            if (mounted) setState(() => _localRefresh++);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Ürün ve Hizmetler',
      subtitle: 'Satış fiyatı, KDV oranı ve stok maliyetlerini yönetin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.products,
      createIcon: Icons.add_box_outlined,
      searchHint: 'Ürün, hizmet veya barkod ara',
      searchText: (item) =>
          '${item['name']} ${item['code']} ${item['barcode']}',
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'Ürün bulunamadı',
      emptyDescription: 'Satışta kullanmak için ürün veya hizmet ekleyin.',
      onCreate: (context) => showProductForm(context, widget.api),
      summaryBuilder: (items) {
        final stocked = items
            .where((item) => item['track_inventory'] == true)
            .length;
        return SummaryGrid(
          items: [
            SummaryItem('Kayıt', '${items.length}', Icons.inventory_2_outlined),
            SummaryItem('Stok Takibi', '$stocked', Icons.warehouse_outlined),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: item['product_type'] == 'SERVICE'
            ? Icons.handyman_outlined
            : Icons.inventory_2_outlined,
        title: item['name']?.toString() ?? 'Ürün',
        subtitle:
            '${item['code'] ?? ''} · KDV %${_trimNumber(item['vat_rate'])} · ${item['unit'] ?? 'ADET'}',
        value: moneyText(item['sales_price']),
        valueSubtitle: 'Satış fiyatı',
        onTap: () => _openProduct(item),
      ),
    );
  }
}

/// Depolar.
class WarehousesPage extends StatefulWidget {
  const WarehousesPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  int _localRefresh = 0;

  Future<void> _open(Map<String, dynamic> warehouse) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${warehouse['name'] ?? 'Depo'}',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            ListTile(
              title: const Text('Kod'),
              subtitle: Text('${warehouse['code'] ?? '-'}'),
            ),
            ListTile(
              title: const Text('Konum'),
              subtitle: Text(
                '${warehouse['city'] ?? ''} ${warehouse['district'] ?? ''}'
                    .trim(),
              ),
            ),
            ListTile(
              title: const Text('Adres'),
              subtitle: Text('${warehouse['address'] ?? '-'}'),
            ),
            ListTile(
              title: const Text('Durum'),
              subtitle: Text(
                warehouse['is_active'] == false ? 'Pasif' : 'Aktif',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Depoyu Düzenle'),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                final changed = await showWarehouseForm(
                  context,
                  widget.api,
                  warehouse: warehouse,
                );
                if (changed && mounted) setState(() => _localRefresh++);
              },
            ),
            if (warehouse['is_active'] != false)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Depoyu Pasifleştir'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  final approved = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Depoyu pasifleştir'),
                      content: Text(
                        '${warehouse['name']} deposu yeni işlemlerde kullanılmayacak.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Vazgeç'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Pasifleştir'),
                        ),
                      ],
                    ),
                  );
                  if (approved != true) return;
                  try {
                    await widget.api.updateWarehouse(
                      (warehouse['id'] as num).toInt(),
                      {'is_active': false},
                    );
                    if (mounted) setState(() => _localRefresh++);
                  } catch (error) {
                    if (mounted)
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$error')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Depolar',
      subtitle: 'Şube ve depo tanımlarını yönetin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.warehouses,
      createIcon: Icons.add_business_outlined,
      emptyIcon: Icons.warehouse_outlined,
      emptyTitle: 'Depo bulunamadı',
      emptyDescription: 'Stok takibi için en az bir depo tanımlayın.',
      onCreate: (context) => showWarehouseForm(context, widget.api),
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.warehouse_outlined,
        title: item['name']?.toString() ?? 'Depo',
        subtitle:
            '${item['code'] ?? ''} · ${item['city'] ?? 'Şehir belirtilmedi'}',
        value: item['is_default'] == true ? 'Varsayılan' : '',
        valueSubtitle: item['is_active'] == true ? 'Aktif' : 'Pasif',
        onTap: () => _open(item),
      ),
    );
  }
}

/// Depo bazlı stok bakiyeleri ve hareketler.
class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return ApiListPage(
      title: 'Depolar ve Stok',
      subtitle: 'Depo bazlı miktar, maliyet ve giriş-çıkış hareketleri.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.stockBalances,
      searchHint: 'Ürün veya depo ara',
      searchText: (item) =>
          '${item['product_name']} ${item['product_code']} ${item['warehouse_name']}',
      emptyIcon: Icons.inventory_outlined,
      emptyTitle: 'Stok kaydı bulunamadı',
      emptyDescription:
          'Stok hareketi ekleyin veya satış faturası kesinleştirin.',
      summaryBuilder: (items) {
        final quantity = items.fold<double>(
          0,
          (sum, item) => sum + (double.tryParse('${item['quantity']}') ?? 0),
        );
        final value = items.fold<double>(
          0,
          (sum, item) => sum + (double.tryParse('${item['total_cost']}') ?? 0),
        );
        return SummaryGrid(
          items: [
            SummaryItem(
              'Toplam Miktar',
              _trimNumber(quantity),
              Icons.straighten,
            ),
            SummaryItem(
              'Stok Değeri',
              moneyText(value),
              Icons.savings_outlined,
            ),
          ],
        );
      },
      trailingActions: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _openMovementForm(context, 'IN'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Giriş'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _openMovementForm(context, 'OUT'),
          icon: const Icon(Icons.remove_rounded, size: 18),
          label: const Text('Çıkış'),
        ),
      ],
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.inventory_2_outlined,
        title: item['product_name']?.toString() ?? 'Ürün',
        subtitle:
            '${item['warehouse_name'] ?? 'Depo'} · ${item['product_code'] ?? ''}',
        value: '${_trimNumber(item['quantity'])} ${item['unit'] ?? ''}',
        valueSubtitle: moneyText(item['total_cost']),
        onTap: () => showAccountingDetailSheet(
          context,
          title: item['product_name']?.toString() ?? 'Stok',
          rows: [
            ('Depo', '${item['warehouse_name'] ?? '-'}'),
            (
              'Miktar',
              '${_trimNumber(item['quantity'])} ${item['unit'] ?? ''}',
            ),
            ('Birim maliyet', moneyText(item['unit_cost'])),
            ('Stok değeri', moneyText(item['total_cost'])),
          ],
        ),
      ),
    );
  }

  Future<void> _openMovementForm(BuildContext context, String type) async {
    final created = await showStockMovementForm(
      context,
      widget.api,
      type: type,
    );
    if (created && mounted) setState(() => _localRefresh++);
  }
}

/// Teklifler.
class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final _search = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _status = '';
  int? _partnerId;
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  late Future<List<Map<String, dynamic>>> _partners;

  @override
  void initState() {
    super.initState();
    _reload();
    _partners = widget.api.partners(type: 'CUSTOMER');
  }

  @override
  void didUpdateWidget(covariant QuotesPage oldWidget) {
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
    _future = widget.api.quotePage(
      page: _page,
      search: _search.text.trim(),
      status: _status,
      partnerId: _partnerId,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
    );
  }

  void _filter() {
    final start = _start.text.trim();
    final end = _end.text.trim();
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if ((start.isNotEmpty && !date.hasMatch(start)) ||
        (end.isNotEmpty && !date.hasMatch(end)) ||
        (start.isNotEmpty && end.isNotEmpty && start.compareTo(end) > 0)) {
      _notify('Geçerli bir tarih aralığı girin.');
      return;
    }
    setState(() {
      _page = 1;
      _reload();
    });
  }

  Future<void> _create() async {
    try {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => QuoteFormPage(api: widget.api)),
      );
      if (created == true && mounted) setState(_reload);
    } catch (error) {
      _notify('$error');
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(
          title: 'Teklifler',
          subtitle:
              'Müşteriye verilen teklifleri hazırlayın ve faturaya çevirin.',
          trailing: IconButton.filled(
            tooltip: 'Yeni teklif',
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
        ),
        TextField(
          controller: _search,
          decoration: const InputDecoration(labelText: 'Teklif numarası ara'),
          onSubmitted: (_) => _filter(),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Durum'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'DRAFT', child: Text('Taslak')),
            DropdownMenuItem(value: 'SENT', child: Text('Gönderildi')),
            DropdownMenuItem(value: 'ACCEPTED', child: Text('Kabul edildi')),
            DropdownMenuItem(value: 'REJECTED', child: Text('Reddedildi')),
            DropdownMenuItem(
              value: 'CONVERTED',
              child: Text('Faturaya dönüştü'),
            ),
            DropdownMenuItem(value: 'CANCELLED', child: Text('İptal edildi')),
          ],
          onChanged: (value) => setState(() {
            _status = value ?? '';
            _page = 1;
            _reload();
          }),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _partners,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return DropdownButtonFormField<int?>(
              initialValue: _partnerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Müşteri'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tümü')),
                ...snapshot.data!.map(
                  (p) => DropdownMenuItem<int?>(
                    value: (p['id'] as num).toInt(),
                    child: Text(
                      '${p['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _partnerId = value;
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
                  labelText: 'Başlangıç',
                  hintText: 'YYYY-AA-GG',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _end,
                decoration: const InputDecoration(
                  labelText: 'Bitiş',
                  hintText: 'YYYY-AA-GG',
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () => setState(_reload),
                child: Text('Teklifler yüklenemedi: ${snapshot.error}'),
              );
            }
            final items = (snapshot.data?['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final total =
                int.tryParse('${snapshot.data?['total']}') ?? items.length;
            return Column(
              children: [
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'Teklif bulunamadı',
                    description: 'Seçilen filtrelerde teklif yok.',
                  ),
                for (final item in items)
                  DataRowCard(
                    icon: Icons.request_quote_outlined,
                    title: item['number']?.toString() ?? 'Teklif',
                    subtitle:
                        '${dateText(item['issue_date'])} · Geçerlilik: ${dateText(item['valid_until'])}',
                    value: moneyText(item['gross_amount']),
                    valueSubtitle: statusLabel(item['status']?.toString()),
                    status: item['status']?.toString(),
                    onTap: () => _openDetail(context, item),
                  ),
                if (total > 20 || _page > 1)
                  Row(
                    children: [
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
                      Expanded(
                        child: Text(
                          'Sayfa $_page · $total teklif',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sonraki sayfa',
                        onPressed: _page * 20 >= total
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

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> quote,
  ) async {
    final id = int.tryParse('${quote['id']}');
    if (id == null) return;
    Map<String, dynamic> detail;
    try {
      detail = await widget.api.quoteDetail(id);
    } catch (error) {
      _notify('$error');
      return;
    }
    if (!mounted || !context.mounted) return;
    final status = detail['status']?.toString() ?? 'DRAFT';
    final lines = (detail['lines'] as List? ?? const [])
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                detail['number']?.toString() ?? 'Teklif',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              AccountingRows(
                rows: [
                  ('Durum', statusLabel(status)),
                  ('Tarih', dateText(detail['issue_date'])),
                  ('Geçerlilik', dateText(detail['valid_until'])),
                  ('Net', moneyText(detail['net_amount'])),
                  ('KDV', moneyText(detail['vat_amount'])),
                  ('Genel toplam', moneyText(detail['gross_amount'])),
                ],
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Kalemler',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                for (final line in lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${line['description'] ?? 'Kalem'}'),
                    subtitle: Text(
                      '${line['quantity'] ?? 0} ${line['unit'] ?? ''} · KDV %${line['vat_rate'] ?? 0}',
                    ),
                    trailing: Text(moneyText(line['line_total'])),
                  ),
              ],
              const SizedBox(height: 8),
              if (status == 'DRAFT')
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'SENT'),
                  child: const Text('Gönderildi'),
                ),
              if (status == 'DRAFT' || status == 'SENT') ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'ACCEPTED'),
                  child: const Text('Kabul edildi'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'REJECTED'),
                  child: const Text('Reddedildi'),
                ),
              ],
              if (status != 'CONVERTED') ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'REVISE'),
                  child: const Text('Revize et'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'COPY'),
                  child: const Text('Kopyala'),
                ),
              ],
              if (status != 'CONVERTED' &&
                  status != 'CANCELLED' &&
                  status != 'REJECTED')
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'CANCELLED'),
                  child: const Text('İptal et'),
                ),
              if (status == 'DRAFT' || status == 'SENT' || status == 'ACCEPTED')
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'CONVERT'),
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: const Text('Faturaya çevir'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'CONVERT') {
        await widget.api.convertQuote(id);
        _notify('Teklif faturaya çevrildi');
      } else if (action == 'COPY' || action == 'REVISE') {
        await widget.api.copyQuote(id, revise: action == 'REVISE');
        _notify(
          action == 'REVISE' ? 'Teklif revize edildi' : 'Teklif kopyalandı',
        );
      } else {
        await widget.api.setQuoteStatus(id, action);
        _notify('Teklif durumu güncellendi');
      }
      setState(_reload);
    } catch (error) {
      _notify(error.toString());
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Gelen (alış) faturaları.
class PurchaseInvoicesPage extends StatelessWidget {
  const PurchaseInvoicesPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });
  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) =>
      PurchaseInvoiceManagementPage(api: api, refreshKey: refreshKey);
}

/// İade faturaları, satış kayıtlarının sunucu filtreli IADE görünümüdür.
class SalesReturnsPage extends StatelessWidget {
  const SalesReturnsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });
  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) => SalesPage(
    api: api,
    refreshKey: refreshKey,
    onQuickAction: () {},
    initialInvoiceType: 'IADE',
  );
}

/// Çalışanlar.
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Çalışanlar',
      subtitle: 'Personel kartları, ücretler, avans ve puantaj kayıtları.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.employees,
      createIcon: Icons.person_add_alt_rounded,
      searchHint: 'Ad, soyad veya sicil no ara',
      searchText: (item) =>
          '${item['first_name']} ${item['last_name']} ${item['employee_no']}',
      emptyIcon: Icons.groups_2_outlined,
      emptyTitle: 'Çalışan bulunamadı',
      emptyDescription: 'Bordro için önce çalışan kartı oluşturun.',
      onCreate: (context) => showEmployeeForm(context, widget.api),
      summaryBuilder: (items) {
        final cost = items.fold<double>(
          0,
          (sum, item) =>
              sum + (double.tryParse('${item['gross_salary']}') ?? 0),
        );
        final active = items.where((item) => item['status'] == 'ACTIVE').length;
        return SummaryGrid(
          items: [
            SummaryItem('Aktif Çalışan', '$active', Icons.badge_outlined),
            SummaryItem('Aylık Brüt', moneyText(cost), Icons.payments_outlined),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.person_outline_rounded,
        title: '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim(),
        subtitle:
            '${item['employee_no'] ?? ''} · ${item['position'] ?? item['department'] ?? 'Görev belirtilmedi'}',
        value: moneyText(item['gross_salary']),
        valueSubtitle: 'Brüt ücret',
        status: item['status']?.toString(),
        onTap: () => _openDetail(context, item),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> employee,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'
                  .trim(),
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            AccountingRows(
              rows: [
                ('Sicil no', '${employee['employee_no'] ?? '-'}'),
                ('Görev', '${employee['position'] ?? '-'}'),
                ('Departman', '${employee['department'] ?? '-'}'),
                ('İşe giriş', dateText(employee['hire_date'])),
                ('Brüt ücret', moneyText(employee['gross_salary'])),
                ('IBAN', '${employee['iban'] ?? '-'}'),
                ('Telefon', '${employee['phone'] ?? '-'}'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'ADVANCE'),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('Avans Ver'),
              ),
            ),
          ],
        ),
      ),
    );
    if (action != 'ADVANCE') return;
    if (!context.mounted) return;
    final created = await showEmployeeAdvanceForm(
      context,
      widget.api,
      employee,
    );
    if (created && mounted) setState(() => _localRefresh++);
  }
}

/// Çek ve senet portföyü.
class ChecksNotesPage extends StatefulWidget {
  const ChecksNotesPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ChecksNotesPage> createState() => _ChecksNotesPageState();
}

class _ChecksNotesPageState extends State<ChecksNotesPage> {
  int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Çekler ve Senetler',
      subtitle: 'Portföy, tahsil, teminat ve protesto durumlarını izleyin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.checksNotes,
      createIcon: Icons.post_add_rounded,
      searchHint: 'Seri no veya keşideci ara',
      searchText: (item) =>
          '${item['serial_no']} ${item['received_from']} ${item['given_to']}',
      emptyIcon: Icons.receipt_outlined,
      emptyTitle: 'Çek/senet kaydı yok',
      emptyDescription: 'Alınan veya verilen çek ve senetleri kaydedin.',
      onCreate: (context) => showCheckNoteForm(context, widget.api),
      summaryBuilder: (items) {
        final incoming = items
            .where((item) => item['direction'] == 'IN')
            .fold<double>(
              0,
              (sum, item) => sum + (double.tryParse('${item['amount']}') ?? 0),
            );
        final outgoing = items
            .where((item) => item['direction'] == 'OUT')
            .fold<double>(
              0,
              (sum, item) => sum + (double.tryParse('${item['amount']}') ?? 0),
            );
        return SummaryGrid(
          items: [
            SummaryItem(
              'Alınan',
              moneyText(incoming),
              Icons.call_received_rounded,
            ),
            SummaryItem(
              'Verilen',
              moneyText(outgoing),
              Icons.call_made_rounded,
            ),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: item['instrument_type'] == 'CHECK'
            ? Icons.receipt_outlined
            : Icons.description_outlined,
        title:
            '${item['instrument_type'] == 'CHECK' ? 'Çek' : 'Senet'} · ${item['serial_no'] ?? ''}',
        subtitle:
            '${item['direction'] == 'IN' ? 'Alınan' : 'Verilen'} · Vade ${dateText(item['due_date'])}',
        value: moneyText(item['amount']),
        valueSubtitle: statusLabel(item['status']?.toString()),
        status: item['status']?.toString(),
        onTap: () => _openDetail(context, item),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> instrument,
  ) async {
    final isIncoming = instrument['direction'] == 'IN';
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${instrument['instrument_type'] == 'CHECK' ? 'Çek' : 'Senet'} ${instrument['serial_no'] ?? ''}',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            AccountingRows(
              rows: [
                ('Yön', isIncoming ? 'Alınan' : 'Verilen'),
                ('Durum', statusLabel(instrument['status']?.toString())),
                (
                  'Keşide/Lehtar',
                  '${instrument['received_from'] ?? instrument['given_to'] ?? '-'}',
                ),
                ('Vade', dateText(instrument['due_date'])),
                ('Tutar', moneyText(instrument['amount'])),
                ('Banka', '${instrument['bank_name'] ?? '-'}'),
              ],
            ),
            const SizedBox(height: 18),
            if (isIncoming)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'COLLECTED'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Tahsil Edildi'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'PAID'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Ödendi'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, 'PROTESTED'),
                child: const Text('Karşılıksız / Protesto'),
              ),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      await widget.api.addCheckNoteEvent(
        checkId: int.parse('${instrument['id']}'),
        eventType: action,
        status: action,
      );
      if (!mounted) return;
      setState(() => _localRefresh++);
      messenger.showSnackBar(
        const SnackBar(content: Text('Çek/senet durumu güncellendi')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

/// Tahsilatlar.
class CollectionsPage extends StatelessWidget {
  const CollectionsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) =>
      CollectionManagementPage(api: api, refreshKey: refreshKey);
}

/// Tedarikçi ödemeleri.
class SupplierPaymentsPage extends StatefulWidget {
  const SupplierPaymentsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<SupplierPaymentsPage> createState() => _SupplierPaymentsPageState();
}

class _SupplierPaymentsPageState extends State<SupplierPaymentsPage> {
  @override
  Widget build(BuildContext context) => SupplierPaymentManagementPage(
    api: widget.api,
    refreshKey: widget.refreshKey,
  );
}

/// Kasa ve banka hesapları.
class FinancialAccountsPage extends StatefulWidget {
  const FinancialAccountsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<FinancialAccountsPage> createState() => _FinancialAccountsPageState();
}

class _FinancialAccountsPageState extends State<FinancialAccountsPage> {
  final _search = TextEditingController();
  String _type = '';
  String _currency = '';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant FinancialAccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) setState(_reload);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.accounts();
  }

  Future<void> _create() async {
    final created = await showFinancialAccountForm(context, widget.api);
    if (created && mounted) setState(_reload);
  }

  String _balanceText(Object? raw, String currency) {
    if (currency == 'TRY') return moneyText(raw);
    final value = num.tryParse('$raw') ?? 0;
    return '${value.toStringAsFixed(2)} $currency';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(
          title: 'Kasa ve Bankalar',
          subtitle: 'Kasa, banka, POS ve kredi kartı hesaplarını yönetin.',
          trailing: IconButton.filled(
            tooltip: 'Yeni hesap',
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
        ),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Hesap, banka veya IBAN ara',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Hesap türü'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'CASH', child: Text('Kasa')),
            DropdownMenuItem(value: 'BANK', child: Text('Banka')),
            DropdownMenuItem(value: 'POS', child: Text('POS')),
            DropdownMenuItem(value: 'CREDIT_CARD', child: Text('Kredi kartı')),
          ],
          onChanged: (value) => setState(() => _type = value ?? ''),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Para birimi'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'TRY', child: Text('TRY')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
          ],
          onChanged: (value) => setState(() => _currency = value ?? ''),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return TextButton(
                onPressed: () => setState(_reload),
                child: Text('Hesaplar alınamadı: ${snapshot.error}'),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final search = _search.text.trim().toLowerCase();
            final items = snapshot.data!
                .where(
                  (item) =>
                      (_type.isEmpty || item['account_type'] == _type) &&
                      (_currency.isEmpty || item['currency'] == _currency) &&
                      (search.isEmpty ||
                          '${item['name']} ${item['bank_name']} ${item['iban']}'
                              .toLowerCase()
                              .contains(search)),
                )
                .toList();
            final balances = <String, double>{};
            for (final item in items) {
              final currency = '${item['currency'] ?? 'TRY'}';
              balances[currency] =
                  (balances[currency] ?? 0) +
                  (double.tryParse('${item['current_balance']}') ?? 0);
            }
            return Column(
              children: [
                SummaryGrid(
                  items: [
                    SummaryItem(
                      'Hesap',
                      '${items.length}',
                      Icons.account_balance_outlined,
                    ),
                    for (final entry in balances.entries)
                      SummaryItem(
                        '${entry.key} bakiye',
                        _balanceText(entry.value, entry.key),
                        Icons.savings_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Hesap bulunamadı',
                    description: 'Seçilen filtrelerde hesap yok.',
                  ),
                for (final item in items)
                  DataRowCard(
                    icon: item['account_type'] == 'CASH'
                        ? Icons.point_of_sale_outlined
                        : Icons.account_balance_outlined,
                    title: item['name']?.toString() ?? 'Hesap',
                    subtitle: [
                      '${item['bank_name'] ?? _accountTypeLabel(item['account_type']?.toString())}',
                      if ('${item['branch_name'] ?? ''}'.isNotEmpty)
                        '${item['branch_name']}',
                      '${item['iban'] ?? 'IBAN yok'}',
                    ].join(' · '),
                    value: _balanceText(
                      item['current_balance'],
                      '${item['currency'] ?? 'TRY'}',
                    ),
                    valueSubtitle: '${item['currency'] ?? 'TRY'} bakiye',
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

String _accountTypeLabel(String? type) => switch (type) {
  'CASH' => 'Kasa',
  'BANK' => 'Banka',
  'POS' => 'POS',
  'CREDIT_CARD' => 'Kredi Kartı',
  _ => 'Hesap',
};

/// Detay alt sayfasında gösterilen etiket-değer listesi.
class AccountingRows extends StatelessWidget {
  const AccountingRows({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].$1,
                      style: const TextStyle(
                        color: FinkitColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      rows[index].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, color: FinkitColors.line),
          ],
        ],
      ),
    );
  }
}

/// Kayıt detayını alt sayfa olarak gösterir.
Future<void> showAccountingDetailSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> rows,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [AccountingRows(rows: rows)],
      ),
    ),
  ),
);

/// Ondalık sayıyı gereksiz sıfırlar olmadan gösterir.
String _trimNumber(dynamic value) {
  final parsed = double.tryParse('$value');
  if (parsed == null) return '0';
  if (parsed == parsed.roundToDouble()) return parsed.toStringAsFixed(0);
  return parsed.toStringAsFixed(2);
}

/// Ödeme hatırlatma kuralları (SMS / e-posta) ve manuel gönderim.
class ReminderRulesPage extends StatefulWidget {
  const ReminderRulesPage({
    super.key,
    required this.api,
    required this.refreshKey,
    this.isClient = false,
    this.isSubUser = false,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;
  final bool isSubUser;

  @override
  State<ReminderRulesPage> createState() => _ReminderRulesPageState();
}

class _ReminderRulesPageState extends State<ReminderRulesPage> {
  Future<List<Map<String, dynamic>>>? _future;
  Future<
    ({Map<String, dynamic> profile, List<Map<String, dynamic>> templates})
  >?
  _settings;
  String? _templateId;
  bool _savingTemplate = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReminderRulesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    setState(() {
      _future = widget.api.reminderRules();
      if (!widget.isClient && !widget.isSubUser) {
        _settings = _loadSettings();
        _templateId = null;
      }
    });
  }

  Future<({Map<String, dynamic> profile, List<Map<String, dynamic>> templates})>
  _loadSettings() async {
    final profile = await widget.api.advisorProfile();
    final templates = await widget.api.messageTemplates();
    return (profile: profile, templates: templates);
  }

  Future<void> _saveTemplate(String selected) async {
    setState(() => _savingTemplate = true);
    try {
      await widget.api.setAdvisorReminderTemplate(
        selected.isEmpty ? null : int.parse(selected),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatma şablonu kaydedildi')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _savingTemplate = false);
    }
  }

  Future<void> _runReminders() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hatırlatmaları gönder'),
        content: const Text(
          'Bugün ödeme vadesi gelen mükelleflere şimdi e-posta hatırlatması gönderilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    try {
      await widget.api.runReminders();
      messenger.showSnackBar(
        const SnackBar(content: Text('Hatırlatmalar gönderildi')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _createRule() async {
    final created = await showReminderRuleForm(context, widget.api);
    if (created && mounted) _load();
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final updated = await showReminderRuleForm(context, widget.api, rule: rule);
    if (updated && mounted) _load();
  }

  Future<void> _toggle(Map<String, dynamic> rule, bool value) async {
    try {
      await widget.api.updateReminderRule(
        int.parse('${rule['id']}'),
        isActive: value,
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> rule) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kuralı sil'),
        content: const Text('Bu hatırlatma kuralı silinsin mi?'),
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
      await widget.api.deleteReminderRule(int.parse('${rule['id']}'));
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Hatırlatma Kuralları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRule,
        backgroundColor: FinkitColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kural Ekle'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rules = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              const PageTitle(
                title: 'Hatırlatma Kuralları',
                subtitle: 'Vadesi yaklaşan ödemeler için otomatik SMS veya e-posta hatırlatması.',
              ),
              if (!widget.isClient && !widget.isSubUser)
                FutureBuilder<
                  ({
                    Map<String, dynamic> profile,
                    List<Map<String, dynamic>> templates,
                  })
                >(
                  future: _settings,
                  builder: (context, settings) {
                    if (settings.connectionState != ConnectionState.done) {
                      return const LoadingState();
                    }
                    if (settings.hasError) {
                      return TextButton(
                        onPressed: _load,
                        child: Text(
                          'Şablon ayarı alınamadı: ${settings.error} · Tekrar dene',
                        ),
                      );
                    }
                    final profile = settings.data!.profile;
                    final templates = settings.data!.templates;
                    final selected =
                        _templateId ??
                        '${profile['payment_reminder_template_id'] ?? ''}';
                    return SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'E-posta hatırlatma şablonu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selected,
                            decoration: const InputDecoration(
                              labelText: 'Şablon',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Varsayılan sistem mesajı'),
                              ),
                              if (selected.isNotEmpty &&
                                  !templates.any(
                                    (item) => '${item['id']}' == selected,
                                  ))
                                DropdownMenuItem(
                                  value: selected,
                                  child: const Text('Mevcut şablon'),
                                ),
                              for (final item in templates)
                                DropdownMenuItem(
                                  value: '${item['id']}',
                                  child: Text(
                                    '${item['name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => _templateId = value ?? '',
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _savingTemplate
                                ? null
                                : () => _saveTemplate(_templateId ?? selected),
                            child: Text(
                              _savingTemplate
                                  ? 'Kaydediliyor…'
                                  : 'Şablonu Kaydet',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (!widget.isClient)
                SurfaceCard(
                  dark: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hatırlatmaları elle çalıştır',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kurallara uyan mükelleflere hemen hatırlatma gönderilir.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _running ? null : _runReminders,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: FinkitColors.ink,
                          ),
                          icon: _running
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _running ? 'Gönderiliyor…' : 'Şimdi Gönder',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SectionHeader(title: 'Kurallar'),
              if (rules.isEmpty)
                const EmptyState(
                  icon: Icons.notifications_active_outlined,
                  title: 'Kural yok',
                  description: 'Ödeme hatırlatması için kural ekleyin.',
                )
              else
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              rule['channel'] == 'sms'
                                  ? Icons.sms_outlined
                                  : Icons.mail_outline_rounded,
                              size: 20,
                              color: FinkitColors.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${rule['channel'] == 'sms' ? 'SMS' : 'E-posta'} · ${rule['days_before']} gün önce',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rule['message']?.toString() ??
                                      'Varsayılan hatırlatma metni',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FinkitColors.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: rule['is_active'] != false,
                            onChanged: (value) => _toggle(rule, value),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Kural işlemleri',
                            onSelected: (action) {
                              if (action == 'edit') _editRule(rule);
                              if (action == 'delete') _delete(rule);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
