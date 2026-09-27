import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/purchase_invoice_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PurchaseManagementApi extends FinkitApi {
  final requests = <Map<String, dynamic>>[];
  int syncs = 0;

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 4, 'name': 'Tedarik A', 'partner_type': 'SUPPLIER'},
  ];

  @override
  Future<Map<String, dynamic>> purchaseInvoicePage({
    int page = 1,
    String? search,
    String? status,
    String? paymentStatus,
    int? supplierId,
    String? startDate,
    String? endDate,
  }) async {
    requests.add({
      'page': page,
      'search': search,
      'status': status,
      'payment_status': paymentStatus,
      'supplier_id': supplierId,
      'start_date': startDate,
      'end_date': endDate,
    });
    return {
      'total': 26,
      'items': [
        {
          'id': page,
          'number': 'ALI-$page',
          'supplier_id': 4,
          'issue_date': '2026-09-27',
          'gross_amount': 120,
          'status': 'DRAFT',
          'payment_status': 'UNPAID',
          'invoice_type': 'ALIS',
          'source_type': 'MANUAL',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> syncPurchaseInbox() async {
    syncs++;
    return {'inserted': 1, 'skipped': 0};
  }
}

void main() {
  testWidgets('purchase invoices use server search, paging and inbox sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = PurchaseManagementApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PurchaseInvoiceManagementPage(api: api, refreshKey: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ALI-1'), findsOneWidget);
    await tester.tap(find.text('Gelen kutusunu senkronize et'));
    await tester.pumpAndSettle();
    expect(api.syncs, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ALI');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.requests.last['search'], 'ALI');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byTooltip('Sonraki sayfa'),
      300,
      scrollable: scrollable,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(api.requests.last['page'], 2);
    expect(find.text('ALI-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
