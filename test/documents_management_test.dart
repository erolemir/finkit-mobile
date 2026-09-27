import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/platform_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DocumentsApi extends FinkitApi {
  final records = <Map<String, dynamic>>[
    {
      'id': 1,
      'file_name': 'KDV-2026.pdf',
      'document_type': 'KDV1_BEYANNAME',
      'client_id': 5,
      'document_date': '2026-09-01',
      'upload_date': '2026-09-02',
    },
    {
      'id': 2,
      'file_name': 'Vergi-Levhasi.pdf',
      'document_type': 'VERGI_LEVHASI',
      'client_id': 6,
      'document_date': '2026-08-01',
      'upload_date': '2026-08-02',
    },
  ];
  int? deleted;

  @override
  Future<List<Map<String, dynamic>>> allDocuments() async => List.of(records);

  @override
  Future<List<Map<String, dynamic>>> clients() async => [
    {'user_id': 5, 'company_title': 'Test Ltd.'},
  ];

  @override
  Future<void> deleteDocument(int documentId) async {
    deleted = documentId;
    records.removeWhere((record) => record['id'] == documentId);
  }
}

void main() {
  testWidgets('bulk upload form fits with keyboard on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentsListPage(
          api: DocumentsApi(),
          refreshKey: 0,
          isClient: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Belge yükle'));
    await tester.pumpAndSettle();
    expect(find.text('PDF Dosyalarını Seç ve Yükle'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2026-09-27');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('document filters and confirmed deletion work at 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = DocumentsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentsListPage(api: api, refreshKey: 0, isClient: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('KDV-2026.pdf'), findsOneWidget);
    await tester.ensureVisible(find.text('KDV-2026.pdf'));
    await tester.tap(find.text('KDV-2026.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Önizle'), findsOneWidget);
    expect(find.text('İndir'), findsOneWidget);
    await tester.tap(find.text('Sil').first);
    await tester.pumpAndSettle();
    expect(api.deleted, isNull);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(api.deleted, 1);
    expect(find.text('KDV-2026.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
