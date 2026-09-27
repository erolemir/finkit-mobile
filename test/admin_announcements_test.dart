import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_announcements_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AnnouncementApi extends FinkitApi {
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> adminGet(String path, {Map<String, String>? query}) async => {
    'items': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> adminPost(String path, [Map<String, dynamic> body = const {}]) async {
    calls.add(path);
    if (path == '/admin/sms-send') {
      expect(body['target'], 'clients');
      expect(body['message'], contains('Yeni özellik'));
    }
    return {'id': 1};
  }
}

void main() {
  testWidgets('announcement SMS is sent only after explicit confirmation', (tester) async {
    final api = AnnouncementApi();
    await tester.pumpWidget(MaterialApp(
      theme: buildFinkitTheme(),
      home: Scaffold(body: AdminAnnouncementsPage(api: api)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni Duyuru'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Yeni özellik');
    await tester.enterText(find.widgetWithText(TextField, 'İçerik'), 'Duyuru metni');
    await tester.tap(find.text('Herkes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mükellefler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SMS de gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.calls, ['/admin/announcements', '/admin/sms-send']);
  });
}
