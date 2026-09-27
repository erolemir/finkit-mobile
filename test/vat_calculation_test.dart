import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/vat_calculation_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class VatApi extends FinkitApi {
  String? start;
  String? end;

  @override
  Future<Map<String, dynamic>> vatCalculation({
    required String startDate,
    required String endDate,
  }) async {
    start = startDate;
    end = endDate;
    return {
      'incoming_vat': 100,
      'outgoing_vat': 400,
      'payable_vat': 300,
      'carried_vat': 0,
      'incoming_by_rate': [
        {'rate': '20', 'vat': 100},
      ],
      'outgoing_by_rate': [
        {'rate': '20', 'vat': 400},
      ],
      'einvoice_outgoing_count': 0,
    };
  }
}

void main() {
  testWidgets('KDV screen shows backend totals and changes report period', (
    tester,
  ) async {
    final api = VatApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: VatCalculationPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.start, isNotNull);
    expect(api.end, isNotNull);
    expect(find.text('Tahmini KDV borcu'), findsOneWidget);
    expect(find.textContaining('300,00'), findsWidgets);
    expect(find.text('Ön muhasebe satış faturası'), findsOneWidget);

    final currentStart = api.start;
    await tester.tap(find.text('Bu ay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geçen ay').last);
    await tester.pumpAndSettle();
    expect(api.start, isNot(currentStart));
    expect(tester.takeException(), isNull);
  });
}
