import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SupportApi extends FinkitApi {
  Map<String, String>? lastQuery;
  Map<String, dynamic>? lastUpdate;
  String? deletedPath;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path.endsWith('/1')) {
      return {
        'id': 1,
        'name': 'Deneme Kullanıcı',
        'contact': 'test@example.com',
        'subject': 'E-belge',
        'message': 'Belgeyi görüntüleyemiyorum',
        'status': 'open',
        'admin_notes': '',
      };
    }
    lastQuery = query;
    return {
      'total': 1,
      'items': [
        {
          'id': 1,
          'name': 'Deneme Kullanıcı',
          'subject': 'E-belge',
          'status': 'open',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> adminPatch(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    lastUpdate = body;
    return {'id': 1, ...body};
  }

  @override
  Future<void> adminDelete(String path) async {
    deletedPath = path;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('support filters and updates a ticket without deleting it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _SupportApi();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AdminSupportPage(api: api))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Açık').last);
    await tester.pumpAndSettle();
    expect(api.lastQuery?['status'], 'open');
    await tester.tap(find.text('E-belge'));
    await tester.pumpAndSettle();
    expect(find.text('Belgeyi görüntüleyemiyorum'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'İncelendi');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.lastUpdate?['admin_notes'], 'İncelendi');
    expect(api.deletedPath, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support delete requires confirmation', (tester) async {
    final api = _SupportApi();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AdminSupportPage(api: api))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-belge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talebi sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.deletedPath, isNull);
    await tester.tap(find.text('Talebi sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(api.deletedPath, '/admin/support/tickets/1');
  });
}
