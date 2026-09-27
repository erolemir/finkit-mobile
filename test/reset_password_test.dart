import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/reset_password_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ResetApi extends FinkitApi {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String password,
  ) async {
    expect(token, 'secret-token');
    expect(password, 'new-password-123');
    calls++;
    return {'message': 'ok'};
  }
}

void main() {
  testWidgets('reset form validates confirmation before posting token', (
    tester,
  ) async {
    final api = ResetApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: ResetPasswordPage(
          api: api,
          token: 'secret-token',
          role: 'CLIENT',
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni şifre (en az 10 karakter)'),
      'new-password-123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni şifre tekrar'),
      'other-password',
    );
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni şifre tekrar'),
      'new-password-123',
    );
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.textContaining('Şifreniz güncellendi'), findsOneWidget);
  });
}
