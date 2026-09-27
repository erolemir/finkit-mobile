import 'package:finkit_mobile/invoice_type_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GIB withholding code and rate must match', () {
    final form = {'invoice_type': 'TEVKIFAT', 'issue_date': '2026-09-27'};
    final line = <String, dynamic>{
      'quantity': '1',
      'unit_price': '15000',
      'vat_rate': '20',
      'withholding_code': '601',
      'withholding_rate': '50',
    };
    expect(invoiceFiscalErrors(form, [line]).join(' '), contains('uyuşmuyor'));
    line['withholding_rate'] = '40';
    expect(invoiceFiscalErrors(form, [line]), isEmpty);
  });

  test(
    '2026 partial withholding threshold is checked on VAT included amount',
    () {
      final form = {'invoice_type': 'TEVKIFAT', 'issue_date': '2026-09-27'};
      final line = <String, dynamic>{
        'quantity': '1',
        'unit_price': '10000',
        'vat_rate': '20',
        'withholding_code': '601',
        'withholding_rate': '40',
      };
      expect(invoiceFiscalErrors(form, [line]).join(' '), contains('12000'));
      line['unit_price'] = '10001';
      expect(invoiceFiscalErrors(form, [line]), isEmpty);
    },
  );

  test(
    'withholding invoice permits an ordinary line beside a withheld line',
    () {
      final form = {'invoice_type': 'TEVKIFAT', 'issue_date': '2026-09-27'};
      final lines = <Map<String, dynamic>>[
        {
          'quantity': '1',
          'unit_price': '15000',
          'vat_rate': '20',
          'withholding_code': '601',
          'withholding_rate': '40',
        },
        {'quantity': '1', 'unit_price': '100', 'vat_rate': '20'},
      ];
      expect(invoiceFiscalErrors(form, lines), isEmpty);
    },
  );

  test('withholding return compares original unwithheld VAT share', () {
    final form = {
      'invoice_type': 'TEVKIFATIADE',
      'issue_date': '2026-09-27',
      'billing_reference': 'ABC2026000000001',
    };
    final line = <String, dynamic>{
      'quantity': '1',
      'unit_price': '100000',
      'vat_rate': '10',
      'withholding_code': '602',
      'withholding_rate': '90',
      'return_ratio': '20',
      'original_unwithheld_vat': '5000',
    };
    expect(invoiceFiscalErrors(form, [line]), isEmpty);
    line['original_unwithheld_vat'] = '4000';
    expect(invoiceFiscalErrors(form, [line]).join(' '), contains('uyuşmuyor'));
  });

  test('BSMV requires zero VAT and exemption 209', () {
    final form = {'invoice_type': 'SATIS', 'issue_date': '2026-09-27'};
    final line = <String, dynamic>{
      'quantity': '1',
      'unit_price': '100',
      'vat_rate': '20',
      'bsmv_rate': '5',
    };
    expect(invoiceFiscalErrors(form, [line]).join(' '), contains('209'));
    line['vat_rate'] = '0';
    line['exemption_code'] = '209';
    expect(invoiceFiscalErrors(form, [line]), isEmpty);
  });

  test('YTB return checks each invoice reference independently', () {
    final form = <String, dynamic>{
      'invoice_type': 'YTB_IADE',
      'investment_incentive_number': '123456',
      'investment_incentive_date': '2026-09-27',
      'billing_references': [
        {'number': 'ABC2026000000001', 'date': '2026-09-01'},
        {'number': '', 'date': '2026-09-02'},
      ],
    };
    final line = <String, dynamic>{
      'quantity': '1',
      'unit_price': '100',
      'vat_rate': '20',
      'incentive_expense_type': '02',
    };
    expect(invoiceFiscalErrors(form, [line]).join(' '), contains('her fatura'));
    (form['billing_references'] as List)[1]['number'] = 'ABC2026000000002';
    expect(
      invoiceFiscalErrors(form, [line]).join(' '),
      isNot(contains('her fatura')),
    );
  });
}
