import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/company_setup_page.dart';
import 'package:finkit_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CompanyApi extends FinkitApi {
  int registrations = 0;
  bool adopted = false;

  @override
  Future<Map<String, dynamic>> publicAdvisors({
    String? city,
    String? district,
    int page = 1,
  }) async => {
    'items': [
      {
        'user_id': 9,
        'full_name': 'Test Müşavir',
        'office_name': 'Test Ofis',
        'city': 'İstanbul',
        'district': 'Kadıköy',
      },
    ],
    'total': 1,
  };

  @override
  Future<Map<String, dynamic>> registerCompanySetup(
    Map<String, dynamic> body,
  ) async {
    registrations++;
    expect(body['advisor_user_id'], 9);
    expect(body['email'], 'user@example.com');
    return {'access_token': 'new-token'};
  }

  @override
  Future<void> adoptRegistrationSession(
    Map<String, dynamic> result, {
    required String email,
  }) async {
    expect(result['access_token'], 'new-token');
    expect(email, 'user@example.com');
    adopted = true;
  }
}

void main() {
  testWidgets('company setup selects advisor and shows pending state', (
    tester,
  ) async {
    final api = CompanyApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinkitTheme(),
        home: CompanySetupPage(api: api, onAuthenticated: () {}),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ad soyad'),
      'Test Kullanıcı',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'E-posta'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Şifre'),
      'StrongPass1!',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Şifre tekrar'),
      'StrongPass1!',
    );
    await tester.ensureVisible(find.text('Müşavir Seçimine Geç'));
    await tester.tap(find.text('Müşavir Seçimine Geç'));
    await tester.pumpAndSettle();
    expect(find.text('Test Müşavir'), findsOneWidget);
    await tester.tap(find.text('Test Müşavir'));
    await tester.ensureVisible(find.text('Başvuruyu Tamamla'));
    await tester.tap(find.text('Başvuruyu Tamamla'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pumpAndSettle();
    expect(api.registrations, 1);
    expect(api.adopted, isTrue);
    expect(find.text('Başvurunuz Alındı'), findsOneWidget);
  });
}
