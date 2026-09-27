import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/verify_email_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class VerifyApi extends FinkitApi {
  String? tokenSeen;

  @override
  Future<void> verifyEmailToken(String token) async {
    tokenSeen = token;
  }
}

void main() {
  testWidgets('email deep link token is verified in the app', (tester) async {
    final api = VerifyApi();
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyEmailPage(api: api, token: 'token-123'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.tokenSeen, 'token-123');
    expect(find.textContaining('E-posta adresiniz doğrulandı'), findsOneWidget);
  });

  testWidgets('missing token does not call the API', (tester) async {
    final api = VerifyApi();
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyEmailPage(api: api, token: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.tokenSeen, isNull);
    expect(find.text('Doğrulama bağlantısı geçersiz.'), findsOneWidget);
  });
}
