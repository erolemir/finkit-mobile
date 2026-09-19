import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'data_pages.dart' show SummaryGrid, SummaryItem;
import 'entry_forms.dart';
import 'invoice_detail_page.dart';

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
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Ürün ve Hizmetler',
      subtitle: 'Satış fiyatı, KDV oranı ve stok maliyetlerini yönetin.',
      refreshKey: refreshKey,
      loader: api.products,
      createIcon: Icons.add_box_outlined,
      searchHint: 'Ürün, hizmet veya barkod ara',
      searchText: (item) =>
          '${item['name']} ${item['code']} ${item['barcode']}',
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'Ürün bulunamadı',
      emptyDescription: 'Satışta kullanmak için ürün veya hizmet ekleyin.',
      onCreate: (context) => showProductForm(context, api),
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
        onTap: () => showAccountingDetailSheet(
          context,
          title: item['name']?.toString() ?? 'Ürün',
          rows: [
            ('Kod', '${item['code'] ?? '-'}'),
            ('Tip', item['product_type'] == 'SERVICE' ? 'Hizmet' : 'Ürün'),
            ('Birim', '${item['unit'] ?? 'ADET'}'),
            ('KDV', '%${_trimNumber(item['vat_rate'])}'),
            ('Satış fiyatı', moneyText(item['sales_price'])),
            ('Alış fiyatı', moneyText(item['purchase_price'])),
            ('Maliyet', moneyText(item['manual_cost'])),
            ('Barkod', '${item['barcode'] ?? '-'}'),
          ],
        ),
      ),
    );
  }
}

/// Depolar.
class WarehousesPage extends StatelessWidget {
  const WarehousesPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Depolar',
      subtitle: 'Şube ve depo tanımlarını yönetin.',
      refreshKey: refreshKey,
      loader: api.warehouses,
      createIcon: Icons.add_business_outlined,
      emptyIcon: Icons.warehouse_outlined,
      emptyTitle: 'Depo bulunamadı',
      emptyDescription: 'Stok takibi için en az bir depo tanımlayın.',
      onCreate: (context) => showWarehouseForm(context, api),
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.warehouse_outlined,
        title: item['name']?.toString() ?? 'Depo',
        subtitle:
            '${item['code'] ?? ''} · ${item['city'] ?? 'Şehir belirtilmedi'}',
        value: item['is_default'] == true ? 'Varsayılan' : '',
        valueSubtitle: item['is_active'] == true ? 'Aktif' : 'Pasif',
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
  int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Teklifler',
      subtitle: 'Müşteriye verilen teklifleri hazırlayın ve faturaya çevirin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.quotes,
      createIcon: Icons.request_quote_outlined,
      searchHint: 'Teklif numarası ara',
      searchText: (item) => '${item['number']} ${item['status']}',
      emptyIcon: Icons.request_quote_outlined,
      emptyTitle: 'Teklif bulunamadı',
      emptyDescription: 'Yeni teklif oluşturarak satış sürecini başlatın.',
      onCreate: (context) => showQuoteForm(context, widget.api),
      summaryBuilder: (items) {
        final total = items.fold<double>(
          0,
          (sum, item) =>
              sum + (double.tryParse('${item['gross_amount']}') ?? 0),
        );
        final open = items
            .where(
              (item) => item['status'] == 'DRAFT' || item['status'] == 'SENT',
            )
            .length;
        return SummaryGrid(
          items: [
            SummaryItem(
              'Teklif Tutarı',
              moneyText(total),
              Icons.summarize_outlined,
            ),
            SummaryItem('Açık Teklif', '$open', Icons.hourglass_bottom_rounded),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.request_quote_outlined,
        title: item['number']?.toString() ?? 'Teklif',
        subtitle:
            '${dateText(item['issue_date'])} · Geçerlilik: ${dateText(item['valid_until'])}',
        value: moneyText(item['gross_amount']),
        valueSubtitle: statusLabel(item['status']?.toString()),
        status: item['status']?.toString(),
        onTap: () => _openDetail(context, item),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> quote,
  ) async {
    final status = quote['status']?.toString() ?? 'DRAFT';
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
              quote['number']?.toString() ?? 'Teklif',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            AccountingRows(
              rows: [
                ('Durum', statusLabel(status)),
                ('Tarih', dateText(quote['issue_date'])),
                ('Geçerlilik', dateText(quote['valid_until'])),
                ('Net', moneyText(quote['net_amount'])),
                ('KDV', moneyText(quote['vat_amount'])),
                ('Genel toplam', moneyText(quote['gross_amount'])),
              ],
            ),
            const SizedBox(height: 18),
            if (status != 'ACCEPTED')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'ACCEPTED'),
                  child: const Text('Müşteri kabul etti'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'CONVERT'),
                icon: const Icon(Icons.post_add_rounded, size: 18),
                label: const Text('Faturaya Çevir'),
              ),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'CONVERT') {
        await widget.api.convertQuote(int.parse('${quote['id']}'));
        _notify('Teklif faturaya çevrildi');
      } else {
        await widget.api.setQuoteStatus(int.parse('${quote['id']}'), action);
        _notify('Teklif durumu güncellendi');
      }
      setState(() => _localRefresh++);
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
class PurchaseInvoicesPage extends StatefulWidget {
  const PurchaseInvoicesPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<PurchaseInvoicesPage> createState() => _PurchaseInvoicesPageState();
}

class _PurchaseInvoicesPageState extends State<PurchaseInvoicesPage> {
  int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Gelen Faturalar',
      subtitle: 'Tedarikçi faturalarını girin, eşleştirin ve kaydedin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.purchaseInvoices,
      createIcon: Icons.receipt_long_outlined,
      searchHint: 'Fatura numarası ara',
      searchText: (item) => '${item['number']} ${item['status']}',
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'Gelen fatura yok',
      emptyDescription:
          'Tedarikçi faturasını elle girin veya e-faturadan çekin.',
      onCreate: (context) => showPurchaseInvoiceForm(context, widget.api),
      summaryBuilder: (items) {
        final total = items.fold<double>(
          0,
          (sum, item) =>
              sum + (double.tryParse('${item['gross_amount']}') ?? 0),
        );
        final unpaid = items
            .where((item) => item['payment_status'] != 'PAID')
            .fold<double>(
              0,
              (sum, item) =>
                  sum + (double.tryParse('${item['gross_amount']}') ?? 0),
            );
        return SummaryGrid(
          items: [
            SummaryItem(
              'Toplam Alış',
              moneyText(total),
              Icons.receipt_long_outlined,
            ),
            SummaryItem('Ödenecek', moneyText(unpaid), Icons.schedule_rounded),
          ],
        );
      },
      itemBuilder: (context, item) {
        final status = item['status']?.toString() ?? 'DRAFT';
        return DataRowCard(
          icon: Icons.receipt_long_outlined,
          title: item['number']?.toString() ?? 'Taslak Alış Faturası',
          subtitle: '${dateText(item['issue_date'])} · ${statusLabel(status)}',
          value: moneyText(item['gross_amount']),
          valueSubtitle: statusLabel(item['payment_status']?.toString()),
          status: status,
          onTap: () => _openDetail(context, item),
        );
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> invoice,
  ) async {
    await openInvoiceDetail(context, widget.api, invoice, purchase: true);
    if (mounted) setState(() => _localRefresh++);
  }
}

/// İade faturaları.
class SalesReturnsPage extends StatelessWidget {
  const SalesReturnsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'İade Faturaları',
      subtitle: 'Müşteriden gelen iadeleri cari ve stok etkisiyle izleyin.',
      refreshKey: refreshKey,
      loader: () => api.salesInvoices(type: 'IADE'),
      createIcon: Icons.assignment_return_outlined,
      searchHint: 'İade faturası ara',
      searchText: (item) => '${item['number']} ${item['status']}',
      emptyIcon: Icons.assignment_return_outlined,
      emptyTitle: 'İade faturası yok',
      emptyDescription: 'İade faturası kesildiğinde burada listelenir.',
      onCreate: (context) => showSalesInvoiceForm(context, api, type: 'IADE'),
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.assignment_return_outlined,
        title: item['number']?.toString() ?? 'İade Faturası',
        subtitle:
            '${dateText(item['issue_date'])} · ${statusLabel(item['status']?.toString())}',
        value: moneyText(item['gross_amount']),
        valueSubtitle: statusLabel(item['payment_status']?.toString()),
        status: item['status']?.toString(),
        onTap: () => openInvoiceDetail(context, api, item),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Tahsilatlar',
      subtitle: 'Müşterilerden gelen tahsilatlar ve fatura eşleşmeleri.',
      refreshKey: refreshKey,
      loader: api.collections,
      emptyIcon: Icons.call_received_rounded,
      emptyTitle: 'Tahsilat yok',
      emptyDescription: 'Tahsilat kaydedildiğinde burada listelenir.',
      summaryBuilder: (items) {
        final total = items.fold<double>(
          0,
          (sum, item) => sum + (double.tryParse('${item['try_amount']}') ?? 0),
        );
        final open = items
            .where((item) => item['status'] != 'CANCELLED')
            .fold<double>(
              0,
              (sum, item) =>
                  sum + (double.tryParse('${item['unallocated_amount']}') ?? 0),
            );
        return SummaryGrid(
          items: [
            SummaryItem(
              'Tahsil Edilen',
              moneyText(total),
              Icons.savings_outlined,
            ),
            SummaryItem(
              'Avans',
              moneyText(open),
              Icons.account_balance_wallet_outlined,
            ),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.call_received_rounded,
        title: moneyText(item['amount']),
        subtitle:
            '${dateText(item['collection_date'])} · ${item['payment_method'] ?? 'HAVALE'}',
        value: moneyText(item['allocated_amount']),
        valueSubtitle: 'Faturaya işlendi',
        status: item['status']?.toString(),
      ),
    );
  }
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
  final int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Ödemeler',
      subtitle: 'Tedarikçilere yapılan ödemeler ve fatura eşleşmeleri.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.supplierPayments,
      createIcon: Icons.payments_outlined,
      emptyIcon: Icons.payments_outlined,
      emptyTitle: 'Ödeme yok',
      emptyDescription: 'Tedarikçi ödemesi kaydedildiğinde burada listelenir.',
      onCreate: (context) => showSupplierPaymentForm(context, widget.api),
      summaryBuilder: (items) {
        final total = items.fold<double>(
          0,
          (sum, item) => sum + (double.tryParse('${item['try_amount']}') ?? 0),
        );
        return SummaryGrid(
          items: [
            SummaryItem('Ödenen', moneyText(total), Icons.payments_outlined),
            SummaryItem(
              'Kayıt',
              '${items.length}',
              Icons.receipt_long_outlined,
            ),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: Icons.payments_outlined,
        title: moneyText(item['amount']),
        subtitle:
            '${dateText(item['payment_date'])} · ${item['payment_method'] ?? 'HAVALE'}',
        value: moneyText(item['allocated_amount']),
        valueSubtitle: 'Faturaya işlendi',
        status: item['status']?.toString(),
      ),
    );
  }
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
  final int _localRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return AccountingListPage(
      title: 'Kasa ve Bankalar',
      subtitle: 'Kasa, banka, POS ve kredi kartı hesaplarını yönetin.',
      refreshKey: widget.refreshKey + _localRefresh,
      loader: widget.api.accounts,
      createIcon: Icons.account_balance_outlined,
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: 'Hesap bulunamadı',
      emptyDescription: 'Kasa veya banka hesabı tanımlayın.',
      onCreate: (context) => showFinancialAccountForm(context, widget.api),
      summaryBuilder: (items) {
        final balance = items.fold<double>(
          0,
          (sum, item) =>
              sum + (double.tryParse('${item['current_balance']}') ?? 0),
        );
        return SummaryGrid(
          items: [
            SummaryItem(
              'Toplam Bakiye',
              moneyText(balance),
              Icons.savings_outlined,
            ),
            SummaryItem(
              'Hesap',
              '${items.length}',
              Icons.account_balance_outlined,
            ),
          ],
        );
      },
      itemBuilder: (context, item) => DataRowCard(
        icon: item['account_type'] == 'CASH'
            ? Icons.point_of_sale_outlined
            : Icons.account_balance_outlined,
        title: item['name']?.toString() ?? 'Hesap',
        subtitle:
            '${item['bank_name'] ?? _accountTypeLabel(item['account_type']?.toString())} · ${item['iban'] ?? 'IBAN yok'}',
        value: moneyText(item['current_balance']),
        valueSubtitle: '${item['currency'] ?? 'TRY'} bakiye',
      ),
    );
  }
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
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ReminderRulesPage> createState() => _ReminderRulesPageState();
}

class _ReminderRulesPageState extends State<ReminderRulesPage> {
  Future<List<Map<String, dynamic>>>? _future;
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
    });
  }

  Future<void> _runReminders() async {
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
                          IconButton(
                            tooltip: 'Sil',
                            onPressed: () => _delete(rule),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: FinkitColors.muted,
                            ),
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
