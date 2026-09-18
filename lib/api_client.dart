import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode = 0]);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class FinkitApi {
  static const defaultBaseUrl = 'https://test.finkit.com.tr/api';
  static const _tokenKey = 'finkit_token';
  static const _refreshTokenKey = 'finkit_refresh_token';
  static const _roleKey = 'finkit_role';
  static const _baseUrlKey = 'finkit_api_base';
  static const _emailKey = 'finkit_email';

  String baseUrl = defaultBaseUrl;
  String? token;
  String? refreshToken;
  String? email;
  String? role;
  bool demoMode = false;

  /// Yenileme başarısız olduğunda (oturum bittiğinde) çağrılır.
  void Function()? onSessionExpired;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    token = prefs.getString(_tokenKey);
    refreshToken = prefs.getString(_refreshTokenKey);
    email = prefs.getString(_emailKey);
    role = prefs.getString(_roleKey);
  }

  /// Arka plan görevleri için kayıtlı oturumla istemci üretir.
  static Future<FinkitApi?> fromStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    if (storedToken == null || storedToken.isEmpty) return null;
    final api = FinkitApi();
    api.baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    api.token = storedToken;
    api.refreshToken = prefs.getString(_refreshTokenKey);
    api.email = prefs.getString(_emailKey);
    return api;
  }

  Future<void> login({
    required String email,
    required String password,
    required String role,
    required String apiBaseUrl,
  }) async {
    baseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    var effectiveRole = role;
    var response = await http.post(
      Uri.parse('$baseUrl/auth/login?role=$effectiveRole'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email.trim(), 'password': password},
    );
    var body = _decode(response);
    // Rol seçimi hesap türüyle uyuşmuyorsa diğer rolle bir kez daha denenir;
    // böylece mükellef/müşavir ayrımı kullanıcıyı ekranda bırakmaz.
    final roleMismatch =
        response.statusCode == 403 &&
        (_detail(body) ?? '').toLowerCase().contains('eşleşmiyor');
    if (roleMismatch) {
      effectiveRole = effectiveRole.toUpperCase() == 'CLIENT'
          ? 'ADVISOR'
          : 'CLIENT';
      response = await http.post(
        Uri.parse('$baseUrl/auth/login?role=$effectiveRole'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email.trim(), 'password': password},
      );
      body = _decode(response);
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(body) ?? 'Giriş yapılamadı',
        response.statusCode,
      );
    }
    token = body['access_token'] as String?;
    refreshToken = body['refresh_token'] as String?;
    this.email = email.trim();
    this.role = effectiveRole;
    demoMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
    await prefs.setString(_emailKey, this.email!);
    await prefs.setString(_roleKey, effectiveRole);
    if (token != null) await prefs.setString(_tokenKey, token!);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken!);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
  }

  Future<void> enableDemo() async {
    demoMode = true;
    token = null;
  }

  Future<void> logout() async {
    token = null;
    refreshToken = null;
    demoMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  /// Süresi dolan erişim jetonunu yeniler (token rotation destekli).
  Future<bool> _refreshAccessToken() async {
    final current = refreshToken;
    if (current == null || demoMode) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': current}),
      );
      if (response.statusCode >= 400) return false;
      final body = _decode(response);
      final access = body['access_token'] as String?;
      if (access == null) return false;
      final rotated = body['refresh_token'] as String?;
      token = access;
      if (rotated != null) refreshToken = rotated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, access);
      if (rotated != null) await prefs.setString(_refreshTokenKey, rotated);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// İsteği gönderir; 401 dönerse jetonu yenileyip bir kez daha dener.
  Future<http.Response> _authorized(
    Future<http.Response> Function() send,
  ) async {
    var response = await send();
    if (response.statusCode == 401 && !demoMode) {
      if (refreshToken == null) {
        // Yenileme jetonu yoksa oturum bitmiştir; giriş ekranına dönülür.
        await logout();
        onSessionExpired?.call();
        return response;
      }
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await send();
      }
      if (response.statusCode == 401) {
        await logout();
        onSessionExpired?.call();
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> entity() => _get('/accounting/entity');

  /// Oturum açan kullanıcının kendi bilgileri (her iki rol için geçerli).
  Future<Map<String, dynamic>> me() => _get('/users/me');

  Future<Map<String, dynamic>> summary({
    String? startDate,
    String? endDate,
  }) async {
    final body = await _get(
      '/accounting/reports/summary',
      query: {'start_date': ?startDate, 'end_date': ?endDate},
    );
    return _summaryOf(body);
  }

  Future<List<Map<String, dynamic>>> partners({String? type}) => _list(
    '/accounting/partners',
    query: {'partner_type': ?type, 'page_size': '200'},
  );

  Future<List<Map<String, dynamic>>> salesInvoices({
    String? type,
    String? status,
  }) => _list(
    '/accounting/sales-invoices',
    query: {
      'page_size': '100',
      'invoice_type': ?type,
      'status': ?status,
    },
  );

  Future<List<Map<String, dynamic>>> purchaseInvoices({
    String? type,
    String? status,
  }) => _list(
    '/accounting/purchase-invoices',
    query: {
      'page_size': '100',
      'invoice_type': ?type,
      'status': ?status,
    },
  );

  Future<List<Map<String, dynamic>>> expenses() =>
      _list('/accounting/expenses', query: {'page_size': '100'});

  Future<List<Map<String, dynamic>>> accounts() =>
      _list('/accounting/financial-accounts');

  Future<List<Map<String, dynamic>>> transactions() =>
      _list('/accounting/financial-transactions', query: {'page_size': '100'});

  Future<List<Map<String, dynamic>>> employees() =>
      _list('/accounting/employees', query: {'page_size': '100'});

  Future<Map<String, dynamic>> payroll() => _get('/accounting/payroll');

  Future<Map<String, dynamic>> report(
    String report, {
    String basis = 'accrual',
  }) => _get(
    '/accounting/reports/$report',
    query: report == 'income-expense' ? {'basis': basis} : null,
  );

  Future<Map<String, dynamic>> createExpense({
    required String description,
    required double netAmount,
    double vatRate = 20,
    int? accountId,
  }) => _post('/accounting/expenses', {
    'expense_date': _today(),
    'description': description,
    'net_amount': netAmount,
    'vat_rate': vatRate,
    'currency': 'TRY',
    'exchange_rate': 1,
    'payment_status': 'UNPAID',
    'financial_account_id': ?accountId,
  });

  Future<Map<String, dynamic>> createCollection({
    required int partnerId,
    required double amount,
    int? accountId,
  }) => _post('/accounting/collections', {
    'partner_id': partnerId,
    'collection_date': _today(),
    'amount': amount,
    'currency': 'TRY',
    'exchange_rate': 1,
    'payment_method': 'HAVALE',
    'financial_account_id': ?accountId,
    'allocations': const [],
  });

  Future<Map<String, dynamic>> createPartner({
    required String code,
    required String name,
    String type = 'CUSTOMER',
    String? taxNumber,
    String? phone,
    String? email,
    String? city,
    int paymentTermDays = 0,
  }) => _post('/accounting/partners', {
    'code': code,
    'name': name,
    'partner_type': type,
    'tax_number': ?taxNumber,
    'phone': ?phone,
    'email': ?email,
    'city': ?city,
    'payment_term_days': paymentTermDays,
    'currency': 'TRY',
  });

  Future<Map<String, dynamic>> createSalesInvoice({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    String invoiceType = 'SATIS',
    DateTime? issueDate,
    DateTime? dueDate,
    String? notes,
  }) => _post('/accounting/sales-invoices', {
    'partner_id': partnerId,
    'invoice_type': invoiceType,
    'source_type': 'MANUAL',
    'issue_date': _dateValue(issueDate ?? DateTime.now()),
    'due_date': ?(dueDate == null ? null : _dateValue(dueDate)),
    'notes': ?notes,
    'currency': 'TRY',
    'exchange_rate': 1,
    'lines': lines,
  });

  Future<Map<String, dynamic>> finalizeSalesInvoice(int invoiceId) =>
      _post('/accounting/sales-invoices/$invoiceId/finalize', const {});

  Future<Map<String, dynamic>> cancelSalesInvoice(int invoiceId) =>
      _post('/accounting/sales-invoices/$invoiceId/cancel', const {});

  Future<List<Map<String, dynamic>>> products() =>
      _list('/accounting/products', query: {'page_size': '200'});

  Future<Map<String, dynamic>> salesInvoice(int invoiceId) =>
      _get('/accounting/sales-invoices/$invoiceId');

  // ── Ürün / hizmet ve stok ──────────────────────────────────
  Future<Map<String, dynamic>> createProduct({
    required String code,
    required String name,
    String type = 'PRODUCT',
    String unit = 'ADET',
    double vatRate = 20,
    double salesPrice = 0,
    double purchasePrice = 0,
    double manualCost = 0,
    bool trackInventory = true,
    String? barcode,
  }) => _post('/accounting/products', {
    'code': code,
    'name': name,
    'product_type': type,
    'unit': unit,
    'vat_rate': vatRate,
    'sales_price': salesPrice,
    'purchase_price': purchasePrice,
    'manual_cost': manualCost,
    'track_inventory': trackInventory,
    'barcode': ?barcode,
  });

  Future<List<Map<String, dynamic>>> warehouses() =>
      _listAny('/accounting/warehouses');

  Future<Map<String, dynamic>> createWarehouse({
    required String code,
    required String name,
    String? city,
    bool isDefault = false,
  }) => _post('/accounting/warehouses', {
    'code': code,
    'name': name,
    'city': ?city,
    'is_default': isDefault,
  });

  Future<List<Map<String, dynamic>>> stockBalances({int? warehouseId}) =>
      _listAny(
        '/accounting/stock/balances',
        query: {
          if (warehouseId != null) 'warehouse_id': '$warehouseId',
        },
      );

  Future<List<Map<String, dynamic>>> stockMovements() =>
      _list('/accounting/stock/movements', query: {'page_size': '100'});

  Future<Map<String, dynamic>> createStockMovement({
    required int warehouseId,
    required int productId,
    required double quantity,
    String type = 'IN',
    double? unitCost,
    String? description,
  }) => _post('/accounting/stock/movements', {
    'warehouse_id': warehouseId,
    'product_id': productId,
    'movement_type': type,
    'movement_date': _today(),
    'quantity': quantity,
    'unit_cost': ?unitCost,
    'description': ?description,
  });

  Future<Map<String, dynamic>> createStockTransfer({
    required int sourceWarehouseId,
    required int targetWarehouseId,
    required int productId,
    required double quantity,
  }) => _post('/accounting/stock/transfers', {
    'source_warehouse_id': sourceWarehouseId,
    'target_warehouse_id': targetWarehouseId,
    'product_id': productId,
    'movement_date': _today(),
    'quantity': quantity,
  });

  // ── Teklifler ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> quotes({String? status}) => _list(
    '/accounting/quotes',
    query: {
      'page_size': '100',
      'status': ?status,
    },
  );

  Future<Map<String, dynamic>> createQuote({
    required int partnerId,
    required String description,
    required double quantity,
    required double unitPrice,
    double vatRate = 20,
    int? productId,
    DateTime? validUntil,
    String? notes,
  }) => _post('/accounting/quotes', {
    'partner_id': partnerId,
    'issue_date': _today(),
    'valid_until': ?(validUntil == null ? null : _dateValue(validUntil)),
    'currency': 'TRY',
    'exchange_rate': 1,
    'notes': ?notes,
    'lines': [
      {
        'product_id': ?productId,
        'description': description,
        'quantity': quantity,
        'unit': 'ADET',
        'unit_price': unitPrice,
        'discount_rate': 0,
        'vat_rate': vatRate,
      },
    ],
  });

  Future<Map<String, dynamic>> setQuoteStatus(int quoteId, String status) =>
      _patch('/accounting/quotes/$quoteId/status', {'status': status});

  Future<Map<String, dynamic>> convertQuote(int quoteId) =>
      _post('/accounting/quotes/$quoteId/convert', const {});

  // ── Gelen faturalar ────────────────────────────────────────
  Future<Map<String, dynamic>> createPurchaseInvoice({
    required int supplierId,
    required String description,
    required double netAmount,
    double vatRate = 20,
    DateTime? dueDate,
    bool inventory = false,
    int? productId,
    int? warehouseId,
    String? number,
  }) => _post('/accounting/purchase-invoices', {
    'supplier_id': supplierId,
    'invoice_type': 'ALIS',
    'source_type': 'MANUAL',
    'number': ?number,
    'issue_date': _today(),
    'due_date': ?(dueDate == null ? null : _dateValue(dueDate)),
    'currency': 'TRY',
    'exchange_rate': 1,
    'lines': [
      {
        'product_id': ?productId,
        'warehouse_id': ?(inventory ? warehouseId : null),
        'description': description,
        'quantity': 1,
        'unit': 'ADET',
        'unit_price': netAmount,
        'discount_rate': 0,
        'vat_rate': vatRate,
      },
    ],
  });

  Future<Map<String, dynamic>> postPurchaseInvoice(int invoiceId) =>
      _post('/accounting/purchase-invoices/$invoiceId/post', const {});

  Future<List<Map<String, dynamic>>> expenseCategories() =>
      _listAny('/accounting/expense-categories');

  Future<Map<String, dynamic>> createExpenseCategory({
    required String name,
    String? code,
  }) => _post('/accounting/expense-categories', {
    'name': name,
    'code': ?code,
  });

  // ── Tahsilat / ödeme ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> collections() =>
      _list('/accounting/collections', query: {'page_size': '100'});

  Future<List<Map<String, dynamic>>> supplierPayments() =>
      _list('/accounting/supplier-payments', query: {'page_size': '100'});

  Future<Map<String, dynamic>> createSupplierPayment({
    required int supplierId,
    required double amount,
    int? accountId,
  }) => _post('/accounting/supplier-payments', {
    'supplier_id': supplierId,
    'payment_date': _today(),
    'amount': amount,
    'currency': 'TRY',
    'exchange_rate': 1,
    'payment_method': 'HAVALE',
    'financial_account_id': ?accountId,
    'allocations': const [],
  });

  Future<Map<String, dynamic>> createFinancialAccount({
    required String name,
    String type = 'CASH',
    String? bankName,
    String? iban,
    double openingBalance = 0,
  }) => _post('/accounting/financial-accounts', {
    'name': name,
    'account_type': type,
    'bank_name': ?bankName,
    'iban': ?iban,
    'currency': 'TRY',
    'opening_balance': openingBalance,
  });

  // ── Çek ve senetler ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> checksNotes({String? direction}) => _list(
    '/accounting/checks-notes',
    query: {
      'page_size': '100',
      'direction': ?direction,
    },
  );

  Future<Map<String, dynamic>> createCheckNote({
    required String direction,
    required String instrumentType,
    required String serialNo,
    required DateTime dueDate,
    required double amount,
    int? partnerId,
    String? bankName,
    String? counterparty,
    String? notes,
  }) => _post('/accounting/checks-notes', {
    'direction': direction,
    'instrument_type': instrumentType,
    'serial_no': serialNo,
    'issue_date': _today(),
    'due_date': _dateValue(dueDate),
    'amount': amount,
    'currency': 'TRY',
    'exchange_rate': 1,
    'partner_id': ?partnerId,
    'bank_name': ?bankName,
    'received_from': ?(direction == 'IN' ? counterparty : null),
    'given_to': ?(direction == 'OUT' ? counterparty : null),
    'notes': ?notes,
  });

  Future<Map<String, dynamic>> addCheckNoteEvent({
    required int checkId,
    required String eventType,
    String? status,
    String? description,
  }) => _post('/accounting/checks-notes/$checkId/events', {
    'event_date': _today(),
    'event_type': eventType,
    'status': ?status,
    'description': ?description,
  });

  // ── Personel ───────────────────────────────────────────────
  Future<Map<String, dynamic>> createEmployee({
    required String employeeNo,
    required String firstName,
    required String lastName,
    required double grossSalary,
    String? nationalId,
    String? position,
    String? department,
    String? phone,
    String? email,
    String? iban,
    DateTime? hireDate,
  }) => _post('/accounting/employees', {
    'employee_no': employeeNo,
    'first_name': firstName,
    'last_name': lastName,
    'national_id': ?nationalId,
    'hire_date': _dateValue(hireDate ?? DateTime.now()),
    'position': ?position,
    'department': ?department,
    'phone': ?phone,
    'email': ?email,
    'iban': ?iban,
    'gross_salary': grossSalary,
    'currency': 'TRY',
  });

  Future<Map<String, dynamic>> createEmployeeAdvance({
    required int employeeId,
    required double amount,
  }) => _post('/accounting/employees/advances', {
    'employee_id': employeeId,
    'advance_date': _today(),
    'amount': amount,
    'currency': 'TRY',
    'exchange_rate': 1,
  });

  Future<Map<String, dynamic>> createAttendance({
    required int employeeId,
    String? workDate,
    double overtimeHours = 0,
  }) => _post('/accounting/employees/attendance', {
    'employee_id': employeeId,
    'work_date': workDate ?? _today(),
    'worked_days': 1,
    'normal_hours': 7.5,
    'overtime_hours': overtimeHours,
  });

  Future<Map<String, dynamic>> createLeave({
    required int employeeId,
    required String leaveType,
    required String startDate,
    required String endDate,
    double days = 1,
  }) => _post('/accounting/employees/leaves', {
    'employee_id': employeeId,
    'leave_type': leaveType,
    'start_date': startDate,
    'end_date': endDate,
    'days': days,
  });

  // ── Bildirimler ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> notifications({int pageSize = 50}) =>
      _list('/notification-center/', query: {'page_size': '$pageSize'});

  Future<int> unreadNotificationCount() async {
    final body = await _get('/notification-center/unread-count');
    final value = body['count'] ?? body['unread_count'] ?? body['total'] ?? 0;
    return int.tryParse('$value') ?? 0;
  }

  Future<Map<String, dynamic>> markNotificationRead(int id) =>
      _patch('/notification-center/$id/read', const {});

  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      _patch('/notification-center/read-all', const {});

  Future<Map<String, dynamic>> registerDeviceToken({
    required String deviceToken,
    required String platform,
  }) => _post('/notification-center/fcm-register', {
    'token': deviceToken,
    'platform': platform,
  });

  // ── Sohbet ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> chatHistory(int otherUserId) =>
      _list('/chat/history/$otherUserId');

  Future<Map<String, dynamic>> sendChatMessage({
    required int receiverId,
    required String content,
  }) => _post('/chat/send', {'receiver_id': receiverId, 'content': content});

  Future<List<Map<String, dynamic>>> chatUnreadCounts() =>
      _list('/chat/unread-counts');

  Future<void> markChatRead(int otherUserId) async {
    await _patch('/chat/read/$otherUserId', const {});
  }

  // ── Cari / mükellef ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> clients() => _list('/clients');

  /// Müşavir yeni mükellef oluşturur; şifre verilmezse geçici şifre üretilir.
  Future<Map<String, dynamic>> createClient({
    required String companyTitle,
    required String fullName,
    required String email,
    required String tckn,
    required double monthlyFee,
    int paymentDueDay = 1,
    String? phoneNumber,
    String? taxNumber,
    String? password,
    bool sendCredentialsEmail = false,
  }) => _post('/clients', {
    'company_title': companyTitle,
    'full_name': fullName,
    'email': email,
    'tckn': tckn,
    'monthly_fee': monthlyFee,
    'payment_due_day': paymentDueDay,
    'phone_number': ?phoneNumber,
    'tax_no': ?taxNumber,
    'password': ?password,
    'send_credentials_email': sendCredentialsEmail,
  });

  /// Mükellef kartını günceller (müşavir).
  Future<Map<String, dynamic>> updateClient(
    int clientId, {
    String? companyTitle,
    String? fullName,
    String? phoneNumber,
    String? taxNumber,
    double? monthlyFee,
    int? paymentDueDay,
  }) => _patch('/clients/$clientId', {
    'company_title': ?companyTitle,
    'full_name': ?fullName,
    'phone_number': ?phoneNumber,
    'tax_no': ?taxNumber,
    'monthly_fee': ?monthlyFee,
    'payment_due_day': ?paymentDueDay,
  });

  Future<Map<String, dynamic>> clientProfile() => _get('/clients/me');

  Future<Map<String, dynamic>> advisorProfile() => _get('/advisors/me');

  // ── Belgeler ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> allDocuments() => _list('/documents/all');

  Future<List<Map<String, dynamic>>> clientDocuments(int clientId) =>
      _list('/documents/$clientId');

  /// Belge yükler; `filePath` seçilen dosyanın tam yoludur.
  Future<Map<String, dynamic>> uploadDocument({
    required int clientId,
    required String documentType,
    required String filePath,
    String? fileName,
    String? documentDate,
  }) => _upload(
    '/documents/upload-single',
    fields: {
      'client_id': '$clientId',
      'document_type': documentType,
      'document_date': ?documentDate,
    },
    fileField: 'file',
    filePath: filePath,
    fileName: fileName,
  );

  String documentDownloadUrl(int documentId) =>
      '$baseUrl/documents/download/$documentId';

  // ── Ödemeler ───────────────────────────────────────────────
  Future<Map<String, dynamic>> paymentsSummary() => _get('/payments/summary');

  Future<List<Map<String, dynamic>>> paymentHistory() =>
      _list('/payments/history');

  Future<List<Map<String, dynamic>>> myPayments() =>
      _list('/payments/my-history');

  Future<List<Map<String, dynamic>>> installments() => _list('/installments');

  Future<List<Map<String, dynamic>>> myInstallments() =>
      _list('/installments/my');

  Future<List<Map<String, dynamic>>> extraCharges() => _list('/extra-charges');

  Future<List<Map<String, dynamic>>> myExtraCharges() =>
      _list('/extra-charges/my');

  // ── E-Fatura ───────────────────────────────────────────────
  Future<Map<String, dynamic>> einvoiceAccount() => _get('/einvoice/account');

  Future<List<Map<String, dynamic>>> einvoiceInvoices() =>
      _list('/einvoice/invoices', query: {'page_size': '50'});

  Future<List<Map<String, dynamic>>> einvoiceInbox() =>
      _list('/einvoice/inbox', query: {'page_size': '50'});

  Future<List<Map<String, dynamic>>> einvoiceDespatches() =>
      _list('/einvoice/despatches', query: {'page_size': '50'});

  Future<List<Map<String, dynamic>>> clientEinvoiceInvoices() =>
      _list('/client-einvoice/invoices', query: {'page_size': '50'});

  Future<List<Map<String, dynamic>>> clientEinvoiceInbox() =>
      _list('/client-einvoice/inbox', query: {'page_size': '50'});

  // ── Takvim, hatırlatıcı, GİB ───────────────────────────────
  Future<List<Map<String, dynamic>>> calendarEvents() =>
      _list('/calendar/events');

  Future<List<Map<String, dynamic>>> gibTaxCalendar() =>
      _list('/general/gib-tax-calendar');

  Future<List<Map<String, dynamic>>> reminderRules() =>
      _list('/reminder-rules');

  Future<Map<String, dynamic>> createReminderRule({
    required String channel,
    required int daysBefore,
    String? message,
  }) => _post('/reminder-rules', {
    'channel': channel,
    'days_before': daysBefore,
    'message': ?message,
  });

  Future<Map<String, dynamic>> updateReminderRule(
    int ruleId, {
    int? daysBefore,
    String? message,
    bool? isActive,
  }) => _patch('/reminder-rules/$ruleId', {
    'days_before': ?daysBefore,
    'message': ?message,
    'is_active': ?isActive,
  });

  Future<void> deleteReminderRule(int ruleId) async {
    await _delete('/reminder-rules/$ruleId');
  }

  /// Bekleyen ödeme hatırlatmalarını hemen gönderir (müşavir aracı).
  Future<Map<String, dynamic>> runReminders() =>
      _post('/rules/run-reminders', const {});

  Future<Map<String, dynamic>> createCalendarEvent({
    required String title,
    required String eventDate,
    String? description,
    String eventType = 'PERSONAL',
    bool isNotificationActive = true,
  }) => _post('/calendar/events', {
    'title': title,
    'description': ?description,
    'event_date': eventDate,
    'event_type': eventType,
    'is_notification_active': isNotificationActive,
  });

  // ── Diğer modüller ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> messageTemplates() =>
      _list('/advisors/templates');

  Future<List<Map<String, dynamic>>> supportTickets() =>
      _list('/support/tickets/my');

  Future<List<Map<String, dynamic>>> forumCategories() =>
      _list('/forum/categories');

  Future<List<Map<String, dynamic>>> forumTopics() => _list('/forum/topics');

  Future<List<Map<String, dynamic>>> announcements() =>
      _list('/general/announcements');

  Future<List<Map<String, dynamic>>> gibAnnouncements() =>
      _list('/general/gib-announcements');

  Future<List<Map<String, dynamic>>> incomingMatchRequests() =>
      _list('/matching/requests/incoming');

  Future<List<Map<String, dynamic>>> myMatchRequests() =>
      _list('/matching/requests/my');

  Future<List<Map<String, dynamic>>> danismaQuestions() =>
      _list('/danisma/questions');

  Future<List<Map<String, dynamic>>> myDanismaQuestions() =>
      _list('/danisma/questions/my');

  Future<Map<String, dynamic>> systemStatus() => _get('/general/system-status');

  // ── Toplu mesaj (mail / WhatsApp) ──────────────────────────
  Future<Map<String, dynamic>> sendBulkMessage({
    required List<int> clientIds,
    required String channel,
    required String message,
    String? subject,
  }) => _post('/notifications/send', {
    'client_ids': clientIds,
    'channel': channel,
    'message': message,
    'subject': ?subject,
  });

  // ── Destek ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> createSupportTicket({
    required String name,
    required String contact,
    required String subject,
    required String message,
  }) => _post('/support/tickets/auth', {
    'name': name,
    'contact': contact,
    'subject': subject,
    'message': message,
  });

  // ── Forum ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> createForumTopic({
    required int categoryId,
    required String title,
    required String content,
  }) => _post('/forum/topics', {
    'category_id': categoryId,
    'title': title,
    'content': content,
  });

  Future<List<Map<String, dynamic>>> forumPosts(int topicId) =>
      _list('/forum/topics/$topicId/posts');

  Future<Map<String, dynamic>> createForumPost({
    required int topicId,
    required String content,
  }) => _post('/forum/topics/$topicId/posts', {'content': content});

  // ── Danışma ────────────────────────────────────────────────
  Future<Map<String, dynamic>> createDanismaQuestion({
    required String title,
    required String content,
    int? categoryId,
  }) => _post('/danisma/questions', {
    'title': title,
    'content': content,
    'category_id': ?categoryId,
  });

  Future<List<Map<String, dynamic>>> danismaCategories() =>
      _list('/danisma/categories');

  Future<List<Map<String, dynamic>>> danismaAnswers(int questionId) =>
      _list('/danisma/questions/$questionId/answers');

  Future<Map<String, dynamic>> createDanismaAnswer({
    required int questionId,
    required String content,
    required double price,
  }) => _post('/danisma/questions/$questionId/answers', {
    'content': content,
    'price': price,
  });

  // ── Elle ödeme ve ek ücret ─────────────────────────────────
  Future<Map<String, dynamic>> createManualPayment({
    required int clientId,
    required double amount,
    String paymentMethod = 'havale_eft',
    String paymentStatus = 'PAID',
    String? description,
    DateTime? paymentDate,
  }) => _post('/payments/manual', {
    'client_id': clientId,
    'amount': amount,
    'payment_method': paymentMethod,
    'payment_type': 'muhasebe',
    'payment_status': paymentStatus,
    'description': ?description,
    'payment_date': ?paymentDate?.toIso8601String(),
  });

  Future<Map<String, dynamic>> createExtraCharge({
    required int clientId,
    required String name,
    required double amount,
    DateTime? dueDate,
    String? description,
  }) => _post('/extra-charges', {
    'client_id': clientId,
    'name': name,
    'amount': amount,
    'due_date': ?(dueDate == null ? null : _dateValue(dueDate)),
    'description': ?description,
  });

  Future<Map<String, dynamic>> markExtraChargePaid(
    int chargeId, {
    String paymentMethod = 'havale_eft',
  }) => _post('/extra-charges/$chargeId/mark-paid', {
    'payment_method': paymentMethod,
  });

  // ── Harici mükellef ve giriş bilgileri ─────────────────────
  Future<List<Map<String, dynamic>>> externalClients() =>
      _list('/external-clients');

  Future<Map<String, dynamic>> createExternalClient({
    required String fullName,
    required String companyTitle,
    String? taxNo,
    String? tckn,
    String? phoneNumber,
    String? email,
    double monthlyFee = 0,
  }) => _post('/external-clients', {
    'full_name': fullName,
    'company_title': companyTitle,
    'tax_no': ?taxNo,
    'tckn': ?tckn,
    'phone_number': ?phoneNumber,
    'email': ?email,
    'monthly_fee': monthlyFee,
    'payment_due_day': 1,
  });

  Future<List<Map<String, dynamic>>> clientCredentials(int clientId) =>
      _list('/clients/$clientId/credentials');

  Future<Map<String, dynamic>> revealClientCredential(
    int clientId,
    String serviceKey,
  ) => _get('/clients/$clientId/credentials/$serviceKey/reveal');

  // ── Profil güncelleme ──────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? city,
  }) => _patch('/users/me', {
    'full_name': ?fullName,
    'phone_number': ?phoneNumber,
    'city': ?city,
  });

  // ── Ödeme (PayTR) ──────────────────────────────────────────
  /// PayTR ödeme formu alanlarını üretir (kart bilgisi içermez).
  Future<Map<String, dynamic>> preparePayment({
    double amount = 0,
    String paymentPurpose = 'monthly_fee',
    int monthCount = 1,
    int installmentCount = 0,
    int? extraChargeId,
    bool storeCard = false,
  }) => _post('/paytr/prepare-payment', {
    'amount': amount,
    'payment_purpose': paymentPurpose,
    'month_count': monthCount,
    'installment_count': installmentCount,
    'extra_charge_id': ?extraChargeId,
    'non_3d': false,
    'store_card': storeCard,
  });

  /// Kayıtlı (tokenize) kartlar; yalnız mükellef rolünde doludur.
  Future<List<Map<String, dynamic>>> storedCards() async {
    final body = await _get('/paytr/stored-cards');
    final cards = body['cards'];
    if (cards is List) {
      return cards
          .whereType<Map>()
          .map((card) => Map<String, dynamic>.from(card))
          .toList();
    }
    return const [];
  }

  Future<void> deleteStoredCard(String ctoken) async {
    await _delete('/paytr/stored-cards/$ctoken');
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (demoMode) return DemoData.get(path);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _authorized(
      () => http.get(uri, headers: _headers()),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(body) ?? 'Veri alınamadı',
        response.statusCode,
      );
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> _list(
    String path, {
    Map<String, String>? query,
  }) async {
    final body = await _get(path, query: query);
    return (body['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Hem `{"items": [...]}` hem de doğrudan `[...]` dönen uçlar için liste okur.
  Future<List<Map<String, dynamic>>> _listAny(
    String path, {
    Map<String, String>? query,
  }) async {
    if (demoMode) {
      final demo = DemoData.get(path);
      return (demo['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _authorized(() => http.get(uri, headers: _headers()));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(decoded is Map<String, dynamic>
                ? decoded
                : <String, dynamic>{'detail': decoded.toString()}) ??
            'Veri alınamadı',
        response.statusCode,
      );
    }
    final raw = decoded is Map ? decoded['items'] : decoded;
    return (raw as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (demoMode) return DemoData.post(path, body);
    final response = await _authorized(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(decoded) ?? 'İşlem tamamlanamadı',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (demoMode) return DemoData.post(path, body);
    final response = await _authorized(
      () => http.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(decoded) ?? 'İşlem tamamlanamadı',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    if (demoMode) return const {};
    final response = await _authorized(
      () => http.delete(Uri.parse('$baseUrl$path'), headers: _headers()),
    );
    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(decoded) ?? 'İşlem tamamlanamadı',
        response.statusCode,
      );
    }
    return decoded;
  }

  /// Dosya yükleme (multipart/form-data).
  Future<Map<String, dynamic>> _upload(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    String? fileName,
  }) async {
    if (demoMode) return DemoData.post(path, fields);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    final authToken = token;
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: fileName,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        _detail(decoded) ?? 'Dosya yüklenemedi',
        response.statusCode,
      );
    }
    return decoded;
  }

  Map<String, String> _headers({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'items': decoded, 'total': decoded.length};
      return {'value': decoded};
    } catch (_) {
      return {'detail': response.body};
    }
  }

  /// Rapor uçları metrikleri `summary` altında döner; sarmalayıcı yoksa
  /// gövdenin kendisi özet kabul edilir.
  Map<String, dynamic> _summaryOf(Map<String, dynamic> body) {
    final summary = body['summary'];
    if (summary is Map) return Map<String, dynamic>.from(summary);
    return body;
  }

  String? _detail(Map<String, dynamic> body) {
    final value = body['detail'] ?? body['message'];
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  String _today() => _dateValue(DateTime.now());

  String _dateValue(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class DemoData {
  static Map<String, dynamic> get(String path) {
    if (path.contains('/reports/summary')) {
      return {
        'summary': {
          'sales_total': 284500,
          'expense_total': 118220,
          'net_total': 166280,
          'cash_balance': 384500,
          'customer_count': 42,
          'supplier_count': 18,
          'employee_count': 7,
        },
      };
    }
    if (path.contains('/partners')) {
      return {
        'items': [
          {
            'id': 1,
            'code': 'M001',
            'name': 'Atlas Teknoloji Ltd.',
            'partner_type': 'CUSTOMER',
            'tax_number': '1234567890',
            'phone': '0532 000 00 01',
            'balance': 34500,
          },
          {
            'id': 2,
            'code': 'M002',
            'name': 'Nova Mimarlık',
            'partner_type': 'CUSTOMER',
            'tax_number': '1234567891',
            'phone': '0532 000 00 02',
            'balance': 52200,
          },
          {
            'id': 3,
            'code': 'T001',
            'name': 'Bulut Sunucu A.Ş.',
            'partner_type': 'SUPPLIER',
            'tax_number': '9876543210',
            'phone': '0212 000 00 03',
            'balance': -2450,
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/sales-invoices')) {
      return {
        'items': [
          {
            'id': 1,
            'number': 'FTR2026000001',
            'partner_id': 1,
            'issue_date': '2026-09-18',
            'due_date': '2026-10-18',
            'gross_amount': 34500,
            'payment_status': 'PAID',
            'status': 'DELIVERED',
          },
          {
            'id': 2,
            'number': 'FTR2026000002',
            'partner_id': 2,
            'issue_date': '2026-09-20',
            'due_date': '2026-10-20',
            'gross_amount': 52200,
            'payment_status': 'UNPAID',
            'status': 'SENT',
          },
          {
            'id': 3,
            'number': 'FTR2026000003',
            'partner_id': 1,
            'issue_date': '2026-09-22',
            'due_date': '2026-10-22',
            'gross_amount': 18750,
            'payment_status': 'PARTIAL',
            'status': 'ACCEPTED',
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/purchase-invoices')) {
      return {
        'items': [
          {
            'id': 1,
            'number': 'AF2026000001',
            'supplier_id': 3,
            'issue_date': '2026-09-11',
            'gross_amount': 18000,
            'payment_status': 'PAID',
            'status': 'POSTED',
          },
          {
            'id': 2,
            'number': 'AF2026000002',
            'supplier_id': 3,
            'issue_date': '2026-09-18',
            'gross_amount': 2450,
            'payment_status': 'UNPAID',
            'status': 'POSTED',
          },
        ],
        'total': 2,
      };
    }
    if (path.contains('/expenses')) {
      return {
        'items': [
          {
            'id': 1,
            'expense_date': '2026-09-01',
            'description': 'Ofis Kira & Stopaj',
            'total_amount': 18000,
            'vat_amount': 3000,
            'payment_status': 'PAID',
          },
          {
            'id': 2,
            'expense_date': '2026-09-18',
            'description': 'Bulut Sunucu Abonelik',
            'total_amount': 2450,
            'vat_amount': 408,
            'payment_status': 'UNPAID',
          },
          {
            'id': 3,
            'expense_date': '2026-09-20',
            'description': 'Kırtasiye Alımı',
            'total_amount': 1250,
            'vat_amount': 208,
            'payment_status': 'PAID',
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/financial-accounts')) {
      return {
        'items': [
          {
            'id': 1,
            'name': 'Merkez Kasa',
            'account_type': 'CASH',
            'current_balance': 42500,
            'currency': 'TRY',
          },
          {
            'id': 2,
            'name': 'Ziraat Vadesiz',
            'account_type': 'BANK',
            'current_balance': 243500,
            'currency': 'TRY',
          },
          {
            'id': 3,
            'name': 'Garanti Ticari',
            'account_type': 'BANK',
            'current_balance': 98500,
            'currency': 'TRY',
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/financial-transactions')) {
      return {
        'items': [
          {
            'id': 1,
            'transaction_date': '2026-09-22',
            'direction': 'IN',
            'amount': 34500,
            'description': 'Atlas Teknoloji tahsilatı',
            'source_type': 'COLLECTION',
          },
          {
            'id': 2,
            'transaction_date': '2026-09-21',
            'direction': 'OUT',
            'amount': 18000,
            'description': 'Ofis kira ödemesi',
            'source_type': 'EXPENSE',
          },
          {
            'id': 3,
            'transaction_date': '2026-09-20',
            'direction': 'IN',
            'amount': 12500,
            'description': 'POS tahsilatı',
            'source_type': 'COLLECTION',
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/employees')) {
      return {
        'items': [
          {
            'id': 1,
            'employee_no': 'P001',
            'first_name': 'Ali',
            'last_name': 'Yılmaz',
            'position': 'Ön Muhasebe',
            'gross_salary': 42000,
            'status': 'ACTIVE',
          },
          {
            'id': 2,
            'employee_no': 'P002',
            'first_name': 'Ayşe',
            'last_name': 'Demir',
            'position': 'Satış Uzmanı',
            'gross_salary': 48000,
            'status': 'ACTIVE',
          },
          {
            'id': 3,
            'employee_no': 'P003',
            'first_name': 'Mert',
            'last_name': 'Kaya',
            'position': 'Depo',
            'gross_salary': 36000,
            'status': 'ACTIVE',
          },
        ],
        'total': 3,
      };
    }
    if (path.contains('/payroll')) {
      return {
        'items': [
          {
            'id': 1,
            'year': 2026,
            'month': 9,
            'status': 'PAID',
            'gross_total': 126000,
            'net_total': 90750,
            'employer_cost_total': 154350,
          },
          {
            'id': 2,
            'year': 2026,
            'month': 8,
            'status': 'PAID',
            'gross_total': 126000,
            'net_total': 90750,
            'employer_cost_total': 154350,
          },
        ],
        'total': 2,
      };
    }
    if (path.contains('/reports/vat')) {
      return {
        'summary': {
          'output_vat': 51120,
          'input_vat': 21240,
          'output_withholding': 0,
          'input_withholding': 0,
          'kdv2': 0,
          'other_adjustments': 0,
          'carried_in': 0,
          'payable': 29880,
          'carried_out': 0,
          'payable_or_carried': 29880,
        },
      };
    }
    if (path.contains('/reports/cash-flow')) {
      return {
        'summary': {
          'opening': 321400,
          'inflow': 124800,
          'outflow': 61700,
          'net': 63100,
          'closing': 384500,
          'upcoming_receivables': 142850,
          'upcoming_payables': 68200,
          'projected_closing': 459150,
        },
      };
    }
    if (path.contains('/reports/sales')) {
      return {
        'summary': {
          'invoice_count': 18,
          'net': 237083,
          'vat': 47417,
          'gross': 284500,
        },
      };
    }
    if (path.contains('/reports/expenses')) {
      return {
        'summary': {'count': 12, 'net': 98517, 'vat': 19703, 'total': 118220},
      };
    }
    if (path.contains('/reports/collections')) {
      return {
        'summary': {
          'count': 9,
          'total': 198450,
          'allocated': 184300,
          'unallocated': 14150,
          'pending_receivables': 142850,
          'overdue_receivables': 18200,
        },
      };
    }
    return {'summary': <String, dynamic>{}, 'items': <dynamic>[]};
  }

  static Map<String, dynamic> post(String path, Map<String, dynamic> body) {
    return {'id': DateTime.now().millisecondsSinceEpoch, ...body};
  }
}
