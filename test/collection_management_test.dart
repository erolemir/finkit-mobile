import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/collection_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CollectionApi extends FinkitApi {
  Map<String, dynamic>? created;
  Map<String, dynamic>? updated;
  int? deleted;
  String? search;
  int page = 0;

  @override
  Future<Map<String, dynamic>> collectionPage({
    int page = 1,
    String? search,
    int? partnerId,
    String? paymentMethod,
    int? financialAccountId,
    String? startDate,
    String? endDate,
  }) async {
    this.page = page;
    this.search = search;
    return {
      'items': [
        {
          'id': 7,
          'partner_id': 2,
          'collection_date': '2026-09-27',
          'amount': 120,
          'allocated_amount': 80,
          'unallocated_amount': 40,
          'payment_method': 'HAVALE',
        },
      ],
      'total': 21,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 2, 'name': 'Atlas', 'partner_type': 'CUSTOMER'},
  ];

  @override
  Future<List<Map<String, dynamic>>> salesInvoices({
    String? type,
    String? status,
  }) async => [
    {
      'id': 3,
      'partner_id': 2,
      'number': 'FAT1',
      'gross_amount': 100,
      'withholding_amount': 0,
      'paid_amount': 0,
      'payment_status': 'UNPAID',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> accounts() async => [];

  @override
  Future<Map<String, dynamic>> createCollection({
    required int partnerId,
    required double amount,
    int? accountId,
    String? collectionDate,
    String paymentMethod = 'HAVALE',
    String? referenceNo,
    String? notes,
    int? invoiceId,
    String? idempotencyKey,
  }) async {
    created = {
      'partner_id': partnerId,
      'amount': amount,
      'invoice_id': invoiceId,
      'key': idempotencyKey,
    };
    return {};
  }

  @override
  Future<Map<String, dynamic>> updateCollection(
    int id,
    Map<String, dynamic> body,
  ) async {
    updated = {'id': id, ...body};
    return {};
  }

  @override
  Future<void> deleteCollection(int id) async {
    deleted = id;
  }
}

void main() {
  testWidgets('collection can be allocated, edited and removed on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = CollectionApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CollectionManagementPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni tahsilat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müşteri').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atlas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avans / sonradan dağıt'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('FAT1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created?['invoice_id'], 3);
    expect(api.created?['amount'], 100);
    expect('${api.created?['key']}', startsWith('mobile-collection-'));
    await tester.ensureVisible(find.text('Düzenle'));
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(api.updated?['id'], 7);
    await tester.ensureVisible(find.text('Kaldır'));
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(api.deleted, isNull);
    await tester.tap(find.text('Kaldır').last);
    await tester.pumpAndSettle();
    expect(api.deleted, 7);
    expect(tester.takeException(), isNull);
  });
}
