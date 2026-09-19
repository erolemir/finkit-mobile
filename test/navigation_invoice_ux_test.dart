import 'dart:convert';

import 'package:google_fonts/google_fonts.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/app_shell.dart';
import 'package:finkit_mobile/pages/invoice_detail_page.dart';
import 'package:finkit_mobile/theme.dart';

class InvoiceApi extends FinkitApi {
  InvoiceApi() {
    demoMode = true;
  }
  bool failLoad = false;
  bool failPost = false;
  int posts = 0;
  int matches = 0;
  Map<String, dynamic> current = {
    'id': 10,
    'number': 'GEL2026000042',
    'status': 'NEEDS_MATCH',
    'supplier_id': null,
    'payment_status': 'UNPAID',
    'issue_date': '2026-09-19',
    'due_date': '2026-10-19',
    'currency': 'TRY',
    'gross_amount': 1200,
    'net_amount': 1000,
    'vat_amount': 200,
    'paid_amount': 200,
    'lines': [
      {
        'description': 'Yıllık bulut sunucu ve destek hizmeti',
        'quantity': 1,
        'unit': 'ADET',
        'unit_price': 1000,
        'vat_rate': 20,
        'line_vat': 200,
        'line_total': 1200,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> purchaseInvoice(int id) async {
    if (failLoad) throw ApiException('Bağlantı kesildi');
    return Map.from(current);
  }

  @override
  Future<Map<String, dynamic>> matchPurchaseSupplier(
    int id,
    int supplierId,
  ) async {
    matches++;
    current = {...current, 'supplier_id': supplierId, 'status': 'DRAFT'};
    return Map.from(current);
  }

  @override
  Future<Map<String, dynamic>> postPurchaseInvoice(int id) async {
    posts++;
    if (failPost) throw ApiException('İşlem tamamlanamadı');
    current = {...current, 'status': 'POSTED'};
    return Map.from(current);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  Future<void> phone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildFinkitTheme(), home: child),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'supplier recovery returns to same invoice and only posts after explicit approval',
    (tester) async {
      final api = InvoiceApi();
      await phone(
        tester,
        InvoiceDetailPage(api: api, invoice: api.current, purchase: true),
      );
      expect(find.text('Tedarikçi eşleştirmesi gerekli'), findsOneWidget);
      expect(api.posts, 0);
      await tester.tap(find.text('Tedarikçi Seç ve Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Tedarikçi Ekle'), findsOneWidget);
      expect(find.text('Atlas Teknoloji Ltd.'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Bulut');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulut Sunucu A.Ş.'));
      await tester.pumpAndSettle();
      expect(find.text('GEL2026000042'), findsOneWidget);
      expect(api.matches, 1);
      expect(api.posts, 0);
      await tester.tap(find.text('Faturayı Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.posts, 0);
      await tester.tap(find.text('Faturayı Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(api.posts, 1);
      expect(find.text('Faturayı Onayla'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invoice loading errors are recoverable and failed posting keeps details',
    (tester) async {
      final api = InvoiceApi()..failLoad = true;
      await phone(
        tester,
        InvoiceDetailPage(api: api, invoice: api.current, purchase: true),
      );
      expect(find.text('Fatura detayı yüklenemedi'), findsOneWidget);
      api.failLoad = false;
      api.current = {...api.current, 'supplier_id': 3, 'status': 'DRAFT'};
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();
      api.failPost = true;
      await tester.tap(find.text('Faturayı Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(find.text('İşlem tamamlanamadı'), findsOneWidget);
      expect(find.text('GEL2026000042'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('menu searches Turkish text and back restores prior tab', (
    tester,
  ) async {
    await phone(
      tester,
      FinkitShell(api: FinkitApi()..demoMode = true, onLogout: () async {}),
    );
    await tester.tap(find.text('Faturalar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tedarikci');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tedarikçiler'));
    await tester.tap(find.text('Tedarikçiler'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('tedarikci'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Satış Faturaları'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Genel Bakış'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long invoice details scroll at larger text scale', (
    tester,
  ) async {
    final api = InvoiceApi();
    api.current['lines'] = List.generate(
      20,
      (_) => (api.current['lines'] as List).first,
    );
    await phone(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: InvoiceDetailPage(
          api: api,
          invoice: api.current,
          purchase: true,
        ),
      ),
    );
    await tester.dragUntilVisible(
      find.text('Tutar Özeti'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture menu and invoice for visual review', (tester) async {
    final key = GlobalKey();
    final api = InvoiceApi();
    await phone(
      tester,
      RepaintBoundary(
        key: key,
        child: FinkitShell(api: api, onLogout: () async {}),
      ),
    );
    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('UX_SCREENSHOTS')) return;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/ux-review')..createSync(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('menu');
    await phone(
      tester,
      RepaintBoundary(
        key: key,
        child: InvoiceDetailPage(
          api: api,
          invoice: api.current,
          purchase: true,
        ),
      ),
    );
    await capture('invoice');
    expect(tester.takeException(), isNull);
  });
}
