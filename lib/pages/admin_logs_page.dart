import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminLogsPage extends StatefulWidget {
  const AdminLogsPage({super.key, required this.api});

  final FinkitApi api;

  @override
  State<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends State<AdminLogsPage> {
  final _search = TextEditingController();
  final _userId = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  late Future<Map<String, dynamic>> _logs;
  late Future<Map<String, dynamic>> _stats;
  int _page = 1;
  String _category = '';
  String _role = '';
  String _method = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _userId.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _reload() {
    _logs = widget.api.adminGet(
      '/admin/logs',
      query: {
        'page': '$_page',
        'page_size': '20',
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        if (_category.isNotEmpty) 'category': _category,
        if (_role.isNotEmpty) 'role': _role,
        if (_method.isNotEmpty) 'method': _method,
        if (_userId.text.trim().isNotEmpty) 'user_id': _userId.text.trim(),
        if (_from.text.trim().isNotEmpty) 'date_from': _from.text.trim(),
        if (_to.text.trim().isNotEmpty) 'date_to': _to.text.trim(),
      },
    );
    _stats = widget.api.adminGet('/admin/logs/stats');
  }

  void _filter() {
    final userId = _userId.text.trim();
    final from = _from.text.trim();
    final to = _to.text.trim();
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if ((userId.isNotEmpty && int.tryParse(userId) == null) ||
        (from.isNotEmpty && !datePattern.hasMatch(from)) ||
        (to.isNotEmpty && !datePattern.hasMatch(to)) ||
        (from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı ID veya tarih aralığı geçersiz.'),
        ),
      );
      return;
    }
    setState(() {
      _page = 1;
      _reload();
    });
  }

  void _preset(int days) {
    final today = DateTime.now();
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    _to.text = days == 0 ? '' : date(today);
    _from.text = days == 0
        ? ''
        : date(today.subtract(Duration(days: days - 1)));
    _filter();
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic>? data) =>
      (data?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  String _user(Map<String, dynamic> row) =>
      '${row['user_name'] ?? row['user_email'] ?? (row['user_id'] == null ? 'Ziyaretçi' : 'Kullanıcı #${row['user_id']}')}';

  String _action(Map<String, dynamic> row) => switch ('${row['action']}') {
    'LOGIN_SUCCESS' => 'Giriş başarılı',
    'LOGIN_FAILED' => 'Giriş başarısız',
    'PAGE_VIEW' => 'Sayfa görüntülendi',
    'CTA_CLICK' => 'CTA tıklandı',
    final action => action.replaceAll('_', ' '),
  };

  String _csvCell(Object? value) {
    final valueText = '${value ?? ''}';
    final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(valueText)
        ? "'$valueText"
        : valueText;
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> _export(List<Map<String, dynamic>> rows) async {
    if (_exporting || rows.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final csv = StringBuffer('\uFEFF');
      csv.writeln(
        'Tarih,Kullanıcı,E-posta,Rol,Kategori,Aksiyon,Hedef,IP,Durum',
      );
      for (final row in rows) {
        csv.writeln(
          [
            row['created_at'],
            _user(row),
            row['user_email'],
            row['user_role'],
            row['category'],
            _action(row),
            row['entity_type'] ?? row['path'],
            row['ip_address'],
            row['status_code'],
          ].map(_csvCell).join(','),
        );
      }
      final path = await FilePicker.saveFile(
        fileName:
            'loglar-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        bytes: Uint8List.fromList(utf8.encode(csv.toString())),
        mimeType: 'text/csv',
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('CSV kaydedildi.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('CSV kaydedilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _detail(Map<String, dynamic> row) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(_action(row), style: Theme.of(context).textTheme.titleLarge),
          for (final key in [
            'created_at',
            'user_name',
            'user_email',
            'user_id',
            'user_role',
            'category',
            'action',
            'method',
            'path',
            'entity_type',
            'entity_id',
            'ip_address',
            'status_code',
            'details',
          ])
            if (row[key] != null)
              ListTile(
                dense: true,
                title: Text(key),
                subtitle: SelectableText('${row[key]}'),
              ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _logs,
    builder: (context, snapshot) {
      final rows = _items(snapshot.data);
      final total = int.tryParse('${snapshot.data?['total']}') ?? rows.length;
      return RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageTitle(
              title: 'Log Takibi',
              subtitle: '$total olay',
              trailing: IconButton.filledTonal(
                tooltip: 'CSV indir',
                onPressed: rows.isEmpty || _exporting
                    ? null
                    : () => _export(rows),
                icon: const Icon(Icons.download_outlined),
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _stats,
              builder: (context, stats) {
                if (!stats.hasData) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final pair in [
                      ('Toplam olay', 'total'),
                      ('Bugün giriş', 'logins_today'),
                      ('Hatalı giriş', 'failed_logins_today'),
                      ('Aktif kullanıcı', 'active_users_today'),
                      ('Sayfa', 'page_views_today'),
                      ('CTA', 'cta_clicks_today'),
                    ])
                      Chip(
                        label: Text('${pair.$1}: ${stats.data?[pair.$2] ?? 0}'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final pair in [
                    ('Tümü', ''),
                    ('Girişler', 'AUTH'),
                    ('Sayfalar', 'PAGE_VIEW'),
                    ('CTA', 'CTA'),
                    ('İşlemler', 'ACTION'),
                    ('Yönetim', 'ADMIN'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(pair.$1),
                        selected: _category == pair.$2,
                        onSelected: (_) => setState(() {
                          _category = pair.$2;
                          _page = 1;
                          _reload();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Kullanıcı, e-posta, aksiyon veya yol ara',
                suffixIcon: IconButton(
                  tooltip: 'Ara',
                  onPressed: _filter,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _filter(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tüm roller')),
                DropdownMenuItem(value: 'ADVISOR', child: Text('Müşavir')),
                DropdownMenuItem(value: 'CLIENT', child: Text('Mükellef')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Yönetici')),
              ],
              onChanged: (value) => setState(() {
                _role = value ?? '';
                _page = 1;
                _reload();
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'İstek yöntemi'),
              items: [
                DropdownMenuItem(value: '', child: Text('Tüm yöntemler')),
                for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'])
                  DropdownMenuItem(value: method, child: Text(method)),
              ],
              onChanged: (value) => setState(() {
                _method = value ?? '';
                _page = 1;
                _reload();
              }),
            ),
            TextField(
              controller: _userId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kullanıcı ID'),
              onSubmitted: (_) => _filter(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _from,
                    decoration: const InputDecoration(
                      labelText: 'Başlangıç YYYY-AA-GG',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _to,
                    decoration: const InputDecoration(
                      labelText: 'Bitiş YYYY-AA-GG',
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => _preset(1),
                  child: const Text('Bugün'),
                ),
                TextButton(
                  onPressed: () => _preset(7),
                  child: const Text('7 gün'),
                ),
                TextButton(
                  onPressed: () => _preset(30),
                  child: const Text('30 gün'),
                ),
                TextButton(
                  onPressed: () => _preset(0),
                  child: const Text('Tümü'),
                ),
                TextButton(onPressed: _filter, child: const Text('Filtrele')),
              ],
            ),
            if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text('Loglar alınamadı: ${snapshot.error}'),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'Olay yok',
                description: 'Seçili filtrelerde kayıt bulunamadı.',
              )
            else
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(_action(row)),
                    subtitle: Text(
                      '${_user(row)} · ${row['category'] ?? '—'} · ${dateText(row['created_at'])}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _detail(row),
                  ),
                ),
            if (total > 20 || _page > 1)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki sayfa',
                    onPressed: _page <= 1
                        ? null
                        : () => setState(() {
                            _page--;
                            _reload();
                          }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$_page · $total olay',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki sayfa',
                    onPressed: _page * 20 >= total
                        ? null
                        : () => setState(() {
                            _page++;
                            _reload();
                          }),
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
