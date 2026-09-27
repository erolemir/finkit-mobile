import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/entry_forms.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class OpeningStockApi extends FinkitApi {
  double? netPrice;
  Map<String, dynamic>? stock;

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [
    {'id': 5, 'name': 'Ana Depo', 'is_default': true, 'is_active': true},
  ];

  @override
  Future<Map<String, dynamic>> createProduct({
    required String code,
    required String name,
    String type = 'PRODUCT',
    String unit = 'ADET',
    double vatRate = 20,
    double salesPrice = 0,
    double purchasePrice = 0,
    double manualCost = 0,
    bool trackInventory = true,
    String? barcode,
    String? description,
    double minimumStock = 0,
    bool isActive = true,
    Map<String, dynamic>? openingStock,
  }) async {
    netPrice = salesPrice;
    stock = openingStock;
    return {'id': 1};
  }
}

void main() {
  testWidgets('gross price and opening stock follow web catalog rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = OpeningStockApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showProductForm(context, api),
              child: const Text('Yeni ürün'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Yeni ürün'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Kalem');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satış Fiyatı'),
      '120',
    );
    await tester.ensureVisible(find.text('Girilen satış fiyatına KDV dâhil'));
    await tester.tap(find.text('Girilen satış fiyatına KDV dâhil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Miktar'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Miktar'), '2');
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Alış Fiyatı'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Alış Fiyatı'),
      '30',
    );
    await tester.ensureVisible(find.text('Ürünü Kaydet'));
    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();
    expect(api.netPrice, 100);
    expect(api.stock?['warehouse_id'], 5);
    expect(api.stock?['quantity'], 2);
    expect(api.stock?['unit_cost'], 30);
  });
}
