// Küçük telefon ekranlarında (360x640) tüm sayfaların taşmadan açıldığını
// doğrular. Demo verisi kullanıldığı için ağ erişimi gerekmez.
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

  testWidgets('kucuk ekranda tum sekmeler ve sayfalar tasmadan acilir', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = FinkitApi()..demoMode = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: FinkitShell(api: api, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Panel açılmalı');

    for (final label in ['Faturalar', 'Kasa', 'Özet']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label taşmamalı');
    }

    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();

    for (final page in [
      'Müşteriler',
      'Ürün ve Hizmetler',
      'Depolar ve Stok',
      'Depo Tanımları',
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
      'Kasa ve Bankalar',
      'Kasa Hareketleri',
      'Çekler ve Senetler',
      'Kasa Raporu',
      'Nakit Akış Raporu',
      'Tüm Raporlar',
      'Mükellefler',
      'Hızlı Giriş Aracı',
      'Harici Mükellefler',
      'Şablonlar',
      'Hatırlatma Kuralları',
      'Belgeler',
      'E-Fatura',
      'E-Belgeler',
      'Duyurular',
      'Sohbet',
      'Mail Gönder',
      'Forum',
      'Mükellef İstekleri',
      'Danışma',
      'Destek',
      'Takvim ve Hatırlatıcılar',
      'Ödemeler',
      'Ek Ücretler',
      'Taksitler',
      'Hesaplama Yap',
      'Not Defteri',
      'Profilim',
      'Bildirimler',
      'Ayarlar',
    ]) {
      await tester.dragUntilVisible(
        find.text(page),
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page açılmalı');
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
    }
  });

  // Hızlı işlem menüsündeki her form ayrı bir oturumda açılır; böylece
  // formlar arası kalan modal durumu testi etkilemez.
  for (final form in [
    'Yeni Fatura',
    'Yeni Müşteri',
    'Gider Ekle',
    'Tahsilat',
  ]) {
    testWidgets('kucuk ekranda "$form" formu tasmadan acilir', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = FinkitApi()..demoMode = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFinkitTheme(),
          home: FinkitShell(api: api, onLogout: () async {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pumpAndSettle();
      // Paneldeki hızlı işlem kutuları da aynı metni taşıdığı için
      // açılan menüdeki son eşleşme seçilir.
      await tester.tap(find.text(form).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$form formu açılmalı');
    });
  }
}
