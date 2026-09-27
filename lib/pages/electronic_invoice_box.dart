import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';
import 'electronic_invoice_page.dart';
import 'einvoice_settings_page.dart';

class ElectronicInvoiceBox extends StatefulWidget {
  const ElectronicInvoiceBox({
    super.key,
    required this.api,
    required this.isClient,
    required this.incoming,
    required this.documentType,
    required this.refreshKey,
  });

  final FinkitApi api;
  final bool isClient;
  final bool incoming;
  final String documentType;
  final int refreshKey;

  @override
  State<ElectronicInvoiceBox> createState() => _ElectronicInvoiceBoxState();
}

class _ElectronicInvoiceBoxState extends State<ElectronicInvoiceBox> {
  final _search = TextEditingController();
  final _identifier = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _status = '';
  int _page = 1;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ElectronicInvoiceBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.documentType != widget.documentType ||
        oldWidget.isClient != widget.isClient ||
        oldWidget.incoming != widget.incoming) {
      _page = 1;
      _reload();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _identifier.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.electronicInvoiceBox(
      isClient: widget.isClient,
      incoming: widget.incoming,
      documentType: widget.documentType,
      status: _status,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
      customerIdentifier: _identifier.text.trim(),
      page: _page,
    );
  }

  void _applyFilters() {
    final start = _start.text.trim();
    final end = _end.text.trim();
    final valid = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if ((start.isNotEmpty && !valid.hasMatch(start)) ||
        (end.isNotEmpty && !valid.hasMatch(end)) ||
        (start.isNotEmpty && end.isNotEmpty && start.compareTo(end) > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir tarih aralığı girin (YYYY-AA-GG).'),
        ),
      );
      return;
    }
    setState(() {
      _page = 1;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final archive = widget.documentType == 'EARCHIVE';
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PageTitle(
            title: widget.incoming
                ? 'Gelen Belgeler'
                : archive
                ? 'E-Arşiv Faturalar'
                : 'Giden E-Faturalar',
            subtitle: widget.incoming
                ? 'Size gönderilen E-Faturaları ve yanıt bekleyen ticari faturaları görüntüleyin.'
                : 'Gönderilen belgeleri ve durumlarını izleyin.',
          ),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Bu sayfada fatura, firma veya belge no ara',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Durum'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tüm durumlar')),
              DropdownMenuItem(value: 'QUEUED', child: Text('Kuyrukta')),
              DropdownMenuItem(value: 'UNKNOWN', child: Text('Bilinmiyor')),
              DropdownMenuItem(value: 'SENT', child: Text('Gönderildi')),
              DropdownMenuItem(
                value: 'DELIVERED',
                child: Text('Teslim edildi'),
              ),
              DropdownMenuItem(value: 'WAITING', child: Text('Yanıt bekliyor')),
              DropdownMenuItem(value: 'ACCEPTED', child: Text('Kabul edildi')),
              DropdownMenuItem(value: 'REJECTED', child: Text('Reddedildi')),
              DropdownMenuItem(value: 'REPORTED', child: Text('Raporlandı')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('İptal edildi')),
              DropdownMenuItem(value: 'ERROR', child: Text('Hata')),
            ],
            onChanged: (value) => setState(() {
              _status = value ?? '';
              _page = 1;
              _reload();
            }),
          ),
          if (!widget.incoming) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _identifier,
              decoration: const InputDecoration(labelText: 'Alıcı VKN/TCKN'),
              onSubmitted: (_) => _applyFilters(),
            ),
          ],
          const SizedBox(height: 10),
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
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                final needsAccount =
                    error is ApiException &&
                    error.statusCode == 404 &&
                    error.message.toLowerCase().contains('izibiz');
                return Column(
                  children: [
                    Text('Belgeler yüklenemedi: $error'),
                    if (needsAccount)
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EInvoiceSettingsPage(
                                api: widget.api,
                                isClient: widget.isClient,
                              ),
                            ),
                          );
                          if (mounted) setState(_reload);
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('İzibiz hesabını tanımla'),
                      ),
                    TextButton.icon(
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                );
              }
              final items = (snapshot.data?['items'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              final query = _search.text.trim().toLowerCase();
              final filtered = items
                  .where(
                    (item) =>
                        query.isEmpty ||
                        [
                          item['invoice_number'],
                          item['document_no'],
                          item['documentNo'],
                          item['number'],
                          item['sender_name'],
                          item['senderName'],
                          item['receiver_name'],
                          item['customer_name'],
                          item['supplierName'],
                          item['uuid'],
                        ].any((v) => '$v'.toLowerCase().contains(query)),
                  )
                  .toList();
              final total =
                  int.tryParse('${snapshot.data?['total']}') ?? items.length;
              return Column(
                children: [
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: widget.incoming
                          ? Icons.move_to_inbox_outlined
                          : Icons.upload_file_outlined,
                      title: query.isNotEmpty
                          ? 'Bu sayfada eşleşen belge yok'
                          : 'Belge bulunamadı',
                      description: query.isNotEmpty
                          ? 'Başka sayfalarda aramak için sayfaları kullanın.'
                          : 'Seçilen filtrelerde belge bulunmuyor.',
                    ),
                  for (final item in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DataRowCard(
                        document: item,
                        icon: widget.incoming
                            ? Icons.inbox_outlined
                            : Icons.receipt_long_outlined,
                        title:
                            '${item['invoice_number'] ?? item['document_no'] ?? item['documentNo'] ?? item['number'] ?? item['provider_id'] ?? item['uuid'] ?? 'Belge'}',
                        subtitle:
                            '${item[widget.incoming ? 'sender_name' : 'receiver_name'] ?? item[widget.incoming ? 'supplierName' : 'customer_name'] ?? item['status'] ?? '—'} · ${dateText(item['issue_date'] ?? item['issueDate'] ?? item['created_at'])}',
                        value: moneyText(
                          item['total'] ??
                              item['amount'] ??
                              item['payable_amount'],
                        ),
                        status: item['status']?.toString(),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ElectronicInvoicePage(
                                api: widget.api,
                                invoice: item,
                                isClient: widget.isClient,
                                incoming: widget.incoming,
                              ),
                            ),
                          );
                          if (mounted) setState(_reload);
                        },
                      ),
                    ),
                  if (total > 20 || _page > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            'Sayfa $_page · $total belge',
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
  }
}
