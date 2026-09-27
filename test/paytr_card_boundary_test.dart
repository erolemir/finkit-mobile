import 'package:finkit_mobile/pages/more_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card form posts only to the exact PayTR HTTPS endpoint', () {
    expect(isTrustedPaytrPaymentUrl('https://www.paytr.com/odeme'), isTrue);
    for (final unsafe in [
      'http://www.paytr.com/odeme',
      'https://paytr.com.evil.test/odeme',
      'https://www.paytr.com:8443/odeme',
      'https://www.paytr.com/odeme?redirect=evil',
      'https://www.paytr.com/odeme#fragment',
      'https://user@www.paytr.com/odeme',
      'https://www.paytr.com/other',
    ]) {
      expect(isTrustedPaytrPaymentUrl(unsafe), isFalse, reason: unsafe);
    }
  });

  test('transient card values are removed after checkout HTML is prepared', () {
    final fields = <String, dynamic>{
      'card_number': '4111111111111111',
      'cvv': '123',
      'cc_owner': 'User',
      'expiry_month': '12',
      'expiry_year': '2030',
      'merchant_oid': 'transaction-1',
      'paytr_token': 'signed-token',
    };
    clearSensitivePaytrFields(fields);
    expect(fields, {
      'merchant_oid': 'transaction-1',
      'paytr_token': 'signed-token',
    });
  });
}
