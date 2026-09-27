import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_settings_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SettingsApi extends FinkitApi {
  String? action;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async => path == '/admin/settings'
      ? {'items': <Map<String, dynamic>>[]}
      : {'maintenance_mode': false, 'scheduled_at': null};

  @override
  Future<Map<String, dynamic>> adminPost(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    action = path;
    this.body = body;
    return {
      'maintenance_mode': false,
      'scheduled_at': '2026-10-01T12:00:00+00:00',
    };
  }
}

void main() {
  testWidgets('maintenance scheduling waits for explicit admin approval', (
    tester,
  ) async {
    final api = SettingsApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(body: AdminSettingsPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bakımı Planla'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tarih ve saat (YYYY-AA-GGTSS:DD)'),
      '2026-10-01T15:00',
    );
    await tester.tap(find.text('Bakımı Planla'));
    await tester.pumpAndSettle();
    expect(api.action, isNull);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.action, '/admin/maintenance/schedule');
    expect(api.body?['scheduled_at'], '2026-10-01T15:00');
    expect(api.body?['notify_users'], true);
  });
}
