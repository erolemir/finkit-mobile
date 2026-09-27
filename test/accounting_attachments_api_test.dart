import 'dart:convert';
import 'dart:io';

import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'expense attachment list, upload and download use web API contract',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'finkit-expense-file-',
      );
      final file = File('${folder.path}${Platform.pathSeparator}receipt.pdf');
      await file.writeAsBytes(utf8.encode('%PDF-receipt'));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      server.listen((request) async {
        try {
          expect(request.headers.value('authorization'), 'Bearer test-token');
          requests.add('${request.method} ${request.uri.path}');
          if (request.uri.path == '/accounting/attachments' &&
              request.method == 'GET') {
            expect(request.uri.queryParameters, {
              'related_type': 'expense',
              'related_id': '17',
            });
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode([
                {'id': 8, 'file_name': 'receipt.pdf'},
              ]),
            );
          } else if (request.method == 'POST') {
            expect(request.uri.queryParameters['related_type'], 'expense');
            expect(request.uri.queryParameters['related_id'], '17');
            final body = utf8.decode(
              await request.fold<List<int>>(
                <int>[],
                (bytes, chunk) => bytes..addAll(chunk),
              ),
            );
            expect(body, contains('name="file"'));
            expect(body, contains('receipt.pdf'));
            expect(body, contains('%PDF-receipt'));
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'id': 8}));
          } else {
            expect(request.uri.path, '/accounting/attachments/8/download');
            request.response.add(utf8.encode('%PDF-receipt'));
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
        expect(await api.accountingAttachments('expense', 17), hasLength(1));
        expect(
          (await api.uploadAccountingAttachment(
            relatedType: 'expense',
            relatedId: 17,
            filePath: file.path,
            fileName: file.uri.pathSegments.last,
          ))['id'],
          8,
        );
        expect(
          utf8.decode(await api.downloadAccountingAttachment(8)),
          '%PDF-receipt',
        );
        expect(requests, [
          'GET /accounting/attachments',
          'POST /accounting/attachments',
          'GET /accounting/attachments/8/download',
        ]);
      } finally {
        await server.close(force: true);
        await folder.delete(recursive: true);
      }
    },
  );
}
