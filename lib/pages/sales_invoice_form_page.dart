import 'dart:math';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../invoice_amounts.dart';
import '../widgets.dart';
import 'partner_form_page.dart';

class _SalesLine {
  _SalesLine()
    : fields = {
        'description': TextEditingController(),
        'quantity': TextEditingController(text: '1'),
        'unit': TextEditingController(text: 'ADET'),
        'unit_price': TextEditingController(text: '0'),
        'discount_rate': TextEditingController(text: '0'),
        'vat_rate': TextEditingController(text: '20'),
        'withholding_rate': TextEditingController(text: '0'),
        'withholding_code': TextEditingController(),
        'withholding_reason': TextEditingController(),
        'exemption_code': TextEditingController(),
        'exemption_reason': TextEditingController(),
        'unit_cost': TextEditingController(),
      };

  int? productId;
  int? warehouseId;
  int? expenseCategoryId;
  final Map<String, TextEditingController> fields;

  String value(String key) => fields[key]!.text.trim();
  double? number(String key) =>
      double.tryParse(value(key).replaceAll(',', '.'));

  Map<String, dynamic>? get payload {
    final quantity = number('quantity');
    final price = number('unit_price');
    final discount = number('discount_rate');
    final vat = number('vat_rate');
    final withholding = number('withholding_rate');
    final cost = value('unit_cost').isEmpty ? null : number('unit_cost');
    if (value('description').isEmpty ||
        value('unit').isEmpty ||
        quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        price == null ||
        !price.isFinite ||
        price < 0 ||
        discount == null ||
        !discount.isFinite ||
        discount < 0 ||
        discount > 100 ||
        vat == null ||
        !vat.isFinite ||
        vat < 0 ||
        vat > 100 ||
        withholding == null ||
        !withholding.isFinite ||
        withholding < 0 ||
        withholding > 100 ||
        (value('unit_cost').isNotEmpty &&
            (cost == null || !cost.isFinite || cost < 0))) {
      return null;
    }
    String? optional(String key) => value(key).isEmpty ? null : value(key);
    return {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'expense_category_id': expenseCategoryId,
      'description': value('description'),
      'quantity': quantity,
      'unit': value('unit'),
      'unit_price': price,
      'discount_rate': discount,
      'vat_rate': vat,
      'withholding_rate': withholding,
      'withholding_code': optional('withholding_code'),
      'withholding_reason': optional('withholding_reason'),
      'exemption_code': optional('exemption_code'),
      'exemption_reason': optional('exemption_reason'),
      'unit_cost': cost,
    };
  }

  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}

class SalesInvoiceFormPage extends StatefulWidget {
  const SalesInvoiceFormPage({
    super.key,
    required this.api,
    this.initialType = 'SATIS',
    this.purchase = false,
  });
  final FinkitApi api;
  final String initialType;
  final bool purchase;

  @override
  State<SalesInvoiceFormPage> createState() => _SalesInvoiceFormPageState();
}

class _SalesInvoiceFormPageState extends State<SalesInvoiceFormPage> {
  final _issueDate = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _dueDate = TextEditingController();
  final _notes = TextEditingController();
  final _exchangeRate = TextEditingController(text: '1');
  final _billingReference = TextEditingController();
  final _billingReferenceDate = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _lines = <_SalesLine>[_SalesLine()];
  late Future<List<List<Map<String, dynamic>>>> _options = _loadOptions();
  int? _partnerId;
  int? _originalInvoiceId;
  late String _invoiceType = widget.initialType;
  String _sourceType = 'MANUAL';
  String _currency = 'TRY';
  String? _requestKey;
  bool _saving = false;
  String? _error;

  Future<List<List<Map<String, dynamic>>>> _loadOptions() => Future.wait([
    widget.api.partners(type: widget.purchase ? 'SUPPLIER' : 'CUSTOMER'),
    widget.api.products(),
    widget.api.warehouses(),
    widget.purchase
        ? widget.api.purchaseInvoices(type: 'ALIS')
        : widget.api.salesInvoices(type: 'SATIS'),
    widget.purchase
        ? widget.api.expenseCategories()
        : Future.value(<Map<String, dynamic>>[]),
  ]);

  Future<void> _createPartner() async {
    final created = await showPartnerCreatePage(
      context,
      widget.api,
      defaultType: widget.purchase ? 'SUPPLIER' : 'CUSTOMER',
    );
    if (created && mounted) setState(() => _options = _loadOptions());
  }

  @override
  void dispose() {
    for (final controller in [
      _issueDate,
      _dueDate,
      _notes,
      _exchangeRate,
      _billingReference,
      _billingReferenceDate,
      _invoiceNumber,
    ]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  Future<void> _save() async {
    final issue = _issueDate.text.trim();
    final due = _dueDate.text.trim();
    final refDate = _billingReferenceDate.text.trim();
    final exchange = double.tryParse(
      _exchangeRate.text.trim().replaceAll(',', '.'),
    );
    if (_partnerId == null ||
        !_validDate(issue) ||
        (due.isNotEmpty && (!_validDate(due) || due.compareTo(issue) < 0)) ||
        (!widget.purchase && refDate.isNotEmpty && !_validDate(refDate)) ||
        (widget.purchase && _invoiceNumber.text.trim().length > 40) ||
        exchange == null ||
        !exchange.isFinite ||
        exchange <= 0 ||
        (!widget.purchase &&
            _invoiceType == 'IADE' &&
            _originalInvoiceId == null &&
            _billingReference.text.trim().isEmpty)) {
      setState(
        () => _error = 'Cari, tarih, kur ve iade referansını kontrol edin.',
      );
      return;
    }
    final lines = _lines.map((line) => line.payload).toList();
    if (lines.any((line) => line == null)) {
      setState(
        () => _error =
            'Bütün kalemlerin miktar, fiyat ve vergi alanlarını kontrol edin.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    _requestKey ??=
        'mobile-invoice-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    try {
      final body = <String, dynamic>{
        if (widget.purchase) 'supplier_id': _partnerId,
        if (!widget.purchase) 'partner_id': _partnerId,
        'invoice_type': _invoiceType,
        'source_type': _sourceType,
        if (widget.purchase)
          'number': _invoiceNumber.text.trim().isEmpty
              ? null
              : _invoiceNumber.text.trim(),
        'issue_date': issue,
        'due_date': due.isEmpty ? null : due,
        'currency': _currency,
        'exchange_rate': exchange,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'original_invoice_id': _invoiceType == 'IADE'
            ? _originalInvoiceId
            : null,
        if (!widget.purchase)
          'billing_reference':
              _invoiceType == 'IADE' && _billingReference.text.trim().isNotEmpty
              ? _billingReference.text.trim()
              : null,
        if (!widget.purchase)
          'billing_reference_date': _invoiceType == 'IADE' && refDate.isNotEmpty
              ? refDate
              : null,
        'lines': lines.cast<Map<String, dynamic>>().map((line) {
          if (widget.purchase) return line;
          return Map<String, dynamic>.from(line)..remove('expense_category_id');
        }).toList(),
      };
      final Map<String, dynamic> created;
      if (widget.purchase) {
        created = await widget.api.createPurchaseInvoiceRecord(
          body,
          idempotencyKey: _requestKey,
        );
      } else {
        created = await widget.api.createSalesInvoiceRecord(
          body,
          idempotencyKey: _requestKey,
        );
      }
      final id = (created['id'] as num?)?.toInt();
      if (id == null) throw ApiException('Fatura kaydı doğrulanamadı');
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  void _remove(_SalesLine line) {
    if (_lines.length == 1) return;
    setState(() => _lines.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.purchase
            ? (_invoiceType == 'IADE'
                  ? 'Yeni alış iadesi'
                  : 'Yeni gelen fatura')
            : (_invoiceType == 'IADE'
                  ? 'Yeni iade faturası'
                  : 'Yeni satış faturası'),
      ),
    ),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _options,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Seçenekler yüklenemedi: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final customers = snapshot.data![0];
        final products = snapshot.data![1];
        final warehouses = snapshot.data![2];
        final categories = snapshot.data![4];
        final invoices = snapshot.data![3]
            .where((item) => item['status'] != 'CANCELLED')
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (customers.isEmpty) ...[
              Text(
                widget.purchase
                    ? 'Önce bir tedarikçi kartı ekleyin.'
                    : 'Önce bir müşteri kartı ekleyin.',
              ),
              TextButton.icon(
                onPressed: _createPartner,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(
                  widget.purchase ? 'Tedarikçi ekle' : 'Müşteri ekle',
                ),
              ),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            DropdownButtonFormField<int?>(
              initialValue: _partnerId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: widget.purchase ? 'Tedarikçi' : 'Müşteri',
              ),
              items: customers
                  .map(
                    (p) => DropdownMenuItem<int?>(
                      value: (p['id'] as num).toInt(),
                      child: Text(
                        '${p['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _partnerId = value),
            ),
            const SizedBox(height: 8),
            _choice('Belge kaynağı', _sourceType, const {
              'MANUAL': 'Manuel kayıt',
              'EINVOICE': 'E-Fatura',
              'EARCHIVE': 'E-Arşiv',
            }, (value) => setState(() => _sourceType = value)),
            const SizedBox(height: 8),
            _choice(
              'Fatura türü',
              _invoiceType,
              widget.purchase
                  ? const {'ALIS': 'Alış', 'IADE': 'İade'}
                  : const {'SATIS': 'Satış', 'IADE': 'İade'},
              (value) => setState(() => _invoiceType = value),
            ),
            if (_invoiceType == 'IADE') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _originalInvoiceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.purchase
                      ? 'Orijinal alış faturası'
                      : 'Orijinal satış faturası',
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      widget.purchase
                          ? 'Referans seçilmedi'
                          : 'Harici referans gireceğim',
                    ),
                  ),
                  ...invoices.map(
                    (invoice) => DropdownMenuItem<int?>(
                      value: (invoice['id'] as num).toInt(),
                      child: Text(
                        '${invoice['number'] ?? 'Taslak'} · ${moneyText(invoice['gross_amount'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _originalInvoiceId = value),
              ),
              if (!widget.purchase) ...[
                _field(_billingReference, 'Harici fatura numarası'),
                _field(
                  _billingReferenceDate,
                  'Harici fatura tarihi YYYY-AA-GG',
                ),
              ],
            ],
            if (widget.purchase) _field(_invoiceNumber, 'Fatura numarası'),
            _field(_issueDate, 'Fatura tarihi YYYY-AA-GG'),
            _field(_dueDate, 'Vade tarihi YYYY-AA-GG'),
            _choice('Para birimi', _currency, const {
              'TRY': 'TRY',
              'USD': 'USD',
              'EUR': 'EUR',
            }, (value) => setState(() => _currency = value)),
            if (_currency != 'TRY')
              _field(_exchangeRate, 'Döviz kuru', numeric: true),
            _field(_notes, 'Not'),
            const SizedBox(height: 16),
            Text('Kalemler', style: Theme.of(context).textTheme.titleMedium),
            for (var index = 0; index < _lines.length; index++)
              _lineCard(index, _lines[index], products, warehouses, categories),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_SalesLine())),
              icon: const Icon(Icons.add),
              label: const Text('Kalem ekle'),
            ),
            const SizedBox(height: 12),
            _totals(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving || customers.isEmpty ? null : _save,
              child: Text(_saving ? 'Kaydediliyor…' : 'Taslak oluştur'),
            ),
          ],
        );
      },
    ),
  );

  Widget _choice(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (option) =>
              DropdownMenuItem(value: option.key, child: Text(option.value)),
        )
        .toList(),
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _lineCard(
    int index,
    _SalesLine line,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> warehouses,
    List<Map<String, dynamic>> categories,
  ) => Card(
    key: ObjectKey(line),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kalem ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Kalemi kaldır',
                onPressed: _lines.length == 1 ? null : () => _remove(line),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          DropdownButtonFormField<int?>(
            initialValue: line.productId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ürün / hizmet'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Serbest satır'),
              ),
              ...products.map(
                (p) => DropdownMenuItem<int?>(
                  value: (p['id'] as num).toInt(),
                  child: Text('${p['name']}', overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              line.productId = value;
              if (value == null) return;
              final product = products.firstWhere((p) => p['id'] == value);
              line.fields['description']!.text = '${product['name'] ?? ''}';
              line.fields['unit_price']!.text =
                  '${product[widget.purchase ? 'purchase_price' : 'sales_price'] ?? 0}';
              line.fields['vat_rate']!.text = '${product['vat_rate'] ?? 20}';
              line.fields['unit']!.text = '${product['unit'] ?? 'ADET'}';
            }),
          ),
          if (warehouses.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: line.warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Depo'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Varsayılan depo'),
                ),
                ...warehouses.map(
                  (w) => DropdownMenuItem<int?>(
                    value: (w['id'] as num).toInt(),
                    child: Text(
                      '${w['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => line.warehouseId = value),
            ),
          ],
          if (widget.purchase && categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: line.expenseCategoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Gider kategorisi'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Seçilmedi'),
                ),
                for (final category in categories)
                  DropdownMenuItem<int?>(
                    value: (category['id'] as num).toInt(),
                    child: Text(
                      '${category['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => line.expenseCategoryId = value),
            ),
          ],
          _field(line.fields['description']!, 'Açıklama'),
          _field(line.fields['quantity']!, 'Miktar', numeric: true),
          _field(line.fields['unit']!, 'Birim'),
          _field(line.fields['unit_price']!, 'Birim fiyat', numeric: true),
          _field(line.fields['discount_rate']!, 'İskonto %', numeric: true),
          _field(line.fields['vat_rate']!, 'KDV %', numeric: true),
          _field(line.fields['withholding_code']!, 'Tevkifat kodu'),
          _field(line.fields['withholding_rate']!, 'Tevkifat %', numeric: true),
          _field(line.fields['withholding_reason']!, 'Tevkifat açıklaması'),
          _field(line.fields['exemption_code']!, 'İstisna kodu'),
          _field(line.fields['exemption_reason']!, 'İstisna açıklaması'),
          _field(line.fields['unit_cost']!, 'Birim maliyet', numeric: true),
        ],
      ),
    ),
  );

  Widget _totals() {
    var net = 0.0, vat = 0.0, withholding = 0.0;
    for (final line in _lines) {
      final payload = line.payload;
      if (payload == null) continue;
      final amounts = calculateInvoiceLineAmounts(payload);
      net += amounts.net;
      vat += amounts.vat;
      withholding += amounts.withholding;
    }
    return Text(
      'Net: ${moneyText(net)} · KDV: ${moneyText(vat)}\nGenel toplam: ${moneyText(net + vat)} · Tevkifat: ${moneyText(withholding)}',
    );
  }
}
