import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_pages.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RefundApi extends FinkitApi {
  int refunds = 0;
  int reconciliations = 0;
  String? attemptStatus;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async => {
    'items': [
      {
        'id': 7,
        'user_name': 'Test Mükellef',
        'amount': 100.0,
        'refunded_amount': 20.0,
        'status': 'PARTIALLY_REFUNDED',
        'refund_attempt_status': attemptStatus,
      },
    ],
    'total': 1,
  };

  @override
  Future<Map<String, dynamic>> adminPost(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (path == '/admin/payments/7/refund/reconcile') {
      reconciliations++;
      attemptStatus = null;
      return {'status': 'success', 'message': 'PayTR iadesi doğrulandı'};
    }
    expect(path, '/admin/payments/7/refund');
    this.body = body;
    refunds++;
    return {'status': 'success'};
  }
}

void main() {
  testWidgets('admin refund validates remaining amount and requires approval', (
    tester,
  ) async {
    final api = RefundApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(
          body: AdminResourcePage(
            api: api,
            module: adminModules.firstWhere(
              (module) => module.id == 'payments',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ödemeyi İade Et'));
    await tester.pumpAndSettle();
    expect(api.refunds, 0);
    await tester.enterText(
      find.widgetWithText(TextField, 'İade tutarı (TL)'),
      '90',
    );
    await tester.tap(find.text('İadeyi Onayla'));
    await tester.pumpAndSettle();
    expect(api.refunds, 0);
    expect(
      find.text('Geçerli bir tutar ve alfasayısal referans girin.'),
      findsOneWidget,
    );

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ödemeyi İade Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'İade tutarı (TL)'),
      '50',
    );
    await tester.tap(find.text('İadeyi Onayla'));
    await tester.pumpAndSettle();
    expect(api.refunds, 1);
    expect(api.body?['amount'], 50);
    expect(
      '${api.body?['request_key']}',
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  testWidgets('uncertain refund exposes status inquiry without resending', (
    tester,
  ) async {
    final api = RefundApi()..attemptStatus = 'UNKNOWN';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: Scaffold(
          body: AdminResourcePage(
            api: api,
            module: adminModules.firstWhere((module) => module.id == 'payments'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    expect(find.text('Ödemeyi İade Et'), findsNothing);
    await tester.tap(find.text('PayTR İade Durumunu Sorgula'));
    await tester.pumpAndSettle();
    expect(api.reconciliations, 1);
    expect(api.refunds, 0);
  });
}
