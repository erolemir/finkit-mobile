import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/sales_invoice_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PurchaseFormApi extends FinkitApi {
  Map<String, dynamic>? created;
  String? requestKey;

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 3, 'name': 'Tedarik A', 'partner_type': 'SUPPLIER'},
  ];

  @override
  Future<List<Map<String, dynamic>>> products() async => [];

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [];

  @override
  Future<List<Map<String, dynamic>>> purchaseInvoices({
    String? type,
    String? status,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> expenseCategories() async => [];

  @override
  Future<Map<String, dynamic>> createPurchaseInvoiceRecord(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    created = body;
    requestKey = idempotencyKey;
    return {'id': 21, 'status': 'DRAFT'};
  }
}

void main() {
  testWidgets('purchase draft keeps two independent lines and supplier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = PurchaseFormApi();
    await tester.pumpWidget(
      MaterialApp(
        home: SalesInvoiceFormPage(
          api: api,
          initialType: 'ALIS',
          purchase: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tedarikçi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tedarik A').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Fatura numarası'),
      'ALI-21',
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
    await tester.enterText(find.widgetWithText(TextField, 'Açıklama'), 'Mal A');
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
      'Mal B',
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
    expect(api.created?['supplier_id'], 3);
    expect(api.created?['partner_id'], isNull);
    expect(api.created?['invoice_type'], 'ALIS');
    expect(api.created?['number'], 'ALI-21');
    final lines = (api.created?['lines'] as List?)
        ?.cast<Map<String, dynamic>>();
    expect(lines, hasLength(2));
    expect(lines?[0]['description'], 'Mal A');
    expect(lines?[1]['description'], 'Mal B');
    expect(api.requestKey, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
