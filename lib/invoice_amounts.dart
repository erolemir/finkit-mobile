import 'dart:math';

double invoiceMoney(double value) =>
    !value.isFinite || value.abs() > 1000000000000
    ? 0
    : ((value + 2.220446049250313e-16 * max(1, value.abs())) * 100).round() /
          100;

double accommodationTaxRate(String? serviceDate) {
  if (serviceDate == null || serviceDate.isEmpty) return 0;
  return serviceDate.compareTo('2026-05-01') >= 0 &&
          serviceDate.compareTo('2026-12-31') <= 0
      ? 1
      : 2;
}

class InvoiceAmountTotals {
  const InvoiceAmountTotals({
    required this.gross,
    required this.discount,
    required this.net,
    required this.vat,
    required this.withholding,
    required this.deduction,
    required this.extra,
    required this.bsmv,
    required this.accommodation,
    required this.total,
  });
  final double gross;
  final double discount;
  final double net;
  final double vat;
  final double withholding;
  final double deduction;
  final double extra;
  final double bsmv;
  final double accommodation;
  final double total;
}

const _vatBaseTaxCodes = <String>{
  '0061',
  '0071',
  '0073',
  '0074',
  '0075',
  '0076',
  '0077',
  '4071',
  '8005',
  '9077',
  '9944',
};
const _variableVatBaseTaxCodes = <String>{'1047', '1048', '8001'};
const _rateTaxCodes = <String>{
  '0022',
  '0061',
  '4071',
  '4080',
  '4081',
  '8005',
  '9021',
  '9944',
};

double _number(dynamic value) {
  final number = double.tryParse('$value');
  return number != null && number.isFinite ? number : 0;
}

class InvoiceLineAmounts {
  const InvoiceLineAmounts({
    required this.gross,
    required this.discount,
    required this.net,
    required this.vat,
    required this.withholding,
    required this.deduction,
    required this.extra,
    required this.bsmv,
    required this.vatBase,
  });
  final double gross,
      discount,
      net,
      vat,
      withholding,
      deduction,
      extra,
      bsmv,
      vatBase;
}

InvoiceLineAmounts calculateInvoiceLineAmounts(Map<String, dynamic> line) {
  final gross = _number(line['quantity']) * _number(line['unit_price']);
  final discount = gross * _number(line['discount_rate']) / 100;
  final net = invoiceMoney(gross - discount);
  final taxes = line['additional_taxes'];
  final amounts = <String, double>{};
  double extra = 0, included = 0;
  if (taxes is List) {
    for (final raw in taxes.whereType<Map>()) {
      final code = '${raw['code'] ?? ''}';
      final base = '${raw['taxable_amount'] ?? ''}'.trim().isNotEmpty
          ? _number(raw['taxable_amount'])
          : net;
      final amount = invoiceMoney(
        _rateTaxCodes.contains(code)
            ? base * _number(raw['rate']) / 100
            : _number(raw['amount']),
      );
      amounts[code] = amount;
      extra += amount;
      if (_variableVatBaseTaxCodes.contains(code)
          ? raw['vat_base_included'] == true
          : _vatBaseTaxCodes.contains(code)) {
        included += amount;
      }
    }
  }
  final vatBase = '${line['special_base_code'] ?? ''}'.isNotEmpty
      ? _number(line['special_base_amount'])
      : invoiceMoney(net + included);
  final vat = invoiceMoney(vatBase * _number(line['vat_rate']) / 100);
  final bsmv = invoiceMoney(net * _number(line['bsmv_rate']) / 100);
  final deductionTax = line['deduction_tax'];
  double deduction = 0;
  if (deductionTax is Map) {
    final base = deductionTax['code'] == '4171'
        ? amounts['0071'] ?? 0
        : _number(deductionTax['taxable_amount']) > 0
        ? _number(deductionTax['taxable_amount'])
        : net;
    deduction = invoiceMoney(base * _number(deductionTax['rate']) / 100);
  }
  return InvoiceLineAmounts(
    gross: invoiceMoney(gross),
    discount: invoiceMoney(discount),
    net: net,
    vat: vat,
    withholding: invoiceMoney(vat * _number(line['withholding_rate']) / 100),
    deduction: deduction,
    extra: invoiceMoney(extra),
    bsmv: bsmv,
    vatBase: vatBase,
  );
}

InvoiceAmountTotals calculateInvoiceAmounts(
  List<Map<String, dynamic>> lines,
  String invoiceType, {
  String? accommodationServiceDate,
}) {
  double gross = 0, discount = 0, net = 0, vat = 0;
  double withholding = 0, deduction = 0, extra = 0, bsmv = 0, accommodation = 0;
  final accommodationRate = invoiceType == 'KONAKLAMA'
      ? accommodationTaxRate(accommodationServiceDate)
      : 0;
  for (final line in lines) {
    final amounts = calculateInvoiceLineAmounts(line);
    gross += amounts.gross;
    discount += amounts.discount;
    net += amounts.net;
    vat += amounts.vat;
    deduction += amounts.deduction;
    extra += amounts.extra;
    bsmv += amounts.bsmv;
    accommodation += invoiceMoney(amounts.net * accommodationRate / 100);
    if (const {
      'TEVKIFAT',
      'TEVKIFATIADE',
      'YTB_TEVKIFAT',
    }.contains(invoiceType)) {
      withholding += amounts.withholding;
    }
  }
  net = invoiceMoney(net);
  gross = invoiceMoney(gross);
  discount = invoiceMoney(discount);
  vat = invoiceMoney(vat);
  withholding = invoiceMoney(withholding);
  deduction = invoiceMoney(deduction);
  extra = invoiceMoney(extra);
  bsmv = invoiceMoney(bsmv);
  accommodation = invoiceMoney(accommodation);
  return InvoiceAmountTotals(
    gross: gross,
    discount: discount,
    net: net,
    vat: vat,
    withholding: withholding,
    deduction: deduction,
    extra: extra,
    bsmv: bsmv,
    accommodation: accommodation,
    total: invoiceMoney(
      net +
          (invoiceType == 'IHRACKAYITLI' ? 0 : vat) +
          accommodation +
          bsmv -
          withholding +
          extra -
          deduction,
    ),
  );
}
