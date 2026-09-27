import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/platform_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TemplatesApi extends FinkitApi {
  final items = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> messageTemplates() async => items;

  @override
  Future<Map<String, dynamic>> saveMessageTemplate({
    int? id,
    required String name,
    required String content,
    required String type,
  }) async {
    final item = {
      'id': id ?? 1,
      'name': name,
      'content': content,
      'template_type': type,
    };
    if (id == null) {
      items.add(item);
    } else {
      items[items.indexWhere((value) => value['id'] == id)] = item;
    }
    return item;
  }

  @override
  Future<void> deleteMessageTemplate(int id) async {
    items.removeWhere((item) => item['id'] == id);
  }
}

void main() {
  testWidgets('message template create, edit and delete on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = TemplatesApi();
    await tester.pumpWidget(
      MaterialApp(home: TemplatesListPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yeni şablon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şablon Adı'),
      'Ödeme',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'İçerik'),
      'Ödemeniz yaklaştı.',
    );
    await tester.ensureVisible(find.text('[Ad]'));
    await tester.tap(find.text('[Ad]'));
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.items.single['name'], 'Ödeme');
    expect(api.items.single['content'], 'Ödemeniz yaklaştı.[Ad]');
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'İçerik'),
      'Yeni metin',
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.items.single['content'], 'Yeni metin');
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(api.items, isNotEmpty);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(api.items, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
