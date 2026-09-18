import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
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
