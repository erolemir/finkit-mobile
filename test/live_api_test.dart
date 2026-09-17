// Mobil istemcinin gerçek backend ile konuştuğunu doğrulayan canlı test.
//
// Çalıştırmak için:
//   $env:FINKIT_LIVE=1; flutter test test/live_api_test.dart
//
// Ortam değişkeni verilmezse test atlanır (CI ve offline ortamlar için).
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = String.fromEnvironment(
  'FINKIT_BASE',
  defaultValue: 'https://test.finkit.com.tr/api',
);

void main() {
  final live = Platform.environment['FINKIT_LIVE'] == '1';

  test('canli akis: giris, cari ve satis faturasi', () async {
    SharedPreferences.setMockInitialValues({});
    final api = FinkitApi();

    await api.login(
      email: 'musavir@gmail.com',
      password: '12345678',
      role: 'ADVISOR',
      apiBaseUrl: _baseUrl,
    );
    expect(api.token, isNotNull, reason: 'Giriş token üretmeli');

    final entity = await api.entity();
    expect(entity['id'], isNotNull, reason: 'Muhasebe entity dönmeli');

    final summary = await api.summary();
    expect(
      summary['sales_total'],
      isNotNull,
      reason: 'Özet metrikleri dönmeli',
    );

    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    final partner = await api.createPartner(
      code: 'MOB$stamp',
      name: 'Mobil Test Cari $stamp',
      type: 'CUSTOMER',
      phone: '0555 000 00 00',
      paymentTermDays: 30,
    );
    final partnerId = partner['id'] as int?;
    expect(partnerId, isNotNull);

    final invoice = await api.createSalesInvoice(
      partnerId: partnerId!,
      lines: [
        {
          'description': 'Mobil uygulama test satırı',
          'quantity': 2,
          'unit': 'ADET',
          'unit_price': 1500,
          'discount_rate': 0,
          'vat_rate': 20,
          'withholding_rate': 0,
        },
      ],
    );
    final invoiceId = invoice['id'] as int?;
    expect(invoiceId, isNotNull);
    expect(
      double.tryParse('${invoice['gross_amount']}'),
      closeTo(3600, 0.01),
      reason: '2 x 1500 + %20 KDV = 3600',
    );

    final finalized = await api.finalizeSalesInvoice(invoiceId!);
    expect(finalized['status'], isNot('DRAFT'));

    final invoices = await api.salesInvoices();
    expect(
      invoices.any((item) => item['id'] == invoiceId),
      isTrue,
      reason: 'Kesinleşen fatura listede görünmeli',
    );

    final vat = await api.report('vat');
    expect(vat['summary'], isA<Map>());

    final cashFlow = await api.report('cash-flow');
    expect(cashFlow['summary'], isA<Map>());
  }, skip: live ? false : 'FINKIT_LIVE=1 verilmedigi icin atlandi');
}
