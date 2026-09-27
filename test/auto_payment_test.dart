import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/more_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AutoPaymentApi extends FinkitApi {
  int enabled = 0;
  int disabled = 0;
  bool active = false;

  @override
  Future<List<Map<String, dynamic>>> storedCards() async => [
    {'ctoken': 'card-1', 'c_brand': 'VISA', 'last_4': '1234'},
  ];

  @override
  Future<List<Map<String, dynamic>>> autoPaymentInstructions() async => active
      ? [{'payment_purpose': 'subscription', 'ctoken': 'card-1', 'is_active': true}]
      : [];

  @override
  Future<Map<String, dynamic>> enableAutoPayment(String purpose, String ctoken) async {
    expect(purpose, 'subscription');
    expect(ctoken, 'card-1');
    enabled++;
    active = true;
    return {'is_active': true};
  }

  @override
  Future<Map<String, dynamic>> disableAutoPayment(String purpose) async {
    expect(purpose, 'subscription');
    disabled++;
    active = false;
    return {'status': 'ok'};
  }
}

void main() {
  testWidgets('automatic payment requires card choice and confirmation', (tester) async {
    final api = AutoPaymentApi();
    await tester.pumpWidget(MaterialApp(
      theme: buildFinkitTheme(),
      home: StoredCardsPage(api: api, refreshKey: 0),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinleştir').first);
    await tester.pumpAndSettle();
    expect(api.enabled, 0);
    await tester.tap(find.text('VISA *1234'));
    await tester.pumpAndSettle();
    expect(api.enabled, 0);
    await tester.tap(find.text('Talimat Ver'));
    await tester.pumpAndSettle();
    expect(api.enabled, 1);
    await tester.tap(find.text('Kapat').first);
    await tester.pumpAndSettle();
    expect(api.disabled, 0);
    await tester.tap(find.text('Kapat').last);
    await tester.pumpAndSettle();
    expect(api.disabled, 1);
  });
}
