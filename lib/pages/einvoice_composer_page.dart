import 'dart:math';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../invoice_amounts.dart';
import '../invoice_tax_catalog.dart';
import '../invoice_type_rules.dart';
import '../widgets.dart';

String _submissionKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _ComposerTax {
  _ComposerTax(this.code, [Map? data])
    : base = TextEditingController(text: '${data?['taxable_amount'] ?? ''}'),
      value = TextEditingController(
        text:
            '${data?[invoiceTaxKind(code)?.mode == 'RATE' ? 'rate' : 'amount'] ?? ''}',
      ),
      vatBaseIncluded = data?['vat_base_included'] == true
          ? true
          : data?['vat_base_included'] == false
          ? false
          : null;
  final String code;
  final TextEditingController base;
  final TextEditingController value;
  bool? vatBaseIncluded;
  Map<String, dynamic> get draft => {
    'code': code,
    'taxable_amount': base.text,
    invoiceTaxKind(code)?.mode == 'RATE' ? 'rate' : 'amount': value.text,
    if (vatBaseIncluded != null) 'vat_base_included': vatBaseIncluded,
  };
  Map<String, dynamic> get payload => {
    'code': code,
    if (base.text.trim().isNotEmpty)
      'taxable_amount': double.parse(base.text.trim()),
    invoiceTaxKind(code)?.mode == 'RATE' ? 'rate' : 'amount': double.parse(
      value.text.trim(),
    ),
    if (vatBaseIncluded != null) 'vat_base_included': vatBaseIncluded,
  };
  void dispose() {
    base.dispose();
    value.dispose();
  }
}

class _ReturnReference {
  _ReturnReference([Map? data])
    : number = TextEditingController(text: '${data?['number'] ?? ''}'),
      date = TextEditingController(text: '${data?['date'] ?? ''}');
  final TextEditingController number;
  final TextEditingController date;
  Map<String, String> get value => {
    'number': number.text.trim(),
    'date': date.text.trim(),
  };
  void dispose() {
    number.dispose();
    date.dispose();
  }
}

class _ComposerLine {
  _ComposerLine([Map<String, dynamic>? data]) {
    productId = int.tryParse('${data?['product_id'] ?? ''}');
    for (final key in const [
      'name',
      'unit',
      'quantity',
      'unit_price',
      'vat_rate',
      'discount_rate',
      'withholding_code',
      'withholding_rate',
      'return_ratio',
      'original_unwithheld_vat',
      'exemption_code',
      'exemption_reason',
      'bsmv_rate',
      'incentive_expense_type',
      'machine_id',
      'machine_sequence_no',
      'waived_vat_rate',
      'special_base_code',
      'special_base_amount',
      'special_expense_type',
      'gtip_code',
      'buyer_dib_line_code',
      'deduction_rate',
      'deduction_base',
    ]) {
      fields[key] = TextEditingController(
        text:
            '${key == 'deduction_rate'
                ? (data?['deduction_tax'] is Map ? data!['deduction_tax']['rate'] : null)
                : key == 'deduction_base'
                ? (data?['deduction_tax'] is Map ? data!['deduction_tax']['taxable_amount'] : null)
                : data?[key] ?? const {'unit': 'ADET', 'quantity': '1', 'vat_rate': '20', 'waived_vat_rate': '20'}[key] ?? ''}',
      );
    }
    final rawTaxes = data?['additional_taxes'];
    if (rawTaxes is List) {
      for (final raw in rawTaxes.whereType<Map>()) {
        taxes.add(_ComposerTax('${raw['code']}', raw));
      }
    }
    final deduction = data?['deduction_tax'];
    if (deduction is Map) {
      deductionCode = '${deduction['code'] ?? ''}';
      eligibilityConfirmed = deduction['eligibility_confirmed'] == true;
    }
  }

  final fields = <String, TextEditingController>{};
  int? productId;
  final taxes = <_ComposerTax>[];
  String deductionCode = '';
  bool eligibilityConfirmed = false;
  String get(String key) => fields[key]!.text.trim();
  Map<String, dynamic> get draft => {
    if (productId != null) 'product_id': productId,
    for (final entry in fields.entries)
      if (!{'deduction_rate', 'deduction_base'}.contains(entry.key))
        entry.key: entry.value.text,
    'additional_taxes': taxes.map((tax) => tax.draft).toList(),
    if (deductionCode.isNotEmpty)
      'deduction_tax': {
        'code': deductionCode,
        'rate': get('deduction_rate'),
        'taxable_amount': get('deduction_base'),
        if (deductionCode == '4171')
          'eligibility_confirmed': eligibilityConfirmed,
      },
  };

  Map<String, dynamic> payload(String invoiceType) {
    final result = <String, dynamic>{
      if (productId != null) 'product_id': productId,
      'name': get('name'),
      'unit': get('unit'),
      'unit_code': 'C62',
      'quantity': double.parse(get('quantity')),
      'unit_price': double.parse(get('unit_price')),
      'vat_rate': double.parse(get('vat_rate')),
      if (get('discount_rate').isNotEmpty)
        'discount_rate': double.parse(get('discount_rate')),
      if (get('exemption_code').isNotEmpty) ...{
        'exemption_code': get('exemption_code'),
        'exemption_reason': get('exemption_reason').isEmpty
            ? 'İstisna kodu ${get('exemption_code')}'
            : get('exemption_reason'),
      },
      if (get('withholding_code').isNotEmpty) ...{
        'withholding_code': get('withholding_code'),
        'withholding_rate': double.parse(get('withholding_rate')),
      },
      if (get('bsmv_rate').isNotEmpty)
        'bsmv_rate': double.parse(get('bsmv_rate')),
      if (taxes.isNotEmpty)
        'additional_taxes': taxes.map((tax) => tax.payload).toList(),
      if (deductionCode.isNotEmpty)
        'deduction_tax': {
          'code': deductionCode,
          'rate': double.parse(get('deduction_rate')),
          if (get('deduction_base').isNotEmpty)
            'taxable_amount': double.parse(get('deduction_base')),
          if (deductionCode == '4171')
            'eligibility_confirmed': eligibilityConfirmed,
        },
      if (invoiceType.startsWith('YTB_')) ...{
        'incentive_expense_type': get('incentive_expense_type'),
        if (get('machine_id').isNotEmpty) 'machine_id': get('machine_id'),
        if (get('machine_sequence_no').isNotEmpty)
          'machine_sequence_no': get('machine_sequence_no'),
      },
      if (invoiceType == 'YTB_ISTISNA')
        'waived_vat_rate': double.parse(get('waived_vat_rate')),
      if (invoiceType == 'OZELMATRAH') ...{
        'special_base_code': get('special_base_code'),
        'special_base_amount': double.parse(get('special_base_amount')),
        if (get('special_expense_type').isNotEmpty)
          'special_expense_type': get('special_expense_type'),
      },
      if (invoiceType == 'IHRACKAYITLI') ...{
        if (get('gtip_code').isNotEmpty) 'gtip_code': get('gtip_code'),
        if (get('buyer_dib_line_code').isNotEmpty)
          'buyer_dib_line_code': get('buyer_dib_line_code'),
      },
    };
    return result;
  }

  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    for (final tax in taxes) {
      tax.dispose();
    }
  }
}

class EInvoiceComposerPage extends StatefulWidget {
  const EInvoiceComposerPage({
    super.key,
    required this.api,
    required this.isClient,
    required this.documentType,
    this.draft,
  });
  final FinkitApi api;
  final bool isClient;
  final String documentType;
  final Map<String, dynamic>? draft;

  @override
  State<EInvoiceComposerPage> createState() => _EInvoiceComposerPageState();
}

class _EInvoiceComposerPageState extends State<EInvoiceComposerPage> {
  final _form = <String, TextEditingController>{};
  final _lines = <_ComposerLine>[];
  final _returnReferences = <_ReturnReference>[];
  late String _documentType;
  String _invoiceType = 'SATIS';
  String _key = _submissionKey();
  int? _accountingPartnerId;
  int? _draftId;
  bool _sendEmail = false;
  bool _busy = false;
  Map<String, dynamic>? _number;
  Map<String, dynamic>? _recipient;
  String? _error;

  static const _invoiceTypes = <String, String>{
    'SATIS': 'Satış',
    'IADE': 'İade',
    'ISTISNA': 'İstisna',
    'TEVKIFAT': 'Tevkifat',
    'TEVKIFATIADE': 'Tevkifat İadesi',
    'YTB_SATIS': 'Yatırım Teşvik Satış',
    'YTB_IADE': 'Yatırım Teşvik İade',
    'YTB_ISTISNA': 'Yatırım Teşvik İstisna',
    'YTB_TEVKIFAT': 'Yatırım Teşvik Tevkifat',
    'KONAKLAMA': 'Konaklama',
    'OZELMATRAH': 'Özel Matrah',
    'IHRACKAYITLI': 'İhraç Kayıtlı',
  };

  @override
  void initState() {
    super.initState();
    final content = widget.draft?['content'];
    final draftForm = content is Map ? content['form'] : null;
    final form = draftForm is Map
        ? Map<String, dynamic>.from(draftForm)
        : <String, dynamic>{};
    _draftId = int.tryParse('${widget.draft?['id']}');
    _documentType = '${form['document_type'] ?? widget.documentType}';
    _invoiceType = '${form['invoice_type'] ?? 'SATIS'}';
    _key = '${form['submission_key'] ?? _submissionKey()}';
    _accountingPartnerId = int.tryParse(
      '${form['accounting_partner_id'] ?? ''}',
    );
    _sendEmail = form['send_email'] == true;
    final draftReferences = form['billing_references'];
    if (draftReferences is List && draftReferences.isNotEmpty) {
      for (final reference in draftReferences.whereType<Map>()) {
        _returnReferences.add(_ReturnReference(reference));
      }
    } else {
      _returnReferences.add(_ReturnReference());
    }
    for (final key in const [
      'identifier',
      'name',
      'tax_office',
      'email',
      'phone',
      'street',
      'building_no',
      'district',
      'city',
      'postal_code',
      'issue_date',
      'serie',
      'billing_reference',
      'billing_reference_date',
      'investment_incentive_number',
      'investment_incentive_date',
      'accommodation_service_date',
      'export_registered_code',
      'despatch_number',
      'despatch_date',
      'earchive_email',
      'note',
      'withholding_operation_date',
      'withholding_operation_total',
      'withholding_operation_reference',
    ]) {
      final today = DateTime.now();
      final todayText =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      _form[key] = TextEditingController(
        text: '${form[key] ?? (key == 'issue_date' ? todayText : '')}',
      );
    }
    final draftLines = content is Map ? content['lines'] : null;
    if (draftLines is List && draftLines.isNotEmpty) {
      for (final line in draftLines.whereType<Map>()) {
        _lines.add(_ComposerLine(Map<String, dynamic>.from(line)));
      }
    } else {
      _lines.add(_ComposerLine());
    }
  }

  @override
  void dispose() {
    for (final controller in _form.values) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    for (final reference in _returnReferences) {
      reference.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _form[key]!.text.trim();
  Widget _field(String key, String label, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _form[key],
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {
        if (key == 'identifier') {
          _accountingPartnerId = null;
          _recipient = null;
          _number = null;
        } else if (key == 'issue_date' || key == 'serie') {
          _number = null;
        }
      }),
    ),
  );

  Future<Map<String, dynamic>?> _pickCatalog({required bool product}) async {
    final search = TextEditingController();
    Future<List<Map<String, dynamic>>> load(String query) => product
        ? widget.api.searchProducts(query)
        : widget.api.searchPartners(query);
    var future = load('');
    try {
      return await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, refresh) => FractionallySizedBox(
            heightFactor: 0.8,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: search,
                            decoration: InputDecoration(
                              labelText: product ? 'Ürün ara' : 'Cari ara',
                            ),
                            onSubmitted: (_) => refresh(
                              () => future = load(search.text.trim()),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ara',
                          onPressed: () =>
                              refresh(() => future = load(search.text.trim())),
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const LoadingState();
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Katalog alınamadı: ${snapshot.error}'),
                          );
                        }
                        final rows = product
                            ? snapshot.data!
                            : snapshot.data!.where((row) {
                                final allowed =
                                    const {
                                      'IADE',
                                      'TEVKIFATIADE',
                                      'YTB_IADE',
                                    }.contains(_invoiceType)
                                    ? const {'SUPPLIER', 'BOTH'}
                                    : const {'CUSTOMER', 'BOTH'};
                                return allowed.contains(
                                  '${row['partner_type']}',
                                );
                              }).toList();
                        if (rows.isEmpty) {
                          return const Center(
                            child: Text('Eşleşen kayıt yok.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return ListTile(
                              title: Text('${row['name'] ?? '-'}'),
                              subtitle: Text(
                                product
                                    ? '${row['code'] ?? ''} · ${moneyText(row['sales_price'])}'
                                    : '${row['code'] ?? ''} · ${row['tax_number'] ?? ''}',
                              ),
                              onTap: () => Navigator.pop(sheetContext, row),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      search.dispose();
    }
  }

  Future<void> _pickPartner() async {
    final partner = await _pickCatalog(product: false);
    if (partner == null || !mounted) return;
    setState(() {
      _accountingPartnerId = (partner['id'] as num).toInt();
      for (final entry in <String, dynamic>{
        'identifier': partner['tax_number'],
        'name': partner['name'],
        'tax_office': partner['tax_office'],
        'email': partner['email'],
        'phone': partner['phone'],
        'street': partner['address'],
        'district': partner['district'],
        'city': partner['city'],
      }.entries) {
        _form[entry.key]!.text = '${entry.value ?? ''}';
      }
      _recipient = null;
      _number = null;
    });
  }

  Future<void> _pickProduct(_ComposerLine line) async {
    final product = await _pickCatalog(product: true);
    if (product == null || !mounted) return;
    setState(() {
      line.productId = (product['id'] as num).toInt();
      line.fields['name']!.text = '${product['name'] ?? ''}';
      line.fields['unit']!.text = '${product['unit'] ?? 'ADET'}';
      line.fields['unit_price']!.text = '${product['sales_price'] ?? 0}';
      line.fields['vat_rate']!.text =
          const {'ISTISNA', 'YTB_ISTISNA'}.contains(_invoiceType)
          ? '0'
          : '${product['vat_rate'] ?? 20}';
    });
  }

  Map<String, dynamic> _draftBody() => {
    'document_type': _documentType,
    'title': _v('name').isEmpty ? 'İsimsiz fatura' : _v('name'),
    'content': {
      'form': {
        for (final entry in _form.entries) entry.key: entry.value.text,
        'document_type': _documentType,
        'invoice_type': _invoiceType,
        'submission_key': _key,
        if (_accountingPartnerId != null)
          'accounting_partner_id': _accountingPartnerId,
        'send_email': _sendEmail,
        'billing_references': _returnReferences
            .map((reference) => reference.value)
            .toList(),
      },
      'lines': _lines.map((line) => line.draft).toList(),
    },
  };

  Future<void> _saveDraft() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.saveElectronicInvoiceDraft(
        _draftBody(),
        id: _draftId,
      );
      if (!mounted) return;
      _draftId = int.tryParse('${result['id']}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taslak kaydedildi. Gönderim yapılmadı.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkRecipient() async {
    final identifier = _v('identifier');
    if (!RegExp(r'^\d{10,11}$').hasMatch(identifier)) {
      setState(() => _error = 'VKN 10, TCKN 11 haneli olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.checkElectronicInvoiceUser(
        identifier,
        isClient: widget.isClient,
      );
      if (mounted) setState(() => _recipient = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewNumber() async {
    if (_documentType == 'AUTO' && _recipient == null) {
      setState(
        () => _error =
            'Otomatik belge türü için önce mükellefiyeti kontrol edin.',
      );
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_v('issue_date')) ||
        (_v('serie').isNotEmpty &&
            !RegExp(r'^[A-Z]{3}$').hasMatch(_v('serie')))) {
      setState(() => _error = 'Tarih YYYY-AA-GG, seri üç büyük harf olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final type = _documentType == 'AUTO'
          ? (_recipient?['is_einvoice_user'] == true ? 'EINVOICE' : 'EARCHIVE')
          : _documentType;
      final result = await widget.api.previewElectronicInvoiceNumber(
        isClient: widget.isClient,
        documentType: type,
        issueDate: _v('issue_date'),
        serie: _v('serie').isEmpty ? null : _v('serie'),
      );
      if (mounted) setState(() => _number = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validationError() {
    if (!RegExp(r'^\d{10,11}$').hasMatch(_v('identifier')))
      return 'Geçerli VKN/TCKN girin.';
    if (_v('name').isEmpty) return 'Müşteri adı veya ünvanı gerekli.';
    if (_number == null) return 'Önce belge numarasını kontrol edin.';
    if (_documentType == 'EINVOICE' &&
        _recipient?['is_einvoice_user'] != true) {
      return 'Alıcı için e-fatura mükellefiyetini kontrol edin.';
    }
    if (_sendEmail &&
        _documentType != 'EINVOICE' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_v('earchive_email'))) {
      return 'Gönderim için geçerli bir e-posta adresi girin.';
    }
    if (const {'IADE', 'TEVKIFATIADE'}.contains(_invoiceType) &&
        (_v('billing_reference').isEmpty ||
            _v('billing_reference_date').isEmpty)) {
      return 'İade edilen faturanın numarası ve tarihi gerekli.';
    }
    if (_invoiceType == 'YTB_IADE' &&
        (_returnReferences.isEmpty ||
            _returnReferences.any(
              (reference) =>
                  reference.value['number']!.isEmpty ||
                  reference.value['date']!.isEmpty,
            ))) {
      return 'İadeye konu her faturanın numarası ve tarihi gerekli.';
    }
    if (_invoiceType.startsWith('YTB_') &&
        (_v('investment_incentive_number').isEmpty ||
            _v('investment_incentive_date').isEmpty)) {
      return 'Yatırım teşvik belgesi numarası ve tarihi gerekli.';
    }
    final operationTotalText = _v('withholding_operation_total');
    if (operationTotalText.isNotEmpty &&
        ((double.tryParse(operationTotalText)?.isFinite != true) ||
            (double.tryParse(operationTotalText) ?? 0) <= 0)) {
      return 'Aynı işlemin KDV dahil toplamı pozitif bir sayı olmalı.';
    }
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final quantity = double.tryParse(line.get('quantity')) ?? 0;
      final price = double.tryParse(line.get('unit_price')) ?? 0;
      final vat = double.tryParse(line.get('vat_rate')) ?? -1;
      final discount = double.tryParse(line.get('discount_rate')) ?? 0;
      if (line.get('name').isEmpty ||
          !quantity.isFinite ||
          !price.isFinite ||
          !vat.isFinite ||
          !discount.isFinite ||
          quantity <= 0 ||
          price <= 0 ||
          !(quantity * price).isFinite ||
          quantity * price > 9999999999.99 ||
          vat < 0 ||
          vat > 100 ||
          discount < 0 ||
          discount > 100) {
        return '${index + 1}. satırda ürün, pozitif miktar/fiyat ve geçerli KDV gerekli.';
      }
      if (vat == 0 && line.get('exemption_code').isEmpty) {
        return '${index + 1}. satırda sıfır KDV için istisna kodu gerekli.';
      }
      final bsmvText = line.get('bsmv_rate');
      if (bsmvText.isNotEmpty &&
          ((double.tryParse(bsmvText)?.isFinite != true) ||
              (double.tryParse(bsmvText) ?? 0) <= 0 ||
              (double.tryParse(bsmvText) ?? 0) > 100)) {
        return '${index + 1}. satırda BSMV oranı 0 ile 100 arasında olmalı.';
      }
      if (const {
            'TEVKIFAT',
            'TEVKIFATIADE',
            'YTB_TEVKIFAT',
          }.contains(_invoiceType) &&
          line.deductionCode != '4171' &&
          (line.get('withholding_code').isNotEmpty ||
              line.get('withholding_rate').isNotEmpty) &&
          (line.get('withholding_code').isEmpty ||
              (double.tryParse(line.get('withholding_rate')) ?? 0) <= 0)) {
        return '${index + 1}. satırda tevkifat kodu ve oranı gerekli.';
      }
      if (line.deductionCode.isNotEmpty) {
        final rate = double.tryParse(line.get('deduction_rate')) ?? 0;
        if (!rate.isFinite || rate <= 0 || rate > 100) {
          return '${index + 1}. satırda geçerli kesinti oranı girin.';
        }
        if (line.get('withholding_code').isNotEmpty) {
          return '${index + 1}. satırda KDV tevkifatı ve diğer kesinti birlikte kullanılamaz.';
        }
        if (line.deductionCode == '4171') {
          if (_invoiceType != 'TEVKIFAT' && _invoiceType != 'IADE') {
            return '${index + 1}. satırda 4171 için TEVKİFAT/İADE türü gerekir.';
          }
          if (rate != 100 ||
              !line.eligibilityConfirmed ||
              line.taxes.length != 1 ||
              line.taxes.first.code != '0071') {
            return '${index + 1}. satırda 4171 için 0071 ÖTV, %100 kesinti ve uygunluk onayı gerekir.';
          }
        } else if (!{'SATIS', 'IADE'}.contains(_invoiceType) ||
            line.taxes.isNotEmpty ||
            (double.tryParse(line.get('bsmv_rate')) ?? 0) > 0) {
          return '${index + 1}. satırda GV/KV stopajı ayrı SATIŞ/İADE faturası gerektirir.';
        }
        final base = line.get('deduction_base');
        if (base.isNotEmpty &&
            ((double.tryParse(base)?.isFinite != true) ||
                (double.tryParse(base) ?? 0) <= 0 ||
                (double.tryParse(base) ?? 0) >
                    calculateInvoiceLineAmounts(line.draft).net)) {
          return '${index + 1}. satırda stopaj matrahı satır netini aşamaz.';
        }
      }
    }
    final taxesError = invoiceAdditionalTaxErrors(
      _invoiceType,
      _lines.map((line) => line.draft).toList(),
      investmentIncentive: _invoiceType.startsWith('YTB_'),
    );
    if (taxesError.isNotEmpty) return taxesError.first;
    final fiscalErrors = invoiceFiscalErrors({
      for (final entry in _form.entries) entry.key: entry.value.text,
      'invoice_type': _invoiceType,
      'billing_references': _returnReferences
          .map((reference) => reference.value)
          .toList(),
    }, _lines.map((line) => line.draft).toList());
    if (fiscalErrors.isNotEmpty) return fiscalErrors.first;
    return null;
  }

  Map<String, dynamic> _payload() {
    final type = _invoiceType.startsWith('YTB_')
        ? _invoiceType.substring(4)
        : _invoiceType;
    return {
      'submission_key': _key,
      if (_accountingPartnerId != null)
        'accounting_partner_id': _accountingPartnerId,
      if (const {'TEVKIFAT', 'YTB_TEVKIFAT'}.contains(_invoiceType)) ...{
        if (_v('withholding_operation_date').isNotEmpty)
          'withholding_operation_date': _v('withholding_operation_date'),
        if (_v('withholding_operation_total').isNotEmpty)
          'withholding_operation_total': double.parse(
            _v('withholding_operation_total'),
          ),
        if (_v('withholding_operation_reference').isNotEmpty)
          'withholding_operation_reference': _v(
            'withholding_operation_reference',
          ),
      },
      'document_type': _documentType,
      'invoice_type': type,
      'issue_date': _v('issue_date'),
      'currency': 'TRY',
      'serie': _number?['serie'],
      'customer': {
        'identifier': _v('identifier'),
        'name': _v('name'),
        if (_v('tax_office').isNotEmpty) 'tax_office': _v('tax_office'),
        if (_v('email').isNotEmpty) 'email': _v('email'),
        if (_v('phone').isNotEmpty) 'phone': _v('phone'),
        'address': {
          if (_v('street').isNotEmpty) 'street': _v('street'),
          if (_v('building_no').isNotEmpty) 'building_no': _v('building_no'),
          if (_v('city').isNotEmpty) 'city': _v('city'),
          if (_v('district').isNotEmpty) 'district': _v('district'),
          if (_v('postal_code').isNotEmpty) 'postal_code': _v('postal_code'),
          'country': 'Türkiye',
        },
      },
      'lines': _lines.map((line) => line.payload(_invoiceType)).toList(),
      if (_v('note').isNotEmpty) 'notes': [_v('note')],
      if (_v('billing_reference').isNotEmpty) ...{
        'billing_reference': _v('billing_reference'),
        'billing_reference_date': _v('billing_reference_date'),
      },
      if (_invoiceType == 'YTB_IADE')
        'billing_references': _returnReferences
            .map((reference) => reference.value)
            .toList(),
      if (_invoiceType.startsWith('YTB_')) ...{
        'investment_incentive_number': _v('investment_incentive_number'),
        'investment_incentive_date': _v('investment_incentive_date'),
      },
      if (_invoiceType == 'IHRACKAYITLI')
        'export_registered_code': _v('export_registered_code'),
      if (_invoiceType == 'KONAKLAMA')
        'accommodation_service_date': _v('accommodation_service_date'),
      if (_v('despatch_number').isNotEmpty) ...{
        'despatch_number': _v('despatch_number'),
        'despatch_date': _v('despatch_date'),
      },
      if (_documentType != 'EINVOICE')
        'earchive': {
          'sending_type': 'ELEKTRONIK',
          'internet_sale': false,
          'send_email': _sendEmail,
          'emails': _sendEmail && _v('earchive_email').isNotEmpty
              ? [_v('earchive_email')]
              : <String>[],
        },
    };
  }

  InvoiceAmountTotals get _amounts => calculateInvoiceAmounts(
    _lines.map((line) => line.draft).toList(),
    _invoiceType,
    accommodationServiceDate: _v('accommodation_service_date'),
  );

  Future<void> _send() async {
    final error = _validationError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Faturayı Gönder'),
        content: Text(
          '${_v('name')} · ${_number?['document_no'] ?? 'Numara sağlayıcıda belirlenecek'}\n${_lines.length} kalem · ${_invoiceTypes[_invoiceType]}\nToplam: ${_amounts.total.toStringAsFixed(2)} TRY\nGönderim mali kayıt oluşturabilir. Bilgileri kontrol ettiniz mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla ve Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Persist the key and exact form before the network send. A retry uses the
      // same key, allowing the backend to resolve uncertain provider outcomes.
      final draft = await widget.api.saveElectronicInvoiceDraft(
        _draftBody(),
        id: _draftId,
      );
      _draftId = int.tryParse('${draft['id']}');
      await widget.api.submitElectronicInvoice(
        _payload(),
        isClient: widget.isClient,
      );
      if (_draftId != null)
        await widget.api.deleteElectronicInvoiceDraft(_draftId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura gönderimi kaydedildi.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (failure) {
      if (failure.statusCode == 422) {
        _key = _submissionKey();
        if (_draftId != null) {
          try {
            await widget.api.saveElectronicInvoiceDraft(
              _draftBody(),
              id: _draftId,
            );
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _error = failure.message);
    } catch (failure) {
      if (mounted)
        setState(
          () => _error =
              '$failure. Gönderim sonucunu giden belgelerden kontrol edin; taslak aynı işlem anahtarını koruyor.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lineEditor(_ComposerLine line, int index) {
    Widget field(String key, String label, {bool numeric = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: line.fields[key],
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {
          if (key == 'name') line.productId = null;
        }),
      ),
    );
    return Card(
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    tooltip: 'Kalemi kaldır',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _lines.removeAt(index);
                      line.dispose();
                    }),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickProduct(line),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(
                line.productId == null
                    ? 'Katalogdan Ürün / Hizmet Seç'
                    : 'Ürün #${line.productId} · Değiştir',
              ),
            ),
            field('name', 'Ürün / hizmet'),
            field('quantity', 'Miktar', numeric: true),
            field('unit', 'Birim'),
            field('unit_price', 'Birim fiyat', numeric: true),
            field('discount_rate', 'İskonto %', numeric: true),
            field('vat_rate', 'KDV %', numeric: true),
            if (const {
              'TEVKIFAT',
              'TEVKIFATIADE',
              'YTB_TEVKIFAT',
            }.contains(_invoiceType)) ...[
              field('withholding_code', 'Tevkifat kodu'),
              field('withholding_rate', 'Tevkifat oranı %', numeric: true),
            ],
            if (_invoiceType == 'TEVKIFATIADE') ...[
              field('return_ratio', 'İade edilen mal oranı %', numeric: true),
              field(
                'original_unwithheld_vat',
                'Alıştaki tevkifatsız KDV',
                numeric: true,
              ),
            ],
            if (const {
                  'ISTISNA',
                  'YTB_ISTISNA',
                  'IADE',
                  'YTB_IADE',
                }.contains(_invoiceType) ||
                line.get('vat_rate') == '0') ...[
              field('exemption_code', 'İstisna kodu'),
              field('exemption_reason', 'İstisna açıklaması'),
            ],
            if (_invoiceType.startsWith('YTB_')) ...[
              field('incentive_expense_type', 'Harcama tipi (01–04)'),
              field('machine_id', 'Makine ID'),
              field('machine_sequence_no', 'Makine sıra no'),
            ],
            if (_invoiceType == 'YTB_ISTISNA')
              field('waived_vat_rate', 'Vazgeçilen KDV %', numeric: true),
            if (_invoiceType == 'OZELMATRAH') ...[
              field('special_base_code', 'Özel matrah kodu'),
              field('special_base_amount', 'Özel matrah tutarı', numeric: true),
              field('special_expense_type', 'Gider türü'),
            ],
            if (_invoiceType == 'IHRACKAYITLI') ...[
              field('gtip_code', 'GTİP kodu'),
              field('buyer_dib_line_code', 'Alıcı DİB satır kodu'),
            ],
            field('bsmv_rate', 'BSMV % (varsa)', numeric: true),
            for (final tax in line.taxes) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tax.code} · ${invoiceTaxKind(tax.code)?.name ?? 'Ek vergi'}',
                    ),
                  ),
                  IconButton(
                    tooltip: '${tax.code} vergisini kaldır',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      line.taxes.remove(tax);
                      tax.dispose();
                      if (tax.code == '0071' && line.deductionCode == '4171') {
                        line.deductionCode = '';
                      }
                    }),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: tax.base,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Vergi matrahı (boşsa satır neti)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: tax.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: invoiceTaxKind(tax.code)?.mode == 'RATE'
                        ? 'Vergi oranı %'
                        : 'Vergi tutarı',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (variableVatBaseTaxCodes.contains(tax.code))
                DropdownButtonFormField<bool>(
                  isExpanded: true,
                  key: ValueKey(
                    'tax-base-${index}-${tax.code}-${tax.vatBaseIncluded}',
                  ),
                  initialValue: tax.vatBaseIncluded,
                  decoration: const InputDecoration(
                    labelText: 'KDV matrahına eklensin mi?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text('Evet, bedelin parçası'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Hayır, bedelden ayrı'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => tax.vatBaseIncluded = value),
                ),
            ],
            if (line.deductionCode.isNotEmpty) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.deductionCode} · ${invoiceTaxKind(line.deductionCode)?.name ?? 'Kesinti'}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kesintiyi kaldır',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      if (line.deductionCode == '4171') {
                        for (final tax
                            in line.taxes
                                .where((tax) => tax.code == '0071')
                                .toList()) {
                          line.taxes.remove(tax);
                          tax.dispose();
                        }
                      }
                      line.deductionCode = '';
                    }),
                  ),
                ],
              ),
              if (line.deductionCode != '4171')
                field(
                  'deduction_base',
                  'Stopaj matrahı (boşsa satır neti)',
                  numeric: true,
                ),
              field('deduction_rate', 'Kesinti oranı %', numeric: true),
              if (line.deductionCode == '4171')
                CheckboxListTile(
                  title: const Text(
                    '0071 ÖTV ürün ve alıcı uygunluğunu doğruladım; tamamı kesilecek.',
                  ),
                  value: line.eligibilityConfirmed,
                  onChanged: (value) =>
                      setState(() => line.eligibilityConfirmed = value == true),
                ),
            ],
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(
                'add-tax-$index-${line.taxes.length}-${line.deductionCode}',
              ),
              decoration: const InputDecoration(
                labelText: 'Ek vergi veya kesinti ekle',
              ),
              items: [
                for (final kind in availableInvoiceTaxes(
                  _invoiceType,
                  bsmv: (double.tryParse(line.get('bsmv_rate')) ?? 0) > 0,
                ))
                  if (!line.taxes.any((tax) => tax.code == kind.code))
                    DropdownMenuItem(
                      value: kind.code,
                      child: Text('${kind.code} · ${kind.name}'),
                    ),
                if (line.deductionCode.isEmpty &&
                    {'SATIS', 'IADE'}.contains(_invoiceType))
                  for (final code in const ['0003', '0011'])
                    DropdownMenuItem(
                      value: 'DEDUCT_$code',
                      child: Text('$code · ${invoiceTaxKind(code)?.name}'),
                    ),
                if (line.deductionCode.isEmpty &&
                    {'TEVKIFAT', 'IADE'}.contains(_invoiceType))
                  const DropdownMenuItem(
                    value: 'DEDUCT_4171',
                    child: Text('4171 · ÖTV 1. Liste Tevkifatı'),
                  ),
              ],
              onChanged: (value) => setState(() {
                if (value == null) return;
                if (value.startsWith('DEDUCT_')) {
                  line.deductionCode = value.substring(7);
                  if (line.deductionCode == '4171') {
                    line.fields['deduction_rate']!.text = '100';
                    if (!line.taxes.any((tax) => tax.code == '0071')) {
                      line.taxes.add(_ComposerTax('0071'));
                    }
                  }
                } else {
                  line.taxes.add(_ComposerTax(value));
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _documentType == 'EARCHIVE' ? 'E-Arşiv Oluştur' : 'E-Fatura Oluştur',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _documentType,
          decoration: const InputDecoration(labelText: 'Belge türü'),
          items: const [
            DropdownMenuItem(value: 'AUTO', child: Text('Otomatik')),
            DropdownMenuItem(value: 'EINVOICE', child: Text('E-Fatura')),
            DropdownMenuItem(value: 'EARCHIVE', child: Text('E-Arşiv')),
          ],
          onChanged: (value) => setState(() {
            _documentType = value ?? _documentType;
            _number = null;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _invoiceType,
          decoration: const InputDecoration(labelText: 'Fatura türü'),
          items: [
            for (final entry in _invoiceTypes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => setState(() {
            if (value != null && value != _invoiceType) {
              _invoiceType = value;
              _accountingPartnerId = null;
            }
          }),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Alıcı'),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickPartner,
          icon: const Icon(Icons.person_search_outlined),
          label: Text(
            _accountingPartnerId == null
                ? 'Cari Kartından Seç'
                : 'Cari #$_accountingPartnerId · Değiştir',
          ),
        ),
        _field('identifier', 'VKN / TCKN', keyboard: TextInputType.number),
        OutlinedButton.icon(
          onPressed: _busy ? null : _checkRecipient,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Mükellefiyeti Kontrol Et'),
        ),
        if (_recipient != null)
          Text(
            _recipient?['is_einvoice_user'] == true
                ? 'E-Fatura mükellefi'
                : 'E-Fatura mükellefi değil',
          ),
        _field('name', 'Alıcı adı / ünvanı'),
        _field('tax_office', 'Vergi dairesi'),
        _field('email', 'E-posta', keyboard: TextInputType.emailAddress),
        _field('phone', 'Telefon'),
        _field('street', 'Adres'),
        _field('building_no', 'Bina no'),
        _field('district', 'İlçe'),
        _field('city', 'İl'),
        _field('postal_code', 'Posta kodu'),
        const SectionHeader(title: 'Belge'),
        _field('issue_date', 'Fatura tarihi (YYYY-AA-GG)'),
        _field('serie', 'Seri (3 harf)'),
        OutlinedButton.icon(
          onPressed: _busy ? null : _previewNumber,
          icon: const Icon(Icons.tag),
          label: const Text('Numarayı Önizle'),
        ),
        if (_number != null)
          Text('Önerilen belge no: ${_number?['document_no'] ?? '—'}'),
        if (const {'IADE', 'TEVKIFATIADE'}.contains(_invoiceType)) ...[
          _field('billing_reference', 'İade edilen fatura no'),
          _field('billing_reference_date', 'İade edilen fatura tarihi'),
        ],
        if (_invoiceType == 'YTB_IADE') ...[
          const SectionHeader(title: 'İade Edilen Faturalar'),
          for (var index = 0; index < _returnReferences.length; index++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${index + 1}. fatura')),
                        if (_returnReferences.length > 1)
                          IconButton(
                            tooltip: 'Referansı kaldır',
                            onPressed: () => setState(() {
                              _returnReferences.removeAt(index).dispose();
                            }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _returnReferences[index].number,
                      decoration: const InputDecoration(
                        labelText: 'Fatura numarası',
                      ),
                    ),
                    TextField(
                      controller: _returnReferences[index].date,
                      decoration: const InputDecoration(
                        labelText: 'Fatura tarihi (YYYY-AA-GG)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _returnReferences.add(_ReturnReference())),
            icon: const Icon(Icons.add),
            label: const Text('İade Faturası Ekle'),
          ),
        ],
        if (_invoiceType.startsWith('YTB_')) ...[
          _field('investment_incentive_number', 'Yatırım teşvik belgesi no'),
          _field('investment_incentive_date', 'Yatırım teşvik belgesi tarihi'),
        ],
        if (_invoiceType == 'KONAKLAMA')
          _field('accommodation_service_date', 'Konaklama tamamlanma tarihi'),
        if (_invoiceType == 'IHRACKAYITLI')
          _field(
            'export_registered_code',
            'İhraç kayıtlı işlem kodu (701–704)',
          ),
        if (const {'TEVKIFAT', 'YTB_TEVKIFAT'}.contains(_invoiceType)) ...[
          _field(
            'withholding_operation_date',
            'İşlem tarihi (boşsa fatura tarihi)',
          ),
          _field(
            'withholding_operation_total',
            'Aynı işlemin KDV dahil toplamı',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            'withholding_operation_reference',
            'İşlem / sözleşme referansı',
          ),
        ],
        _field('despatch_number', 'İrsaliye no (varsa)'),
        _field('despatch_date', 'İrsaliye tarihi (varsa)'),
        if (_documentType != 'EINVOICE') ...[
          SwitchListTile(
            title: const Text('E-posta ile gönder'),
            value: _sendEmail,
            onChanged: (value) => setState(() => _sendEmail = value),
          ),
          if (_sendEmail) _field('earchive_email', 'Gönderim e-postası'),
        ],
        _field('note', 'Fatura notu'),
        const SectionHeader(title: 'Kalemler'),
        for (var index = 0; index < _lines.length; index++)
          _lineEditor(_lines[index], index),
        OutlinedButton.icon(
          onPressed: () => setState(() => _lines.add(_ComposerLine())),
          icon: const Icon(Icons.add),
          label: const Text('Kalem Ekle'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ara Toplam: ${_amounts.net.toStringAsFixed(2)} TRY'),
                Text('KDV: ${_amounts.vat.toStringAsFixed(2)} TRY'),
                if (_amounts.extra != 0)
                  Text('Ek vergiler: ${_amounts.extra.toStringAsFixed(2)} TRY'),
                if (_amounts.deduction != 0)
                  Text(
                    'Kesintiler: -${_amounts.deduction.toStringAsFixed(2)} TRY',
                  ),
                if (_amounts.withholding != 0)
                  Text(
                    'Tevkifat: ${_amounts.withholding.toStringAsFixed(2)} TRY',
                  ),
                if (_amounts.bsmv != 0)
                  Text('BSMV: ${_amounts.bsmv.toStringAsFixed(2)} TRY'),
                if (_amounts.accommodation != 0)
                  Text(
                    'Konaklama vergisi: ${_amounts.accommodation.toStringAsFixed(2)} TRY',
                  ),
                const Divider(),
                Text(
                  'Ödenecek Tutar: ${_amounts.total.toStringAsFixed(2)} TRY',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Taslak Kaydet'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(_busy ? 'İşleniyor…' : 'Önizle ve Gönder'),
        ),
      ],
    ),
  );
}

class EInvoiceDraftsPage extends StatefulWidget {
  const EInvoiceDraftsPage({
    super.key,
    required this.api,
    required this.isClient,
    required this.documentType,
  });
  final FinkitApi api;
  final bool isClient;
  final String documentType;

  @override
  State<EInvoiceDraftsPage> createState() => _EInvoiceDraftsPageState();
}

class _EInvoiceDraftsPageState extends State<EInvoiceDraftsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.api.electronicInvoiceDrafts(widget.documentType);
  }

  Future<void> _delete(Map<String, dynamic> draft) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Taslağı Sil'),
        content: Text('${draft['title']} taslağı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.api.deleteElectronicInvoiceDraft(
        int.parse('${draft['id']}'),
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Taslak Faturalar')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(
              title: 'Taslak Faturalar',
              subtitle: widget.documentType == 'EARCHIVE'
                  ? 'E-Arşiv taslakları'
                  : 'E-Fatura taslakları',
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text('Taslaklar alınamadı: ${snapshot.error}'),
              )
            else if (snapshot.data!.isEmpty)
              const EmptyState(
                icon: Icons.drafts_outlined,
                title: 'Taslak yok',
                description: 'Henüz taslak kaydedilmedi.',
              )
            else
              for (final draft in snapshot.data!)
                Card(
                  child: ListTile(
                    title: Text('${draft['title']}'),
                    subtitle: Text(dateText(draft['updated_at'])),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EInvoiceComposerPage(
                            api: widget.api,
                            isClient: widget.isClient,
                            documentType: widget.documentType,
                            draft: draft,
                          ),
                        ),
                      );
                      if (mounted) setState(_reload);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Taslağı sil',
                      onPressed: () => _delete(draft),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
