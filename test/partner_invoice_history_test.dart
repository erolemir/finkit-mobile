import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/partner_invoice_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HistoryApi extends FinkitApi {
  int outgoingSeen = 0;

  @override
  Future<Map<String, dynamic>> partnerInvoiceOverview(
    int partnerId, {
    int outgoingPage = 1,
    int incomingPage = 1,
  }) async {
    expect(partnerId, 7);
    outgoingSeen = outgoingPage;
    return {
      'outgoing': {
        'total': '150.00',
        'count': 21,
        'page': outgoingPage,
        'items': [
          {
            'id': outgoingPage,
            'number': 'ABC2026000000001',
            'display_date': '2026-09-27',
            'invoice_type': 'SATIS',
            'amount': '150.00',
            'currency': 'TRY',
          },
        ],
      },
      'incoming': {'total': '0.00', 'count': 0, 'items': []},
    };
  }
}

void main() {
  testWidgets('partner invoice history shows both directions and pages', (
    tester,
  ) async {
    final api = HistoryApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerInvoiceHistoryPage(
          api: api,
          partnerId: 7,
          partnerName: 'Test Cari',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABC2026000000001'), findsOneWidget);
    expect(find.textContaining('Gelen faturalar'), findsOneWidget);
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(api.outgoingSeen, 2);
  });
}
