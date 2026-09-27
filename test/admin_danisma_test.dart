import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_danisma_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DanismaAdminApi extends FinkitApi {
  String? decision;

  @override
  Future<Map<String, dynamic>> adminDanismaQuestionPage({
    int page = 1,
    String search = '',
  }) async => {
    'total': 1,
    'items': [
      {
        'id': 1,
        'title': 'KDV sorusu',
        'content': 'KDV nasıl hesaplanır?',
        'client_name': 'Test Mükellef',
        'answer_count': 1,
        'view_count': 3,
        'answers': [
          {
            'id': 2,
            'advisor_name': 'Test Müşavir',
            'content': 'Matrah üzerinden hesaplanır.',
            'price': 100,
            'is_paid': true,
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> adminDanismaStats() async => {
    'total_questions': 1,
    'total_answers': 1,
    'paid_answers': 1,
    'total_revenue': 100,
    'pending_refunds': 1,
  };

  @override
  Future<Map<String, dynamic>> adminDanismaFeedback({
    int page = 1,
    String feedbackType = '',
    String refundStatus = '',
  }) async => {
    'total': 1,
    'items': [
      {
        'id': 4,
        'question_title': 'KDV sorusu',
        'client_name': 'Test Mükellef',
        'feedback_type': 'wrong',
        'refund_status': 'pending',
        'amount': 100,
        'comment': 'Hatalı',
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> adminDanismaRefundDecision(
    int feedbackId, {
    required String decision,
    String? note,
  }) async {
    this.decision = decision;
    return {};
  }
}

void main() {
  testWidgets('admin consultation detail, stats and approved refund', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = DanismaAdminApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminDanismaPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('KDV sorusu'));
    await tester.pumpAndSettle();
    expect(find.text('Matrah üzerinden hesaplanır.'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İstatistikler'));
    await tester.pumpAndSettle();
    expect(find.text('Yanıt oranı'), findsOneWidget);
    await tester.tap(find.text('Geri bildirimler'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('İadeyi onayla'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('İadeyi onayla'));
    await tester.pumpAndSettle();
    expect(api.decision, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İadeyi onayla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.decision, 'approved');
    expect(tester.takeException(), isNull);
  });
}
