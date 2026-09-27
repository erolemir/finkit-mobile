import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/admin_users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class UsersApi extends FinkitApi {
  Map<String, String>? lastQuery;
  int deletions = 0;

  @override
  Future<Map<String, dynamic>> adminGet(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path == '/admin/logs') return {'items': <Map<String, dynamic>>[]};
    if (path == '/admin/users/7') {
      return {
        'id': 7,
        'full_name': 'Test Admin',
        'email': 'admin@example.invalid',
        'role': 'ADMIN',
      };
    }
    if (path == '/admin/users/8') {
      return {
        'id': 8,
        'full_name': 'Test Mükellef',
        'email': 'client@example.invalid',
        'role': 'CLIENT',
        'is_banned': false,
      };
    }
    lastQuery = query;
    final system = query?['role'] == 'ADMIN';
    return {
      'total': 1,
      'items': [
        system
            ? {
                'id': 7,
                'full_name': 'Test Admin',
                'email': 'admin@example.invalid',
                'role': 'ADMIN',
                'is_banned': false,
              }
            : {
                'id': 8,
                'full_name': 'Test Mükellef',
                'email': 'client@example.invalid',
                'role': 'CLIENT',
                'is_banned': false,
              },
      ],
    };
  }

  @override
  Future<void> adminDelete(String path) async {
    deletions++;
  }
}

void main() {
  testWidgets('system users query ADMIN and hide destructive admin actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = UsersApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(api: api, systemOnly: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.lastQuery?['role'], 'ADMIN');
    await tester.tap(find.text('Test Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcıyı sil'), findsNothing);
    expect(find.text('Hesabı yasakla'), findsNothing);
    expect(api.deletions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('business member deletion needs exact name confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = UsersApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.lastQuery?['role'], '');
    await tester.scrollUntilVisible(
      find.text('Test Mükellef'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Test Mükellef'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kullanıcıyı sil'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Kullanıcıyı sil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Yanlış');
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(api.deletions, 0);
    expect(find.text('Onay metni eşleşmedi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
