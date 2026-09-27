import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/data_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PartnerApi extends FinkitApi {
  @override
  Future<Map<String, dynamic>> partner(int id) async => {
    'id': id,
    'name': 'Test Müşteri',
    'partner_type': 'CUSTOMER',
  };
}

void main() {
  testWidgets('customer detail collection action passes the selected partner', (
    tester,
  ) async {
    int? collectedId;
    final api = PartnerApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => PartnerDetailSheet(
                  api: api,
                  partner: const {
                    'id': 7,
                    'name': 'Test Müşteri',
                    'partner_type': 'CUSTOMER',
                  },
                  onCollect: (id) async => collectedId = id,
                ),
              ),
              child: const Text('Cari Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cari Aç'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tahsilat Al'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tahsilat Al'));
    await tester.pumpAndSettle();
    expect(collectedId, 7);
  });
}
