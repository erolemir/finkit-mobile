export 'reports_page.dart';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_forms.dart';
import 'exchange_rates_section.dart';
import 'invoice_detail_page.dart';
import 'partner_edit_dialog.dart';
import 'partner_invoice_history_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.onQuickAction,
    this.initialInvoiceType,
  });

  final FinkitApi api;
  final int refreshKey;
  final VoidCallback onQuickAction;
  final String? initialInvoiceType;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _search = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _status = '';
  String _paymentStatus = '';
  late String _invoiceType = widget.initialInvoiceType ?? '';
  int? _partnerId;
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  late Future<List<Map<String, dynamic>>> _partnersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SalesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialInvoiceType != widget.initialInvoiceType) {
      _invoiceType = widget.initialInvoiceType ?? '';
      _page = 1;
      _load();
    } else if (oldWidget.refreshKey != widget.refreshKey) {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _load() {
    _future = widget.api.salesInvoicePage(
      page: _page,
      search: _search.text.trim(),
      status: _status,
      paymentStatus: _paymentStatus,
      invoiceType: _invoiceType,
      partnerId: _partnerId,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
    );
    _partnersFuture = widget.api.partners(type: 'CUSTOMER');
  }

  void _applyFilters() {
    final start = _start.text.trim();
    final end = _end.text.trim();
    bool validDate(String value) {
      if (value.isEmpty) return true;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
      final parsed = DateTime.tryParse(value);
      return parsed != null &&
          parsed.toIso8601String().substring(0, 10) == value;
    }

    if (!validDate(start) ||
        !validDate(end) ||
        (start.isNotEmpty && end.isNotEmpty && start.compareTo(end) > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tarih aralığı girin.')),
      );
      return;
    }
    setState(() {
      _page = 1;
      _load();
    });
  }

  Future<void> _openCreateForm() async {
    final created = await showSalesInvoiceForm(
      context,
      widget.api,
      type: widget.initialInvoiceType ?? 'SATIS',
    );
    if (created && mounted) {
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış faturası kaydedildi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      color: FinkitColors.ink,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PageTitle(
            title: widget.initialInvoiceType == 'IADE'
                ? 'İade Faturaları'
                : 'Satış Faturaları',
            subtitle: widget.initialInvoiceType == 'IADE'
                ? 'İade kayıtlarının durumunu ve cari etkilerini izleyin.'
                : 'Satış ve iade kayıtlarının durumunu ve tahsilatlarını yönetin.',
            trailing: IconButton.filled(
              onPressed: _openCreateForm,
              style: IconButton.styleFrom(
                backgroundColor: FinkitColors.ink,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Fatura numarası / not ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Belge durumu'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tümü')),
              DropdownMenuItem(value: 'DRAFT', child: Text('Taslak')),
              DropdownMenuItem(value: 'FINALIZED', child: Text('Kesinleşti')),
              DropdownMenuItem(value: 'SENT', child: Text('Gönderildi')),
              DropdownMenuItem(
                value: 'DELIVERED',
                child: Text('Teslim edildi'),
              ),
              DropdownMenuItem(value: 'CANCELLED', child: Text('İptal')),
              DropdownMenuItem(value: 'ERROR', child: Text('Hata')),
            ],
            onChanged: (value) => setState(() {
              _status = value ?? '';
              _page = 1;
              _load();
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
              _load();
            }),
          ),
          const SizedBox(height: 8),
          if (widget.initialInvoiceType == null) ...[
            DropdownButtonFormField<String>(
              initialValue: _invoiceType,
              decoration: const InputDecoration(labelText: 'Fatura türü'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tümü')),
                DropdownMenuItem(value: 'SATIS', child: Text('Satış')),
                DropdownMenuItem(value: 'IADE', child: Text('İade')),
              ],
              onChanged: (value) => setState(() {
                _invoiceType = value ?? '';
                _page = 1;
                _load();
              }),
            ),
            const SizedBox(height: 8),
          ],
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _partnersFuture,
            builder: (context, snapshot) {
              final partners = snapshot.data ?? const <Map<String, dynamic>>[];
              _knownPartners = partners;
              if (snapshot.hasError) {
                return Text('Müşteriler yüklenemedi: ${snapshot.error}');
              }
              return DropdownButtonFormField<int?>(
                initialValue: _partnerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Müşteri'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tümü'),
                  ),
                  ...partners.map(
                    (partner) => DropdownMenuItem<int?>(
                      value: (partner['id'] as num).toInt(),
                      child: Text(
                        '${partner['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _partnerId = value;
                  _page = 1;
                  _load();
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
              onPressed: _applyFilters,
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
                return _PageError(
                  message: '${snapshot.error}',
                  onRetry: () => setState(_load),
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
                  for (final invoice in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DataRowCard(
                        icon: Icons.post_add_rounded,
                        title: invoice['number']?.toString() ?? 'Taslak Fatura',
                        subtitle:
                            '${_partnerName(invoice['partner_id'])} · ${dateText(invoice['issue_date'])} · ${statusLabel(invoice['status']?.toString())}',
                        value: moneyText(invoice['gross_amount']),
                        valueSubtitle: 'Vade ${dateText(invoice['due_date'])}',
                        status: invoice['payment_status']?.toString(),
                        document: invoice,
                        onTap: () async {
                          await openInvoiceDetail(context, widget.api, invoice);
                          if (mounted) setState(_load);
                        },
                      ),
                    ),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.post_add_rounded,
                      title: 'Fatura bulunamadı',
                      description:
                          'Bu filtreye uygun satış faturası bulunmuyor.',
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('$total kayıt · $_page. sayfa')),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Önceki sayfa',
                            onPressed: _page <= 1
                                ? null
                                : () => setState(() {
                                    _page--;
                                    _load();
                                  }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Sonraki sayfa',
                            onPressed: _page * 25 >= total
                                ? null
                                : () => setState(() {
                                    _page++;
                                    _load();
                                  }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
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

  String _partnerName(dynamic id) {
    // Müşteri listesi ikinci istekten geldiği için kayıtlar id ile de gösterilir.
    final partners = _knownPartners;
    final matches = partners
        .where((partner) => partner['id'] == id)
        .map((partner) => partner['name']?.toString() ?? '')
        .toList();
    return matches.isNotEmpty ? matches.first : 'Müşteri #$id';
  }

  List<Map<String, dynamic>> _knownPartners = [];
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  Future<_ExpenseData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future = Future.wait([
      widget.api.expenses(),
      widget.api.purchaseInvoices(),
    ]).then((values) => _ExpenseData(expenses: values[0], invoices: values[1]));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExpenseData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _PageError(
            message: snapshot.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        final data = snapshot.data!;
        final total = data.expenses.fold<double>(
          0,
          (sum, item) =>
              sum + (double.tryParse('${item['total_amount']}') ?? 0),
        );
        final unpaid = data.expenses
            .where((item) => item['payment_status'] != 'PAID')
            .fold<double>(
              0,
              (sum, item) =>
                  sum + (double.tryParse('${item['total_amount']}') ?? 0),
            );
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          color: FinkitColors.ink,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const PageTitle(
                title: 'Giderler',
                subtitle: 'Gelen E-Fatura, E-Arşiv, manuel alış kayıtları ve işletme giderlerini birlikte izleyin.',
              ),
              SummaryGrid(
                items: [
                  SummaryItem(
                    'Toplam Gider',
                    moneyText(total),
                    Icons.receipt_long_outlined,
                  ),
                  SummaryItem(
                    'Ödenmemiş',
                    moneyText(unpaid),
                    Icons.schedule_rounded,
                  ),
                ],
              ),
              SectionHeader(
                title: 'Gelen Faturalar',
                action: '${data.invoices.length} kayıt',
              ),
              if (data.invoices.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Gelen fatura yok',
                  description: 'E-fatura gelen kutunuz senkronize edildiğinde burada görünür.',
                )
              else
                ...data.invoices
                    .take(4)
                    .map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DataRowCard(
                          icon: Icons.receipt_long_outlined,
                          title:
                              invoice['number']?.toString() ?? 'Gelen fatura',
                          subtitle:
                              'Tedarikçi · ${dateText(invoice['issue_date'])}',
                          value: moneyText(invoice['gross_amount']),
                          status: invoice['payment_status']?.toString(),
                          document: invoice,
                          onTap: () async {
                            await openInvoiceDetail(
                              context,
                              widget.api,
                              invoice,
                              purchase: true,
                            );
                            if (mounted) setState(_load);
                          },
                        ),
                      ),
                    ),
              const SectionHeader(title: 'Gider Listesi'),
              if (data.expenses.isEmpty)
                const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Gider kaydı yok',
                  description: 'İlk giderinizi ekleyerek başlayın.',
                )
              else
                ...data.expenses.map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      icon: Icons.shopping_bag_outlined,
                      title: expense['description']?.toString() ?? 'Gider',
                      subtitle:
                          '${dateText(expense['expense_date'])} · KDV ${moneyText(expense['vat_amount'])}',
                      value: moneyText(expense['total_amount']),
                      status: expense['payment_status']?.toString(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SurfaceCard(
                dark: true,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu dönem ${moneyText(total)}, bunun ${moneyText(unpaid)} kısmı henüz ödenmedi.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
      },
    );
  }
}

class CashPage extends StatefulWidget {
  const CashPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  Future<_CashData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CashPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future =
        Future.wait([
          widget.api.accounts(),
          widget.api.transactions(),
          widget.api.report('cash-flow'),
        ]).then(
          (values) => _CashData(
            accounts: values[0] as List<Map<String, dynamic>>,
            transactions: values[1] as List<Map<String, dynamic>>,
            cashFlow: Map<String, dynamic>.from(
              (values[2] as Map<String, dynamic>)['summary'] as Map? ?? {},
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CashData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _PageError(
            message: snapshot.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        final data = snapshot.data!;
        final balance = data.accounts.fold<double>(
          0,
          (sum, account) =>
              sum + (double.tryParse('${account['current_balance']}') ?? 0),
        );
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          color: FinkitColors.ink,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const PageTitle(
                title: 'Kasa ve Banka',
                subtitle:
                    'Nakit pozisyonunuzu ve hesap hareketlerinizi izleyin.',
              ),
              SurfaceCard(
                dark: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Nakit',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      moneyText(balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DarkMetric(
                            'Giriş',
                            moneyText(data.cashFlow['inflow']),
                            Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DarkMetric(
                            'Çıkış',
                            moneyText(data.cashFlow['outflow']),
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Hesaplar'),
              if (data.accounts.isEmpty)
                const EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Hesap yok',
                  description: 'Kasa veya banka hesabı tanımlayın.',
                )
              else
                ...data.accounts.map(
                  (account) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      icon: account['account_type'] == 'BANK'
                          ? Icons.account_balance_outlined
                          : Icons.account_balance_wallet_outlined,
                      title: account['name']?.toString() ?? 'Hesap',
                      subtitle: statusLabel(
                        account['account_type']?.toString(),
                      ),
                      value: moneyText(account['current_balance']),
                    ),
                  ),
                ),
              const SectionHeader(title: 'Son Hareketler'),
              if (data.transactions.isEmpty)
                const EmptyState(
                  icon: Icons.swap_vert_rounded,
                  title: 'Hareket yok',
                  description: 'Tahsilat ve ödemeler burada görünecek.',
                )
              else
                ...data.transactions.map((transaction) {
                  final incoming = transaction['direction'] == 'IN';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      icon: incoming
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      title:
                          transaction['description']?.toString() ??
                          statusLabel(transaction['source_type']?.toString()),
                      subtitle:
                          '${dateText(transaction['transaction_date'])} · ${statusLabel(transaction['source_type']?.toString())}',
                      value:
                          '${incoming ? '+' : '-'}${moneyText(transaction['amount'])}',
                      positive: incoming,
                    ),
                  );
                }),
              ExchangeRatesSection(api: widget.api),
            ],
          ),
        );
      },
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.api,
    required this.refreshKey,
    this.partnerType,
  });

  final FinkitApi api;
  final int refreshKey;

  /// 'CUSTOMER' veya 'SUPPLIER'; boş bırakılırsa tüm cari kartlar listelenir.
  final String? partnerType;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  Future<List<Map<String, dynamic>>>? _future;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future = widget.api.partners(type: widget.partnerType);
  }

  Future<void> _openCreateForm() async {
    final created = await showPartnerForm(
      context,
      widget.api,
      defaultType: widget.partnerType ?? 'CUSTOMER',
    );
    if (created && mounted) {
      setState(_load);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cari kartı kaydedildi')));
    }
  }

  Future<void> _editPartner(Map<String, dynamic> partner) async {
    final id = int.tryParse('${partner['id']}');
    if (id == null) return;
    final changes = await showPartnerEditDialog(context, partner);
    if (changes == null || !mounted) return;
    try {
      await widget.api.updatePartner(id, changes);
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cari kartı güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _archivePartner(Map<String, dynamic> partner) async {
    final id = int.tryParse('${partner['id']}');
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cari Kartını Arşivle'),
        content: Text('${partner['name']} arşivlensin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Arşivle'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await widget.api.archivePartner(id);
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _PageError(
            message: snapshot.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        final query = _search.text.toLowerCase();
        final items = snapshot.data!.where((partner) {
          return '${partner['name']} ${partner['tax_number']}'
              .toLowerCase()
              .contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageTitle(
              title: widget.partnerType == 'SUPPLIER'
                  ? 'Tedarikçiler'
                  : 'Müşteriler',
              subtitle: widget.partnerType == 'SUPPLIER'
                  ? 'Tedarikçi kartları, borç bakiyeleri ve ödeme vadeleri.'
                  : 'Cari hesapları, bakiyeleri ve iletişim bilgilerini yönetin.',
              trailing: IconButton.filled(
                onPressed: _openCreateForm,
                style: IconButton.styleFrom(
                  backgroundColor: FinkitColors.ink,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Müşteri, VKN veya telefon ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Müşteri bulunamadı',
                description:
                    'Arama kriterini değiştirin veya yeni müşteri ekleyin.',
              )
            else
              ...items.map(
                (partner) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DataRowCard(
                    icon: Icons.business_outlined,
                    title: partner['name']?.toString() ?? 'Cari',
                    subtitle:
                        '${partner['code'] ?? ''} · ${statusLabel(partner['partner_type']?.toString())}',
                    value: moneyText(partner['balance']),
                    valueSubtitle: 'Cari bakiye',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: FinkitColors.canvas,
                      builder: (_) => PartnerDetailSheet(
                        api: widget.api,
                        partner: partner,
                        onCollect: (id) async {
                          final created = await showCollectionEntryForm(
                            context,
                            widget.api,
                            initialPartnerId: id,
                          );
                          if (created && mounted) setState(_load);
                        },
                        onEdit: _editPartner,
                        onArchive: _archivePartner,
                        onInvoices: (item) async {
                          final id = int.tryParse('${item['id']}');
                          if (id == null || !mounted) return;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => PartnerInvoiceHistoryPage(
                                api: widget.api,
                                partnerId: id,
                                partnerName: '${item['name'] ?? 'Cari'}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  Future<_PayrollData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PayrollPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future = Future.wait([widget.api.employees(), widget.api.payroll()]).then(
      (values) => _PayrollData(
        employees: values[0] as List<Map<String, dynamic>>,
        runs:
            ((values[1] as Map<String, dynamic>)['items'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PayrollData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _PageError(
            message: snapshot.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        final data = snapshot.data!;
        final salaryTotal = data.employees.fold<double>(
          0,
          (sum, employee) =>
              sum + (double.tryParse('${employee['gross_salary']}') ?? 0),
        );
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          color: FinkitColors.ink,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const PageTitle(
                title: 'Personel ve Bordro',
                subtitle: 'Çalışanları, puantajı ve dönemsel bordroyu yönetin.',
              ),
              SummaryGrid(
                items: [
                  SummaryItem(
                    'Aktif Çalışan',
                    '${data.employees.where((e) => e['status'] == 'ACTIVE').length}',
                    Icons.groups_2_outlined,
                  ),
                  SummaryItem(
                    'Brüt Maaş',
                    moneyText(salaryTotal),
                    Icons.payments_outlined,
                  ),
                ],
              ),
              const SectionHeader(title: 'Çalışanlar'),
              if (data.employees.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Çalışan yok',
                  description: 'Personel kartı ekleyerek başlayın.',
                )
              else
                ...data.employees.map(
                  (employee) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      icon: Icons.person_outline_rounded,
                      title:
                          '${employee['first_name']} ${employee['last_name']}',
                      subtitle:
                          '${employee['employee_no']} · ${employee['position'] ?? 'Görev belirtilmedi'}',
                      value: moneyText(employee['gross_salary']),
                      status: employee['status']?.toString(),
                    ),
                  ),
                ),
              const SectionHeader(title: 'Bordro Dönemleri'),
              if (data.runs.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Bordro dönemi yok',
                  description:
                      'Dönemsel bordro hesaplandığında burada görünür.',
                )
              else
                ...data.runs.map(
                  (run) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DataRowCard(
                      icon: Icons.calendar_month_outlined,
                      title:
                          '${run['year']}-${run['month'].toString().padLeft(2, '0')}',
                      subtitle: 'Net ${moneyText(run['net_total'])}',
                      value: moneyText(run['employer_cost_total']),
                      valueSubtitle: 'İşveren maliyeti',
                      status: run['status']?.toString(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.onCustomers,
    required this.onPayroll,
    required this.onReports,
    required this.onLogout,
  });

  final VoidCallback onCustomers;
  final VoidCallback onPayroll;
  final VoidCallback onReports;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Müşteriler',
        'Cari hesaplar ve bakiyeler',
        Icons.people_outline_rounded,
        onCustomers,
      ),
      (
        'Personel ve Bordro',
        'Çalışan ve bordro işlemleri',
        Icons.groups_2_outlined,
        onPayroll,
      ),
      (
        'Raporlar',
        'Finansal rapor merkezi',
        Icons.insert_chart_outlined_rounded,
        onReports,
      ),
      ('Çıkış Yap', 'Oturumu güvenli kapat', Icons.logout_rounded, onLogout),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const PageTitle(
          title: 'Menü',
          subtitle: 'Diğer finans ve muhasebe modüllerine ulaşın.',
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DataRowCard(
              icon: item.$3,
              title: item.$1,
              subtitle: item.$2,
              value: '',
              valueSubtitle: 'Aç',
              onTap: item.$4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseData {
  _ExpenseData({required this.expenses, required this.invoices});

  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> invoices;
}

class _CashData {
  _CashData({
    required this.accounts,
    required this.transactions,
    required this.cashFlow,
  });

  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> cashFlow;
}

class _PayrollData {
  _PayrollData({required this.employees, required this.runs});

  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> runs;
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 46,
              color: FinkitColors.mutedLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Veriler alınamadı',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FinkitColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryItem {
  const SummaryItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.items});

  final List<SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    // Dar ekranlarda kart sayısı kadar sütun kullanılır; böylece 3-4 kart
    // yan yana sığmadığında metin kırpılmaz ve dikey taşma olmaz.
    final columns = items.length.clamp(1, 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 20, color: FinkitColors.muted),
                      const SizedBox(height: 10),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FinkitColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ChoiceChip(
            label: Text(item),
            selected: selected == item,
            onSelected: (_) => onSelected(item),
          );
        },
      ),
    );
  }
}

class PartnerDetailSheet extends StatefulWidget {
  const PartnerDetailSheet({
    super.key,
    required this.api,
    required this.partner,
    this.onCollect,
    this.onEdit,
    this.onArchive,
    this.onInvoices,
  });

  final FinkitApi api;
  final Map<String, dynamic> partner;
  final Future<void> Function(int partnerId)? onCollect;
  final Future<void> Function(Map<String, dynamic> partner)? onEdit;
  final Future<void> Function(Map<String, dynamic> partner)? onArchive;
  final Future<void> Function(Map<String, dynamic> partner)? onInvoices;

  @override
  State<PartnerDetailSheet> createState() => _PartnerDetailSheetState();
}

class _PartnerDetailSheetState extends State<PartnerDetailSheet> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = int.tryParse('${widget.partner['id']}');
    _future = id == null
        ? Future<Map<String, dynamic>>.value(widget.partner)
        : widget.api.partner(id).catchError((_) => widget.partner);
  }

  List<Map<String, dynamic>> _rows(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final partner = snapshot.data ?? widget.partner;
          final addresses = _rows(partner['addresses']);
          final contacts = _rows(partner['contacts']);
          final bankAccounts = _rows(partner['bank_accounts']);
          final openingBalances = _rows(partner['opening_balances']);
          final loading =
              snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner['name']?.toString() ?? 'Cari Detayı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (partner['surname'] != null &&
                    '${partner['surname']}'.trim().isNotEmpty)
                  Text(
                    '${partner['surname']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 18),
                _DetailLine('Kod', '${partner['code'] ?? '—'}'),
                _DetailLine(
                  'Tip',
                  statusLabel(partner['partner_type']?.toString()),
                ),
                _DetailLine('VKN / TCKN', '${partner['tax_number'] ?? '—'}'),
                _DetailLine('Vergi Dairesi', '${partner['tax_office'] ?? '—'}'),
                _DetailLine('Telefon', '${partner['phone'] ?? '—'}'),
                _DetailLine('e-Posta', '${partner['email'] ?? '—'}'),
                _DetailLine('Bakiye', moneyText(partner['balance'])),
                _DetailLine(
                  'e-Dönüşüm',
                  partner['e_transformation_enabled'] == true ? 'Tanımlı' : '—',
                ),
                if (addresses.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _DetailSectionTitle('Adresler'),
                  for (final address in addresses)
                    _DetailLine(
                      '${address['title'] ?? 'Adres'}'
                      '${address['is_default'] == true ? ' (varsayılan)' : ''}',
                      [address['address'], address['district'], address['city']]
                          .where((part) => '${part ?? ''}'.trim().isNotEmpty)
                          .join(', '),
                    ),
                ],
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _DetailSectionTitle('Yetkili Bilgileri'),
                  for (final contact in contacts)
                    _DetailLine(
                      '${contact['full_name'] ?? 'Yetkili'}',
                      '${contact['phone'] ?? contact['email'] ?? '—'}',
                    ),
                ],
                if (bankAccounts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _DetailSectionTitle('IBAN'),
                  for (final account in bankAccounts)
                    _DetailLine(
                      '${account['bank_name'] ?? 'IBAN'}',
                      '${account['iban'] ?? '—'}',
                    ),
                ],
                if (openingBalances.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _DetailSectionTitle('Açılış Bakiyesi'),
                  for (final balance in openingBalances)
                    _DetailLine(
                      balance['direction'] == 'CREDIT' ? 'Alacaklı' : 'Borçlu',
                      '${moneyText(balance['amount'])} '
                      '${balance['currency'] ?? ''}',
                    ),
                ],
                if (loading) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 18),
                if (partner['partner_type'] != 'SUPPLIER' &&
                    widget.onCollect != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final id = int.tryParse('${partner['id']}');
                        if (id == null) return;
                        Navigator.pop(context);
                        widget.onCollect!(id);
                      },
                      icon: const Icon(Icons.call_received_rounded),
                      label: const Text('Tahsilat Al'),
                    ),
                  ),
                if (widget.onEdit != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onEdit!(partner);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Cari Kartını Düzenle'),
                  ),
                if (widget.onInvoices != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onInvoices!(partner);
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Fatura Geçmişi'),
                  ),
                if (widget.onArchive != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onArchive!(partner);
                    },
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Cari Kartını Arşivle'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: FinkitColors.muted,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: FinkitColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
