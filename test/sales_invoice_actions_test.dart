import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/invoice_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SalesActionsApi extends FinkitApi {
  int cancelled = 0;
  int copied = 0;
  String? despatch;
  Map<String, dynamic> current = {
    'id': 7,
    'number': 'SAT-1',
    'partner_id': 2,
    'status': 'FINALIZED',
    'payment_status': 'UNPAID',
    'source_type': 'MANUAL',
    'issue_date': '2026-09-27',
    'currency': 'TRY',
    'net_amount': 100,
    'vat_amount': 20,
    'gross_amount': 120,
    'paid_amount': 0,
    'lines': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> salesInvoice(int id) async => Map.of(current);

  @override
  Future<Map<String, dynamic>> partner(int id) async => {
    'id': id,
    'name': 'Atlas',
  };

  @override
  Future<Map<String, dynamic>> cancelSalesInvoice(int id) async {
    cancelled++;
    current = {...current, 'status': 'CANCELLED'};
    return Map.of(current);
  }

  @override
  Future<Map<String, dynamic>> copySalesInvoice(int id) async {
    copied++;
    current = {...current, 'id': 8, 'number': null, 'status': 'DRAFT'};
    return Map.of(current);
  }

  @override
  Future<Map<String, dynamic>> linkSalesInvoiceDespatch(
    int id,
    String despatchUuid,
  ) async {
    despatch = despatchUuid;
    current = {...current, 'despatch_uuid': despatchUuid};
    return Map.of(current);
  }
}

void main() {
  testWidgets('sales cancellation needs confirmation and copy creates draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = SalesActionsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDetailPage(api: api, invoice: api.current),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Faturayı iptal et'),
      300,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('Faturayı iptal et'));
    await tester.tap(find.text('Faturayı iptal et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.cancelled, 0);
    await tester.tap(find.text('Faturayı iptal et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    expect(api.cancelled, 1);
    expect(find.text('Faturayı iptal et'), findsNothing);
    await tester.ensureVisible(find.text('Faturayı kopyala'));
    await tester.tap(find.text('Faturayı kopyala'));
    await tester.pumpAndSettle();
    expect(api.copied, 1);
    expect(api.current['status'], 'DRAFT');
    expect(tester.takeException(), isNull);
  });

  testWidgets('despatch link accepts a tracking number', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = SalesActionsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDetailPage(api: api, invoice: api.current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('E-İrsaliye bağla'), 300);
    await tester.ensureVisible(find.text('E-İrsaliye bağla'));
    await tester.tap(find.text('E-İrsaliye bağla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'TRACK-123');
    await tester.tap(find.text('Bağla'));
    await tester.pumpAndSettle();
    expect(api.despatch, 'TRACK-123');
    expect(find.text('TRACK-123'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider content actions appear only with document UUID', (
    tester,
  ) async {
    final api = SalesActionsApi();
    api.current = {...api.current, 'e_document_uuid': 'doc-123'};
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDetailPage(api: api, invoice: api.current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('HTML görüntüle'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('HTML görüntüle'), findsOneWidget);
    expect(find.text('PDF indir'), findsOneWidget);
    expect(find.text('UBL indir'), findsOneWidget);
  });
}
