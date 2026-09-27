import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/more_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CardRegistrationApi extends FinkitApi {
  int preparations = 0;

  @override
  Future<List<Map<String, dynamic>>> storedCards() async => [];

  @override
  Future<List<Map<String, dynamic>>> autoPaymentInstructions() async => [];

  @override
  Future<Map<String, dynamic>> prepareCardRegistration() async {
    preparations++;
    return {};
  }
}

void main() {
  testWidgets('new card requires explicit charge confirmation on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = CardRegistrationApi();
    await tester.pumpWidget(
      MaterialApp(home: StoredCardsPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni Kart Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Kartımı kaydet'), findsNothing);
    expect(find.text('Kartı Doğrula ve Kaydet'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kart Üzerindeki İsim'),
      'Test User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kart Numarası'),
      '4111111111111111',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Ay (AA)'), '12');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Yıl (YYYY)'),
      '2028',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'CVV'), '123');
    await tester.ensureVisible(find.text('Kartı Doğrula ve Kaydet'));
    await tester.tap(find.text('Kartı Doğrula ve Kaydet'));
    await tester.pumpAndSettle();
    expect(api.preparations, 0);
    expect(find.textContaining('küçük bir doğrulama tutarı'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.preparations, 0);
    expect(tester.takeException(), isNull);
  });
}
