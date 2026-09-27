import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_sms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SmsApi extends FinkitApi {
  Map<String, String>? lastQuery;
  String? postedPath;
  Map<String, dynamic>? postedBody;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    lastQuery = query;
    if (path.endsWith('/7')) {
      return {
        'order_id': '7',
        'status_text': 'Gönderiliyor',
        'messages': [
          {'number': '05550000000', 'status_text': 'Gönderiliyor'},
        ],
      };
    }
    return {
      'count': 1,
      'orders': [
        {
          'id': 7,
          'sender': 'FINKIT',
          'status': 113,
          'status_text': 'Gönderiliyor',
          'total': 1,
          'delivered': 0,
          'undelivered': 0,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> adminPost(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    postedPath = path;
    postedBody = body;
    return {'status': 'success'};
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('SMS detail, cancellation approval and targeted send on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _SmsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminSmsPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.lastQuery?['page'], '1');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sipariş #7'));
    await tester.pumpAndSettle();
    expect(find.text('05550000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('SMS siparişini iptal et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.postedPath, isNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('SMS gönder'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tüm kullanıcılar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özel numaralar').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Duyuru');
    await tester.enterText(find.byType(TextField).at(2), '05550000000');
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(api.postedPath, isNull);
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(api.postedPath, '/admin/sms-send');
    expect(api.postedBody?['custom_numbers'], ['05550000000']);
    expect(tester.takeException(), isNull);
  });
}
