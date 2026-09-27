import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_system_updates_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SystemUpdateApi extends FinkitApi {
  Map<String, dynamic>? created;

  @override
  Future<Map<String, dynamic>> adminGet(String path, {Map<String, String>? query}) async => {
    'items': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> adminPost(String path, [Map<String, dynamic> body = const {}]) async {
    expect(path, '/admin/system-updates');
    created = body;
    return {'id': 1};
  }
}

Future<void> scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('system update email requires approval', (tester) async {
    final api = SystemUpdateApi();
    await tester.pumpWidget(MaterialApp(
      theme: buildFinkitTheme(),
      home: Scaffold(body: AdminSystemUpdatesPage(api: api)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni Güncelleme'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Revizyon no'), '2.0');
    await tester.enterText(find.widgetWithText(TextField, 'Yapılan güncellemeler'), 'Yeni ekranlar');
    await scrollTo(tester, 'E-posta da gönder');
    await tester.tap(find.text('E-posta da gönder'));
    await scrollTo(tester, 'Kaydet');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created, isNull);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.created?['send_email'], true);
    expect(api.created?['revision_number'], '2.0');
  });
}
