import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_financial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FinancialApi extends FinkitApi {
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    calls.add(path);
    if (path.endsWith('summary')) {
      return {
        'total_subscription_revenue': 100,
        'total_service_fee_revenue': 75,
        'monthly_breakdown': [
          {
            'month': '2026-09',
            'subscription_revenue': 100,
            'service_fee_revenue': 75,
          },
        ],
      };
    }
    if (path.endsWith('subscriptions')) {
      return {
        'items': [
          {
            'full_name': 'Mükellef A',
            'email': 'a@example.com',
            'is_active': true,
          },
        ],
      };
    }
    return {
      'items': [
        {
          'advisor_name': 'Müşavir B',
          'office_name': 'B Ofisi',
          'clients': [
            {
              'full_name': 'Mükellef A',
              'monthly_fee': 75,
              'payment_status': 'PAID',
            },
          ],
        },
      ],
    };
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('admin financial summary, tabs and fee detail fit a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _FinancialApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminFinancialPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      api.calls,
      containsAll([
        '/admin/financial/summary',
        '/admin/financial/subscriptions',
        '/admin/financial/service-fees',
      ]),
    );
    expect(find.text('Mükellef A'), findsOneWidget);
    await tester.ensureVisible(find.text('Hizmet ücretleri'));
    await tester.tap(find.text('Hizmet ücretleri'));
    await tester.pumpAndSettle();
    expect(find.text('Müşavir B'), findsOneWidget);
    await tester.tap(find.text('Müşavir B'));
    await tester.pumpAndSettle();
    expect(find.text('Mükellef A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
