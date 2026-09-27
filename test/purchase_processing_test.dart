import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/purchase_processing_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PurchaseApi extends FinkitApi {
  List<int>? expensed;
  List<Map<String, dynamic>>? stocked;

  @override
  Future<List<Map<String, dynamic>>> products() async => [
    {
      'id': 10,
      'name': 'Stok Ürünü',
      'product_type': 'PRODUCT',
      'track_inventory': true,
      'is_active': true,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [
    {'id': 3, 'name': 'Ana Depo', 'is_active': true},
  ];

  @override
  Future<List<Map<String, dynamic>>> expenseCategories() async => [];

  @override
  Future<Map<String, dynamic>> expensifyPurchaseInvoice(
    int invoiceId,
    List<int> lineIds, {
    int? categoryId,
  }) async {
    expect(invoiceId, 42);
    expensed = lineIds;
    return {'id': invoiceId};
  }

  @override
  Future<Map<String, dynamic>> stockifyPurchaseInvoice(
    int invoiceId,
    List<Map<String, dynamic>> lines,
  ) async {
    expect(invoiceId, 42);
    stocked = lines;
    return {'id': invoiceId};
  }
}

const invoice = <String, dynamic>{
  'id': 42,
  'lines': [
    {'id': 1, 'description': 'Kalem A', 'quantity': 2, 'line_total': 120},
    {'id': 2, 'description': 'Kalem B', 'quantity': 1, 'line_total': 60},
  ],
};

void main() {
  testWidgets('purchase lines require confirmation before expensify', (
    tester,
  ) async {
    final api = PurchaseApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: PurchaseProcessingPage(api: api, invoice: invoice),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Kalemleri İşle');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(api.expensed, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.expensed, isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla ve İşle'));
    await tester.pumpAndSettle();
    expect(api.expensed, [1, 2]);
    expect(api.stocked, isNull);
  });
}
