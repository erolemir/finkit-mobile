import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PartiesApi extends FinkitApi {
  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path == '/admin/advisors')
      return {
        'items': [
          {
            'user_id': 7,
            'full_name': 'Test Müşavir',
            'office_name': 'Atlas',
            'client_count': 1,
            'total_revenue': 100,
          },
        ],
        'total': 1,
      };
    if (path == '/admin/advisors/7')
      return {
        'user_id': 7,
        'full_name': 'Test Müşavir',
        'office_name': 'Atlas',
        'clients': [
          {
            'user_id': 8,
            'company_title': 'Örnek Ltd',
            'payment_status': 'PAID',
            'monthly_fee': 100,
          },
        ],
      };
    if (path == '/admin/clients')
      return {
        'items': [
          {
            'user_id': 8,
            'user': {
              'full_name': 'Test Mükellef',
              'email': 'client@example.invalid',
            },
            'company_title': 'Örnek Ltd',
            'advisor_name': 'Test Müşavir',
          },
        ],
        'total': 1,
      };
    return {};
  }
}

void main() {
  testWidgets('advisor detail shows linked clients on phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminResourcePage(
            api: PartiesApi(),
            module: const AdminModule(
              'advisors',
              'Müşavirler',
              '/admin/advisors',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Müşavir'));
    await tester.pumpAndSettle();
    expect(find.text('Bağlı mükellefler'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Örnek Ltd'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Örnek Ltd'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('client card uses nested user name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminResourcePage(
            api: PartiesApi(),
            module: const AdminModule(
              'clients',
              'Mükellefler',
              '/admin/clients',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Mükellef'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
