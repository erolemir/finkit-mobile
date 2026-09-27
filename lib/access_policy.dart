/// Mirrors the web panel's menu permissions. The API remains the final
/// authority for every request; this only controls mobile navigation.
class AppAccessPolicy {
  const AppAccessPolicy({
    required this.role,
    this.isSubUser = false,
    this.modulePermissions = const {},
    this.isPaymentLocked = false,
  });

  final String role;
  final bool isSubUser;
  final Map<String, List<String>> modulePermissions;
  final bool isPaymentLocked;

  bool get isClient => role.toUpperCase() == 'CLIENT';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  bool canAccess(String module, [String action = 'read']) =>
      !isSubUser || (modulePermissions[module]?.contains(action) ?? false);

  bool canOpenView(String view) {
    if (isPaymentLocked &&
        isClient &&
        !const {
          'payments',
          'payment-form',
          'payment-extra-charge',
          'payment-installment',
        }.contains(view)) {
      return false;
    }
    if (view == 'sub-users') return !isSubUser;
    if (isSubUser && const {'profile', 'settings', 'notes'}.contains(view)) {
      return false;
    }
    final module = moduleForView(view);
    return module == null || canAccess(module);
  }

  static String? moduleForView(String view) {
    if (view.startsWith('accounting-')) return 'accounting';
    if (view.startsWith('einvoice') ||
        view.startsWith('earchive') ||
        view == 'edocuments') {
      return 'einvoice';
    }
    const modules = <String, String>{
      'clients': 'clients',
      'documents': 'documents',
      'payments': 'payments',
      'stored-cards': 'payments',
      'payment-form': 'payments',
      'payment-extra-charge': 'payments',
      'payment-installment': 'payments',
      'chat': 'chat',
      'messages': 'notifications',
      'calendar': 'calendar',
      'templates': 'templates',
      'rules': 'reminders',
      'credentials': 'credentials',
      'reminders': 'reminders',
      'notes': 'settings',
      'notifications': 'notifications',
      'support': 'support',
      'forum': 'forum',
      'matching': 'matching',
      'profile': 'settings',
      'settings': 'settings',
    };
    return modules[view];
  }

  factory AppAccessPolicy.fromUser(
    Map<String, dynamic> user, {
    Map<String, dynamic>? client,
    DateTime? now,
  }) {
    final rawPermissions = user['module_permissions'];
    final permissions = <String, List<String>>{};
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        final value = entry.value;
        if (value is List) {
          permissions['${entry.key}'] = value.map((item) => '$item').toList();
        }
      }
    }
    final role = '${user['role'] ?? ''}'.toUpperCase();
    final bypass = client?['bypass_payment'] == true;
    final end = DateTime.tryParse('${client?['subscription_end_date'] ?? ''}');
    final subscriptionExpired =
        end == null || !end.isAfter(now ?? DateTime.now());
    final feeOverdue = client?['payment_status'] == 'OVERDUE';
    return AppAccessPolicy(
      role: role,
      isSubUser: user['parent_user_id'] != null,
      modulePermissions: permissions,
      isPaymentLocked:
          role == 'CLIENT' &&
          client != null &&
          !bypass &&
          (subscriptionExpired || feeOverdue),
    );
  }
}
