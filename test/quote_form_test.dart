import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/quote_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class QuoteFormApi extends FinkitApi {
  Map<String, dynamic>? created;

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 2, 'name': 'Atlas', 'partner_type': 'CUSTOMER'},
  ];

  @override
  Future<List<Map<String, dynamic>>> products() async => [];

  @override
  Future<Map<String, dynamic>> createQuoteRecord(
    Map<String, dynamic> body,
  ) async {
    created = body;
    return {};
  }
}

void main() {
  testWidgets('quote form saves two independently edited lines on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = QuoteFormApi();
    await tester.pumpWidget(MaterialApp(home: QuoteFormPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müşteri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atlas').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Açıklama').first,
      'Hizmet A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Birim fiyat').first,
      '100',
    );
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Kalem ekle'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Kalem ekle'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kalem 2'),
      250,
      scrollable: scrollable,
    );
    final descriptions = find.widgetWithText(TextField, 'Açıklama');
    await tester.enterText(descriptions.last, 'Hizmet B');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Teklifi kaydet'),
      400,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('Teklifi kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teklifi kaydet'));
    await tester.pumpAndSettle();
    final lines = (api.created?['lines'] as List?)
        ?.cast<Map<String, dynamic>>();
    expect(lines, hasLength(2));
    expect(lines?[0]['description'], 'Hizmet A');
    expect(lines?[1]['description'], 'Hizmet B');
    expect(tester.takeException(), isNull);
  });
}
