import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

const _statuses = <String, String>{
  '': 'Tümü',
  'open': 'Açık',
  'in_progress': 'İşlemde',
  'resolved': 'Çözüldü',
  'closed': 'Kapatıldı',
};

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.adminGet(
      '/admin/support/tickets',
      query: {
        'page': '$_page',
        'page_size': '20',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_status.isNotEmpty) 'status': _status,
      },
    );
  }

  void _refresh() => setState(_reload);

  Future<void> _open(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}');
    if (id == null) return;
    try {
      final detail = await widget.api.adminGet('/admin/support/tickets/$id');
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _SupportDetail(api: widget.api, ticket: detail),
        ),
      );
      if (changed == true && mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Talep açılamadı: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final body = snapshot.data;
      final rows = (body?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final total = int.tryParse('${body?['total']}') ?? rows.length;
      return RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(title: 'Destek Talepleri', subtitle: '$total kayıt'),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Ad veya iletişim bilgisi ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) {
                _page = 1;
                _refresh();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: [
                for (final entry in _statuses.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                _status = value ?? '';
                _page = 1;
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: _refresh,
                child: Text(
                  'Talepler alınamadı: ${snapshot.error} · Tekrar dene',
                ),
              )
            else if (rows.isEmpty)
              const EmptyState(
                icon: Icons.support_agent_rounded,
                title: 'Talep bulunamadı',
                description: 'Arama veya durum filtresini değiştirebilirsiniz.',
              )
            else
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['subject'] ?? 'Destek talebi'}'),
                    subtitle: Text(
                      '${row['name'] ?? ''} · ${_statuses['${row['status']}'] ?? row['status'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(row),
                  ),
                ),
            if (total > 20)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$total kayıt · $_page. sayfa'),
                  IconButton(
                    tooltip: 'Önceki sayfa',
                    onPressed: _page > 1
                        ? () {
                            _page--;
                            _refresh();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Sonraki sayfa',
                    onPressed: _page * 20 < total
                        ? () {
                            _page++;
                            _refresh();
                          }
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

class _SupportDetail extends StatefulWidget {
  const _SupportDetail({required this.api, required this.ticket});
  final FinkitApi api;
  final Map<String, dynamic> ticket;

  @override
  State<_SupportDetail> createState() => _SupportDetailState();
}

class _SupportDetailState extends State<_SupportDetail> {
  late String _status = '${widget.ticket['status'] ?? 'open'}';
  late final _notes = TextEditingController(
    text: '${widget.ticket['admin_notes'] ?? ''}',
  );
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.adminPatch(
        '/admin/support/tickets/${widget.ticket['id']}',
        {'status': _status, 'admin_notes': _notes.text.trim()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Talep güncellenemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi sil'),
        content: const Text('Bu destek talebi kalıcı olarak silinecek.'),
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
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.adminDelete(
        '/admin/support/tickets/${widget.ticket['id']}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Talep silinemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Destek Talebi')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${widget.ticket['subject'] ?? ''}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '${widget.ticket['name'] ?? ''} · ${widget.ticket['contact'] ?? ''}',
        ),
        const SizedBox(height: 16),
        SelectableText('${widget.ticket['message'] ?? ''}'),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Durum'),
          items: [
            for (final entry in _statuses.entries)
              if (entry.key.isNotEmpty)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _status = value ?? _status),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Yönetici notu'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Kaydet'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Talebi sil'),
        ),
      ],
    ),
  );
}
