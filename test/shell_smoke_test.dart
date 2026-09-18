// Uygulama kabuğunun demo verisiyle hatasız çizildiğini ve sekmelerin
// gezilebildiğini doğrulayan arayüz smoke testi (ağ erişimi gerektirmez).
import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/app_shell.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      'Cari Hesaplar',
      'Personel ve Bordro',
      'Raporlar',
      'Belgeler',
      'E-Fatura',
      'Sohbet',
      'Takvim ve Hatırlatıcılar',
      'Bildirimler',
    ]) {
      await tester.dragUntilVisible(
        find.text(page),
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
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
