import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WarehouseManagementApi extends FinkitApi {
  final item = <String, dynamic>{
    'id': 5,
    'code': 'D001',
    'name': 'Eski Depo',
    'city': 'Ankara',
    'is_default': true,
    'is_active': true,
  };
  Map<String, dynamic>? updated;

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [item];

  @override
  Future<Map<String, dynamic>> updateWarehouse(
    int id,
    Map<String, dynamic> changes,
  ) async {
    expect(id, 5);
    updated = changes;
    item.addAll(changes);
    return item;
  }
}

void main() {
  testWidgets('warehouse edits and archive confirmation work at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = WarehouseManagementApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: WarehousesPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eski Depo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depoyu Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Depo Adı'),
      'Yeni Depo',
    );
    await tester.ensureVisible(find.text('Değişiklikleri Kaydet'));
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();
    expect(api.updated?['name'], 'Yeni Depo');
    expect(find.text('Yeni Depo'), findsOneWidget);
    await tester.tap(find.text('Yeni Depo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depoyu Pasifleştir'));
    await tester.pumpAndSettle();
    expect(api.item['is_active'], true);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.item['is_active'], true);
    await tester.tap(find.text('Yeni Depo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depoyu Pasifleştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pasifleştir'));
    await tester.pumpAndSettle();
    expect(api.item['is_active'], false);
  });
}
