import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/sales_invoice_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SalesFormApi extends FinkitApi {
  Map<String, dynamic>? created;
  String? requestKey;

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 2, 'name': 'Atlas', 'partner_type': 'CUSTOMER'},
  ];

  @override
  Future<List<Map<String, dynamic>>> products() async => [];

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [];

  @override
  Future<List<Map<String, dynamic>>> salesInvoices({
    String? type,
    String? status,
  }) async => [];

  @override
  Future<Map<String, dynamic>> createSalesInvoiceRecord(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    created = body;
    requestKey = idempotencyKey;
    return {'id': 12, 'status': 'DRAFT'};
  }
}

void main() {
  testWidgets('sales return draft sends two lines and original reference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = SalesFormApi();
    await tester.pumpWidget(
      MaterialApp(
        home: SalesInvoiceFormPage(api: api, initialType: 'IADE'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müşteri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atlas').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Harici fatura numarası'),
      'SAT-2026-1',
    );
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Açıklama'),
      300,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Açıklama').first,
      'İade kalemi A',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Birim fiyat'),
      300,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Birim fiyat').first,
      '100',
    );
    await tester.scrollUntilVisible(
      find.text('Kalem ekle'),
      350,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Kalem ekle'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kalem 2'),
      300,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Açıklama').last,
      'İade kalemi B',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Taslak oluştur'),
      500,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('Taslak oluştur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taslak oluştur'));
    await tester.pumpAndSettle();
    expect(api.created?['invoice_type'], 'IADE');
    expect(api.created?['billing_reference'], 'SAT-2026-1');
    expect(api.created?['source_type'], 'MANUAL');
    final lines = (api.created?['lines'] as List?)
        ?.cast<Map<String, dynamic>>();
    expect(lines, hasLength(2));
    expect(lines?[0]['description'], 'İade kalemi A');
    expect(lines?[1]['description'], 'İade kalemi B');
    expect(api.requestKey, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
