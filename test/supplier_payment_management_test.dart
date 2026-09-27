import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/supplier_payment_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SupplierPaymentApi extends FinkitApi {
  Map<String, dynamic>? created;
  String? search;
  int page = 0;

  @override
  Future<Map<String, dynamic>> supplierPaymentPage({
    int page = 1,
    String? search,
    int? supplierId,
    String? paymentMethod,
    int? financialAccountId,
    String? startDate,
    String? endDate,
  }) async {
    this.page = page;
    this.search = search;
    return {'items': <Map<String, dynamic>>[], 'total': 0};
  }

  @override
  Future<List<Map<String, dynamic>>> partners({String? type}) async => [
    {'id': 2, 'name': 'Atlas', 'partner_type': 'SUPPLIER'},
  ];

  @override
  Future<Map<String, dynamic>> purchaseInvoicePage({
    int page = 1,
    String? search,
    String? status,
    String? paymentStatus,
    int? supplierId,
    String? startDate,
    String? endDate,
  }) async => {
    'items': page == 1
        ? [
            {
              'id': 3,
              'supplier_id': 2,
              'number': 'ALIS1',
              'status': 'POSTED',
              'gross_amount': 120,
              'paid_amount': 20,
              'payment_status': 'PARTIAL',
            },
          ]
        : [
            {
              'id': 4,
              'supplier_id': 2,
              'number': 'ALIS2',
              'status': 'POSTED',
              'gross_amount': 50,
              'paid_amount': 0,
              'payment_status': 'UNPAID',
            },
          ],
    'total': 26,
  };

  @override
  Future<List<Map<String, dynamic>>> accounts() async => [];

  @override
  Future<Map<String, dynamic>> createSupplierPayment({
    required int supplierId,
    required double amount,
    int? accountId,
    String? paymentDate,
    String paymentMethod = 'HAVALE',
    String? referenceNo,
    String? notes,
    int? invoiceId,
    List<Map<String, dynamic>>? allocations,
    String? idempotencyKey,
  }) async {
    created = {
      'supplier_id': supplierId,
      'amount': amount,
      'invoice_id': invoiceId,
      'allocations': allocations,
      'key': idempotencyKey,
    };
    return {};
  }
}

void main() {
  testWidgets(
    'supplier payment chooses invoice and remaining amount on phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = SupplierPaymentApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupplierPaymentManagementPage(api: api, refreshKey: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Liste');
      await tester.tap(find.byTooltip('Yeni ödeme'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Form');
      await tester.tap(find.text('Tedarikçi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atlas').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Tedarikçi seçimi');
      await tester.tap(find.text('Gelen fatura ekle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Fatura menüsü');
      await tester.tap(find.text('ALIS1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelen fatura ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sonraki fatura sayfası'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALIS2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(api.created?['allocations'], [
        {'invoice_id': 3, 'amount': 100.0},
        {'invoice_id': 4, 'amount': 50.0},
      ]);
      expect(api.created?['amount'], 150);
      expect('${api.created?['key']}', startsWith('mobile-supplier-payment-'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('allocation cannot exceed payment amount', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = SupplierPaymentApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplierPaymentManagementPage(api: api, refreshKey: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni ödeme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tedarikçi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atlas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelen fatura ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALIS1').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tutar'), '90');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created, isNull);
    expect(
      find.text('Faturalara dağıtılan tutar ödeme tutarını aşamaz.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
