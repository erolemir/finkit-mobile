import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AccountsApi extends FinkitApi {
  Map<String, dynamic>? created;

  @override
  Future<List<Map<String, dynamic>>> accounts() async => [
    {
      'id': 1,
      'name': 'Kasa',
      'account_type': 'CASH',
      'current_balance': 100,
      'currency': 'TRY',
    },
    {
      'id': 2,
      'name': 'Dolar Banka',
      'account_type': 'BANK',
      'bank_name': 'Atlas',
      'current_balance': 50,
      'currency': 'USD',
    },
  ];

  @override
  Future<Map<String, dynamic>> createFinancialAccount({
    required String name,
    String type = 'CASH',
    String? bankName,
    String? branchName,
    String? iban,
    String currency = 'TRY',
    double openingBalance = 0,
  }) async {
    created = {
      'name': name,
      'type': type,
      'branch_name': branchName,
      'currency': currency,
      'opening_balance': openingBalance,
    };
    return {};
  }
}

void main() {
  testWidgets('account balances stay separated by currency on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = AccountsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FinancialAccountsPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TRY bakiye'), findsWidgets);
    expect(find.text('USD bakiye'), findsWidgets);
    expect(find.text('50.00 USD'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account form sends branch and selected currency', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = AccountsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FinancialAccountsPage(api: api, refreshKey: 0)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni hesap'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hesap Adı'),
      'Yeni Banka',
    );
    await tester.tap(find.text('Kasa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banka').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şube Adı'),
      'Merkez',
    );
    await tester.ensureVisible(find.text('Para Birimi'));
    await tester.tap(find.text('TRY').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hesabı Kaydet'));
    await tester.tap(find.text('Hesabı Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created?['branch_name'], 'Merkez');
    expect(api.created?['currency'], 'USD');
    expect(tester.takeException(), isNull);
  });
}
