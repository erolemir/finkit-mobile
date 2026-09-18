// Uygulama kabuğunun demo verisiyle hatasız çizildiğini ve sekmelerin
// gezilebildiğini doğrulayan arayüz smoke testi (ağ erişimi gerektirmez).
import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/app_shell.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menüdeki bir özelliği görünür alana getirip açar.
Future<void> openMenuEntry(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView).first,
    const Offset(0, -160),
  );
  await tester.pumpAndSettle();
  // Alt menü çubuğunun üstünde kalması için gerekirse biraz daha kaydır.
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect = tester.getRect(finder);
  if (rect.bottom > screen.height - 150) {
    await tester.drag(
      find.byType(ListView).first,
      Offset(0, -(rect.bottom - (screen.height - 170))),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Not defteri gibi yerel depolama kullanan ekranlar için sahte depo.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('panel ve sekmeler demo verisiyle hatasız açılır', (
    WidgetTester tester,
  ) async {
    final api = FinkitApi()..demoMode = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: FinkitShell(api: api, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Genel Bakış'), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final label in ['Faturalar', 'Kasa', 'Özet']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label sekmesi açılmalı');
    }

    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();

    for (final page in const [
      'Müşteriler',
      'Ürün ve Hizmetler',
      'Depolar ve Stok',
      'Teklifler',
      'İade Faturaları',
      'Tahsilatlar',
      'Gider Listesi',
      'Gelen Faturalar',
      'Tedarikçiler',
      'Çalışanlar',
      'Bordro ve Puantaj',
      'Kasa ve Bankalar',
      'Çekler ve Senetler',
      'Tüm Raporlar',
      'Harici Mükellefler',
      'Belgeler',
      'E-Fatura',
      'E-Belgeler',
      'Sohbet',
      'Mail Gönder',
      'Forum',
      'Hesaplama Yap',
      'Not Defteri',
      'Takvim ve Hatırlatıcılar',
      'Bildirimler',
      'Ayarlar',
    ]) {
      await openMenuEntry(tester, page);
      expect(
        tester.takeException(),
        isNull,
        reason: '$page ekranı hatasız açılmalı',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
