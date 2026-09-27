import 'package:finkit_mobile/access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subuser opens only granted modules and never owner screens', () {
    final policy = AppAccessPolicy.fromUser({
      'role': 'ADVISOR',
      'parent_user_id': 4,
      'module_permissions': {
        'accounting': ['read'],
        'documents': ['read'],
      },
    });

    expect(policy.canOpenView('accounting-sales-invoices'), isTrue);
    expect(policy.canOpenView('documents'), isTrue);
    expect(policy.canOpenView('payments'), isFalse);
    expect(policy.canOpenView('sub-users'), isFalse);
    expect(policy.canOpenView('settings'), isFalse);
    expect(policy.canAccess('accounting', 'write'), isFalse);
  });

  test('expired or overdue client is limited to payment views', () {
    final expired = AppAccessPolicy.fromUser(
      {'role': 'CLIENT'},
      client: {
        'subscription_end_date': '2026-01-01T00:00:00+03:00',
        'payment_status': 'PAID',
      },
      now: DateTime(2026, 9, 27),
    );
    expect(expired.isPaymentLocked, isTrue);
    expect(expired.canOpenView('payments'), isTrue);
    expect(expired.canOpenView('documents'), isFalse);

    final free = AppAccessPolicy.fromUser(
      {'role': 'CLIENT'},
      client: {'bypass_payment': true, 'payment_status': 'OVERDUE'},
    );
    expect(free.isPaymentLocked, isFalse);
  });
}
