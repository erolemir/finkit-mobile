import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/data_pages.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SalesListApi extends FinkitApi {
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> salesInvoicePage({
    int page = 1,
    String? search,
    String? status,
    String? paymentStatus,
    String? invoiceType,
    int? partnerId,
    String? startDate,
    String? endDate,
  }) async {
    requests.add({
      'page': page,
      'search': search,
      'status': status,
      'payment_status': paymentStatus,
      'invoice_type': invoiceType,
      'partner_id': partnerId,
      'start_date': startDate,
      'end_date': endDate,
    });
    return {
      'total': 26,
      'items': [
        {
          'id': page,
          'number': 'SAT-$page',
          'partner_id': 5,
          'issue_date': '2026-09-27',
          'due_date': '2026-10-27',
          'gross_amount': 120,
          'status': 'DRAFT',
          'payment_status': 'UNPAID',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 5, 'name': 'Atlas', 'partner_type': 'CUSTOMER'},
  ];
}

void main() {
  testWidgets('return view stays on server IADE filter', (tester) async {
    final api = SalesListApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SalesReturnsPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requests.single['invoice_type'], 'IADE');
    expect(find.text('İade Faturaları'), findsOneWidget);
    expect(find.text('Fatura türü'), findsNothing);
  });

  testWidgets('sales list uses server filters and pagination on small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = SalesListApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesPage(api: api, refreshKey: 0, onQuickAction: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SAT-1'), findsOneWidget);
    expect(find.textContaining('Atlas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'SAT');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.requests.last['search'], 'SAT');

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Sonraki sayfa'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byTooltip('Sonraki sayfa'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(api.requests.last['page'], 2);
    expect(find.text('SAT-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
