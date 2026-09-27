import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/electronic_invoice_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InvoiceActionApi extends FinkitApi {
  int cancelCalls = 0;
  int responseCalls = 0;
  String? lastResponse;

  @override
  Future<Map<String, dynamic>> cancelElectronicInvoice(
    String uuid, {
    required bool isClient,
  }) async {
    cancelCalls++;
    expect(uuid, 'invoice-uuid');
    return {'status': 'CANCELLED'};
  }

  @override
  Future<Map<String, dynamic>> respondElectronicInvoice(
    String providerId, {
    required bool isClient,
    required String responseType,
    String description = '',
  }) async {
    responseCalls++;
    lastResponse = responseType;
    expect(providerId, 'inbox-42');
    return {'response_type': responseType};
  }
}

void main() {
  testWidgets('outgoing cancellation requires explicit approval', (
    tester,
  ) async {
    final api = InvoiceActionApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: ElectronicInvoicePage(
          api: api,
          invoice: const {
            'uuid': 'invoice-uuid',
            'status': 'SENT',
            'document_type': 'EINVOICE',
          },
          isClient: false,
          incoming: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cancel = find.widgetWithText(OutlinedButton, 'Faturayı İptal Et');
    await tester.scrollUntilVisible(
      cancel,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(api.cancelCalls, 0);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.cancelCalls, 0);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal Et'));
    await tester.pumpAndSettle();
    expect(api.cancelCalls, 1);
    expect(find.text('Faturayı İptal Et'), findsNothing);
  });

  testWidgets(
    'commercial incoming invoice sends a response after confirmation',
    (tester) async {
      final api = InvoiceActionApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFinkitTheme(),
          home: ElectronicInvoicePage(
            api: api,
            invoice: const {
              'provider_id': 'inbox-42',
              'profile': 'TICARIFATURA',
              'document_type': 'EINVOICE',
            },
            isClient: true,
            incoming: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kabul Et'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kabul Et'));
      await tester.pumpAndSettle();
      expect(api.responseCalls, 0);
      await tester.tap(find.text('Gönder'));
      await tester.pumpAndSettle();
      expect(api.responseCalls, 1);
      expect(api.lastResponse, 'KABUL');
      expect(find.text('Kabul Et'), findsNothing);
    },
  );
}
