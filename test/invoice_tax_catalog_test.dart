import 'package:finkit_mobile/invoice_tax_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web tax choices depend on invoice type and BSMV mode', () {
    expect(
      availableInvoiceTaxes('SATIS').any((tax) => tax.code == '0074'),
      true,
    );
    expect(
      availableInvoiceTaxes('ISTISNA').map((tax) => tax.code),
      containsAll(['0022', '9021']),
    );
    expect(availableInvoiceTaxes('SATIS', bsmv: true).map((tax) => tax.code), [
      '0061',
    ]);
    expect(availableInvoiceTaxes('TEVKIFAT'), isEmpty);
  });

  test('duplicate excise and invalid amounts are rejected before sending', () {
    final line = <String, dynamic>{
      'vat_rate': '20',
      'additional_taxes': [
        {'code': '0074', 'amount': 'NaN'},
        {'code': '0074', 'amount': '100'},
      ],
    };
    final errors = invoiceAdditionalTaxErrors('SATIS', [line]).join(' ');
    expect(errors, contains('aynı vergi'));
    expect(errors, contains('pozitif tutar'));
  });
}
