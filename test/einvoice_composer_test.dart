import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/einvoice_composer_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ComposerApi extends FinkitApi {
  int draftSaves = 0;
  int sends = 0;
  String? savedKey;
  String? sentKey;
  Map<String, dynamic>? sentPayload;
  Map<String, dynamic>? savedDraft;

  @override
  Future<Map<String, dynamic>> electronicInvoiceAccount({
    required bool isClient,
  }) async => {
    'account': {
      'einvoice_serie': 'SYN',
      'einvoice_series': ['SYN', 'ABC'],
      'earchive_serie': 'EAR',
      'earchive_series': ['EAR', 'ARC'],
    },
  };

  @override
  Future<List<Map<String, dynamic>>> searchPartners(String search) async => [
    {
      'id': 9,
      'code': 'M009',
      'name': 'Seçilen Cari',
      'partner_type': 'CUSTOMER',
      'tax_number': '1234567890',
      'city': 'İstanbul',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> searchProducts(String search) async => [
    {
      'id': 14,
      'code': 'U014',
      'name': 'Seçilen Ürün',
      'unit': 'ADET',
      'sales_price': '100',
      'vat_rate': '20',
    },
  ];

  @override
  Future<Map<String, dynamic>> saveElectronicInvoiceDraft(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    draftSaves++;
    savedDraft = body;
    savedKey = '${(body['content'] as Map)['form']['submission_key']}';
    return {'id': id ?? 7};
  }

  @override
  Future<Map<String, dynamic>> checkElectronicInvoiceUser(
    String identifier, {
    required bool isClient,
  }) async => {'is_einvoice_user': true};

  @override
  Future<Map<String, dynamic>> previewElectronicInvoiceNumber({
    required bool isClient,
    required String documentType,
    required String issueDate,
    String? serie,
  }) async => {'serie': 'ABC', 'document_no': 'ABC2026000000001'};

  @override
  Future<Map<String, dynamic>> submitElectronicInvoice(
    Map<String, dynamic> payload, {
    required bool isClient,
  }) async {
    sends++;
    sentKey = '${payload['submission_key']}';
    sentPayload = payload;
    return {'uuid': 'invoice-1'};
  }

  @override
  Future<void> deleteElectronicInvoiceDraft(int id) async {}
}

Future<void> scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registered invoice codes appear in the composer dropdown', (
    tester,
  ) async {
    final api = ComposerApi();
    await tester.pumpWidget(
      MaterialApp(
        home: EInvoiceComposerPage(
          api: api,
          isClient: false,
          documentType: 'EINVOICE',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Fatura kodu (3 harf)');
    final seriesField = find.byKey(
      const ValueKey('invoice-series-EINVOICE-SYN,ABC-'),
    );
    await tester.ensureVisible(seriesField);
    await tester.pumpAndSettle();
    await tester.tap(seriesField);
    await tester.pumpAndSettle();
    expect(find.text('SYN'), findsWidgets);
    expect(find.text('ABC'), findsWidgets);
    expect(find.text('ARC'), findsNothing);
  });
  testWidgets('YTB return sends all invoice references', (tester) async {
    final api = ComposerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: EInvoiceComposerPage(
          api: api,
          isClient: false,
          documentType: 'EINVOICE',
          draft: {
            'content': {
              'form': {
                'invoice_type': 'YTB_IADE',
                'identifier': '1234567890',
                'name': 'Teşvik İadesi',
                'issue_date': '2026-09-27',
                'investment_incentive_number': '123456',
                'investment_incentive_date': '2026-09-27',
                'billing_references': [
                  {'number': 'ABC2026000000001', 'date': '2026-09-01'},
                  {'number': 'ABC2026000000002', 'date': '2026-09-02'},
                ],
              },
              'lines': [
                {
                  'name': 'Ürün',
                  'unit': 'ADET',
                  'quantity': '1',
                  'unit_price': '100',
                  'vat_rate': '20',
                  'incentive_expense_type': '02',
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.tap(find.text('Mükellefiyeti Kontrol Et'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Numarayı Önizle');
    await tester.tap(find.text('Numarayı Önizle'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Önizle ve Gönder');
    await tester.tap(find.text('Önizle ve Gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla ve Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect((api.sentPayload?['billing_references'] as List).length, 2);
  });

  testWidgets('catalog choices persist partner and product links in draft', (
    tester,
  ) async {
    final api = ComposerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: EInvoiceComposerPage(
          api: api,
          isClient: false,
          documentType: 'EINVOICE',
        ),
      ),
    );
    await tester.tap(find.text('Cari Kartından Seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçilen Cari'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'VKN / TCKN'), findsOneWidget);
    await scrollTo(tester, 'Katalogdan Ürün / Hizmet Seç');
    await tester.tap(find.text('Katalogdan Ürün / Hizmet Seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçilen Ürün'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Taslak Kaydet');
    await tester.tap(find.text('Taslak Kaydet'));
    await tester.pumpAndSettle();
    final content = api.savedDraft?['content'] as Map;
    expect((content['form'] as Map)['accounting_partner_id'], 9);
    expect(((content['lines'] as List).first as Map)['product_id'], 14);
  });

  testWidgets('saving a draft does not submit an invoice', (tester) async {
    final api = ComposerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: EInvoiceComposerPage(
          api: api,
          isClient: false,
          documentType: 'EINVOICE',
        ),
      ),
    );
    await scrollTo(tester, 'Taslak Kaydet');
    await tester.tap(find.text('Taslak Kaydet'));
    await tester.pumpAndSettle();
    expect(api.draftSaves, 1);
    expect(api.sends, 0);
    expect(api.savedKey, isNotEmpty);
    expect(find.text('Taslak kaydedildi. Gönderim yapılmadı.'), findsOneWidget);
  });

  testWidgets('sending requires approval and reuses the persisted key', (
    tester,
  ) async {
    final api = ComposerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: EInvoiceComposerPage(
          api: api,
          isClient: false,
          documentType: 'EINVOICE',
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'VKN / TCKN'),
      '1234567890',
    );
    await tester.tap(find.text('Mükellefiyeti Kontrol Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Alıcı adı / ünvanı'),
      'Test Alıcı',
    );
    await scrollTo(tester, 'Numarayı Önizle');
    await tester.tap(find.text('Numarayı Önizle'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Ürün / hizmet');
    await tester.enterText(
      find.widgetWithText(TextField, 'Ürün / hizmet'),
      'Hizmet',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Birim fiyat'),
      '100',
    );
    await scrollTo(tester, 'Önizle ve Gönder');
    await tester.tap(find.text('Önizle ve Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    await tester.tap(find.text('Önizle ve Gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla ve Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(api.draftSaves, 1);
    expect(api.sentKey, api.savedKey);
  });

  testWidgets(
    'drafted excise and stamp tax reach the send payload and totals',
    (tester) async {
      final api = ComposerApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFinkitTheme(),
          home: EInvoiceComposerPage(
            api: api,
            isClient: false,
            documentType: 'EINVOICE',
            draft: {
              'id': 7,
              'content': {
                'form': {
                  'document_type': 'EINVOICE',
                  'invoice_type': 'SATIS',
                  'identifier': '1234567890',
                  'name': 'Vergi Testi',
                  'issue_date': '2026-09-27',
                },
                'lines': [
                  {
                    'name': 'Ürün',
                    'unit': 'ADET',
                    'quantity': '1',
                    'unit_price': '1000',
                    'vat_rate': '20',
                    'additional_taxes': [
                      {'code': '0074', 'amount': '100'},
                      {
                        'code': '1047',
                        'amount': '10',
                        'vat_base_included': false,
                      },
                    ],
                  },
                ],
              },
            },
          ),
        ),
      );
      await tester.tap(find.text('Mükellefiyeti Kontrol Et'));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Numarayı Önizle');
      await tester.tap(find.text('Numarayı Önizle'));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Ödenecek Tutar: 1330.00 TRY');
      expect(find.text('Ek vergiler: 110.00 TRY'), findsOneWidget);
      await scrollTo(tester, 'Önizle ve Gönder');
      await tester.tap(find.text('Önizle ve Gönder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla ve Gönder'));
      await tester.pumpAndSettle();
      expect(api.sends, 1);
      final line = (api.sentPayload!['lines'] as List).first as Map;
      final taxes = line['additional_taxes'] as List;
      expect(taxes, hasLength(2));
      expect((taxes[0] as Map)['amount'], 100);
      expect((taxes[1] as Map)['vat_base_included'], false);
    },
  );
}
