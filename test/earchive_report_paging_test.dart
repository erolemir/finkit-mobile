import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('E-Arşiv raporu ilk 100 belgeyle sınırlanmaz', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final pages = <int>[];
    server.listen((request) async {
      final page = int.parse(request.uri.queryParameters['page'] ?? '1');
      pages.add(page);
      final items = page == 1
          ? List.generate(
              100,
              (index) => {'id': index + 1, 'status': 'REPORTED'},
            )
          : [
              {'id': 101, 'status': 'PENDING'},
            ];
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'items': items, 'total': 101}));
      await request.response.close();
    });
    final api = FinkitApi()
      ..baseUrl = 'http://127.0.0.1:${server.port}'
      ..token = 'test-token';
    final items = await api.electronicArchiveReportItems(
      isClient: false,
      startDate: '2026-09-01',
      endDate: '2026-09-30',
    );
    expect(items.length, 101);
    expect(pages, [1, 2]);
  });
}
