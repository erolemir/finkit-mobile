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
      'Ürün ve Hizmetler',
      'Depolar ve Stok',
      'Teklifler',
      'Satış Faturaları',
      'İade Faturaları',
      'Tahsilatlar',
      'Satış Raporu',
      'Tahsilat Raporu',
      'Gelir-Gider Raporu',
      'Gider Listesi',
      'Gelen Faturalar',
      'Tedarikçiler',
      'Çalışanlar',
      'Bordro ve Puantaj',
      'Gider Raporu',
      'Ödemeler Raporu',
      'KDV Raporu',
      'Tedarikçi Ödemeleri',
      'Kasa ve Bankalar',
      'Çekler ve Senetler',
      'Kasa Raporu',
      'Nakit Akış Raporu',
      'Tüm Raporlar',
      'Belgelerim',
      'E-Fatura',
      'Duyurular',
      'Sohbet',
      'Müşavir Taleplerim',
      'Danışma',
      'Destek',
      'Takvim ve Hatırlatıcılar',
      'Ödemeler',
      'Ek Ücretler',
      'Taksitler',
      'Kartlarım',
      'Hesaplama Yap',
      'Not Defteri',
      'Profilim',
      'Bildirimler',
      'Ayarlar',
    ]) {
      await tester.dragUntilVisible(
        find.text(page).first,
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(page).first);
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
