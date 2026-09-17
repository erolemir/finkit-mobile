import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.onOpenSales,
    required this.onOpenExpenses,
    required this.onOpenCash,
    required this.onOpenReports,
  });

  final FinkitApi api;
  final int refreshKey;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenCash;
  final VoidCallback onOpenReports;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    setState(() {
      _future =
          Future.wait([
            widget.api.summary(),
            widget.api.salesInvoices(),
            widget.api.expenses(),
            widget.api.accounts(),
            widget.api.report('cash-flow'),
          ]).then((values) {
            final summary = values[0] as Map<String, dynamic>;
            final cashFlow = Map<String, dynamic>.from(
              (values[4] as Map<String, dynamic>)['summary'] as Map? ?? {},
            );
            return _DashboardData(
              summary: summary,
              sales: values[1] as List<Map<String, dynamic>>,
              expenses: values[2] as List<Map<String, dynamic>>,
              accounts: values[3] as List<Map<String, dynamic>>,
              cashFlow: cashFlow,
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: _load,
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          color: FinkitColors.ink,
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const PageTitle(
                title: 'Genel Bakış',
                subtitle: 'İşletmenizin bugünkü finansal görünümü.',
              ),
              SizedBox(
                height: 176,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    MetricCard(
                      label: 'Tahsil Edilecek',
                      value: moneyText(data.summary['sales_total']),
                      icon: Icons.trending_up_rounded,
                      foot: 'Bu dönem satışlar',
                      status: 'success',
                      width: 220,
                    ),
                    const SizedBox(width: 12),
                    MetricCard(
                      label: 'Ödenecekler',
                      value: moneyText(data.summary['expense_total']),
                      icon: Icons.trending_down_rounded,
                      foot: 'Bu dönem giderler',
                      status: 'warning',
                      width: 220,
                    ),
                    const SizedBox(width: 12),
                    MetricCard(
                      label: 'Kasa & Banka',
                      value: moneyText(data.summary['cash_balance']),
                      icon: Icons.account_balance_outlined,
                      foot: '${data.accounts.length} aktif hesap',
                      dark: true,
                      width: 220,
                    ),
                    const SizedBox(width: 12),
                    MetricCard(
                      label: 'Net Sonuç',
                      value: moneyText(data.summary['net_total']),
                      icon: Icons.auto_graph_rounded,
                      foot: 'Gelir - gider',
                      status: 'success',
                      width: 220,
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Hızlı İşlemler'),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 0.83,
                children: [
                  QuickTile(
                    icon: Icons.post_add_rounded,
                    label: 'Satış Faturası',
                    primary: true,
                    onTap: widget.onOpenSales,
                  ),
                  QuickTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Gider Ekle',
                    onTap: widget.onOpenExpenses,
                  ),
                  QuickTile(
                    icon: Icons.call_received_rounded,
                    label: 'Tahsilat',
                    onTap: widget.onOpenCash,
                  ),
                  QuickTile(
                    icon: Icons.insert_chart_outlined_rounded,
                    label: 'Raporlar',
                    onTap: widget.onOpenReports,
                  ),
                ],
              ),
              const SectionHeader(title: 'İşletme Özeti'),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Aylık Gelir & Gider',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: moneyText(data.summary['net_total']),
                          value: 'success',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const MiniBarChart(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SurfaceCard(
                      child: Column(
                        children: [
                          const Text(
                            'Tahsilat Oranı',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const CollectionDonut(),
                          const SizedBox(height: 8),
                          Text(
                            '${moneyText(data.summary['sales_total'])} hedef',
                            style: const TextStyle(
                              color: FinkitColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nakit Akışı',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Sparkline(),
                          Text(
                            'Kapanış ${moneyText(data.cashFlow['closing'])}',
                            style: const TextStyle(
                              color: FinkitColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SectionHeader(
                title: 'Son Hareketler',
                action: 'Tümünü Gör',
                onAction: widget.onOpenSales,
              ),
              if (data.sales.isEmpty && data.expenses.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Henüz hareket yok',
                  description:
                      'İlk faturanızı oluşturduğunuzda burada görünecek.',
                )
              else ...[
                ...data.sales
                    .take(3)
                    .map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DataRowCard(
                          icon: Icons.post_add_rounded,
                          title:
                              invoice['number']?.toString() ?? 'Taslak Fatura',
                          subtitle:
                              'Satış faturası · ${dateText(invoice['issue_date'])}',
                          value: '+${moneyText(invoice['gross_amount'])}',
                          positive: true,
                          status: invoice['payment_status']?.toString(),
                        ),
                      ),
                    ),
                ...data.expenses
                    .take(3)
                    .map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DataRowCard(
                          icon: Icons.receipt_long_outlined,
                          title: expense['description']?.toString() ?? 'Gider',
                          subtitle:
                              'Gider · ${dateText(expense['expense_date'])}',
                          value: '-${moneyText(expense['total_amount'])}',
                          positive: false,
                          status: expense['payment_status']?.toString(),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DashboardData {
  _DashboardData({
    required this.summary,
    required this.sales,
    required this.expenses,
    required this.accounts,
    required this.cashFlow,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic> cashFlow;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
