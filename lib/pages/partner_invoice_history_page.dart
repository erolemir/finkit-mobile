import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class PartnerInvoiceHistoryPage extends StatefulWidget {
  const PartnerInvoiceHistoryPage({
    super.key,
    required this.api,
    required this.partnerId,
    required this.partnerName,
  });
  final FinkitApi api;
  final int partnerId;
  final String partnerName;

  @override
  State<PartnerInvoiceHistoryPage> createState() =>
      _PartnerInvoiceHistoryPageState();
}

class _PartnerInvoiceHistoryPageState extends State<PartnerInvoiceHistoryPage> {
  int _outgoingPage = 1;
  int _incomingPage = 1;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.api.partnerInvoiceOverview(
      widget.partnerId,
      outgoingPage: _outgoingPage,
      incomingPage: _incomingPage,
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> direction) =>
      (direction['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  Widget _section(String title, Map<String, dynamic> direction, bool outgoing) {
    final rows = _rows(direction);
    final page = outgoing ? _outgoingPage : _incomingPage;
    final count = int.tryParse('${direction['count']}') ?? rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: '$title · ${direction['total'] ?? 0} TRY'),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Fatura yok',
            description: 'Bu yönde fatura kaydı bulunamadı.',
          ),
        for (final row in rows)
          DataRowCard(
            icon: outgoing ? Icons.outbox_outlined : Icons.inbox_outlined,
            title: '${row['number'] ?? 'Numarasız fatura'}',
            subtitle:
                '${row['display_date'] ?? row['issue_date'] ?? ''} · ${row['invoice_type'] ?? ''}',
            value: '${row['amount'] ?? 0} ${row['currency'] ?? 'TRY'}',
          ),
        if (count > 20)
          Row(
            children: [
              TextButton(
                onPressed: page <= 1
                    ? null
                    : () => setState(() {
                        if (outgoing) {
                          _outgoingPage--;
                        } else {
                          _incomingPage--;
                        }
                        _load();
                      }),
                child: const Text('Önceki'),
              ),
              Text('$page / ${(count / 20).ceil()}'),
              TextButton(
                onPressed: page * 20 >= count
                    ? null
                    : () => setState(() {
                        if (outgoing) {
                          _outgoingPage++;
                        } else {
                          _incomingPage++;
                        }
                        _load();
                      }),
                child: const Text('Sonraki'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.partnerName} · Faturalar')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: Text(
                'Fatura geçmişi yüklenemedi: ${snapshot.error} · Tekrar dene',
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageTitle(title: widget.partnerName, subtitle: 'Fatura geçmişi'),
              _section(
                'Giden faturalar',
                Map<String, dynamic>.from(data['outgoing'] as Map? ?? {}),
                true,
              ),
              _section(
                'Gelen faturalar',
                Map<String, dynamic>.from(data['incoming'] as Map? ?? {}),
                false,
              ),
            ],
          ),
        );
      },
    ),
  );
}
