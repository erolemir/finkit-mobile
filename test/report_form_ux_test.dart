import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/reports_page.dart';
import 'package:finkit_mobile/pages/entry_forms.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class TestApi extends FinkitApi {
  final calls = <Map<String, String?>>[];
  final saved = Completer<Map<String, dynamic>>();
  int writes = 0;
  double? savedAmount;
  @override
  Future<Map<String, dynamic>> report(
    String report, {
    String basis = 'accrual',
    String? startDate,
    String? endDate,
  }) async {
    calls.add({
      'report': report,
      'basis': basis,
      'start': startDate,
      'end': endDate,
    });
    return {
      'summary': {
        'invoice_count': 18,
        'net': 237083,
        'vat': 47417,
        'gross': 284500,
      },
      'by_month': [
        {'period': '2026-09', 'net': 237083, 'gross': 284500},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> createExpense({
    required String description,
    required double netAmount,
    double vatRate = 20,
    int? accountId,
  }) {
    writes++;
    savedAmount = netAmount;
    return saved.future;
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['FINKIT_CAPTURE'];
  if (directory == null) return;
  await expectLater(
    find.byKey(const ValueKey('capture')),
    matchesGoldenFile(Uri.file('$directory/$name.png')),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontPath = Platform.environment['FINKIT_REVIEW_FONT'];
    final iconsPath = Platform.environment['FINKIT_REVIEW_ICONS'];
    if (fontPath == null || iconsPath == null) return;
    final reviewFont = ByteData.sublistView(File(fontPath).readAsBytesSync());
    final assets = {
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'assets/Inter-$weight.ttf': [
          {'asset': 'assets/Inter-$weight.ttf'},
        ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final path = utf8.decode(message!.buffer.asUint8List());
          if (path == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(assets);
          }
          if (assets.containsKey(path)) return reviewFont;
          return null;
        });
    for (final family in [
      'Ahem',
      'Roboto',
      'Inter_regular',
      'Inter_500',
      'Inter_600',
      'Inter_700',
      'Inter_800',
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(File(iconsPath).readAsBytesSync())),
      );
    await icons.load();
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('count and quantity retain their units', () {
    expect(reportValue('invoice_count', 18), '18');
    expect(reportValue('quantity', 2.5), '2,5');
    expect(reportValue('gross', 18), contains('₺'));
    expect(reportValue('net', -18), contains('-'));
  });
  testWidgets(
    'report filters request real dates and breakdowns fit the phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = TestApi();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: buildFinkitTheme(),
            home: ReportDetailPage(
              api: api,
              report: 'sales',
              title: 'Satış Raporu',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('18'), findsOneWidget);
      await capture(tester, 'report-sales');
      await tester.tap(find.text('Geçen ay'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(
        api.calls.last['start'],
        DateTime(now.year, now.month - 1).toIso8601String().substring(0, 10),
      );
      expect(
        api.calls.last['end'],
        DateTime(now.year, now.month, 0).toIso8601String().substring(0, 10),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('2026-09'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'library search opens selected report',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? opened;
      final api = FinkitApi()..demoMode = true;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: buildFinkitTheme(),
            home: Scaffold(
              body: ReportsPage(
                api: api,
                refreshKey: 0,
                onOpenReport: (r) => opened = r,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'report-library');
      await tester.enterText(find.byType(TextField), 'stok');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stok Raporu'));
      await tester.pumpAndSettle();
      expect(opened, 'stock');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'expense stays usable above keyboard and prevents duplicate save',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = TestApi();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: buildFinkitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showExpenseEntryForm(context, api),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await capture(tester, 'expense-form');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Ofis malzemeleri',
      );
      await tester.enterText(find.byType(TextFormField).last, '-2');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      await tester.enterText(find.byType(TextFormField).last, '1250,50');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.widgetWithText(ElevatedButton, 'Kaydet')).bottom,
        lessThanOrEqualTo(360),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      expect(api.writes, 1);
      expect(api.savedAmount, 1250.5);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      api.saved.complete({});
      await tester.pumpAndSettle();
      expect(find.text('Aç'), findsOneWidget);
    },
  );
}
