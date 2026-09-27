import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ProductManagementApi extends FinkitApi {
  final item = <String, dynamic>{
    'id': 3,
    'code': 'U001',
    'name': 'Eski Ürün',
    'product_type': 'PRODUCT',
    'unit': 'ADET',
    'sales_price': '100',
    'purchase_price': '50',
    'manual_cost': '50',
    'vat_rate': '20',
    'track_inventory': true,
    'minimum_stock': '1',
    'is_active': true,
  };
  Map<String, dynamic>? updated;
  int? deleted;

  @override
  Future<List<Map<String, dynamic>>> products() async =>
      deleted == null ? [item] : [];

  @override
  Future<Map<String, dynamic>> product(int id) async => item;

  @override
  Future<Map<String, dynamic>> productStockDetail(int id) async => {
    'current_quantity': '2',
    'balances': [
      {'warehouse_name': 'Ana Depo', 'quantity': '2', 'value': '100'},
    ],
    'movements': [
      {
        'id': 9,
        'description': 'Stok girişi',
        'movement_date': '2026-09-27',
        'warehouse_name': 'Ana Depo',
        'signed_quantity': '2',
        'total_cost': '100',
      },
    ],
    'sales': [
      {
        'invoice_id': 4,
        'number': 'SAT-4',
        'quantity': '1',
        'line_total': '120',
      },
    ],
    'purchases': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> changes,
  ) async {
    expect(id, 3);
    updated = changes;
    item.addAll(changes);
    return item;
  }

  @override
  Future<void> deleteProduct(int id) async => deleted = id;
}

void main() {
  testWidgets('product history and edit refresh the card on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ProductManagementApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: ProductsPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eski Ürün'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Depo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Stok girişi'), 250);
    expect(find.text('Stok girişi'), findsOneWidget);
    await tester.tap(find.textContaining('Satışlar'));
    await tester.pumpAndSettle();
    expect(find.text('SAT-4'), findsOneWidget);
    await tester.ensureVisible(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad'),
      'Yeni Ürün',
    );
    await tester.ensureVisible(find.text('Değişiklikleri Kaydet'));
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();
    expect(api.updated?['name'], 'Yeni Ürün');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Yeni Ürün'), findsOneWidget);
  });

  testWidgets('delete requires confirmation and hides the product', (
    tester,
  ) async {
    final api = ProductManagementApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: ProductsPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eski Ürün'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(api.deleted, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.deleted, isNull);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(api.deleted, 3);
    expect(find.text('Eski Ürün'), findsNothing);
  });
}
