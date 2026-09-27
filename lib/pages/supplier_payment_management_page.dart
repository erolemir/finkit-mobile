import 'dart:math';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class SupplierPaymentManagementPage extends StatefulWidget {
  const SupplierPaymentManagementPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<SupplierPaymentManagementPage> createState() =>
      _SupplierPaymentManagementPageState();
}

class _SupplierPaymentManagementPageState
    extends State<SupplierPaymentManagementPage> {
  final _search = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _method = '';
  int? _supplierId;
  int? _accountId;
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  late Future<List<List<Map<String, dynamic>>>> _options;

  @override
  void initState() {
    super.initState();
    _reload();
    _options = Future.wait([
      widget.api.partners(type: 'SUPPLIER'),
      widget.api.accounts(),
    ]);
  }

  @override
  void didUpdateWidget(covariant SupplierPaymentManagementPage oldWidget) {
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
    _future = widget.api.supplierPaymentPage(
      page: _page,
      search: _search.text.trim(),
      supplierId: _supplierId,
      paymentMethod: _method,
      financialAccountId: _accountId,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tarih aralığı girin.')),
      );
      return;
    }
    setState(() {
      _page = 1;
      _reload();
    });
  }

  Future<void> _create() async {
    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _SupplierPaymentForm(api: widget.api),
      );
      if (changed == true && mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(
          title: 'Tedarikçi Ödemeleri',
          subtitle: 'Fatura ödemesi ve avansları kasa/banka hesabına bağlayın.',
          trailing: IconButton.filled(
            tooltip: 'Yeni ödeme',
            onPressed: _create,
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
            return Column(
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tedarikçi'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tümü'),
                    ),
                    ...snapshot.data![0].map(
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
                    _supplierId = value;
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
                    ...snapshot.data![1].map(
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
                child: Text('Ödemeler yüklenemedi: ${snapshot.error}'),
              );
            }
            final items = (snapshot.data?['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final total =
                int.tryParse('${snapshot.data?['total']}') ?? items.length;
            final suppliers = _options;
            return FutureBuilder<List<List<Map<String, dynamic>>>>(
              future: suppliers,
              builder: (context, options) {
                final names = {
                  for (final p in options.data?[0] ?? <Map<String, dynamic>>[])
                    p['id']: '${p['name']}',
                };
                return Column(
                  children: [
                    if (items.isEmpty)
                      const EmptyState(
                        icon: Icons.payments_outlined,
                        title: 'Ödeme yok',
                        description:
                            'Seçilen filtrelerde tedarikçi ödemesi bulunmuyor.',
                      ),
                    for (final item in items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${dateText(item['payment_date'])} · ${names[item['supplier_id']] ?? '#${item['supplier_id']}'}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                moneyText(item['amount']),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${item['payment_method'] ?? '—'} · Dağıtılan: ${moneyText(item['allocated_amount'])}',
                              ),
                              Text(
                                'Avans: ${moneyText(item['unallocated_amount'])}',
                              ),
                              if ('${item['reference_no'] ?? ''}'.isNotEmpty)
                                Text('Referans: ${item['reference_no']}'),
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
                              'Sayfa $_page · $total ödeme',
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
            );
          },
        ),
      ],
    ),
  );
}

class _SupplierPaymentForm extends StatefulWidget {
  const _SupplierPaymentForm({required this.api});
  final FinkitApi api;

  @override
  State<_SupplierPaymentForm> createState() => _SupplierPaymentFormState();
}

class _SupplierPaymentFormState extends State<_SupplierPaymentForm> {
  final _date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  late final Future<List<List<Map<String, dynamic>>>> _options = Future.wait([
    widget.api.partners(type: 'SUPPLIER'),
    widget.api.accounts(),
  ]);
  late final String _idempotencyKey =
      'mobile-supplier-payment-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  int? _supplierId;
  int? _accountId;
  final Map<int, Map<String, dynamic>> _selectedInvoices = {};
  final Map<int, double> _allocatedAmounts = {};
  String _method = 'HAVALE';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickInvoice() async {
    if (_supplierId == null) {
      setState(() => _error = 'Önce tedarikçi seçin.');
      return;
    }
    final invoice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SupplierInvoicePicker(
        api: widget.api,
        supplierId: _supplierId!,
        excludedIds: _selectedInvoices.keys.toSet(),
      ),
    );
    if (!mounted || invoice == null) return;
    final id = (invoice['id'] as num).toInt();
    final gross = num.tryParse('${invoice['gross_amount']}') ?? 0;
    final paid = num.tryParse('${invoice['paid_amount']}') ?? 0;
    final remaining = (gross - paid).toDouble();
    setState(() {
      _selectedInvoices[id] = invoice;
      _allocatedAmounts[id] = remaining;
      _amount.text = _allocatedAmounts.values
          .fold<double>(0, (a, b) => a + b)
          .toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final day = DateTime.tryParse(_date.text.trim());
    if (_supplierId == null ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        day == null ||
        _date.text.trim() != day.toIso8601String().substring(0, 10)) {
      setState(
        () => _error = 'Tedarikçi, tarih ve sıfırdan büyük tutar girin.',
      );
      return;
    }
    final allocated = _allocatedAmounts.values.fold<double>(0, (a, b) => a + b);
    for (final entry in _selectedInvoices.entries) {
      final invoice = entry.value;
      final remaining =
          ((num.tryParse('${invoice['gross_amount']}') ?? 0) -
                  (num.tryParse('${invoice['paid_amount']}') ?? 0))
              .toDouble();
      final value = _allocatedAmounts[entry.key];
      if (value == null ||
          !value.isFinite ||
          value <= 0 ||
          (value * 100).round() > (remaining * 100).round()) {
        setState(
          () => _error =
              'Her fatura için kalan tutarı aşmayan pozitif dağıtım girin.',
        );
        return;
      }
    }
    if ((allocated * 100).round() > (amount * 100).round()) {
      setState(
        () => _error = 'Faturalara dağıtılan tutar ödeme tutarını aşamaz.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createSupplierPayment(
        supplierId: _supplierId!,
        amount: amount,
        paymentDate: _date.text.trim(),
        paymentMethod: _method,
        accountId: _accountId,
        allocations: [
          for (final entry in _allocatedAmounts.entries)
            {'invoice_id': entry.key, 'amount': entry.value},
        ],
        referenceNo: _reference.text.trim(),
        notes: _notes.text.trim(),
        idempotencyKey: _idempotencyKey,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
    title: const Text('Yeni tedarikçi ödemesi'),
    content: SizedBox(
      width: 450,
      child: SingleChildScrollView(
        child: FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: _options,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Seçenekler yüklenemedi: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final suppliers = snapshot.data![0];
            final accounts = snapshot.data![1];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (suppliers.isEmpty)
                  const Text('Önce tedarikçi kartı ekleyin.'),
                DropdownButtonFormField<int>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tedarikçi'),
                  items: suppliers
                      .map(
                        (p) => DropdownMenuItem<int>(
                          value: (p['id'] as num).toInt(),
                          child: Text(
                            '${p['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _supplierId = value;
                    _selectedInvoices.clear();
                    _allocatedAmounts.clear();
                    _amount.clear();
                  }),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _supplierId == null ? null : _pickInvoice,
                    icon: const Icon(Icons.add),
                    label: const Text('Gelen fatura ekle'),
                  ),
                ),
                if (_selectedInvoices.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Fatura seçmezseniz ödeme avans olarak kaydedilir.',
                    ),
                  ),
                for (final entry in _selectedInvoices.entries)
                  Row(
                    key: ValueKey('allocation-${entry.key}'),
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('allocation-amount-${entry.key}'),
                          initialValue: _allocatedAmounts[entry.key]
                              ?.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${entry.value['number'] ?? '#${entry.key}'} dağıtımı',
                          ),
                          onChanged: (value) => _allocatedAmounts[entry.key] =
                              double.tryParse(value.replaceAll(',', '.')) ??
                              double.nan,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Faturayı kaldır',
                        onPressed: () => setState(() {
                          _selectedInvoices.remove(entry.key);
                          _allocatedAmounts.remove(entry.key);
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                TextField(
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: 'Tarih YYYY-AA-GG',
                  ),
                ),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Tutar'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Ödeme yöntemi'),
                  items: const [
                    DropdownMenuItem(value: 'NAKIT', child: Text('Nakit')),
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
                      setState(() => _method = value ?? 'HAVALE'),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kasa / banka'),
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
                  onChanged: (value) => setState(() => _accountId = value),
                ),
                TextField(
                  controller: _reference,
                  decoration: const InputDecoration(labelText: 'Referans No'),
                ),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  maxLines: 2,
                ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Kaydet'),
      ),
    ],
  );
}

class _SupplierInvoicePicker extends StatefulWidget {
  const _SupplierInvoicePicker({
    required this.api,
    required this.supplierId,
    required this.excludedIds,
  });

  final FinkitApi api;
  final int supplierId;
  final Set<int> excludedIds;

  @override
  State<_SupplierInvoicePicker> createState() => _SupplierInvoicePickerState();
}

class _SupplierInvoicePickerState extends State<_SupplierInvoicePicker> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.purchaseInvoicePage(
      page: _page,
      supplierId: widget.supplierId,
      status: 'POSTED',
      search: _search.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
    title: const Text('Gelen fatura seç'),
    content: SizedBox(
      width: 450,
      height: 460,
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Numara veya tedarikçi ara',
              suffixIcon: IconButton(
                tooltip: 'Ara',
                onPressed: () => setState(() {
                  _page = 1;
                  _reload();
                }),
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => setState(() {
              _page = 1;
              _reload();
            }),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(_reload),
                    child: Text('Faturalar yüklenemedi: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = (snapshot.data?['items'] as List? ?? const [])
                    .whereType<Map>()
                    .map((value) => Map<String, dynamic>.from(value))
                    .where(
                      (invoice) =>
                          invoice['payment_status'] != 'PAID' &&
                          !widget.excludedIds.contains(
                            (invoice['id'] as num).toInt(),
                          ),
                    )
                    .toList();
                final total =
                    int.tryParse('${snapshot.data?['total']}') ?? items.length;
                return Column(
                  children: [
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text('Bu sayfada ödenmemiş fatura yok.'),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final invoice = items[index];
                                final gross =
                                    num.tryParse(
                                      '${invoice['gross_amount']}',
                                    ) ??
                                    0;
                                final paid =
                                    num.tryParse('${invoice['paid_amount']}') ??
                                    0;
                                return ListTile(
                                  title: Text(
                                    '${invoice['number'] ?? '#${invoice['id']}'}',
                                  ),
                                  subtitle: Text(
                                    'Kalan: ${moneyText(gross - paid)}',
                                  ),
                                  onTap: () => Navigator.pop(context, invoice),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Önceki fatura sayfası',
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
                            '$_page · $total fatura',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sonraki fatura sayfası',
                          onPressed: _page * 25 >= total
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
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kapat'),
      ),
    ],
  );
}
