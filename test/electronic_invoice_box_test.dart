import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/electronic_invoice_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class BoxApi extends FinkitApi {
  bool missingAccount = false;
  int page = 0;
  String? status;
  String? identifier;
  String? start;
  String? end;
  bool? incoming;

  @override
  Future<Map<String, dynamic>> electronicInvoiceBox({
    required bool isClient,
    required bool incoming,
    String documentType = 'EINVOICE',
    String? status,
    String? startDate,
    String? endDate,
    String? customerIdentifier,
    int page = 1,
  }) async {
    if (missingAccount) {
      throw ApiException('Önce İzibiz hesabınızı tanımlayın', 404);
    }
    this.page = page;
    this.status = status;
    identifier = customerIdentifier;
    start = startDate;
    end = endDate;
    this.incoming = incoming;
    return {
      'items': [
        {
          'uuid': 'invoice-$page',
          'invoice_number': 'ABC202600000000$page',
          'receiver_name': 'Atlas Ltd.',
          'issue_date': '2026-09-27',
          'total': 120,
          'document_type': documentType,
        },
      ],
      'total': 21,
    };
  }
}

void main() {
  testWidgets('missing Izibiz account offers settings', (tester) async {
    final api = BoxApi()..missingAccount = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElectronicInvoiceBox(
            api: api,
            isClient: true,
            incoming: false,
            documentType: 'EINVOICE',
            refreshKey: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İzibiz hesabını tanımla'), findsOneWidget);
  });

  testWidgets('box filters and pages use server parameters on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = BoxApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElectronicInvoiceBox(
            api: api,
            isClient: false,
            incoming: false,
            documentType: 'EARCHIVE',
            refreshKey: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABC2026000000001'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '1234567890');
    await tester.enterText(find.byType(TextField).at(2), '2026-09-01');
    await tester.enterText(find.byType(TextField).at(3), '2026-09-30');
    await tester.tap(find.text('Filtrele'));
    await tester.pumpAndSettle();
    expect(api.identifier, '1234567890');
    expect(api.start, '2026-09-01');
    expect(api.end, '2026-09-30');
    await tester.ensureVisible(find.byTooltip('Sonraki sayfa'));
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(api.page, 2);
    expect(find.text('ABC2026000000002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
