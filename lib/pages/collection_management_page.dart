import 'dart:math';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class CollectionManagementPage extends StatefulWidget {
  const CollectionManagementPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });
  final FinkitApi api;
  final int refreshKey;

  @override
  State<CollectionManagementPage> createState() =>
      _CollectionManagementPageState();
}

class _CollectionManagementPageState extends State<CollectionManagementPage> {
  final _search = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _method = '';
  int? _partnerId;
  int? _accountId;
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  late Future<List<List<Map<String, dynamic>>>> _options;

  @override
  void initState() {
    super.initState();
    _reload();
    _options = Future.wait([
      widget.api.partners(type: 'CUSTOMER'),
      widget.api.accounts(),
    ]);
  }

  @override
  void didUpdateWidget(covariant CollectionManagementPage oldWidget) {
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
    _future = widget.api.collectionPage(
      page: _page,
      search: _search.text.trim(),
      paymentMethod: _method,
      partnerId: _partnerId,
      financialAccountId: _accountId,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
    );
  }

  void _filter() {
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

  Future<void> _edit([Map<String, dynamic>? item]) async {
    try {
      final changed = await showCollectionForm(context, widget.api, item: item);
      if (changed && mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tahsilatı kaldır'),
        content: const Text(
          'Faturaya dağıtılan tutarlar geri alınır. Bu tahsilatı kaldırmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteCollection(id);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(
          title: 'Tahsilatlar',
          subtitle: 'Faturaya dağıtılan tutarı ve kalan avansı izleyin.',
          trailing: IconButton.filled(
            tooltip: 'Yeni tahsilat',
            onPressed: _edit,
            icon: const Icon(Icons.add),
          ),
        ),
        TextField(
          controller: _search,
          decoration: const InputDecoration(labelText: 'Referans / not ara'),
          onSubmitted: (_) => _filter(),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Ödeme yöntemi'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Tümü')),
            DropdownMenuItem(value: 'NAKIT', child: Text('Nakit')),
            DropdownMenuItem(value: 'HAVALE', child: Text('Havale/EFT')),
            DropdownMenuItem(value: 'KREDI_KARTI', child: Text('Kredi kartı')),
            DropdownMenuItem(value: 'CEK', child: Text('Çek')),
          ],
          onChanged: (value) => setState(() {
            _method = value ?? '';
            _page = 1;
            _reload();
          }),
        ),
        FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: _options,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final partners = snapshot.data![0];
            final accounts = snapshot.data![1];
            return Column(
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _partnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Müşteri'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...partners.map(
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
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kasa / banka'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...accounts.map(
                      (a) => DropdownMenuItem<int?>(
                        value: (a['id'] as num).toInt(),
                        child: Text(
                          '${a['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _accountId = value;
                    _page = 1;
                    _reload();
                  }),
                ),
              ],
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
                child: Text('Tahsilatlar yüklenemedi: ${snapshot.error}'),
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
                    icon: Icons.call_received_rounded,
                    title: 'Tahsilat yok',
                    description: 'Seçilen filtrelerde tahsilat bulunmuyor.',
                  ),
                for (final item in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${dateText(item['collection_date'])} · ${item['payment_method'] ?? '—'}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            moneyText(item['amount']),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Dağıtılan: ${moneyText(item['allocated_amount'])} · Avans: ${moneyText(item['unallocated_amount'])}',
                          ),
                          if ('${item['notes'] ?? ''}'.isNotEmpty)
                            Text('${item['notes']}'),
                          Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _edit(item),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Düzenle'),
                              ),
                              TextButton.icon(
                                onPressed: () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Kaldır'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          'Sayfa $_page · $total tahsilat',
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

Future<bool> showCollectionForm(
  BuildContext context,
  FinkitApi api, {
  Map<String, dynamic>? item,
}) async {
  final editing = item != null;
  final resources = await Future.wait([
    api.partners(type: 'CUSTOMER'),
    api.salesInvoices(),
    api.accounts(),
  ]);
  if (!context.mounted) return false;
  final partners = resources[0];
  final invoices = resources[1];
  final accounts = resources[2];
  if (!editing && partners.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce müşteri kartı ekleyin.')),
    );
    return false;
  }
  final date = TextEditingController(
    text:
        '${item?['collection_date'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
  );
  final amount = TextEditingController(text: '${item?['amount'] ?? ''}');
  final reference = TextEditingController(
    text: '${item?['reference_no'] ?? ''}',
  );
  final notes = TextEditingController(text: '${item?['notes'] ?? ''}');
  int? partnerId = (item?['partner_id'] as num?)?.toInt();
  int? invoiceId;
  int? accountId = (item?['financial_account_id'] as num?)?.toInt();
  String method = '${item?['payment_method'] ?? 'HAVALE'}';
  bool saving = false;
  String? error;
  final idempotencyKey =
      'mobile-collection-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _ControllerOwner(
          controllers: [date, amount, reference, notes],
          child: StatefulBuilder(
            builder: (context, refresh) {
              final available = invoices
                  .where(
                    (invoice) =>
                        invoice['partner_id'] == partnerId &&
                        invoice['payment_status'] != 'PAID',
                  )
                  .toList();
              return AlertDialog(
                title: Text(editing ? 'Tahsilatı düzenle' : 'Yeni tahsilat'),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        DropdownButtonFormField<int>(
                          initialValue: partnerId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Müşteri',
                          ),
                          items: partners
                              .map(
                                (p) => DropdownMenuItem(
                                  value: (p['id'] as num).toInt(),
                                  child: Text(
                                    '${p['name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: editing
                              ? null
                              : (value) => refresh(() {
                                  partnerId = value;
                                  invoiceId = null;
                                }),
                        ),
                        if (!editing)
                          DropdownButtonFormField<int?>(
                            key: ValueKey(partnerId),
                            initialValue: invoiceId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Fatura',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Avans / sonradan dağıt'),
                              ),
                              ...available.map(
                                (inv) => DropdownMenuItem<int?>(
                                  value: (inv['id'] as num).toInt(),
                                  child: Text(
                                    '${inv['number'] ?? 'Taslak'} · ${moneyText(inv['gross_amount'])}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => refresh(() {
                              invoiceId = value;
                              if (value != null) {
                                final invoice = available.firstWhere(
                                  (inv) => inv['id'] == value,
                                );
                                final gross =
                                    num.tryParse(
                                      '${invoice['gross_amount']}',
                                    ) ??
                                    0;
                                final withheld =
                                    num.tryParse(
                                      '${invoice['withholding_amount']}',
                                    ) ??
                                    0;
                                final paid =
                                    num.tryParse('${invoice['paid_amount']}') ??
                                    0;
                                amount.text = (gross - withheld - paid)
                                    .toStringAsFixed(2);
                              }
                            }),
                          ),
                        TextField(
                          controller: date,
                          decoration: const InputDecoration(
                            labelText: 'Tarih YYYY-AA-GG',
                          ),
                        ),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Tutar'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: method,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ödeme yöntemi',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'NAKIT',
                              child: Text('Nakit'),
                            ),
                            DropdownMenuItem(
                              value: 'HAVALE',
                              child: Text('Havale/EFT'),
                            ),
                            DropdownMenuItem(
                              value: 'KREDI_KARTI',
                              child: Text('Kredi kartı'),
                            ),
                            DropdownMenuItem(value: 'CEK', child: Text('Çek')),
                          ],
                          onChanged: (value) =>
                              refresh(() => method = value ?? 'HAVALE'),
                        ),
                        DropdownButtonFormField<int?>(
                          initialValue: accountId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kasa/Banka',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Seçin'),
                            ),
                            ...accounts.map(
                              (a) => DropdownMenuItem<int?>(
                                value: (a['id'] as num).toInt(),
                                child: Text(
                                  '${a['name']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              refresh(() => accountId = value),
                        ),
                        TextField(
                          controller: reference,
                          decoration: const InputDecoration(
                            labelText: 'Referans No',
                          ),
                        ),
                        TextField(
                          controller: notes,
                          decoration: const InputDecoration(
                            labelText: 'Açıklama',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final value = double.tryParse(
                              amount.text.trim().replaceAll(',', '.'),
                            );
                            final day = date.text.trim();
                            if ((!editing && partnerId == null) ||
                                value == null ||
                                !value.isFinite ||
                                value <= 0 ||
                                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
                              refresh(
                                () => error = 'Müşteri, tarih ve sıfırdan büyük tutar girin.',
                              );
                              return;
                            }
                            refresh(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              if (editing) {
                                await api.updateCollection(
                                  (item['id'] as num).toInt(),
                                  {
                                    'collection_date': day,
                                    'amount': value,
                                    'payment_method': method,
                                    'financial_account_id': accountId,
                                    'reference_no': reference.text.trim(),
                                    'notes': notes.text.trim(),
                                  },
                                );
                              } else {
                                await api.createCollection(
                                  partnerId: partnerId!,
                                  amount: value,
                                  accountId: accountId,
                                  collectionDate: day,
                                  paymentMethod: method,
                                  invoiceId: invoiceId,
                                  referenceNo: reference.text.trim(),
                                  notes: notes.text.trim(),
                                  idempotencyKey: idempotencyKey,
                                );
                              }
                              if (dialogContext.mounted)
                                Navigator.pop(dialogContext, true);
                            } catch (e) {
                              refresh(() {
                                saving = false;
                                error = '$e';
                              });
                            }
                          },
                    child: Text(editing ? 'Güncelle' : 'Kaydet'),
                  ),
                ],
              );
            },
          ),
        ),
      ) ??
      false;
}

class _ControllerOwner extends StatefulWidget {
  const _ControllerOwner({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_ControllerOwner> createState() => _ControllerOwnerState();
}

class _ControllerOwnerState extends State<_ControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
