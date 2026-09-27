import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/extra_documents_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ExtraDocumentApi extends FinkitApi {
  String? kind;
  Map<String, dynamic>? payload;
  int sends = 0;

  @override
  Future<Map<String, dynamic>> createExtraDocument(
    String kind,
    Map<String, dynamic> payload,
  ) async {
    this.kind = kind;
    this.payload = payload;
    sends++;
    return {'uuid': 'created-1'};
  }

  @override
  Future<Map<String, dynamic>> checkDespatchUser(String identifier) async => {
    'is_einvoice_user': true,
    'suggested_alias': 'urn:mail:defaultpk',
  };
}

Future<void> scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  await scrollTo(tester, label);
  await tester.enterText(find.widgetWithText(TextField, label), value);
}

void main() {
  testWidgets('E-SMM requires confirmation and uses the web payload shape', (
    tester,
  ) async {
    final api = ExtraDocumentApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: ExtraDocumentCreatePage(api: api, kind: 'esmm'),
      ),
    );
    await enter(tester, 'VKN / TCKN', '1234567890');
    await enter(tester, 'Ad / Ünvan', 'Test Alıcı');
    await enter(tester, 'Ürün / Hizmet', 'Danışmanlık');
    await enter(tester, 'Birim fiyat', '100');
    await scrollTo(tester, 'Gönder');
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    await tester.tap(find.text('Onayla ve Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(api.kind, 'esmm');
    expect((api.payload!['customer'] as Map)['identifier'], '1234567890');
    final line = (api.payload!['lines'] as List).single as Map;
    expect(line['quantity'], 1);
    expect(line['unit_price'], 100);
    expect(line['gv_stopaj_rate'], 20);
  });

  testWidgets('E-İrsaliye checks recipient and carries alias', (tester) async {
    final api = ExtraDocumentApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: ExtraDocumentCreatePage(api: api, kind: 'despatches'),
      ),
    );
    await enter(tester, 'VKN / TCKN', '1234567890');
    await tester.tap(find.text('E-İrsaliye Mükellefiyetini Kontrol Et'));
    await tester.pumpAndSettle();
    await enter(tester, 'Ad / Ünvan', 'Alıcı');
    await enter(tester, 'Ürün / Hizmet', 'Ürün');
    await scrollTo(tester, 'Gönder');
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla ve Gönder'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(api.kind, 'despatches');
    expect(api.payload!['receiver_alias'], 'urn:mail:defaultpk');
  });
}
