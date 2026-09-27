import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/document_types.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:finkit_mobile/pages/data_pages.dart';
import 'package:finkit_mobile/pages/dashboard_page.dart';
import 'package:finkit_mobile/pages/platform_pages.dart';
import 'package:finkit_mobile/pages/electronic_invoice_page.dart';
import 'package:finkit_mobile/pages/invoice_detail_page.dart';
import 'package:finkit_mobile/theme.dart';

final archive = <String, dynamic>{
  'id': 1,
  'uuid': 'test-uuid',
  'number': 'ARS2026000001',
  'document_type': 'EARCHIVE',
  'source_type': 'MANUAL',
  'profile': 'EARSIVFATURA',
  'invoice_type': 'IADE',
  'status': 'DRAFT',
  'payment_status': 'UNPAID',
  'partner_id': 1,
  'supplier_id': 3,
  'gross_amount': 1200,
  'issue_date': '2026-09-20',
};

class TypeApi extends FinkitApi {
  TypeApi() {
    demoMode = true;
  }
  @override
  Future<List<Map<String, dynamic>>> salesInvoices({
    String? type,
    String? status,
  }) async => [archive];
  @override
  Future<Map<String, dynamic>> salesInvoicePage({
    int page = 1,
    String? search,
    String? status,
    String? paymentStatus,
    String? invoiceType,
    int? partnerId,
    String? startDate,
    String? endDate,
  }) async => {
    'items': [archive],
    'total': 1,
  };
  @override
  Future<List<Map<String, dynamic>>> purchaseInvoices({
    String? type,
    String? status,
  }) async => [archive];
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
    'items': [archive],
    'total': 1,
  };
  @override
  Future<List<Map<String, dynamic>>> einvoiceInvoices({
    String? documentType,
  }) async => [archive];
  @override
  Future<List<Map<String, dynamic>>> clientEinvoiceInvoices({
    String? documentType,
  }) async => [archive];
  @override
  Future<List<Map<String, dynamic>>> einvoiceInbox() async => [
    {...archive, 'document_type': 'EINVOICE', 'profile': 'TICARIFATURA'},
  ];
  @override
  Future<List<Map<String, dynamic>>> clientEinvoiceInbox() => einvoiceInbox();
  @override
  Future<Map<String, dynamic>> electronicInvoiceBox({
    required bool isClient,
    required bool incoming,
    String documentType = 'EINVOICE',
    String? status,
    String? startDate,
    String? endDate,
    String? customerIdentifier,
    int page = 1,
  }) async => {
    'items': incoming ? await einvoiceInbox() : [archive],
    'total': 1,
    'page': incoming ? page - 1 : page,
  };
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
    'document channel is independent of invoice operation and delivery status',
    () {
      expect(documentTypeLabel(archive), 'E-Arşiv');
      expect(invoiceKindLabel(archive), 'İade');
      expect(invoiceProfileLabel(archive), 'E-Arşiv fatura');
      expect(
        documentTypeLabel({
          'documentType': 'e_invoice',
          'invoiceType': 'TEVKIFAT',
        }),
        'E-Fatura',
      );
      expect(invoiceKindLabel({'documentTypeCode': 'TEVKIFAT'}), 'Tevkifat');
      expect(documentTypeLabel({'profileId': 'TICARIFATURA'}), 'E-Fatura');
      expect(documentTypeLabel({'source_type': 'EARCHIVE'}), 'E-Arşiv');
      expect(documentTypeLabel({'source_type': 'ESMM'}), 'E-SMM');
      expect(documentTypeLabel({'document_type': 'MM'}), 'E-Müstahsil');
      expect(documentTypeLabel({'document_type': 'EDESPATCH'}), 'E-İrsaliye');
      expect(documentTypeLabel({'source_type': 'MANUAL'}), 'Manuel kayıt');
      expect(
        documentTypeLabel({
          'source_type': 'MANUAL',
          'e_document_uuid': 'existing',
        }),
        'Belge türü belirtilmemiş',
      );
      expect(
        documentTypeLabel({'document_type': 'AUTO'}),
        'Belge türü bekleniyor',
      );
      expect(
        documentTypeLabel({'invoice_type': 'SATIS', 'status': 'SENT'}),
        'Belge türü belirtilmemiş',
      );
      expect(
        documentTypeLabel({'document_type': 123}),
        'Belge türü belirtilmemiş',
      );
    },
  );

  for (final client in [false, true]) {
    testWidgets(
      'electronic lists and details show types and page explanations for client=$client',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = TypeApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildFinkitTheme(),
            home: EInvoiceListPage(
              api: api,
              refreshKey: 0,
              isClient: client,
              documentType: 'EARCHIVE',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('E-Arşiv Faturalar'), findsWidgets);
        expect(find.text('E-Arşiv'), findsWidgets);
        expect(find.text('İade'), findsOneWidget);
        await tester.tap(find.text('ARS2026000001'));
        await tester.pumpAndSettle();
        expect(find.byType(ElectronicInvoicePage), findsOneWidget);
        expect(find.text('E-Arşiv Detayı'), findsOneWidget);
        expect(find.text('E-Arşiv'), findsWidgets);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildFinkitTheme(),
            home: EInvoiceListPage(
              api: api,
              refreshKey: 1,
              isClient: client,
              initialIndex: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('E-Fatura'), findsWidgets);
        await tester.tap(find.text('Gelen'));
        await tester.pumpAndSettle();
        expect(find.text('E-Fatura'), findsWidgets);
        expect(
          find.textContaining('Size gönderilen E-Faturaları'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invoice type is visible on all accounting invoice surfaces', (
    tester,
  ) async {
    final api = TypeApi();
    final pages = <Widget>[
      SalesPage(api: api, refreshKey: 0, onQuickAction: () {}),
      PurchaseInvoicesPage(api: api, refreshKey: 0),
      SalesReturnsPage(api: api, refreshKey: 0),
      ExpensesPage(api: api, refreshKey: 0),
      DashboardPage(
        api: api,
        refreshKey: 0,
        onOpenSales: () {},
        onOpenCash: () {},
        onOpenExpenses: () {},
        onOpenReports: () {},
      ),
      const SingleChildScrollView(
        child: InvoiceContent(
          invoice: {'document_type': 'EARCHIVE', 'invoice_type': 'IADE'},
          partnerName: 'Örnek Firma',
        ),
      ),
    ];
    for (final page in pages) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFinkitTheme(),
          home: Scaffold(body: page),
        ),
      );
      await tester.pumpAndSettle();
      if (find.text('E-Arşiv').evaluate().isEmpty) {
        await tester.dragUntilVisible(
          find.text('E-Arşiv'),
          find.byType(Scrollable).first,
          const Offset(0, -200),
        );
      }
      expect(find.text('İade'), findsWidgets, reason: '${page.runtimeType}');
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });
}
