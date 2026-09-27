import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_attachments_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AttachmentsApi extends FinkitApi {
  int? requestedRecord;

  @override
  Future<List<Map<String, dynamic>>> accountingAttachments(
    String relatedType,
    int relatedId,
  ) async {
    expect(relatedType, 'expense');
    requestedRecord = relatedId;
    return [
      {'id': 8, 'file_name': 'gider.pdf', 'uploaded_at': '2026-09-27T10:00:00'},
    ];
  }
}

void main() {
  testWidgets('expense attachment selector loads chosen record on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = AttachmentsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AccountingAttachmentsPanel(
                api: api,
                relatedType: 'expense',
                records: const [(id: 17, label: 'Fatura gideri')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dosya Ekle'), findsOneWidget);
    expect(find.text('gider.pdf'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fatura gideri').last);
    await tester.pumpAndSettle();
    expect(api.requestedRecord, 17);
    expect(find.text('gider.pdf'), findsOneWidget);
    expect(find.text('İndir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
