import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ApprovalApi extends FinkitApi {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async => {
    'items': [
      {'user_id': 14, 'full_name': 'Bekleyen Müşavir', 'status': 'PENDING'},
    ],
    'total': 1,
  };

  @override
  Future<Map<String, dynamic>> adminPost(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    this.path = path;
    this.body = body;
    return {'status': 'APPROVED'};
  }
}

void main() {
  testWidgets('advisor approval is sent only after confirmation', (
    tester,
  ) async {
    final api = ApprovalApi();
    final module = adminModules.firstWhere(
      (item) => item.id == 'advisor-approvals',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(
          body: AdminResourcePage(api: api, module: module),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekleyen Müşavir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müşaviri onayla'));
    await tester.pumpAndSettle();
    expect(api.path, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.path, isNull);
    await tester.tap(find.text('Bekleyen Müşavir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müşaviri onayla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.path, '/admin/advisor-approvals/14/approve');
    expect(api.body, isEmpty);
  });
}
