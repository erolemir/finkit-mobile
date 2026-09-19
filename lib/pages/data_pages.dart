export 'reports_page.dart';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_forms.dart';
import 'invoice_detail_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.onQuickAction,
  });

  final FinkitApi api;
  final int refreshKey;
  final VoidCallback onQuickAction;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  String _filter = 'Tümü';
  String _search = '';
  Future<List<Map<String, dynamic>>>? _future;
  Future<List<Map<String, dynamic>>>? _partnersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SalesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future = widget.api.salesInvoices();
    _partnersFuture = widget.api.partners();
  }

  Future<void> _openCreateForm() async {
    final created = await showSalesInvoiceForm(context, widget.api);
    if (created && mounted) {
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış faturası kaydedildi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, salesSnapshot) {
        if (salesSnapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (salesSnapshot.hasError) {
          return _PageError(
            message: salesSnapshot.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _partnersFuture,
          builder: (context, partnerSnapshot) {
            final partners =
                partnerSnapshot.data ?? const <Map<String, dynamic>>[];
            final all = salesSnapshot.data ?? const <Map<String, dynamic>>[];
            final items = all.where((invoice) {
              if (!'${invoice['number']} ${_partnerName(partners, invoice['partner_id'])}'
                  .toLowerCase()
                  .replaceAll('ı', 'i')
                  .contains(_search)) {
                return false;
              }
              final payment = invoice['payment_status']?.toString() ?? '';
              return switch (_filter) {
                'Ödenen' => payment == 'PAID',
                'Bekleyen' => payment == 'UNPAID' || payment == 'PARTIAL',
                'Geciken' => payment == 'OVERDUE',
                _ => true,
              };
            }).toList();
            final total = all.fold<double>(
              0,
              (sum, item) =>
                  sum + (double.tryParse('${item['gross_amount']}') ?? 0),
            );
            final unpaid = all
                .where((item) => item['payment_status'] != 'PAID')
                .fold<double>(
                  0,
                  (sum, item) =>
                      sum + (double.tryParse('${item['gross_amount']}') ?? 0),
                );
            return RefreshIndicator(
              onRefresh: () async => setState(_load),
              color: FinkitColors.ink,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  PageTitle(
                    title: 'Satış Faturaları',
                    subtitle: 'Faturaları izleyin, durumlarını ve tahsilatlarını yönetin.',
                    trailing: IconButton.filled(
                      onPressed: _openCreateForm,
                      style: IconButton.styleFrom(
                        backgroundColor: FinkitColors.ink,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                  SummaryGrid(
                    items: [
                      SummaryItem(
                        'Toplam Satış',
                        moneyText(total),
                        Icons.trending_up_rounded,
                      ),
                      SummaryItem(
                        'Bekleyen',
                        moneyText(unpaid),
                        Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Fatura veya müşteri ara',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(
                      () => _search = value.toLowerCase().replaceAll('ı', 'i'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilterRow(
                    items: const ['Tümü', 'Ödenen', 'Bekleyen', 'Geciken'],
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.post_add_rounded,
                      title: 'Fatura bulunamadı',
                      description:
                          'Bu filtreye uygun satış faturası bulunmuyor.',
                    )
                  else
                    ...items.map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DataRowCard(
                          icon: Icons.post_add_rounded,
                          title:
                              invoice['number']?.toString() ?? 'Taslak Fatura',
                          subtitle:
                              '${_partnerName(partners, invoice['partner_id'])} · ${dateText(invoice['issue_date'])}',
                          value: moneyText(invoice['gross_amount']),
                          valueSubtitle:
                              'Vade ${dateText(invoice['due_date'])}',
                          status: invoice['payment_status']?.toString(),
                          onTap: () async {
                            await openInvoiceDetail(
                              context,
                              widget.api,
                              invoice,
                            );
                            if (mounted) setState(_load);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _partnerName(List<Map<String, dynamic>> partners, dynamic id) {
    final matches = partners
        .where((partner) => partner['id'] == id)
        .map((partner) => partner['name']?.toString() ?? '')
        .toList();
    return matches.isNotEmpty ? matches.first : 'Müşteri #$id';
  }
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
                subtitle: 'Gelen faturaları ve işletme giderlerini tek akışta yönetin.',
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

  void _load() => _future = widget.api.partners(type: widget.partnerType);

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
                      builder: (_) =>
                          PartnerDetailSheet(api: widget.api, partner: partner),
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
  });

  final FinkitApi api;
  final Map<String, dynamic> partner;

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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call_received_rounded),
                    label: const Text('Tahsilat Al'),
                  ),
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
