import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LogsApi extends FinkitApi {
  Map<String, String>? lastQuery;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path.endsWith('/stats')) {
      return {
        'total': 30,
        'logins_today': 2,
        'failed_logins_today': 1,
        'active_users_today': 2,
        'page_views_today': 5,
        'cta_clicks_today': 3,
      };
    }
    lastQuery = query;
    return {
      'total': 30,
      'items': [
        {
          'id': 1,
          'action': 'LOGIN_SUCCESS',
          'category': 'AUTH',
          'user_name': 'Test Müşavir',
          'user_email': 'test@example.invalid',
          'created_at': '2026-09-27T10:00:00',
          'path': '/api/auth/login',
          'status_code': 200,
        },
      ],
    };
  }
}

void main() {
  testWidgets('admin log filters, stats and detail fit phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = LogsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminLogsPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Toplam olay: 30'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Giriş başarılı'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Giriş başarılı'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Girişler'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Girişler'));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['category'], 'AUTH');
    await tester.scrollUntilVisible(find.text('Giriş başarılı'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Giriş başarılı'));
    await tester.pumpAndSettle();
    expect(find.text('/api/auth/login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
