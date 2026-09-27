import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/registration_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RegistrationApi extends FinkitApi {
  int prechecks = 0;
  String? registeredRole;
  Map<String, dynamic>? registeredBody;

  @override
  Future<Map<String, dynamic>> registrationPrecheck(
    Map<String, dynamic> body,
  ) async {
    prechecks++;
    return {'valid': true, 'errors': <String, String>{}};
  }

  @override
  Future<Map<String, dynamic>> registerAccount(
    String role,
    Map<String, dynamic> body,
  ) async {
    registeredRole = role;
    registeredBody = body;
    return {'id': 42};
  }
}

void main() {
  testWidgets(
    'client registration checks fields and waits for explicit KVKK acceptance',
    (tester) async {
      final api = RegistrationApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFinkitTheme(),
          home: RegistrationPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ad Soyad'),
        'Ada Demir',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'E-posta'),
        'ada@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'TC Kimlik No'),
        '10000000146',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Şifre'),
        'ValidPass!1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Şifre Tekrar'),
        'ValidPass!1',
      );
      await tester.ensureVisible(find.text('Devam Et'));
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(api.prechecks, 1);
      await tester.enterText(
        find.widgetWithText(TextField, 'Müşavir Kodu'),
        'ABCD1234',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Şirket Ünvanı'),
        'Ada Ltd',
      );
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(api.prechecks, 2);
      await tester.enterText(find.widgetWithText(TextField, 'İl'), 'İstanbul');
      await tester.enterText(find.widgetWithText(TextField, 'İlçe'), 'Kadıköy');
      await tester.tap(find.widgetWithText(FilledButton, 'Hesap Aç'));
      await tester.pumpAndSettle();
      expect(api.registeredRole, isNull);
      await tester.tap(find.text('Aydınlatma Metnini Oku'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Okudum, Kabul Ediyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hesap Aç'));
      await tester.pumpAndSettle();
      expect(api.registeredRole, 'CLIENT');
      expect(api.registeredBody?['company_title'], 'Ada Ltd');
      expect(find.textContaining('Doğrulama bağlantısı'), findsOneWidget);
    },
  );
}
