import 'dart:math';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminModule {
  const AdminModule(this.id, this.title, this.path, {this.itemsKey = 'items'});

  final String id;
  final String title;
  final String path;
  final String itemsKey;
}

const adminModules = <AdminModule>[
  AdminModule('users', 'Üyeler', '/admin/users'),
  AdminModule('advisors', 'Müşavirler', '/admin/advisors'),
  AdminModule('clients', 'Mükellefler', '/admin/clients'),
  AdminModule(
    'advisor-changes',
    'Müşavir Değişiklikleri',
    '/admin/advisor-change-requests',
  ),
  AdminModule('approvals', 'Onay Bekleyenler', '/admin/pending-approvals'),
  AdminModule(
    'advisor-approvals',
    'Müşavir Onayları',
    '/admin/advisor-approvals',
  ),
  AdminModule('financial', 'Finansal Yönetim', '/admin/financial/summary'),
  AdminModule('payments', 'Ödeme Logları', '/admin/payment-logs'),
  AdminModule(
    'transfers',
    'Pazaryeri Transferleri',
    '/admin/platform-transfers',
  ),
  AdminModule(
    'sms-reports',
    'SMS Raporları',
    '/admin/sms-reports',
    itemsKey: 'orders',
  ),
  AdminModule('danisma', 'Danışmanlık', '/danisma/admin/questions'),
  AdminModule(
    'system-updates',
    'Sistem Güncellemeleri',
    '/admin/system-updates',
  ),
  AdminModule('announcements', 'Duyurular', '/admin/announcements'),
  AdminModule('support', 'Destek Talepleri', '/admin/support/tickets'),
  AdminModule('system-users', 'Kullanıcılar', '/admin/users'),
  AdminModule('settings', 'Ayarlar', '/admin/settings'),
  AdminModule('logs', 'Log Takibi', '/admin/logs'),
];

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.adminGet('/admin/dashboard');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) => RefreshIndicator(
      onRefresh: () async =>
          setState(() => _future = widget.api.adminGet('/admin/dashboard')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageTitle(title: 'Panel', subtitle: 'Finkit yönetim özeti'),
          if (snapshot.connectionState != ConnectionState.done)
            const LoadingState()
          else if (snapshot.hasError)
            TextButton(
              onPressed: () => setState(
                () => _future = widget.api.adminGet('/admin/dashboard'),
              ),
              child: Text(
                'Yönetim verisi alınamadı: ${snapshot.error} · Tekrar dene',
              ),
            )
          else
            ...snapshot.data!.entries.map(
              (entry) => Card(
                child: ListTile(
                  title: Text(_label(entry.key)),
                  subtitle: Text('${entry.value}'),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AdminResourcePage extends StatefulWidget {
  const AdminResourcePage({super.key, required this.api, required this.module});
  final FinkitApi api;
  final AdminModule module;

  @override
  State<AdminResourcePage> createState() => _AdminResourcePageState();
}

class _AdminResourcePageState extends State<AdminResourcePage> {
  final _search = TextEditingController();
  final _refundKeys = <int, ({double amount, String reference, String key})>{};
  int _page = 1;
  String _paymentStatus = '';
  String _transferStatus = '';
  String _advisorSort = 'client_count_desc';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    if (widget.module.id == 'danisma') {
      _future = widget.api.adminDanismaQuestions(page: _page);
      return;
    }
    _future = widget.api.adminGet(
      widget.module.path,
      query: {
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (widget.module.id == 'payments' && _paymentStatus.isNotEmpty)
          'status': _paymentStatus,
        if (widget.module.id == 'transfers' && _transferStatus.isNotEmpty)
          'status': _transferStatus,
        if (widget.module.id != 'settings' && widget.module.id != 'financial')
          'page': '$_page',
        if (widget.module.id != 'settings' && widget.module.id != 'financial')
          'page_size': '30',
      },
    );
  }

  void _reload() => setState(_load);

  List<Map<String, dynamic>> _rows(Map<String, dynamic> body) {
    final raw = body[widget.module.itemsKey];
    if (raw is List) {
      final rows = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (widget.module.id == 'advisors') {
        final parts = _advisorSort.split('_');
        final field = parts.take(parts.length - 1).join('_');
        final descending = parts.last == 'desc';
        rows.sort((a, b) {
          final first = num.tryParse('${a[field]}') ?? 0;
          final second = num.tryParse('${b[field]}') ?? 0;
          return descending ? second.compareTo(first) : first.compareTo(second);
        });
      }
      return rows;
    }
    if (widget.module.id == 'financial') {
      return body.entries
          .map((entry) => {'name': _label(entry.key), 'value': entry.value})
          .toList();
    }
    return const [];
  }

  String _rowTitle(Map<String, dynamic> row) =>
      '${row['title'] ?? (row['user'] is Map ? row['user']['full_name'] : null) ?? row['full_name'] ?? row['company_title'] ?? row['office_name'] ?? row['name'] ?? row['email'] ?? row['order_id'] ?? row['id'] ?? 'Kayıt'}';

  Future<void> _showDetails(Map<String, dynamic> row) async {
    var detail = row;
    if (widget.module.id == 'advisors') {
      try {
        detail = await widget.api.adminGet('/admin/advisors/${row['user_id']}');
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Müşavir ayrıntısı alınamadı: $error')),
          );
        }
      }
    }
    if (!mounted) return;
    final current = detail;
    final user = current['user'] is Map ? current['user'] as Map : const {};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              _rowTitle(current),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (widget.module.id == 'transfers' &&
                current['status'] == 'SUBMITTED' &&
                '${current['error_message'] ?? ''}'.contains('mutabakat'))
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('PayTR sonucu doğrulanmalı'),
                subtitle: Text(
                  'Talimat tekrar gönderilmez. PayTR kaydı ve transfer bildirimiyle mutabakat yapın.',
                ),
              ),
            if (user.isNotEmpty)
              for (final key in ['full_name', 'email', 'phone_number'])
                if (user[key] != null)
                  ListTile(
                    dense: true,
                    title: Text(_label(key)),
                    subtitle: Text('${user[key]}'),
                  ),
            for (final entry in current.entries)
              if (entry.key != 'user' && entry.key != 'clients')
                ListTile(
                  dense: true,
                  title: Text(_label(entry.key)),
                  subtitle: Text('${entry.value ?? '—'}'),
                ),
            if (current['clients'] is List) ...[
              const Divider(),
              Text(
                'Bağlı mükellefler',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final client
                  in (current['clients'] as List).whereType<Map>())
                Card(
                  child: ListTile(
                    title: Text(
                      '${client['company_title'] ?? client['full_name'] ?? 'Mükellef'}',
                    ),
                    subtitle: Text(
                      '${client['email'] ?? ''} · ${client['payment_status'] ?? '—'}',
                    ),
                    trailing: Text(moneyText(client['monthly_fee'])),
                  ),
                ),
            ],
            for (final action in _actions(current))
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () async {
                  Navigator.pop(context);
                  await _runAction(action);
                },
              ),
            if (const {'advisors', 'clients'}.contains(widget.module.id))
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(
                  widget.module.id == 'advisors'
                      ? 'Müşaviri sil'
                      : 'Mükellefi sil',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteParty(current);
                },
              ),
            if (widget.module.id == 'payments' &&
                const {
                  'PENDING',
                  'UNKNOWN',
                }.contains('${row['refund_attempt_status']}'))
              ListTile(
                leading: const Icon(Icons.sync_outlined),
                title: const Text('PayTR İade Durumunu Sorgula'),
                subtitle: const Text('İade yeniden gönderilmez.'),
                onTap: () async {
                  Navigator.pop(context);
                  await _reconcileRefund(row);
                },
              ),
            if (widget.module.id == 'payments' &&
                row['refund_attempt_status'] == null &&
                const {
                  'SUCCESS',
                  'PARTIALLY_REFUNDED',
                }.contains('${row['status']}') &&
                (double.tryParse('${row['amount']}') ?? 0) >
                    (double.tryParse('${row['refunded_amount']}') ?? 0))
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Ödemeyi İade Et'),
                onTap: () async {
                  Navigator.pop(context);
                  await _refund(row);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteParty(Map<String, dynamic> row) async {
    final id = row['user_id'];
    if (id == null) return;
    final user = row['user'];
    final name =
        '${row['full_name'] ?? (user is Map ? user['full_name'] : null) ?? row['email'] ?? ''}'
            .trim();
    var typed = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Onaylamak için "$name" yazın.'),
            TextField(
              onChanged: (value) => typed = value,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    if (typed.trim().replaceAll(RegExp(r'\s+'), ' ') !=
        name.replaceAll(RegExp(r'\s+'), ' ')) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Onay metni eşleşmedi.')));
      }
      return;
    }
    try {
      await widget.api.adminDelete('/admin/users/$id');
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  List<_AdminAction> _actions(Map<String, dynamic> row) {
    final id = row['user_id'] ?? row['id'];
    if (id == null) return const [];
    return switch (widget.module.id) {
      'users' || 'system-users' => [
        if (row['is_banned'] == true || row['is_active'] == false)
          _AdminAction(
            'Yasağı kaldır',
            Icons.lock_open_outlined,
            '/admin/users/$id/unban',
            'POST',
          )
        else
          _AdminAction(
            'Hesabı yasakla',
            Icons.block_outlined,
            '/admin/users/$id/ban',
            'POST',
            needsReason: true,
          ),
        _AdminAction(
          'Kullanıcıyı sil',
          Icons.delete_outline,
          '/admin/users/$id',
          'DELETE',
        ),
      ],
      'advisors' => [
        _AdminAction(
          'Danışma erişimini değiştir',
          Icons.question_answer_outlined,
          '/admin/advisors/$id/danisma-toggle',
          'PATCH',
        ),
      ],
      'clients' => [
        _AdminAction(
          'Ödeme muafiyetini değiştir',
          Icons.payment_outlined,
          '/admin/clients/$id/payment-bypass-toggle',
          'PATCH',
        ),
      ],
      'transfers' => [
        if (row['status'] == 'BOUNCED' ||
            (row['status'] == 'FAILED' &&
                (int.tryParse('${row['retry_count'] ?? 0}') ?? 0) == 0 &&
                '${row['error_message'] ?? ''}'.startsWith(
                  'IBAN aktarilamadi:',
                )))
          _AdminAction(
            'Transferi yeniden dene',
            Icons.refresh_rounded,
            '/admin/platform-transfers/$id/retry',
            'POST',
          ),
      ],
      'approvals' => [
        _AdminAction(
          'Mükellefi onayla',
          Icons.check_rounded,
          '/admin/pending-approvals/$id/approve',
          'POST',
        ),
        _AdminAction(
          'Mükellefi reddet',
          Icons.close_rounded,
          '/admin/pending-approvals/$id/reject',
          'POST',
          needsReason: true,
        ),
      ],
      'advisor-approvals' => [
        _AdminAction(
          'Müşaviri onayla',
          Icons.check_rounded,
          '/admin/advisor-approvals/$id/approve',
          'POST',
        ),
        _AdminAction(
          'Müşaviri reddet',
          Icons.close_rounded,
          '/admin/advisor-approvals/$id/reject',
          'POST',
          needsReason: true,
        ),
      ],
      'advisor-changes' => [
        if ('${row['status']}'.toLowerCase() == 'pending') ...[
          _AdminAction(
            'Müşavir değişikliğini onayla',
            Icons.check_rounded,
            '/admin/advisor-change-requests/$id',
            'PATCH',
            body: const {'status': 'approved'},
          ),
          _AdminAction(
            'Müşavir değişikliğini reddet',
            Icons.close_rounded,
            '/admin/advisor-change-requests/$id',
            'PATCH',
            body: const {'status': 'rejected'},
            reasonKey: 'admin_note',
            needsReason: true,
          ),
        ],
      ],
      _ => const [],
    };
  }

  Future<void> _runAction(_AdminAction action) async {
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.label),
        content: action.needsReason
            ? TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Gerekçe'),
              )
            : const Text('Bu işlemi onaylıyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    final reasonValue = reason.text.trim();
    reason.dispose();
    if (approved != true) return;
    if (action.needsReason && reasonValue.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gerekçe gerekli.')));
      return;
    }
    try {
      final body = <String, dynamic>{
        ...action.body,
        if (action.needsReason) action.reasonKey: reasonValue,
      };
      if (action.method == 'DELETE') {
        await widget.api.adminDelete(action.path);
      } else if (action.method == 'PATCH') {
        await widget.api.adminPatch(action.path, body);
      } else {
        await widget.api.adminPost(action.path, body);
      }
      if (mounted) _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _refund(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    final amount = double.tryParse('${row['amount']}') ?? 0;
    final refunded = double.tryParse('${row['refunded_amount']}') ?? 0;
    final maxRefund = amount - refunded;
    if (id == null || maxRefund <= 0) return;
    final input = await showDialog<({String amount, String reference})>(
      context: context,
      builder: (context) => _RefundDialog(maxRefund: maxRefund),
    );
    final requested = double.tryParse(
      (input?.amount ?? '').trim().replaceAll(',', '.'),
    );
    final reference = input?.reference.trim() ?? '';
    if (input == null || !mounted) return;
    if (requested == null ||
        requested <= 0 ||
        requested > maxRefund ||
        (requested * 100).roundToDouble() != requested * 100 ||
        (reference.isNotEmpty &&
            !RegExp(r'^[A-Za-z0-9]+$').hasMatch(reference))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir tutar ve alfasayısal referans girin.'),
        ),
      );
      return;
    }
    final previous = _refundKeys[id];
    final requestKey =
        previous != null &&
            previous.amount == requested &&
            previous.reference == reference
        ? previous.key
        : _newRefundKey();
    _refundKeys[id] = (
      amount: requested,
      reference: reference,
      key: requestKey,
    );
    try {
      await widget.api.adminPost('/admin/payments/$id/refund', {
        'amount': requested,
        'reference_no': reference,
        'request_key': requestKey,
      });
      _refundKeys.remove(id);
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (error.statusCode == 400) _refundKeys.remove(id);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _reconcileRefund(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;
    try {
      final result = await widget.api.adminPost(
        '/admin/payments/$id/refund/reconcile',
        const {},
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['message'] ?? result['status']}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PayTR durumu sorgulanamadı: $error')),
        );
      }
    }
  }

  String _newRefundKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final rows = snapshot.hasData
          ? _rows(snapshot.data!)
          : const <Map<String, dynamic>>[];
      final total = int.tryParse('${snapshot.data?['total']}') ?? rows.length;
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(title: widget.module.title, subtitle: '$total kayıt'),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => setState(() {
                _page = 1;
                _load();
              }),
            ),
            if (widget.module.id == 'advisors')
              DropdownButtonFormField<String>(
                initialValue: _advisorSort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sıralama'),
                items: const [
                  DropdownMenuItem(
                    value: 'client_count_desc',
                    child: Text('Mükellef sayısı: çoktan aza'),
                  ),
                  DropdownMenuItem(
                    value: 'client_count_asc',
                    child: Text('Mükellef sayısı: azdan çoğa'),
                  ),
                  DropdownMenuItem(
                    value: 'total_revenue_desc',
                    child: Text('Gelir: çoktan aza'),
                  ),
                  DropdownMenuItem(
                    value: 'total_revenue_asc',
                    child: Text('Gelir: azdan çoğa'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _advisorSort = value ?? 'client_count_desc'),
              ),
            if (widget.module.id == 'payments')
              DropdownButtonFormField<String>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Ödeme durumu'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tümü')),
                  DropdownMenuItem(value: 'SUCCESS', child: Text('Başarılı')),
                  DropdownMenuItem(
                    value: 'PARTIALLY_REFUNDED',
                    child: Text('Kısmi iade'),
                  ),
                  DropdownMenuItem(
                    value: 'REFUNDED',
                    child: Text('İade edildi'),
                  ),
                  DropdownMenuItem(value: 'FAILED', child: Text('Hatalı')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Bekliyor')),
                ],
                onChanged: (value) => setState(() {
                  _paymentStatus = value ?? '';
                  _page = 1;
                  _load();
                }),
              ),
            if (widget.module.id == 'transfers')
              DropdownButtonFormField<String>(
                initialValue: _transferStatus,
                decoration: const InputDecoration(labelText: 'Transfer durumu'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tümü')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Bekliyor')),
                  DropdownMenuItem(
                    value: 'SUBMITTED',
                    child: Text('Talimat verildi'),
                  ),
                  DropdownMenuItem(value: 'SUCCESS', child: Text('Tamamlandı')),
                  DropdownMenuItem(value: 'FAILED', child: Text('Başarısız')),
                  DropdownMenuItem(value: 'BOUNCED', child: Text('Geri döndü')),
                ],
                onChanged: (value) => setState(() {
                  _transferStatus = value ?? '';
                  _page = 1;
                  _load();
                }),
              ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: _reload,
                child: Text('Veri alınamadı: ${snapshot.error} · Tekrar dene'),
              )
            else if (rows.isEmpty)
              const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Kayıt yok',
                description: 'Bu bölümde kayıt bulunamadı.',
              )
            else
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(_rowTitle(row)),
                    subtitle: Text(
                      '${row['status'] ?? row['email'] ?? row['created_at'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showDetails(row),
                  ),
                ),
            if (total > 30)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _page > 1
                        ? () => setState(() {
                            _page--;
                            _load();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$_page'),
                  IconButton(
                    onPressed: _page * 30 < total
                        ? () => setState(() {
                            _page++;
                            _load();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.maxRefund});
  final double maxRefund;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final _amount = TextEditingController(
    text: widget.maxRefund.toStringAsFixed(2),
  );
  final _reference = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PayTR Ödeme İadesi'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'En fazla ${widget.maxRefund.toStringAsFixed(2)} TL iade edilebilir.',
        ),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'İade tutarı (TL)'),
        ),
        TextField(
          controller: _reference,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'Referans no (isteğe bağlı)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          amount: _amount.text,
          reference: _reference.text,
        )),
        child: const Text('İadeyi Onayla'),
      ),
    ],
  );
}

class _AdminAction {
  const _AdminAction(
    this.label,
    this.icon,
    this.path,
    this.method, {
    this.needsReason = false,
    this.reasonKey = 'reason',
    this.body = const {},
  });
  final String label;
  final IconData icon;
  final String path;
  final String method;
  final bool needsReason;
  final String reasonKey;
  final Map<String, dynamic> body;
}

String _label(String key) => key.replaceAll('_', ' ');
