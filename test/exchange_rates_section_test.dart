import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/exchange_rates_section.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RatesApi extends FinkitApi {
  int fetches = 0;
  String? requestedDate;

  @override
  Future<List<Map<String, dynamic>>> exchangeRates({
    String? currency,
    String? startDate,
    String? endDate,
  }) async => [
    {
      'currency': 'USD',
      'rate_date': '2026-09-27',
      'rate': '42.1234',
      'source': 'TCMB',
    },
  ];

  @override
  Future<Map<String, dynamic>> fetchTcmbRates(String rateDate) async {
    fetches++;
    requestedDate = rateDate;
    return {
      'items': [
        {'currency': 'USD'},
      ],
    };
  }
}

void main() {
  testWidgets('cash rates show published values and fetch selected TCMB day', (
    tester,
  ) async {
    final api = RatesApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: ExchangeRatesSection(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('USD · 2026-09-27'), findsOneWidget);
    expect(find.text('42.1234'), findsOneWidget);
    await tester.tap(find.text('TCMB’den Getir'));
    await tester.pumpAndSettle();
    expect(api.fetches, 1);
    expect(api.requestedDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(find.text('1 TCMB kuru alındı.'), findsOneWidget);
  });
}
