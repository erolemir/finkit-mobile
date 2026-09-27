import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TransfersApi extends FinkitApi {
  String? requestedStatus;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    requestedStatus = query?['status'];
    final items = [
      {'id': 1, 'title': 'Bekleyen transfer', 'status': 'PENDING'},
      {
        'id': 2,
        'title': 'IBAN hatalı transfer',
        'status': 'FAILED',
        'retry_count': 0,
        'error_message': 'IBAN aktarilamadi: hatalı',
      },
      {
        'id': 3,
        'title': 'Sonucu belirsiz transfer',
        'status': 'SUBMITTED',
        'error_message': 'Sonuç belirsiz, mutabakat gerekli',
      },
    ];
    return {
      'total': items.length,
      'items': requestedStatus == null
          ? items
          : items.where((item) => item['status'] == requestedStatus).toList(),
    };
  }
}

void main() {
  testWidgets('transfer retry appears only for failed transfer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = TransfersApi();
    final module = adminModules.firstWhere((item) => item.id == 'transfers');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminResourcePage(api: api, module: module),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekleyen transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Transferi yeniden dene'), findsNothing);
    Navigator.of(tester.element(find.text('Bekleyen transfer').last)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonucu belirsiz transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Transferi yeniden dene'), findsNothing);
    Navigator.of(tester.element(find.text('Sonucu belirsiz transfer').last))
        .pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('IBAN hatalı transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Transferi yeniden dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
