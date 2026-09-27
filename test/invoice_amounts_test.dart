import 'package:finkit_mobile/invoice_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web parity: additional taxes change VAT base and payable', () {
    final line = <String, dynamic>{
      'quantity': '1',
      'unit_price': '1000',
      'vat_rate': '20',
      'additional_taxes': [
        {'code': '0074', 'amount': '100'},
        {'code': '1047', 'amount': '10', 'vat_base_included': false},
      ],
    };
    final amount = calculateInvoiceAmounts([line], 'SATIS');
    expect(amount.net, 1000);
    expect(amount.vat, 220);
    expect(amount.extra, 110);
    expect(amount.total, 1330);
  });

  test('web parity: deduction is subtracted from payable', () {
    final sale = <String, dynamic>{
      'quantity': '1',
      'unit_price': '1000',
      'vat_rate': '20',
      'deduction_tax': {'code': '0003', 'rate': '10'},
    };
    final amount = calculateInvoiceAmounts([sale], 'SATIS');
    expect(amount.deduction, 100);
    expect(amount.total, 1100);
  });

  test('discount, VAT and withholding follow web line rounding', () {
    final totals = calculateInvoiceAmounts([
      {
        'quantity': '2',
        'unit_price': '123.45',
        'discount_rate': '10',
        'vat_rate': '20',
        'withholding_rate': '50',
      },
    ], 'TEVKIFAT');
    expect(totals.net, 222.21);
    expect(totals.vat, 44.44);
    expect(totals.withholding, 22.22);
    expect(totals.total, 244.43);
  });

  test('2026 accommodation rate window matches web rule', () {
    expect(accommodationTaxRate('2026-04-30'), 2);
    expect(accommodationTaxRate('2026-05-01'), 1);
    expect(accommodationTaxRate('2026-12-31'), 1);
    expect(accommodationTaxRate('2027-01-01'), 2);
  });

  test('invalid preview numbers cannot overflow money rounding', () {
    expect(invoiceMoney(double.infinity), 0);
    expect(invoiceMoney(double.nan), 0);
    expect(invoiceMoney(1e300), 0);
  });
}
