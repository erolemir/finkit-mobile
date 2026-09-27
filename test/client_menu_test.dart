import 'package:finkit_mobile/pages/menu_page.dart';
// Mükellef (CLIENT) menüsündeki tüm ekranların küçük ekranda taşmadan
// açıldığını doğrular; mükellefin muhasebe modülüne erişebildiğini gösterir.
import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/app_shell.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mukellef menusundeki tum ekranlar acilir', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = FinkitApi()
      ..demoMode = true
      ..role = 'CLIENT';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: FinkitShell(api: api, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();

    for (final page in const [
      'Müşteriler',
      'Hizmetler',
      'Stok Ana Sayfa',
      'Teklifler',
      'Satış Faturaları',
      'Gelir ve Giderler',
      'Gelen Faturalar',
      'Tedarikçiler',
      'Kasa ve Bankalar',
      'Çekler ve Senetler',
      'Belgelerim',
      'Gelen Kutusu',
      'Giden Kutusu',
      'E-Arşiv Faturalar',
      'Duyurular',
      'Sohbet',
      'Danışma',
      'Destek',
      'Takvim & GİB',
      'Ödemelerim',
      'Kartlarım',
      'Hesaplama Yap',
      'Not Defteri',
      'Profilim',
      'Bildirimler',
    ]) {
      await tester.enterText(find.byType(TextField).first, page);
      await tester.pumpAndSettle();
      final menuItem = find
          .descendant(
            of: find.byType(FeatureMenuPage),
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.data == page,
            ),
          )
          .last;
      await tester.dragUntilVisible(
        menuItem,
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await tester.ensureVisible(menuItem);
      await tester.pumpAndSettle();
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$page ekranı mükellef için hatasız açılmalı',
      );
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('musavire ozel ekranlar mukellef menusunde gorunmez', (
    WidgetTester tester,
  ) async {
    final api = FinkitApi()
      ..demoMode = true
      ..role = 'CLIENT';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: FinkitShell(api: api, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();

    for (final page in const [
      'Mükellefler',
      'Hızlı Giriş Aracı',
      'Hatırlatma Kuralları',
      'Forum',
    ]) {
      expect(
        find.text(page),
        findsNothing,
        reason: '$page yalnız müşavirde olmalı',
      );
    }
  });
}
