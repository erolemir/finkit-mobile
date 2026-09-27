import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminSmsPage extends StatefulWidget {
  const AdminSmsPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminSmsPage> createState() => _AdminSmsPageState();
}

class _AdminSmsPageState extends State<AdminSmsPage> {
  late DateTimeRange _range;
  late Future<Map<String, dynamic>> _future;
  int _page = 1;
  bool _sending = false;
  String? _cancelingId;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 30)),
      end: today,
    );
    _reload();
  }

  void _reload() {
    _future = widget.api.adminGet(
      '/admin/sms-reports',
      query: {
        'start_date': DateFormat('yyyy-MM-dd').format(_range.start),
        'end_date': DateFormat('yyyy-MM-dd').format(_range.end),
        'page': '$_page',
      },
    );
  }

  void _refresh() => setState(_reload);

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (range == null || !mounted) return;
    setState(() {
      _range = range;
      _page = 1;
      _reload();
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _SmsSendDialog(),
    );
    if (payload == null || !mounted) return;
    final target = payload['target'] == 'custom'
        ? '${(payload['custom_numbers'] as List).length} özel numara'
        : '${payload['target']} grubu';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS gönderimini onayla'),
        content: Text('$target için SMS gönderilecek. İşlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.api.adminPost('/admin/sms-send', payload);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('SMS gönderilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel(String id) async {
    if (_cancelingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS siparişini iptal et'),
        content: Text('#$id numaralı sipariş iptal edilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelingId = id);
    try {
      await widget.api.adminPost('/admin/sms-cancel/$id');
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sipariş iptal edilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelingId = null);
    }
  }

  void _open(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SmsDetailPage(api: widget.api, orderId: id),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final body = snapshot.data ?? {};
      final orders = (body['orders'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final count = int.tryParse('${body['count']}') ?? orders.length;
      return RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(title: 'SMS Yönetimi', subtitle: '$count sipariş'),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: const Text('SMS gönder'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                '${DateFormat('dd.MM.yyyy').format(_range.start)} – ${DateFormat('dd.MM.yyyy').format(_range.end)}',
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: _refresh,
                child: Text(
                  'SMS raporları alınamadı: ${snapshot.error} · Tekrar dene',
                ),
              )
            else if (orders.isEmpty)
              const EmptyState(
                icon: Icons.sms_outlined,
                title: 'SMS kaydı bulunamadı',
                description: 'Farklı bir tarih aralığı seçebilirsiniz.',
              )
            else
              for (final order in orders)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('Sipariş #${order['id']}'),
                        subtitle: Text(
                          '${order['sender'] ?? '—'} · ${order['status_text'] ?? '—'}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open('${order['id']}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Toplam ${order['total'] ?? 0} · Başarılı ${order['delivered'] ?? 0} · Başarısız ${order['undelivered'] ?? 0}',
                              ),
                            ),
                            if ('${order['status']}' == '113')
                              IconButton(
                                tooltip: 'SMS siparişini iptal et',
                                onPressed: _cancelingId == null
                                    ? () => _cancel('${order['id']}')
                                    : null,
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (count > 20)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$count sipariş · $_page. sayfa'),
                  IconButton(
                    onPressed: _page > 1
                        ? () => setState(() {
                            _page--;
                            _reload();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: orders.isNotEmpty
                        ? () => setState(() {
                            _page++;
                            _reload();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class _SmsDetailPage extends StatefulWidget {
  const _SmsDetailPage({required this.api, required this.orderId});
  final FinkitApi api;
  final String orderId;
  @override
  State<_SmsDetailPage> createState() => _SmsDetailPageState();
}

class _SmsDetailPageState extends State<_SmsDetailPage> {
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = widget.api.adminGet(
    '/admin/sms-reports/${widget.orderId}',
    query: {'page': '$_page'},
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Sipariş #${widget.orderId}')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final body = snapshot.data ?? {};
        final messages = (body['messages'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Durum: ${body['status_text'] ?? '—'}'),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text(
                  'Ayrıntı alınamadı: ${snapshot.error} · Tekrar dene',
                ),
              )
            else if (messages.isEmpty)
              const Text('Bu sayfada mesaj bulunamadı.')
            else
              for (final message in messages)
                Card(
                  child: ListTile(
                    title: Text('${message['number'] ?? ''}'),
                    subtitle: Text('${message['status_text'] ?? '—'}'),
                  ),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$_page. sayfa'),
                IconButton(
                  onPressed: _page > 1
                      ? () => setState(() {
                          _page--;
                          _reload();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: messages.isNotEmpty
                      ? () => setState(() {
                          _page++;
                          _reload();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _SmsSendDialog extends StatefulWidget {
  const _SmsSendDialog();
  @override
  State<_SmsSendDialog> createState() => _SmsSendDialogState();
}

class _SmsSendDialogState extends State<_SmsSendDialog> {
  final _message = TextEditingController();
  final _sender = TextEditingController();
  final _numbers = TextEditingController();
  String _target = 'all';
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    _sender.dispose();
    _numbers.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _message.text.trim();
    final numbers = _numbers.text
        .split(RegExp(r'[\n,;]+'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (message.isEmpty || (_target == 'custom' && numbers.isEmpty)) {
      setState(() => _error = 'Mesaj ve özel hedef için numara gereklidir.');
      return;
    }
    Navigator.pop(context, {
      'message': message,
      'sender': _sender.text.trim(),
      'target': _target,
      'custom_numbers': _target == 'custom' ? numbers : <String>[],
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('SMS duyurusu'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _target,
            decoration: const InputDecoration(labelText: 'Hedef'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tüm kullanıcılar')),
              DropdownMenuItem(value: 'clients', child: Text('Mükellefler')),
              DropdownMenuItem(value: 'advisors', child: Text('Müşavirler')),
              DropdownMenuItem(value: 'custom', child: Text('Özel numaralar')),
            ],
            onChanged: (v) => setState(() => _target = v ?? 'all'),
          ),
          TextField(
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mesaj'),
          ),
          TextField(
            controller: _sender,
            decoration: const InputDecoration(
              labelText: 'Gönderici (isteğe bağlı)',
            ),
          ),
          if (_target == 'custom')
            TextField(
              controller: _numbers,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Numaralar (satır veya virgülle ayır)',
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Devam')),
    ],
  );
}
