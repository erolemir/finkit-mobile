class InvoiceTaxKind {
  const InvoiceTaxKind(this.code, this.name, this.mode, this.vatBase);
  final String code;
  final String name;
  final String mode;
  final bool vatBase;
}

// Mirrors the active GIB choices in the web invoiceTaxCatalog.
const invoiceTaxKinds = <InvoiceTaxKind>[
  InvoiceTaxKind('0003', 'Gelir Vergisi Stopajı', 'SPECIAL', false),
  InvoiceTaxKind('0011', 'Kurumlar Vergisi Stopajı', 'SPECIAL', false),
  InvoiceTaxKind('0022', 'Sigorta Muameleleri Vergisi', 'RATE', false),
  InvoiceTaxKind('0061', 'KKDF Kesintisi', 'RATE', true),
  InvoiceTaxKind('0071', 'ÖTV 1. Liste', 'AMOUNT', true),
  InvoiceTaxKind('0073', 'ÖTV 3. Liste', 'AMOUNT', true),
  InvoiceTaxKind('0074', 'ÖTV 4. Liste', 'AMOUNT', true),
  InvoiceTaxKind('0075', 'ÖTV 3A Liste', 'AMOUNT', true),
  InvoiceTaxKind('0076', 'ÖTV 3B Liste', 'AMOUNT', true),
  InvoiceTaxKind('0077', 'ÖTV 3C Liste', 'AMOUNT', true),
  InvoiceTaxKind('1047', 'Damga Vergisi', 'AMOUNT', false),
  InvoiceTaxKind(
    '1048',
    '5035 Sayılı Kanuna Göre Damga Vergisi',
    'AMOUNT',
    false,
  ),
  InvoiceTaxKind('4071', 'Elektrik ve Havagazı Tüketim Vergisi', 'RATE', true),
  InvoiceTaxKind('4080', 'Özel İletişim Vergisi', 'RATE', false),
  InvoiceTaxKind(
    '4081',
    '5035 Sayılı Kanuna Göre Özel İletişim Vergisi',
    'RATE',
    false,
  ),
  InvoiceTaxKind('4171', 'ÖTV 1. Liste Tevkifatı', 'SPECIAL', false),
  InvoiceTaxKind('8001', 'Borsa Tescil Ücreti', 'AMOUNT', true),
  InvoiceTaxKind('8005', 'Elektrik Tüketim Vergisi', 'RATE', true),
  InvoiceTaxKind('8006', 'Telsiz Kullanım Ücreti', 'AMOUNT', false),
  InvoiceTaxKind('8007', 'Telsiz Ruhsat Ücreti', 'AMOUNT', false),
  InvoiceTaxKind('8008', 'Çevre Temizlik Vergisi', 'AMOUNT', false),
  InvoiceTaxKind(
    '9021',
    '4961 Banka Sigorta Muameleleri Vergisi',
    'RATE',
    false,
  ),
  InvoiceTaxKind('9077', 'ÖTV 2. Liste', 'AMOUNT', true),
  InvoiceTaxKind('9944', 'Hal Rüsumu', 'RATE', true),
];

InvoiceTaxKind? invoiceTaxKind(String code) {
  for (final kind in invoiceTaxKinds) {
    if (kind.code == code) return kind;
  }
  return null;
}

const variableVatBaseTaxCodes = {'1047', '1048', '8001'};

List<InvoiceTaxKind> availableInvoiceTaxes(
  String invoiceType, {
  bool bsmv = false,
}) {
  if (bsmv) {
    return {'SATIS', 'ISTISNA'}.contains(invoiceType)
        ? invoiceTaxKinds.where((kind) => kind.code == '0061').toList()
        : [];
  }
  if (invoiceType == 'ISTISNA') {
    return invoiceTaxKinds
        .where((kind) => {'0022', '9021'}.contains(kind.code))
        .toList();
  }
  if ({'SATIS', 'IADE'}.contains(invoiceType)) {
    return invoiceTaxKinds
        .where(
          (kind) =>
              kind.mode != 'SPECIAL' &&
              (invoiceType != 'SATIS' || !{'0022', '9021'}.contains(kind.code)),
        )
        .toList();
  }
  return [];
}

double _n(dynamic value) {
  final number = double.tryParse('$value');
  return number != null && number.isFinite ? number : 0;
}

String _s(dynamic value) => '${value ?? ''}'.trim();

List<String> invoiceAdditionalTaxErrors(
  String invoiceType,
  List<Map<String, dynamic>> lines, {
  bool investmentIncentive = false,
}) {
  final errors = <String>[];
  final financialCodes = <String>{};
  var hasBsmv = false;
  var hasOtherThanKkdf = false;
  for (final line in lines) {
    hasBsmv |= _n(line['bsmv_rate']) > 0;
    for (final raw in (line['additional_taxes'] as List? ?? [])) {
      if (raw is! Map) continue;
      final code = _s(raw['code']);
      hasOtherThanKkdf |= code != '0061';
      if ({'0022', '9021'}.contains(code)) financialCodes.add(code);
    }
  }
  if (hasBsmv && hasOtherThanKkdf) {
    errors.add('BSMV ile yalnız KKDF ek vergisi birlikte kullanılabilir');
  }
  if (financialCodes.isNotEmpty &&
      (financialCodes.length > 1 ||
          lines.any(
            (line) => !(line['additional_taxes'] as List? ?? [])
                .whereType<Map>()
                .any((tax) => financialCodes.contains(_s(tax['code']))),
          ))) {
    errors.add('BSMV/SMV tüm satırlarda aynı vergi koduyla kullanılmalı');
  }
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final taxes = (line['additional_taxes'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final codes = taxes.map((tax) => _s(tax['code'])).toList();
    if (codes.toSet().length != codes.length) {
      errors.add('${i + 1}. satırda aynı vergi iki kez seçilemez');
    }
    if (codes.length > 10)
      errors.add('${i + 1}. satırda en fazla 10 ek vergi kullanılabilir');
    final specialOtv =
        invoiceType == 'TEVKIFAT' &&
        (line['deduction_tax'] is Map &&
            _s((line['deduction_tax'] as Map)['code']) == '4171') &&
        codes.length == 1 &&
        codes.first == '0071';
    if (taxes.isNotEmpty &&
        ((!{'SATIS', 'IADE', 'ISTISNA'}.contains(invoiceType) && !specialOtv) ||
            investmentIncentive)) {
      errors.add('Ek vergiler bu fatura tipiyle kullanılamaz');
    }
    if (line['deduction_tax'] is Map &&
        _s((line['deduction_tax'] as Map)['code']) == '4171' &&
        (codes.length != 1 || codes.first != '0071')) {
      errors.add('4171 kesintisi için aynı satırda yalnız 0071 ÖTV olmalı');
    }
    if (invoiceType == 'ISTISNA' &&
        codes.any(
          (code) =>
              !{'0022', '9021'}.contains(code) &&
              !(code == '0061' && _n(line['bsmv_rate']) > 0),
        )) {
      errors.add(
        'İstisna faturasında yalnız sigorta muamele vergisi veya BSMV ile KKDF seçilebilir',
      );
    }
    if (codes
            .where(
              (code) => {
                '0071',
                '0073',
                '0074',
                '0075',
                '0076',
                '0077',
                '9077',
              }.contains(code),
            )
            .length >
        1) {
      errors.add('${i + 1}. satırda birden fazla ÖTV listesi seçilemez');
    }
    if ([
      {'1047', '1048'},
      {'4080', '4081'},
      {'4071', '8005'},
    ].any((group) => codes.where(group.contains).length > 1)) {
      errors.add(
        '${i + 1}. satırda alternatif vergi kodları birlikte kullanılamaz',
      );
    }
    if (codes.any((code) => {'0022', '9021'}.contains(code)) &&
        (codes.length != 1 ||
            _n(line['vat_rate']) != 0 ||
            _s(line['exemption_code']) != '209')) {
      errors.add(
        '${i + 1}. satırdaki BSMV/SMV için KDV %0 ve 209 istisna kodu gerekir',
      );
    }
    for (final tax in taxes) {
      final code = _s(tax['code']);
      final kind = invoiceTaxKind(code);
      final base = _s(tax['taxable_amount']);
      final rate = _s(tax['rate']);
      final amount = _s(tax['amount']);
      if (code == '0061' && _n(line['bsmv_rate']) > 0 && base.isEmpty) {
        errors.add('${i + 1}. satırda BSMV ile KKDF için faiz matrahını girin');
      }
      if (variableVatBaseTaxCodes.contains(code) &&
          tax['vat_base_included'] is! bool) {
        errors.add('${i + 1}. satır $code için KDV matrahı seçimini yapın');
      }
      if (!variableVatBaseTaxCodes.contains(code) &&
          tax.containsKey('vat_base_included')) {
        errors.add(
          '${i + 1}. satır $code için KDV matrahı seçimi kullanılamaz',
        );
      }
      if (base.isNotEmpty &&
          (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(base) ||
              _n(base) <= 0 ||
              _n(base) > 9999999999.99)) {
        errors.add('${i + 1}. satır $code için pozitif vergi matrahı girin');
      }
      if (kind == null || kind.mode == 'SPECIAL') {
        errors.add('${i + 1}. satırda geçersiz ek vergi kodu: $code');
      } else if (kind.mode == 'RATE' &&
          (rate.isEmpty ||
              _n(rate) <= 0 ||
              _n(rate) > 100 ||
              amount.isNotEmpty)) {
        errors.add(
          '${i + 1}. satır $code için 0-100 arasında pozitif oran girin',
        );
      } else if (kind.mode == 'AMOUNT' &&
          (amount.isEmpty ||
              _n(amount) <= 0 ||
              _n(amount) > 9999999999.99 ||
              !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount) ||
              rate.isNotEmpty)) {
        errors.add('${i + 1}. satır $code için pozitif tutar girin');
      }
    }
  }
  return errors.toSet().toList();
}
