import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote status is sent in the backend query parameter', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    try {
      final api = FinkitApi()
        ..baseUrl = 'http://127.0.0.1:${server.port}'
        ..token = 'test-token';
      final update = api.setQuoteStatus(7, 'SENT');
      final request = await requestFuture;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/accounting/quotes/7/status');
      expect(request.uri.queryParameters['status'], 'SENT');
      expect(request.headers.value('authorization'), 'Bearer test-token');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'id': 7, 'status': 'SENT'}));
      await request.response.close();
      expect((await update)['status'], 'SENT');
    } finally {
      await server.close(force: true);
    }
  });
}
