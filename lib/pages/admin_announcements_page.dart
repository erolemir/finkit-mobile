import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.api.adminGet('/admin/announcements');
  }

  Future<void> _edit([Map<String, dynamic>? announcement]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _AnnouncementForm(api: widget.api, existing: announcement),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _toggle(Map<String, dynamic> announcement) async {
    try {
      await widget.api.adminPut('/admin/announcements/${announcement['id']}', {
        'is_active': announcement['is_active'] != true,
      });
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(Map<String, dynamic> announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: Text('${announcement['title']} silinsin mi?'),
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
    try {
      await widget.api.adminDelete(
        '/admin/announcements/${announcement['id']}',
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle(
          title: 'Duyurular',
          subtitle: 'Kullanıcılara gönderilen duyurular',
        ),
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Yeni Duyuru'),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError)
              return const LoadingState();
            if (snapshot.hasError)
              return TextButton(
                onPressed: () => setState(_reload),
                child: Text('Duyurular alınamadı: ${snapshot.error}'),
              );
            final raw = snapshot.data?['items'];
            final rows = raw is List
                ? raw
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList()
                : <Map<String, dynamic>>[];
            if (rows.isEmpty)
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz duyuru yok.'),
              );
            return Column(
              children: [
                for (final row in rows)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('${row['title']}'),
                          subtitle: Text(
                            '${row['content']}\n${row['target_role'] ?? 'Herkes'} · ${row['is_active'] == true ? 'Aktif' : 'Pasif'}',
                          ),
                          isThreeLine: true,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _edit(row),
                              child: const Text('Düzenle'),
                            ),
                            TextButton(
                              onPressed: () => _toggle(row),
                              child: Text(
                                row['is_active'] == true
                                    ? 'Pasife Al'
                                    : 'Aktifleştir',
                              ),
                            ),
                            TextButton(
                              onPressed: () => _delete(row),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({required this.api, this.existing});
  final FinkitApi api;
  final Map<String, dynamic>? existing;

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  late final _title = TextEditingController(
    text: '${widget.existing?['title'] ?? ''}',
  );
  late final _content = TextEditingController(
    text: '${widget.existing?['content'] ?? ''}',
  );
  late final _expires = TextEditingController(
    text: '${widget.existing?['expires_at'] ?? ''}'.split('T').first,
  );
  late String _targetRole = '${widget.existing?['target_role'] ?? ''}';
  bool _sendSms = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _expires.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = 'Başlık ve içerik gerekli.');
      return;
    }
    final expires = _expires.text.trim();
    if (expires.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expires)) {
      setState(() => _error = 'Bitiş tarihi YYYY-AA-GG olmalı.');
      return;
    }
    if (_sendSms) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SMS Gönder'),
          content: const Text(
            'Duyuru kaydedildikten sonra seçilen kitleye toplu SMS gönderilecek. Onaylıyor musunuz?',
          ),
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
      if (approved != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'target_role': _targetRole.isEmpty ? null : _targetRole,
        'expires_at': expires.isEmpty ? null : expires,
      };
      if (widget.existing == null) {
        await widget.api.adminPost('/admin/announcements', {
          ...payload,
          'is_active': true,
        });
      } else {
        await widget.api.adminPut(
          '/admin/announcements/${widget.existing!['id']}',
          payload,
        );
      }
      if (_sendSms) {
        try {
          await widget.api.adminPost('/admin/sms-send', {
            'message': '${_title.text.trim()}\n\n${_content.text.trim()}',
            'target': _targetRole == 'CLIENT'
                ? 'clients'
                : _targetRole == 'ADVISOR'
                ? 'advisors'
                : 'all',
          });
        } catch (error) {
          if (mounted) {
            setState(
              () =>
                  _error = 'Duyuru kaydedildi fakat SMS gönderilemedi: $error',
            );
          }
          return;
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Yeni Duyuru' : 'Duyuruyu Düzenle'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Başlık'),
        ),
        TextField(
          controller: _content,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'İçerik'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _targetRole,
          decoration: const InputDecoration(labelText: 'Hedef kitle'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Herkes')),
            DropdownMenuItem(value: 'ADVISOR', child: Text('Müşavirler')),
            DropdownMenuItem(value: 'CLIENT', child: Text('Mükellefler')),
          ],
          onChanged: (value) => setState(() => _targetRole = value ?? ''),
        ),
        TextField(
          controller: _expires,
          decoration: const InputDecoration(
            labelText: 'Bitiş tarihi (YYYY-AA-GG, isteğe bağlı)',
          ),
        ),
        if (widget.existing == null)
          SwitchListTile(
            title: const Text('SMS de gönder'),
            value: _sendSms,
            onChanged: (value) => setState(() => _sendSms = value),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}
