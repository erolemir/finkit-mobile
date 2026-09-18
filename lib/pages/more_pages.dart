import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';

String _t(dynamic value, [String fallback = '—']) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

/// Mükelleflere toplu mesaj (e-posta / WhatsApp) gönderir.
class BulkMessagePage extends StatefulWidget {
  const BulkMessagePage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<BulkMessagePage> createState() => _BulkMessagePageState();
}

class _BulkMessagePageState extends State<BulkMessagePage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final Set<int> _selected = {};
  List<Map<String, dynamic>> _clients = const [];
  String _channel = 'EMAIL';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final clients = await widget.api.clients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _selected
          ..clear()
          ..addAll(
            clients
                .map((c) => int.tryParse('${c['user_id']}'))
                .whereType<int>(),
          );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await widget.api.sendBulkMessage(
        clientIds: _selected.toList(),
        channel: _channel,
        message: _message.text.trim(),
        subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _message.clear();
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${result['sent_count'] ?? _selected.length} mükellefe gönderildi',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Mail Gönder')),
      body: _loading
          ? const LoadingState()
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const PageTitle(
                  title: 'Toplu Mesaj',
                  subtitle:
                      'Seçtiğiniz mükelleflere e-posta veya WhatsApp gönderin.',
                ),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'EMAIL',
                            label: Text('E-posta'),
                            icon: Icon(Icons.mail_outline_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: 'WHATSAPP',
                            label: Text('WhatsApp'),
                            icon: Icon(Icons.chat_outlined, size: 18),
                          ),
                        ],
                        selected: {_channel},
                        onSelectionChanged: (value) =>
                            setState(() => _channel = value.first),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _subject,
                        decoration: const InputDecoration(
                          labelText: 'Konu',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _message,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Mesaj',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Alıcılar (${_selected.length}/${_clients.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              if (_selected.length == _clients.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(
                                    _clients
                                        .map(
                                          (c) =>
                                              int.tryParse('${c['user_id']}'),
                                        )
                                        .whereType<int>(),
                                  );
                              }
                            }),
                            child: Text(
                              _selected.length == _clients.length
                                  ? 'Temizle'
                                  : 'Tümünü seç',
                            ),
                          ),
                        ],
                      ),
                      for (final client in _clients)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _selected.contains(
                            int.tryParse('${client['user_id']}'),
                          ),
                          title: Text(
                            _t(client['company_title'], 'Mükellef'),
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          subtitle: Text(
                            _t(client['user']?['full_name'], ''),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onChanged: (checked) {
                            final id = int.tryParse('${client['user_id']}');
                            if (id == null) return;
                            setState(() {
                              if (checked == true) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_sending ? 'Gönderiliyor…' : 'Mesajı Gönder'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Müşavir için mükellef giriş bilgileri kasası.
class CredentialsPage extends StatefulWidget {
  const CredentialsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<CredentialsPage> createState() => _CredentialsPageState();
}

class _CredentialsPageState extends State<CredentialsPage> {
  int? _clientId;
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _credentials = const [];
  bool _loading = true;
  final Map<String, String> _revealed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final clients = await widget.api.clients();
      final first = clients.isNotEmpty
          ? int.tryParse('${clients.first['user_id']}')
          : null;
      List<Map<String, dynamic>> credentials = const [];
      if (first != null) {
        credentials = await widget.api.clientCredentials(first);
      }
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _clientId = first;
        _credentials = credentials;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCredentials(int clientId) async {
    setState(() {
      _clientId = clientId;
      _loading = true;
      _revealed.clear();
    });
    try {
      final credentials = await widget.api.clientCredentials(clientId);
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reveal(Map<String, dynamic> item) async {
    final clientId = _clientId;
    final serviceKey = item['service_key']?.toString();
    if (clientId == null || serviceKey == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await widget.api.revealClientCredential(
        clientId,
        serviceKey,
      );
      final secret =
          result['password']?.toString() ??
          result['secret']?.toString() ??
          result['value']?.toString();
      if (secret == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Kayıtlı şifre bulunamadı')),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: secret));
      if (!mounted) return;
      setState(() => _revealed[serviceKey] = secret);
      messenger.showSnackBar(const SnackBar(content: Text('Şifre kopyalandı')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Giriş Bilgileri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const PageTitle(
            title: 'Giriş Bilgileri',
            subtitle: 'Mükelleflerin kurum şifreleri; dokunarak kopyalayın.',
          ),
          if (_clients.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _clientId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mükellef',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              items: _clients
                  .map(
                    (client) => DropdownMenuItem<int>(
                      value: int.tryParse('${client['user_id']}'),
                      child: Text(
                        _t(client['company_title'], 'Mükellef'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _loadCredentials(value);
              },
            ),
          const SizedBox(height: 14),
          if (_loading)
            const LoadingState()
          else if (_credentials.isEmpty)
            const EmptyState(
              icon: Icons.key_outlined,
              title: 'Kayıtlı bilgi yok',
              description: 'Bu mükellef için giriş bilgisi kaydedilmemiş. Web panelinden ekleyebilirsiniz.',
            )
          else
            ..._credentials.map((item) {
              final serviceKey = item['service_key']?.toString() ?? '';
              final secret = _revealed[serviceKey];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t(
                                item['service_name'] ?? item['label'],
                                serviceKey,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _reveal(item),
                            icon: const Icon(Icons.key_rounded, size: 16),
                            label: Text(secret == null ? 'Göster' : 'Kopyala'),
                          ),
                        ],
                      ),
                      Text(
                        'Kullanıcı: ${_t(item['username'], '—')}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: FinkitColors.muted,
                        ),
                      ),
                      if (secret != null)
                        Text(
                          'Şifre: $secret',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Harici (sisteme kayıtlı olmayan) mükellefler.
class ExternalClientsPage extends StatelessWidget {
  const ExternalClientsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Harici Mükellefler')),
      body: ApiListPage(
        title: 'Harici Mükellefler',
        subtitle: 'Portala girmeyen, yalnız takip edilen mükellefler.',
        refreshKey: refreshKey,
        loader: api.externalClients,
        searchHint: 'Ünvan ara',
        searchText: (item) => '${item['company_title']} ${item['full_name']}',
        emptyIcon: Icons.folder_shared_outlined,
        emptyTitle: 'Kayıt yok',
        emptyDescription: 'Harici mükellef eklenmemiş.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.folder_shared_outlined,
          title: _t(item['company_title'], 'Harici mükellef'),
          subtitle:
              '${_t(item['full_name'], '')} · ${_t(item['phone_number'], '')}',
          value: moneyText(item['monthly_fee']),
          valueSubtitle: 'Aylık ücret',
          status: item['payment_status']?.toString(),
        ),
      ),
    );
  }
}

/// Müşavir e-belgeleri (irsaliyeler).
class DespatchListPage extends StatelessWidget {
  const DespatchListPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('E-Belgeler')),
      body: ApiListPage(
        title: 'E-Belgeler',
        subtitle: 'Gönderilen ve gelen e-irsaliyeler.',
        refreshKey: refreshKey,
        loader: api.einvoiceDespatches,
        emptyIcon: Icons.local_shipping_outlined,
        emptyTitle: 'İrsaliye yok',
        emptyDescription: 'Kayıtlı e-irsaliye bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.local_shipping_outlined,
          title: _t(
            item['despatch_number'] ?? item['number'] ?? item['uuid'],
            'İrsaliye',
          ),
          subtitle:
              '${_t(item['receiver_name'] ?? item['customer_name'] ?? item['status'], '')} · ${dateText(item['issue_date'] ?? item['created_at'])}',
          value: dateText(item['issue_date'] ?? item['created_at']),
          valueSubtitle: 'Tarih',
          status: item['status']?.toString(),
        ),
      ),
    );
  }
}

/// Yerel not defteri (cihazda saklanır).
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  static const _key = 'finkit_notes';
  List<Map<String, dynamic>> _notes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<Map<String, dynamic>> notes = const [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          notes = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {
        // Bozuk kayıt varsa notlar boş kabul edilir.
      }
    }
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_notes));
  }

  Future<void> _add() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni Not',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Not',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (title.text.trim().isEmpty && body.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        _notes = [
          {
            'title': title.text.trim().isEmpty ? 'Not' : title.text.trim(),
            'body': body.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          },
          ..._notes,
        ];
      });
      await _save();
    }
    title.dispose();
    body.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Not Defteri')),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              children: [
                PageTitle(
                  title: 'Not Defteri',
                  subtitle: '${_notes.length} not · cihazınızda saklanır.',
                  trailing: IconButton.filled(
                    onPressed: _add,
                    style: IconButton.styleFrom(
                      backgroundColor: FinkitColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                if (_notes.isEmpty)
                  const EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Not yok',
                    description: 'Sağ üstteki + ile ilk notunuzu ekleyin.',
                  )
                else
                  ..._notes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DataRowCard(
                        icon: Icons.sticky_note_2_outlined,
                        title: _t(note['title'], 'Not'),
                        subtitle: _t(note['body'], ''),
                        value: dateText(note['created_at']),
                        valueSubtitle: 'Tarih',
                        onTap: () async {
                          setState(
                            () => _notes = _notes
                                .where((n) => n != note)
                                .toList(),
                          );
                          await _save();
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Basit finansal hesaplama araçları (KDV, stopaj, net maaş).
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _amount = TextEditingController();
  double _rate = 20;
  String _mode = 'haric'; // haric | dahil
  String _tool = 'kdv'; // kdv | stopaj | maas

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;

  double get _net => _mode == 'haric' ? _value : _value / (1 + _rate / 100);

  double get _vat => _net * _rate / 100;

  double get _withholding => _net * _rate / 100;

  double get _employerCost => _net * 1.2275;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Hesaplama Yap')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const PageTitle(
            title: 'Hesaplama Yap',
            subtitle: 'KDV, stopaj ve işveren maliyeti hesapları.',
          ),
          SurfaceCard(
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kdv', label: Text('KDV')),
                    ButtonSegment(value: 'stopaj', label: Text('Stopaj')),
                    ButtonSegment(value: 'maas', label: Text('Maaş')),
                  ],
                  selected: {_tool},
                  onSelectionChanged: (value) =>
                      setState(() => _tool = value.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Tutar (₺)',
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: _rate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Oran (%)',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  items: const [1.0, 8.0, 10.0, 15.0, 18.0, 20.0, 25.0]
                      .map(
                        (rate) => DropdownMenuItem<double>(
                          value: rate,
                          child: Text('%${rate.toStringAsFixed(0)}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _rate = value ?? _rate),
                ),
                if (_tool == 'kdv') ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'haric', label: Text('KDV hariç')),
                      ButtonSegment(value: 'dahil', label: Text('KDV dahil')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) =>
                        setState(() => _mode = value.first),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FinkitColors.ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: _tool == 'kdv'
                  ? [
                      _CalcRow('Matrah', moneyText(_net)),
                      _CalcRow(
                        'KDV (%${_rate.toStringAsFixed(0)})',
                        moneyText(_vat),
                      ),
                      _CalcRow(
                        'Genel Toplam',
                        moneyText(_net + _vat),
                        emphasize: true,
                      ),
                    ]
                  : _tool == 'stopaj'
                  ? [
                      _CalcRow('Brüt', moneyText(_value)),
                      _CalcRow(
                        'Stopaj (%${_rate.toStringAsFixed(0)})',
                        moneyText(_withholding),
                      ),
                      _CalcRow(
                        'Net',
                        moneyText(_value - _withholding),
                        emphasize: true,
                      ),
                    ]
                  : [
                      _CalcRow('Net / Brüt', moneyText(_value)),
                      _CalcRow(
                        'Tahmini işveren maliyeti',
                        moneyText(_employerCost),
                        emphasize: true,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'SGK işveren payı ve işsizlik sigortası yaklaşık %22,75 varsayılır.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasize ? Colors.white : Colors.white70,
      fontSize: emphasize ? 18 : 13.5,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// Forum konusu: mesajları listeler, yanıt yazmaya izin verir.
class ForumTopicPage extends StatefulWidget {
  const ForumTopicPage({
    super.key,
    required this.api,
    required this.topicId,
    required this.title,
  });

  final FinkitApi api;
  final int topicId;
  final String title;

  @override
  State<ForumTopicPage> createState() => _ForumTopicPageState();
}

class _ForumTopicPageState extends State<ForumTopicPage> {
  final _reply = TextEditingController();
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = await widget.api.forumPosts(widget.topicId);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.createForumPost(topicId: widget.topicId, content: text);
      _reply.clear();
      await _load();
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(content: Text('Yanıt eklendi')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      if (_posts.isEmpty)
                        const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Yanıt yok',
                          description: 'İlk yanıtı siz yazın.',
                        )
                      else
                        ..._posts.map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t(
                                      post['author_name'] ?? post['author'],
                                      'Kullanıcı',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t(post['content'], ''),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateText(post['created_at']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: FinkitColors.mutedLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Yanıtınızı yazın…',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: FinkitColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Danışma sorusu: yanıtları gösterir, müşavir yanıt yazabilir.
class DanismaQuestionPage extends StatefulWidget {
  const DanismaQuestionPage({
    super.key,
    required this.api,
    required this.question,
    required this.isClient,
  });

  final FinkitApi api;
  final Map<String, dynamic> question;
  final bool isClient;

  @override
  State<DanismaQuestionPage> createState() => _DanismaQuestionPageState();
}

class _DanismaQuestionPageState extends State<DanismaQuestionPage> {
  final _answer = TextEditingController();
  final _price = TextEditingController(text: '250');
  List<Map<String, dynamic>> _answers = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answer.dispose();
    _price.dispose();
    super.dispose();
  }

  int? get _questionId => int.tryParse('${widget.question['id']}');

  Future<void> _load() async {
    final id = _questionId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final answers = await widget.api.danismaAnswers(id);
      if (!mounted) return;
      setState(() {
        _answers = answers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final id = _questionId;
    final text = _answer.text.trim();
    if (id == null || text.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.createDanismaAnswer(
        questionId: id,
        content: text,
        price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      );
      _answer.clear();
      await _load();
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(content: Text('Yanıt gönderildi')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Danışma Sorusu')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(question['title'] ?? question['question'], 'Soru'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(question['content'] ?? question['description'], ''),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_t(question['client_name'], '')} · ${dateText(question['created_at'])}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: FinkitColors.mutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(title: 'Yanıtlar'),
                if (_loading)
                  const LoadingState()
                else if (_answers.isEmpty)
                  const EmptyState(
                    icon: Icons.question_answer_outlined,
                    title: 'Yanıt yok',
                    description: 'Bu soruya henüz yanıt verilmemiş.',
                  )
                else
                  ..._answers.map(
                    (answer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(answer['advisor_name'], 'Müşavir'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t(answer['content'], ''),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ücret: ${moneyText(answer['price'])}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: FinkitColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isClient)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _answer,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Yanıtınızı yazın…',
                              prefixIcon: Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Ücret',
                              prefixIcon: Icon(Icons.currency_lira_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          style: IconButton.styleFrom(
                            backgroundColor: FinkitColors.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PayTR ödeme formunu uygulama içinde açar (kart bilgisi backend'e gitmez).
Future<void> startInAppPayment(
  BuildContext context,
  FinkitApi api, {
  int? extraChargeId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // Kart bilgileri yalnızca cihazda alınır ve doğrudan PayTR'ye gönderilir.
    final entry = await showCardEntrySheet(context, amount: 0);
    if (entry == null || !context.mounted) return;

    final prepared = await api.preparePayment(
      paymentPurpose: extraChargeId == null ? 'monthly_fee' : 'extra_charge',
      extraChargeId: extraChargeId,
      storeCard: entry.storeCard,
    );
    final postUrl = prepared['post_url']?.toString();
    final fields = prepared['fields'];
    if (postUrl == null || postUrl.isEmpty || fields is! Map) {
      throw Exception(prepared['message']?.toString() ?? 'Ödeme başlatılamadı');
    }
    if (!context.mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PaymentCheckoutPage(
          title: 'Ödeme',
          postUrl: postUrl,
          fields: {...Map<String, dynamic>.from(fields), ...entry.cardFields},
          returnUrl: '/paytr/3d-result',
        ),
      ),
    );
    if (result == 'paid') {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ödemeniz alındı, teşekkürler!')),
      );
    }
  } catch (error) {
    // Ödeme başlatılamazsa kullanıcı web paneline yönlendirilir.
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    if (context.mounted) await openWebPanel(context, api);
  }
}

/// Kart bilgisi giriş formu. Veriler cihazda kalır, sunucuya gönderilmez.
Future<CardEntryResult?> showCardEntrySheet(
  BuildContext context, {
  required double amount,
}) {
  final owner = TextEditingController();
  final number = TextEditingController();
  final month = TextEditingController();
  final year = TextEditingController();
  final cvv = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var storeCard = false;

  return showModalBottomSheet<CardEntryResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kart Bilgileri',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  amount > 0
                      ? 'Ödenecek tutar: ${moneyText(amount)}'
                      : 'Kart bilgileriniz yalnızca PayTR ile paylaşılır.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: owner,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kart Üzerindeki İsim',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value ?? '').trim().length < 3
                      ? 'Kart sahibinin adını girin'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kart Numarası',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 15
                        ? 'Geçerli kart numarası girin'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: month,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ay (AA)'),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          return parsed == null || parsed < 1 || parsed > 12
                              ? 'AA'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Yıl (YYYY)',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          return parsed == null || parsed < 2024
                              ? 'YYYY'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: cvv,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'CVV'),
                        validator: (value) {
                          final digits = (value ?? '').trim();
                          return digits.length < 3 ? 'CVV' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: storeCard,
                  onChanged: (value) =>
                      setSheetState(() => storeCard = value ?? false),
                  title: const Text(
                    'Kartımı kaydet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Sonraki ödemelerde kart bilgisi girmeden ödeyebilirsiniz.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(
                        sheetContext,
                        CardEntryResult(
                          cardFields: {
                            'cc_owner': owner.text.trim(),
                            'card_number': number.text.replaceAll(
                              RegExp(r'\D'),
                              '',
                            ),
                            'expiry_month': month.text.trim().padLeft(2, '0'),
                            'expiry_year': year.text.trim(),
                            'cvv': cvv.text.trim(),
                          },
                          storeCard: storeCard,
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('Güvenli Ödemeye Devam Et'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    owner.dispose();
    number.dispose();
    month.dispose();
    year.dispose();
    cvv.dispose();
  });
}

/// Kart formu çıktısı: kart alanları ve kartı kaydet tercihi.
class CardEntryResult {
  const CardEntryResult({required this.cardFields, required this.storeCard});

  final Map<String, String> cardFields;
  final bool storeCard;
}

/// Kayıtlı (tokenize) kartlar — PayTR kart saklama listesi.
class StoredCardsPage extends StatefulWidget {
  const StoredCardsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<StoredCardsPage> createState() => _StoredCardsPageState();
}

class _StoredCardsPageState extends State<StoredCardsPage> {
  List<Map<String, dynamic>> _cards = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cards = await widget.api.storedCards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> card) async {
    final ctoken = card['ctoken']?.toString();
    if (ctoken == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.deleteStoredCard(ctoken);
      messenger.showSnackBar(const SnackBar(content: Text('Kart silindi')));
      await _load();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Kartlarım')),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const PageTitle(
                  title: 'Kartlarım',
                  subtitle: 'Ödeme sırasında "Kartımı kaydet" derseniz kartınız burada listelenir.',
                ),
                if (_error != null)
                  _InlineError(message: _error!, onRetry: _load)
                else if (_cards.isEmpty)
                  const EmptyState(
                    icon: Icons.credit_card_outlined,
                    title: 'Kayıtlı kart yok',
                    description: 'Ödeme yaparken kartı kaydetmeyi seçtiğinizde burada görünür.',
                  )
                else
                  ..._cards.map((card) {
                    final masked =
                        card['masked_number']?.toString() ??
                        card['card_number']?.toString() ??
                        (card['last_4'] != null
                            ? '**** **** **** ${card['last_4']}'
                            : 'Kayıtlı kart');
                    final bank =
                        card['card_bank']?.toString() ??
                        card['bank_name']?.toString() ??
                        card['card_type']?.toString() ??
                        '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DataRowCard(
                        icon: Icons.credit_card_rounded,
                        title: masked,
                        subtitle: bank,
                        value: 'Sil',
                        valueSubtitle: '',
                        onTap: () => _delete(card),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

/// Uygulama ayarları: bildirim tercihi, sunucu bilgisi ve oturum işlemleri.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.api, required this.onLogout});

  final FinkitApi api;
  final VoidCallback onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = AppNotifications.instance.enabled;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.api.systemStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Sistem durumu alınamazsa ayarlar yine gösterilir.
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = widget.api.baseUrl
        .replaceAll(RegExp(r'/api$'), '')
        .replaceFirst(RegExp(r'^https?://'), '');
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const PageTitle(
            title: 'Ayarlar',
            subtitle: 'Bildirimler, sunucu bilgisi ve oturum.',
          ),
          SurfaceCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notifications,
                    onChanged: (value) async {
                      await AppNotifications.instance.setEnabled(value);
                      if (mounted) setState(() => _notifications = value);
                    },
                    title: const Text(
                      'Bildirimler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Tahsilat, fatura ve hatırlatıcı bildirimleri',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  const Divider(height: 1, color: FinkitColors.line),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text(
                      'Sunucu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      serverUrl,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  const Divider(height: 1, color: FinkitColors.line),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: const Text(
                      'Sistem Durumu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _status == null
                          ? 'Kontrol ediliyor…'
                          : (_status!['maintenance_mode'] == true
                                ? 'Bakım modunda'
                                : 'Çalışıyor'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public_rounded),
                    title: const Text(
                      'Web panelini aç',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Ödeme ve web’e özel işlemler için tarayıcıda açılır',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => openWebPanel(context, widget.api),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text(
                      'Finkit Mobil',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Sürüm 1.3.0 · Android',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Çıkış Yap'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: FinkitColors.muted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FinkitColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

/// Ödeme alternatifi: web panelini tarayıcıda açar.
Future<void> openWebPanel(BuildContext context, FinkitApi api) async {
  final uri = Uri.parse(api.baseUrl.replaceAll(RegExp(r'/api$'), ''));
  final messenger = ScaffoldMessenger.of(context);
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Tarayıcı açılamadı: $uri')),
      );
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class PaymentCheckoutPage extends StatefulWidget {
  const PaymentCheckoutPage({
    super.key,
    required this.title,
    required this.postUrl,
    required this.fields,
    required this.returnUrl,
  });

  final String title;
  final String postUrl;
  final Map<String, dynamic> fields;
  final String returnUrl;

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  late final WebViewController _controller;
  bool _finished = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // PayTR tamamlandığında kendi sonuç sayfamıza döner.
            if (request.url.contains('/paytr/3d-result') ||
                request.url.contains('/paytr/callback') ||
                request.url.contains(widget.returnUrl)) {
              _onReturn(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_checkoutHtml());
  }

  void _onReturn(String url) {
    if (_finished) return;
    final lower = url.toLowerCase();
    final failed =
        lower.contains('fail') ||
        lower.contains('error') ||
        lower.contains('hata');
    setState(() {
      _finished = true;
      _success = !failed;
    });
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// PayTR'ye doğrudan gönderilen gizli form (kart alanları PayTR'de eklenir).
  String _checkoutHtml() {
    final inputs = widget.fields.entries
        .map(
          (entry) =>
              '<input type="hidden" name="${_escape(entry.key)}" '
              'value="${_escape('${entry.value}')}">',
        )
        .join();
    return '''
<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#F6F7F9;margin:0;padding:40px 20px;text-align:center;color:#17202B}</style>
</head><body>
<h2 style="font-size:17px">Ödeme sayfasına yönlendiriliyorsunuz</h2>
<p style="color:#687181;font-size:13px">Kart bilgileriniz doğrudan PayTR'ye iletilir.</p>
<form id="paytr" action="${_escape(widget.postUrl)}" method="post">$inputs</form>
<script>document.getElementById('paytr').submit();</script>
</body></html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(widget.title)),
      body: _finished
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _success
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 56,
                      color: _success
                          ? FinkitColors.success
                          : FinkitColors.danger,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _success ? 'Ödeme alındı' : 'Ödeme tamamlanamadı',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _success
                          ? 'Ödemeniz kaydedildi; makbuz bildirimi gönderilecek.'
                          : 'Kart bilgilerini kontrol edip tekrar deneyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FinkitColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _success ? 'paid' : 'failed',
                        ),
                        child: const Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
