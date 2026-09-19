import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';

const _reports = [
  (
    'sales',
    'Satış Raporu',
    'Ciro, vergi ve satış dağılımı',
    'Satış',
    Icons.trending_up_rounded,
  ),
  (
    'collections',
    'Tahsilat Raporu',
    'Tahsilatlar ve açık alacaklar',
    'Satış',
    Icons.call_received_rounded,
  ),
  (
    'expenses',
    'Gider Raporu',
    'Giderlerinizi kategorilere göre inceleyin',
    'Gider',
    Icons.receipt_long_outlined,
  ),
  (
    'payments',
    'Ödemeler Raporu',
    'Tedarikçi ve personel ödemeleri',
    'Gider',
    Icons.payments_outlined,
  ),
  (
    'income-expense',
    'Gelir-Gider Raporu',
    'Gelir, maliyet ve net sonuç',
    'Finans',
    Icons.auto_graph_rounded,
  ),
  (
    'cash-flow',
    'Nakit Akışı',
    'Nakit girişleri, çıkışları ve beklentiler',
    'Finans',
    Icons.swap_vert_rounded,
  ),
  (
    'cash-register',
    'Kasa Raporu',
    'Hesap bazında açılış ve kapanış',
    'Finans',
    Icons.account_balance_wallet_outlined,
  ),
  (
    'vat',
    'KDV Raporu',
    'Hesaplanan, indirilecek ve ödenecek KDV',
    'Gider',
    Icons.percent_rounded,
  ),
  (
    'aging',
    'Vade Yaşlandırma',
    'Geciken alacaklar ve vade dağılımı',
    'Satış',
    Icons.schedule_rounded,
  ),
  (
    'stock',
    'Stok Raporu',
    'Stok miktarı, değeri ve kritik ürünler',
    'Operasyon',
    Icons.inventory_2_outlined,
  ),
  (
    'payroll',
    'Bordro Raporu',
    'Brüt, net ve işveren maliyeti',
    'Operasyon',
    Icons.groups_2_outlined,
  ),
];

Color _categoryColor(String category) => switch (category) {
  'Satış' => const Color(0xFF087F70),
  'Gider' => const Color(0xFFB75332),
  'Operasyon' => FinkitColors.violet,
  _ => FinkitColors.primary,
};

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.onOpenReport,
  });
  final FinkitApi api;
  final int refreshKey;
  final ValueChanged<String> onOpenReport;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> _summary;
  String _query = '';
  String _category = 'Tümü';
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _summary = widget.api.summary();
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.api != widget.api) {
      _summary = widget.api.summary();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _reports
        .where(
          (r) =>
              (_category == 'Tümü' || r.$4 == _category) &&
              '${r.$2} ${r.$3}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _summary = widget.api.summary());
        await _summary;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const PageTitle(
            title: 'Finansal bakış',
            subtitle: 'Doğru rapora ulaşın, rakamların arkasını görün.',
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _summary,
            builder: (context, snapshot) => SurfaceCard(
              dark: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BU AYIN ÖZETİ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator()
                  else if (snapshot.hasError) ...[
                    const Text(
                      'Özet yüklenemedi. Raporları aşağıdan açabilirsiniz.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _summary = widget.api.summary()),
                      child: const Text(
                        'Yeniden dene',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ] else ...[
                    Text(
                      moneyText(snapshot.data?['net_total']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Net sonuç',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nakit bakiye  ${moneyText(snapshot.data?['cash_balance'])}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Rapor ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Aramayı temizle',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Tümü', 'Satış', 'Gider', 'Finans', 'Operasyon']
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SectionHeader(title: 'Rapor kütüphanesi · ${items.length}'),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Eşleşen rapor yok',
              description:
                  'Başka bir kelime arayın veya Tümü kategorisini seçin.',
            ),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                onTap: () => widget.onOpenReport(r.$1),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _categoryColor(r.$4).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(r.$5, color: _categoryColor(r.$4)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.$2,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FinkitColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: FinkitColors.muted,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String reportValue(String key, dynamic value) {
  if (value == null) return '—';
  final number = num.tryParse('$value');
  if (number == null) return '$value';
  if (key == 'count' ||
      key.endsWith('_count') ||
      key == 'quantity' ||
      key == 'days_overdue' ||
      key == 'year' ||
      key == 'month') {
    return NumberFormat.decimalPattern('tr_TR').format(number);
  }
  if (key.contains('rate')) {
    return '%${NumberFormat.decimalPattern('tr_TR').format(number)}';
  }
  return moneyText(number);
}

String reportLabel(String key) => _labels[key] ?? key.replaceAll('_', ' ');
const _labels = {
  'sales_gross': 'Brüt satış', 'cost_of_sales': 'Satış maliyeti',
  'fx_gain': 'Kur farkı geliri', 'fx_loss': 'Kur farkı gideri',
  'operating_result': 'Faaliyet sonucu', 'net_result': 'Net sonuç',
  'partner': 'Cari', 'product': 'Ürün', 'warehouse': 'Depo', 'category': 'Kategori',
  'account': 'Hesap', 'invoice': 'Fatura', 'bucket': 'Vade grubu',
  'net': 'Net tutar',
  'vat': 'KDV',
  'gross': 'Genel toplam',
  'total': 'Toplam',
  'count': 'Kayıt sayısı',
  'invoice_count': 'Fatura sayısı',
  'item_count': 'Ürün sayısı',
  'movement_count': 'Hareket sayısı',
  'low_stock_count': 'Kritik stok',
  'run_count': 'Bordro sayısı',
  'sales_total': 'Satış toplamı',
  'expense_total': 'Gider toplamı',
  'net_total': 'Net sonuç',
  'cash_balance': 'Nakit bakiye',
  'allocated': 'Dağıtılan tahsilat',
  'unallocated': 'Avans',
  'pending_receivables': 'Bekleyen alacak',
  'overdue_receivables': 'Gecikmiş alacak',
  'output_vat': 'Hesaplanan KDV',
  'input_vat': 'İndirilecek KDV',
  'payable': 'Ödenecek KDV',
  'carried_out': 'Devreden KDV',
  'carried_in': 'Önceki dönem KDV',
  'output_withholding': 'Satış tevkifatı',
  'input_withholding': 'Alış tevkifatı',
  'kdv2': 'KDV 2',
  'other_adjustments': 'Diğer düzeltmeler',
  'payable_or_carried': 'KDV bakiyesi',
  'opening': 'Açılış',
  'closing': 'Kapanış',
  'inflow': 'Nakit girişi',
  'outflow': 'Nakit çıkışı',
  'projected_closing': 'Beklenen kapanış',
  'upcoming_receivables': 'Beklenen alacak',
  'upcoming_payables': 'Beklenen ödeme',
  'gross_total': 'Brüt toplam',
  'employer_cost_total': 'İşveren maliyeti',
  'supplier_payments': 'Tedarikçi ödemeleri',
  'expense_payments': 'Gider ödemeleri',
  'payroll_payments': 'Bordro ödemeleri',
  'quantity': 'Miktar',
  'value': 'Stok değeri',
  'movement_in_value': 'Stok giriş değeri',
  'movement_out_value': 'Stok çıkış değeri',
  'not_due': 'Vadesi gelmemiş',
  '0_30': '1–30 gün gecikmiş',
  '31_60': '31–60 gün gecikmiş',
  '61_90': '61–90 gün gecikmiş',
  '90_plus': '90 günden fazla',
  'sales_net': 'Net satış',
  'sales_vat': 'Satış KDV',
  'expense_net': 'Net gider',
  'expense_vat': 'Gider KDV',
  'cost_of_goods': 'Satış maliyeti',
  'gross_profit': 'Brüt kâr',
  'net_profit': 'Net kâr',
  'cash_in': 'Nakit girişi',
  'cash_out': 'Nakit çıkışı',
  'net_cash_result': 'Net nakit sonucu',
  'by_month': 'Aylık dağılım',
  'by_partner': 'Müşteri dağılımı',
  'by_product': 'Ürün dağılımı',
  'by_warehouse': 'Depo dağılımı',
  'by_category': 'Kategori dağılımı',
  'by_supplier': 'Tedarikçi dağılımı',
  'by_status': 'Durum dağılımı',
  'by_method': 'Ödeme yöntemi',
  'items': 'Kayıt detayları',
  'movements': 'Stok hareketleri',
  'accounts': 'Hesaplar',
  'amount': 'Tutar',
  'remaining': 'Kalan tutar',
  'manual_cost': 'Birim maliyet',
  'unit_cost': 'Birim maliyet',
  'total_cost': 'Toplam maliyet',
  'days_overdue': 'Gecikme günü',
  'date': 'Tarih',
  'due_date': 'Vade',
  'period': 'Dönem',
  'description': 'Açıklama',
  'status': 'Durum',
  'payment_status': 'Ödeme durumu',
  'method': 'Yöntem',
  'payment_method': 'Ödeme yöntemi',
  'direction': 'Yön',
  'number': 'Belge no',
  'product_name': 'Ürün',
  'warehouse_name': 'Depo',
  'product_code': 'Ürün kodu',
  'name': 'Ad',
  'year': 'Yıl',
  'month': 'Ay',
};

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.api,
    required this.report,
    required this.title,
  });
  final FinkitApi api;
  final String report;
  final String title;
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Future<Map<String, dynamic>> _future;
  late DateTimeRange _range;
  String _preset = 'Bu ay';
  String _basis = 'accrual';
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateUtils.dateOnly(now),
    );
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => widget.api.report(
    widget.report,
    basis: _basis,
    startDate: DateFormat('yyyy-MM-dd').format(_range.start),
    endDate: DateFormat('yyyy-MM-dd').format(_range.end),
  );
  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _select(String preset) {
    final now = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _preset = preset;
      _range = switch (preset) {
        'Geçen ay' => DateTimeRange(
          start: DateTime(now.year, now.month - 1),
          end: DateTime(now.year, now.month, 0),
        ),
        'Bu yıl' => DateTimeRange(start: DateTime(now.year), end: now),
        _ => DateTimeRange(start: DateTime(now.year, now.month), end: now),
      };
      _future = _load();
    });
  }

  Future<void> _pick() async {
    if (widget.report == 'aging') {
      final date = await showDatePicker(
        context: context,
        initialDate: _range.end,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Vade değerlendirme tarihi',
        cancelText: 'Vazgeç',
        confirmText: 'Uygula',
      );
      if (date == null || !mounted) return;
      setState(() {
        _preset = 'Özel';
        _range = DateTimeRange(start: date, end: date);
        _future = _load();
      });
    } else {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Rapor dönemini seçin',
        cancelText: 'Vazgeç',
        saveText: 'Uygula',
      );
      if (range == null || !mounted) return;
      setState(() {
        _preset = 'Özel';
        _range = range;
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = widget.report == 'stock'
        ? 'Güncel stok durumu'
        : widget.report == 'aging'
        ? '${dateText(_range.end.toIso8601String())} itibarıyla'
        : '${dateText(_range.start.toIso8601String())} – ${dateText(_range.end.toIso8601String())}';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Raporu yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.report != 'stock')
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(dateLabel),
                  )
                else
                  Text(
                    dateLabel,
                    style: const TextStyle(color: FinkitColors.muted),
                  ),
                if (widget.report != 'stock' && widget.report != 'aging')
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Bu ay', 'Geçen ay', 'Bu yıl']
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(p),
                                selected: _preset == p,
                                onSelected: (_) => _select(p),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (widget.report == 'income-expense')
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final b in [
                        ('accrual', 'Tahakkuk'),
                        ('cash', 'Nakit'),
                      ])
                        ChoiceChip(
                          label: Text(b.$2),
                          selected: _basis == b.$1,
                          onSelected: (_) {
                            setState(() {
                              _basis = b.$1;
                              _future = _load();
                            });
                          },
                        ),
                    ],
                  ),
                if (widget.api.demoMode)
                  const Text(
                    'Demo verisi · Dönem değiştiğinde örnek tutarlar sabit kalır.',
                    style: TextStyle(fontSize: 11, color: FinkitColors.muted),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: FinkitColors.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Rapor yüklenemedi',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Yeniden dene'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snapshot.data ?? {};
                final summary = Map<String, dynamic>.from(
                  data['summary'] is Map ? data['summary'] : {},
                );
                final sections = data.entries
                    .where(
                      (e) => e.value is List && (e.value as List).isNotEmpty,
                    )
                    .toList();
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      if (summary.isEmpty && sections.isEmpty)
                        const EmptyState(
                          icon: Icons.insert_chart_outlined_rounded,
                          title: 'Bu dönemde kayıt yok',
                          description: 'Başka bir dönem seçerek raporunuzu görüntüleyebilirsiniz.',
                        ),
                      if (summary.isNotEmpty) ...[
                        const Text(
                          'DÖNEM GÖSTERGELERİ',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: FinkitColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final e in summary.entries)
                                SizedBox(
                                  width:
                                      constraints.maxWidth < 340 ||
                                          MediaQuery.textScalerOf(context)
                                                  .scale(1) >
                                              1.3
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2,
                                  child: _Indicator(
                                    label: reportLabel(e.key),
                                    value: reportValue(e.key, e.value),
                                    color: _metricColor(e.key, e.value),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_comparison(summary).length >= 2) ...[
                          const SectionHeader(title: 'Tutar karşılaştırması'),
                          SurfaceCard(
                            child: _Bars(entries: _comparison(summary)),
                          ),
                        ],
                      ],
                      for (final section in sections)
                        _Breakdown(
                          key: ValueKey(
                            '${widget.report}:$_preset:$_basis:$_range:${section.key}',
                          ),
                          name: section.key,
                          rows: (section.value as List)
                              .whereType<Map>()
                              .map((r) => Map<String, dynamic>.from(r))
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _metricColor(String key, dynamic value) {
  if ((num.tryParse('$value') ?? 0) < 0 ||
      key.contains('overdue') ||
      key == 'low_stock_count' ||
      key == '90_plus') {
    return const Color(0xFFB73649);
  }
  if (key.contains('expense') ||
      key.contains('outflow') ||
      key.contains('payable') ||
      key.contains('cost')) {
    return const Color(0xFFB75332);
  }
  if (key.contains('vat') || key.contains('count')) return FinkitColors.violet;
  return FinkitColors.primary;
}

List<MapEntry<String, dynamic>> _comparison(Map<String, dynamic> summary) {
  for (final keys in [
    ['sales_gross', 'expense_total'],
    ['inflow', 'outflow'],
    ['cash_in', 'cash_out'],
    ['sales_net', 'expense_net'],
    ['sales_total', 'expense_total'],
    ['output_vat', 'input_vat'],
    ['allocated', 'unallocated'],
    ['supplier_payments', 'expense_payments', 'payroll_payments'],
    ['not_due', '0_30', '31_60', '61_90', '90_plus'],
    ['net', 'vat'],
    ['gross_total', 'net_total'],
  ]) {
    if (keys.every(summary.containsKey)) {
      return keys.map((k) => MapEntry(k, summary[k])).toList();
    }
  }
  return [];
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: FinkitColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ],
    ),
  );
}

class _Bars extends StatelessWidget {
  const _Bars({required this.entries});
  final List<MapEntry<String, dynamic>> entries;
  @override
  Widget build(BuildContext context) {
    final max = entries.fold<double>(0, (v, e) {
      final n = (double.tryParse('${e.value}') ?? 0).abs();
      return n > v ? n : v;
    });
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  children: [
                    Text(
                      reportLabel(e.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      reportValue(e.key, e.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: max == 0
                      ? 0
                      : ((double.tryParse('${e.value}') ?? 0).abs() / max)
                            .clamp(0, 1),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: _metricColor(e.key, e.value),
                  backgroundColor: FinkitColors.line,
                  semanticsLabel:
                      '${reportLabel(e.key)} ${reportValue(e.key, e.value)}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Breakdown extends StatefulWidget {
  const _Breakdown({super.key, required this.name, required this.rows});
  final String name;
  final List<Map<String, dynamic>> rows;
  @override
  State<_Breakdown> createState() => _BreakdownState();
}

class _BreakdownState extends State<_Breakdown> {
  int _limit = 10;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.rows
        .where(
          (r) =>
              r.values.join(' ').toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '${reportLabel(widget.name)} · ${widget.rows.length}',
        ),
        if (widget.rows.length > 5)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              onChanged: (v) => setState(() {
                _query = v;
                _limit = 10;
              }),
              decoration: const InputDecoration(
                hintText: 'Bu listede ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aramanızla eşleşen kayıt yok.'),
          ),
        for (final row in rows.take(_limit))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in row.entries.where(
                    (e) =>
                        e.value != null && e.value is! Map && e.value is! List,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Text(
                            e.key.endsWith('_id') || e.key == 'id'
                                ? '${reportLabel(e.key.replaceAll('_id', ''))} no'
                                : reportLabel(e.key),
                            style: const TextStyle(
                              color: FinkitColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _cell(e.key, e.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (rows.length > _limit)
          OutlinedButton(
            onPressed: () => setState(() => _limit += 20),
            child: Text('Daha fazla göster (${rows.length - _limit})'),
          ),
      ],
    );
  }

  String _cell(String key, dynamic value) {
    if (key.endsWith('_id') ||
        key == 'id' ||
        key == 'number' ||
        key == 'product_code') {
      return '$value';
    }
    if (key == 'date' || key.endsWith('_date')) return dateText(value);
    if (key.contains('status') || key == 'method' || key == 'payment_method') {
      return statusLabel('$value');
    }
    if (key == 'direction') {
      return switch (value) {
        'IN' || 'TRANSFER_IN' => 'Giriş',
        'OUT' || 'TRANSFER_OUT' => 'Çıkış',
        _ => '$value',
      };
    }
    return reportValue(key, value);
  }
}
