import 'package:flutter/material.dart';

import '../api_client.dart';
import '../invoice_amounts.dart';
import '../widgets.dart';

class _QuoteLine {
  _QuoteLine()
    : description = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'ADET'),
      unitPrice = TextEditingController(text: '0'),
      discountRate = TextEditingController(text: '0'),
      vatRate = TextEditingController(text: '20'),
      withholdingRate = TextEditingController(text: '0'),
      exemptionCode = TextEditingController(),
      exemptionReason = TextEditingController(),
      withholdingCode = TextEditingController(),
      withholdingReason = TextEditingController();

  int? productId;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;
  final TextEditingController discountRate;
  final TextEditingController vatRate;
  final TextEditingController withholdingRate;
  final TextEditingController exemptionCode;
  final TextEditingController exemptionReason;
  final TextEditingController withholdingCode;
  final TextEditingController withholdingReason;

  double? number(TextEditingController field) =>
      double.tryParse(field.text.trim().replaceAll(',', '.'));

  Map<String, dynamic>? get payload {
    final count = number(quantity);
    final price = number(unitPrice);
    final discount = number(discountRate);
    final vat = number(vatRate);
    final withholding = number(withholdingRate);
    if (description.text.trim().isEmpty ||
        unit.text.trim().isEmpty ||
        count == null ||
        !count.isFinite ||
        count <= 0 ||
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
        withholding > 100) {
      return null;
    }
    return {
      'product_id': productId,
      'description': description.text.trim(),
      'quantity': count,
      'unit': unit.text.trim(),
      'unit_price': price,
      'discount_rate': discount,
      'vat_rate': vat,
      'withholding_rate': withholding,
      'exemption_code': exemptionCode.text.trim().isEmpty
          ? null
          : exemptionCode.text.trim(),
      'exemption_reason': exemptionReason.text.trim().isEmpty
          ? null
          : exemptionReason.text.trim(),
      'withholding_code': withholdingCode.text.trim().isEmpty
          ? null
          : withholdingCode.text.trim(),
      'withholding_reason': withholdingReason.text.trim().isEmpty
          ? null
          : withholdingReason.text.trim(),
    };
  }

  void dispose() {
    for (final field in [
      description,
      quantity,
      unit,
      unitPrice,
      discountRate,
      vatRate,
      withholdingRate,
      exemptionCode,
      exemptionReason,
      withholdingCode,
      withholdingReason,
    ]) {
      field.dispose();
    }
  }
}

class QuoteFormPage extends StatefulWidget {
  const QuoteFormPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends State<QuoteFormPage> {
  final _issueDate = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _validUntil = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <_QuoteLine>[_QuoteLine()];
  late final Future<List<List<Map<String, dynamic>>>> _options = Future.wait([
    widget.api.partners(type: 'CUSTOMER'),
    widget.api.products(),
  ]);
  int? _partnerId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _issueDate.dispose();
    _validUntil.dispose();
    _notes.dispose();
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
    final until = _validUntil.text.trim();
    if (_partnerId == null ||
        !_validDate(issue) ||
        (until.isNotEmpty &&
            (!_validDate(until) || until.compareTo(issue) < 0))) {
      setState(() => _error = 'Müşteri ve geçerli teklif tarihlerini girin.');
      return;
    }
    final payload = _lines.map((line) => line.payload).toList();
    if (payload.any((line) => line == null)) {
      setState(
        () => _error = 'Her kalemde açıklama, miktar, fiyat ve geçerli vergi oranları girin.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createQuoteRecord({
        'partner_id': _partnerId,
        'issue_date': issue,
        'valid_until': until.isEmpty ? null : until,
        'currency': 'TRY',
        'exchange_rate': 1,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'lines': payload.cast<Map<String, dynamic>>(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = '$error';
        });
    }
  }

  void _remove(_QuoteLine line) {
    if (_lines.length == 1) return;
    setState(() => _lines.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni teklif')),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _options,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Text('Seçenekler yüklenemedi: ${snapshot.error}'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final customers = snapshot.data![0];
        final products = snapshot.data![1];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (customers.isEmpty)
              const Text('Teklif oluşturmak için önce müşteri kartı ekleyin.'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            DropdownButtonFormField<int>(
              initialValue: _partnerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Müşteri'),
              items: customers
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
              onChanged: (value) => setState(() => _partnerId = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _issueDate,
              decoration: const InputDecoration(
                labelText: 'Teklif tarihi YYYY-AA-GG',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _validUntil,
              decoration: const InputDecoration(
                labelText: 'Geçerlilik tarihi YYYY-AA-GG',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Not'),
            ),
            const SizedBox(height: 18),
            Text('Kalemler', style: Theme.of(context).textTheme.titleMedium),
            for (var index = 0; index < _lines.length; index++)
              _lineCard(index, _lines[index], products),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_QuoteLine())),
              icon: const Icon(Icons.add),
              label: const Text('Kalem ekle'),
            ),
            const SizedBox(height: 12),
            _totals(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || customers.isEmpty ? null : _save,
              child: Text(_saving ? 'Kaydediliyor...' : 'Teklifi kaydet'),
            ),
          ],
        );
      },
    ),
  );

  Widget _lineCard(
    int index,
    _QuoteLine line,
    List<Map<String, dynamic>> products,
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
              if (value != null) {
                final product = products.firstWhere((p) => p['id'] == value);
                line.description.text = '${product['name'] ?? ''}';
                line.unitPrice.text = '${product['sales_price'] ?? 0}';
                line.vatRate.text = '${product['vat_rate'] ?? 20}';
                line.unit.text = '${product['unit'] ?? 'ADET'}';
              }
            }),
          ),
          _field(line.description, 'Açıklama'),
          _field(line.quantity, 'Miktar', numeric: true),
          _field(line.unit, 'Birim'),
          _field(line.unitPrice, 'Birim fiyat', numeric: true),
          _field(line.discountRate, 'İskonto %', numeric: true),
          _field(line.vatRate, 'KDV %', numeric: true),
          _field(line.withholdingCode, 'Tevkifat kodu'),
          _field(line.withholdingRate, 'Tevkifat %', numeric: true),
          _field(line.withholdingReason, 'Tevkifat açıklaması'),
          _field(line.exemptionCode, 'İstisna kodu'),
          _field(line.exemptionReason, 'İstisna açıklaması'),
        ],
      ),
    ),
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
      'Net: ${moneyText(net)} · KDV: ${moneyText(vat)} · Tevkifat: ${moneyText(withholding)}\nGenel toplam: ${moneyText(net + vat)} · Tevkifat sonrası: ${moneyText(net + vat - withholding)}',
    );
  }
}
