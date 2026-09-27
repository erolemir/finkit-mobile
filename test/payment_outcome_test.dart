import 'package:finkit_mobile/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _PaymentStatusApi extends FinkitApi {
  _PaymentStatusApi(this.responses);

  final List<Object> responses;
  int calls = 0;

  @override
  Future<String> paymentStatus(String transactionId) async {
    expect(transactionId, 'txn-1');
    final response = responses[calls++];
    if (response is Exception) throw response;
    return response as String;
  }
}

void main() {
  const noDelay = Duration.zero;

  test(
    'waits through callback lag and transient failure before success',
    () async {
      final api = _PaymentStatusApi([
        'PENDING',
        Exception('temporary'),
        'SUCCESS',
      ]);
      expect(
        await api.waitForPaymentOutcome(
          'txn-1',
          attempts: 3,
          firstDelay: noDelay,
          retryDelay: noDelay,
        ),
        'SUCCESS',
      );
      expect(api.calls, 3);
    },
  );

  test('refunded verification is a terminal outcome', () async {
    final api = _PaymentStatusApi(['PENDING', 'REFUNDED']);
    expect(
      await api.waitForPaymentOutcome(
        'txn-1',
        attempts: 3,
        firstDelay: noDelay,
        retryDelay: noDelay,
      ),
      'REFUNDED',
    );
    expect(api.calls, 2);
  });

  test('unconfirmed result remains pending after bounded retries', () async {
    final api = _PaymentStatusApi(['PENDING', 'PENDING']);
    expect(
      await api.waitForPaymentOutcome(
        'txn-1',
        attempts: 2,
        firstDelay: noDelay,
        retryDelay: noDelay,
      ),
      'PENDING',
    );
    expect(api.calls, 2);
  });
}
