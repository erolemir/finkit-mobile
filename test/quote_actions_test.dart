import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class QuoteApi extends FinkitApi {
  String? status;
  bool? revise;
  String? search;
  int page = 0;

  @override
  Future<Map<String, dynamic>> quotePage({
    int page = 1,
    String? search,
    String? status,
    int? partnerId,
    String? startDate,
    String? endDate,
  }) async {
    this.page = page;
    this.search = search;
    return {
      'items': [
        {
          'id': 7,
          'number': 'TEK-1',
          'status': 'DRAFT',
          'issue_date': '2026-09-27',
          'valid_until': '2026-10-27',
          'gross_amount': 120,
        },
      ],
      'total': 21,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [];

  @override
  Future<Map<String, dynamic>> quoteDetail(int quoteId) async => {
    'id': quoteId,
    'number': 'TEK-1',
    'status': 'DRAFT',
    'issue_date': '2026-09-27',
    'valid_until': '2026-10-27',
    'net_amount': 100,
    'vat_amount': 20,
    'gross_amount': 120,
    'lines': [
      {
        'description': 'Danışmanlık',
        'quantity': 1,
        'unit': 'ADET',
        'vat_rate': 20,
        'line_total': 120,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> copyQuote(
    int quoteId, {
    bool revise = false,
  }) async {
    this.revise = revise;
    return {};
  }

  @override
  Future<Map<String, dynamic>> setQuoteStatus(
    int quoteId,
    String status,
  ) async {
    this.status = status;
    return {};
  }
}

void main() {
  testWidgets('quote details expose revision, copy and valid status actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = QuoteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuotesPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEK-1'));
    await tester.pumpAndSettle();
    expect(find.text('Danışmanlık'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Revize et'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Revize et'));
    await tester.pumpAndSettle();
    expect(api.revise, true);
    await tester.tap(find.text('TEK-1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('İptal et'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    expect(api.status, 'CANCELLED');
    expect(tester.takeException(), isNull);
  });
}
