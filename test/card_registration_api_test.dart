import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepare and status requests use PayTR registration contract', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((request) async {
      try {
        expect(request.headers.value('authorization'), 'Bearer test-token');
        requests.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST') {
          expect(request.uri.path, '/paytr/prepare-card-registration');
          final body = await utf8.decoder.bind(request).join();
          expect(jsonDecode(body), {'non_3d': false});
          request.response.write(
            jsonEncode({'transaction_id': 'CARDREG-1', 'status': 'success'}),
          );
        } else {
          expect(request.uri.queryParameters['transaction_id'], 'CARDREG-1');
          request.response.write(jsonEncode({'status': 'REFUNDED'}));
        }
      } catch (error) {
        request.response.statusCode = 500;
        request.response.write('$error');
      } finally {
        await request.response.close();
      }
    });
    try {
      final api = FinkitApi()
        ..baseUrl = 'http://127.0.0.1:${server.port}'
        ..token = 'test-token';
      expect(
        (await api.prepareCardRegistration())['transaction_id'],
        'CARDREG-1',
      );
      expect(await api.paymentStatus('CARDREG-1'), 'REFUNDED');
      expect(requests, [
        'POST /paytr/prepare-card-registration',
        'GET /paytr/payment-status',
      ]);
    } finally {
      await server.close(force: true);
    }
  });
}
