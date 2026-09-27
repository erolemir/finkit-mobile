import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/data_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ManagePartnerApi extends FinkitApi {
  final item = <String, dynamic>{
    'id': 7,
    'code': 'M001',
    'name': 'Eski Müşteri',
    'partner_type': 'CUSTOMER',
    'payment_term_days': 0,
    'is_active': true,
  };
  Map<String, dynamic>? updated;
  int? archived;

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async =>
      archived == null ? [item] : [];

  @override
  Future<Map<String, dynamic>> partner(int id) async => item;

  @override
  Future<Map<String, dynamic>> updatePartner(
    int id,
    Map<String, dynamic> changes,
  ) async {
    expect(id, 7);
    updated = changes;
    item.addAll(changes);
    return item;
  }

  @override
  Future<void> archivePartner(int id) async => archived = id;
}

Future<void> openPartnerAction(WidgetTester tester, String label) async {
  await tester.tap(find.text('Eski Müşteri'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('customer edit saves the changed card', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ManagePartnerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: CustomersPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await openPartnerAction(tester, 'Cari Kartını Düzenle');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad / ünvan'),
      'Yeni Müşteri',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.updated?['name'], 'Yeni Müşteri');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Müşteri'), findsOneWidget);
  });

  testWidgets('archive waits for an explicit confirmation', (tester) async {
    final api = ManagePartnerApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: CustomersPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await openPartnerAction(tester, 'Cari Kartını Arşivle');
    expect(api.archived, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.archived, isNull);
    await openPartnerAction(tester, 'Cari Kartını Arşivle');
    await tester.tap(find.text('Arşivle'));
    await tester.pumpAndSettle();
    expect(api.archived, 7);
  });
}
