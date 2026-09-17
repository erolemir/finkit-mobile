import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import 'dashboard_page.dart';
import 'data_pages.dart';
import 'entry_forms.dart';

class FinkitShell extends StatefulWidget {
  const FinkitShell({super.key, required this.api, required this.onLogout});

  final FinkitApi api;
  final Future<void> Function() onLogout;

  @override
  State<FinkitShell> createState() => _FinkitShellState();
}

class _FinkitShellState extends State<FinkitShell> {
  int _index = 0;
  int _refreshKey = 0;
  String _userName = '';
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  /// Üst barda oturum açan kullanıcının adı ve şirketi gösterilir.
  Future<void> _loadIdentity() async {
    if (widget.api.demoMode) {
      if (!mounted) return;
      setState(() {
        _userName = 'Demo Kullanıcı';
        _companyName = '';
      });
      return;
    }
    String? name;
    String? company;
    try {
      final me = await widget.api.me();
      name = me['full_name']?.toString();
    } catch (_) {
      // Kullanıcı bilgisi alınamazsa mevcut değer korunur.
    }
    try {
      final entity = await widget.api.entity();
      // Ticari ad boş bırakılmışsa unvana düşülür.
      final trade = entity['trade_name']?.toString().trim();
      final legal = entity['legal_name']?.toString().trim();
      company = (trade != null && trade.isNotEmpty) ? trade : legal;
    } catch (_) {
      // Şirket bilgisi alınamazsa mevcut değer korunur.
    }
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _userName = name;
      if (company != null && company.isNotEmpty) _companyName = company;
    });
  }

  void _refresh() {
    setState(() => _refreshKey++);
    _loadIdentity();
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Raporlar')),
          body: ReportsPage(
            api: widget.api,
            refreshKey: _refreshKey,
            onOpenReport: (report) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportDetailPage(
                    api: widget.api,
                    report: report,
                    title: reportTitle(report),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCustomers() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Müşteriler')),
          body: CustomersPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ),
    );
  }

  void _openPayroll() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Personel ve Bordro')),
          body: PayrollPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ),
    );
  }

  void _openExpenses() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Giderler')),
          body: ExpensesPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ),
    );
  }

  Future<void> _showQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => _QuickActionSheet(
        api: widget.api,
        onSales: () {
          Navigator.pop(sheetContext);
          setState(() => _index = 1);
        },
        onInvoice: () async {
          Navigator.pop(sheetContext);
          await _showSalesInvoiceForm();
        },
        onCustomer: () async {
          Navigator.pop(sheetContext);
          await _showCustomerForm();
        },
        onExpense: () async {
          Navigator.pop(sheetContext);
          await _showExpenseForm();
          _refresh();
        },
        onCollection: () async {
          Navigator.pop(sheetContext);
          await _showCollectionForm();
          _refresh();
        },
        onReports: () {
          Navigator.pop(sheetContext);
          _openReports();
        },
      ),
    );
  }

  Future<void> _showSalesInvoiceForm() async {
    final created = await showSalesInvoiceForm(context, widget.api);
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış faturası kaydedildi')),
      );
    }
    _refresh();
  }

  Future<void> _showCustomerForm() async {
    final created = await showPartnerForm(context, widget.api);
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cari kartı kaydedildi')));
    }
    _refresh();
  }

  Future<void> _showExpenseForm() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gider Ekle',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Açıklama gerekli'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Net Tutar',
                  prefixIcon: Icon(Icons.currency_lira_rounded),
                ),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Geçerli tutar girin'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await widget.api.createExpense(
                        description: description.text.trim(),
                        netAmount: double.parse(amount.text),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gider kaydedildi')),
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCollectionForm() async {
    final partners = await widget.api.partners();
    final accounts = await widget.api.accounts();
    if (!mounted) return;
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int? partnerId = partners.isNotEmpty ? partners.first['id'] as int? : null;
    int? accountId = accounts.isNotEmpty ? accounts.first['id'] as int? : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tahsilat Al',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: partnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Müşteri',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: partners
                      .map(
                        (partner) => DropdownMenuItem<int>(
                          value: partner['id'] as int?,
                          child: Text(partner['name']?.toString() ?? 'Müşteri'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => partnerId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kasa / Banka',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem<int>(
                          value: account['id'] as int?,
                          child: Text(account['name']?.toString() ?? 'Hesap'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => accountId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tahsilat Tutarı',
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Geçerli tutar girin'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate() ||
                          partnerId == null) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(sheetContext);
                      try {
                        await widget.api.createCollection(
                          partnerId: partnerId!,
                          amount: double.parse(amount.text),
                          accountId: accountId,
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Tahsilat kaydedildi')),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    child: const Text('Tahsilatı Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return SalesPage(
          api: widget.api,
          refreshKey: _refreshKey,
          onQuickAction: _showQuickActions,
        );
      case 2:
        return CashPage(api: widget.api, refreshKey: _refreshKey);
      case 3:
        return MenuPage(
          onCustomers: _openCustomers,
          onPayroll: _openPayroll,
          onReports: _openReports,
          onLogout: () => widget.onLogout(),
        );
      default:
        return DashboardPage(
          api: widget.api,
          refreshKey: _refreshKey,
          onOpenSales: () => setState(() => _index = 1),
          onOpenExpenses: _openExpenses,
          onOpenCash: () => setState(() => _index = 2),
          onOpenReports: _openReports,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Topbar(
              demoMode: widget.api.demoMode,
              userName: _userName,
              companyName: _companyName,
              onRefresh: _refresh,
              onMenu: () => setState(() => _index = 3),
            ),
            Expanded(child: _page()),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        index: _index,
        onSelect: (value) => setState(() => _index = value),
        onAdd: _showQuickActions,
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.demoMode,
    required this.userName,
    required this.companyName,
    required this.onRefresh,
    required this.onMenu,
  });

  final bool demoMode;
  final String userName;
  final String companyName;
  final VoidCallback onRefresh;
  final VoidCallback onMenu;

  /// "Musavir İsmi" -> "Mİ"; boşsa Finkit logosu kullanılır.
  String get _initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  String get _greeting {
    final first = userName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Merhaba' : 'Merhaba, $first';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: FinkitColors.canvas.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x99E7EAEF))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onMenu,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF292C33), Color(0xFF111216)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  demoMode
                      ? 'Demo modu'
                      : (companyName.isNotEmpty ? companyName : 'Finkit'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FinkitColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yeni bildiriminiz yok')),
              );
            },
            icon: Badge(
              smallSize: 8,
              backgroundColor: FinkitColors.danger,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(color: FinkitColors.canvas),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xE7E8EBEF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A131821),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _BottomItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Özet',
              active: index == 0,
              onTap: () => onSelect(0),
            ),
            _BottomItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Faturalar',
              active: index == 1,
              onTap: () => onSelect(1),
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: FinkitColors.ink,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x47101114),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            _BottomItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: 'Kasa',
              active: index == 2,
              onTap: () => onSelect(2),
            ),
            _BottomItem(
              icon: Icons.grid_view_rounded,
              activeIcon: Icons.grid_view_rounded,
              label: 'Menü',
              active: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF0F2F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 21,
                color: active ? FinkitColors.ink : FinkitColors.mutedLight,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: active ? FinkitColors.ink : FinkitColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({
    required this.api,
    required this.onSales,
    required this.onInvoice,
    required this.onCustomer,
    required this.onExpense,
    required this.onCollection,
    required this.onReports,
  });

  final FinkitApi api;
  final VoidCallback onSales;
  final VoidCallback onInvoice;
  final VoidCallback onCustomer;
  final VoidCallback onExpense;
  final VoidCallback onCollection;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Yeni Fatura', Icons.post_add_rounded, onInvoice),
      ('Yeni Müşteri', Icons.person_add_alt_1_rounded, onCustomer),
      ('Gider Ekle', Icons.receipt_long_outlined, onExpense),
      ('Tahsilat', Icons.call_received_rounded, onCollection),
      ('Fatura Listesi', Icons.list_alt_rounded, onSales),
      ('Raporlar', Icons.insert_chart_outlined_rounded, onReports),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hızlı İşlem', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final action in actions)
                InkWell(
                  onTap: action.$3,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FinkitColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(action.$2, color: FinkitColors.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String reportTitle(String report) {
  return switch (report) {
    'sales' => 'Satış Raporu',
    'collections' => 'Tahsilat Raporu',
    'expenses' => 'Gider Raporu',
    'payments' => 'Ödemeler Raporu',
    'vat' => 'KDV Raporu',
    'income-expense' => 'Gelir-Gider Raporu',
    'cash-flow' => 'Nakit Akışı',
    'cash-register' => 'Kasa Raporu',
    'stock' => 'Stok Raporu',
    'aging' => 'Vade Yaşlandırma',
    'payroll' => 'Bordro Raporu',
    _ => 'Rapor',
  };
}
