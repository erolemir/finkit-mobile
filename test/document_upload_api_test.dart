import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk PDF upload sends both files, date and bearer token', () async {
    final folder = await Directory.systemTemp.createTemp(
      'finkit-document-test-',
    );
    final first = File('${folder.path}${Platform.pathSeparator}first.pdf');
    final second = File('${folder.path}${Platform.pathSeparator}second.pdf');
    await first.writeAsBytes(utf8.encode('%PDF-one'));
    await second.writeAsBytes(utf8.encode('%PDF-two'));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestChecked = Completer<void>();
    server.listen((request) async {
      try {
        expect(request.uri.path, '/documents/upload');
        expect(request.method, 'POST');
        expect(request.headers.value('authorization'), 'Bearer test-token');
        final body = utf8.decode(
          await request.fold<List<int>>(
            <int>[],
            (bytes, chunk) => bytes..addAll(chunk),
          ),
        );
        for (final value in [
          'name="client_id"',
          'name="document_type"',
          'name="document_date"',
          '2026-09-27',
          'first.pdf',
          'second.pdf',
          '%PDF-one',
          '%PDF-two',
        ]) {
          expect(body, contains(value));
        }
        requestChecked.complete();
        request.response.statusCode = 201;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {'id': 1},
            {'id': 2},
          ]),
        );
      } catch (error, stack) {
        requestChecked.completeError(error, stack);
        request.response.statusCode = 500;
      } finally {
        await request.response.close();
      }
    });
    try {
      final api = FinkitApi()
        ..baseUrl = 'http://127.0.0.1:${server.port}'
        ..token = 'test-token';
      final result = await api.uploadDocuments(
        clientId: 5,
        documentType: 'FIRMA_EVRAK',
        filePaths: [first.path, second.path],
        documentDate: '2026-09-27',
      );
      await requestChecked.future;
      expect(result, hasLength(2));
    } finally {
      await server.close(force: true);
      await folder.delete(recursive: true);
    }
  });
}
