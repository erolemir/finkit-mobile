import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminSystemUpdatesPage extends StatefulWidget {
  const AdminSystemUpdatesPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminSystemUpdatesPage> createState() => _AdminSystemUpdatesPageState();
}

class _AdminSystemUpdatesPageState extends State<AdminSystemUpdatesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.api.adminGet('/admin/system-updates');
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SystemUpdateForm(api: widget.api, existing: existing),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sistem Güncellemesini Sil'),
        content: Text('${item['revision_number']} kaydı silinsin mi?'),
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
      await widget.api.adminDelete('/admin/system-updates/${item['id']}');
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _sendEmail(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Güncelleme Maili Gönder'),
        content: Text(
          '${item['revision_number']} güncellemesi seçilen kullanıcı grubuna e-posta olarak gönderilsin mi?',
        ),
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
    try {
      await widget.api.adminPost(
        '/admin/system-updates/${item['id']}/send-email',
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
          title: 'Sistem Güncellemeleri',
          subtitle: 'Revizyon ve sağlık bilgileri',
        ),
      FilledButton.icon(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Güncelleme'),
      ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError)
              return const LoadingState();
            if (snapshot.hasError)
              return TextButton(
                onPressed: () => setState(_reload),
                child: Text('Güncellemeler alınamadı: ${snapshot.error}'),
              );
            final raw = snapshot.data?['items'];
            final items = raw is List
                ? raw
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList()
                : <Map<String, dynamic>>[];
            if (items.isEmpty)
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz güncelleme yok.'),
              );
            return Column(
              children: [
                for (final item in items)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${item['revision_number']} · ${item['software_name']}',
                          ),
                          subtitle: Text(
                            '${item['revision_date']} · ${item['is_published'] == true ? 'Yayında' : 'Taslak'} · ${item['health_status']}\n${item['summary']}',
                          ),
                          isThreeLine: true,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _edit(item),
                              child: const Text('Düzenle'),
                            ),
                            TextButton(
                              onPressed: () => _sendEmail(item),
                              child: const Text('Mail Gönder'),
                            ),
                            TextButton(
                              onPressed: () => _delete(item),
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

class _SystemUpdateForm extends StatefulWidget {
  const _SystemUpdateForm({required this.api, this.existing});
  final FinkitApi api;
  final Map<String, dynamic>? existing;

  @override
  State<_SystemUpdateForm> createState() => _SystemUpdateFormState();
}

class _SystemUpdateFormState extends State<_SystemUpdateForm> {
  late final _software = TextEditingController(
    text: '${widget.existing?['software_name'] ?? 'Finkit'}',
  );
  late final _revision = TextEditingController(
    text: '${widget.existing?['revision_number'] ?? ''}',
  );
  late final _date = TextEditingController(
    text: '${widget.existing?['revision_date'] ?? _today()}',
  );
  late final _summary = TextEditingController(
    text: '${widget.existing?['summary'] ?? ''}',
  );
  late final _hardware = TextEditingController(
    text: '${widget.existing?['hardware'] ?? ''}',
  );
  late String _health = '${widget.existing?['health_status'] ?? 'OK'}';
  late String _target = '${widget.existing?['target_role'] ?? ''}';
  late bool _published = widget.existing?['is_published'] != false;
  late bool _maintenance = widget.existing?['maintenance_done'] != false;
  late bool _antivirus = widget.existing?['antivirus'] != false;
  late bool _config = widget.existing?['min_config_ok'] != false;
  late bool _version = widget.existing?['version_current'] != false;
  bool _sendEmail = false;
  bool _busy = false;
  String? _error;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final field in [_software, _revision, _date, _summary, _hardware]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_revision.text.trim().isEmpty ||
        _summary.text.trim().isEmpty ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_date.text.trim())) {
      setState(() => _error = 'Revizyon, özet ve YYYY-AA-GG tarihi gerekli.');
      return;
    }
    if (_sendEmail) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Güncelleme Maili'),
          content: const Text(
            'Kayıt oluşturulduktan sonra hedef kitleye e-posta gönderilsin mi?',
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
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'software_name': _software.text.trim().isEmpty
            ? 'Finkit'
            : _software.text.trim(),
        'revision_number': _revision.text.trim(),
        'revision_date': _date.text.trim(),
        'summary': _summary.text.trim(),
        'health_status': _health,
        'hardware': _hardware.text.trim().isEmpty
            ? null
            : _hardware.text.trim(),
        'maintenance_done': _maintenance,
        'antivirus': _antivirus,
        'min_config_ok': _config,
        'version_current': _version,
        'target_role': _target.isEmpty ? null : _target,
        'is_published': _published,
      };
      if (widget.existing == null) {
        await widget.api.adminPost('/admin/system-updates', {
          ...body,
          'send_email': _sendEmail,
        });
      } else {
        await widget.api.adminPut(
          '/admin/system-updates/${widget.existing!['id']}',
          body,
        );
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
      title: Text(
        widget.existing == null ? 'Yeni Güncelleme' : 'Güncellemeyi Düzenle',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _software,
          decoration: const InputDecoration(labelText: 'Yazılım'),
        ),
        TextField(
          controller: _revision,
          decoration: const InputDecoration(labelText: 'Revizyon no'),
        ),
        TextField(
          controller: _date,
          decoration: const InputDecoration(
            labelText: 'Revizyon tarihi YYYY-AA-GG',
          ),
        ),
        TextField(
          controller: _summary,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Yapılan güncellemeler'),
        ),
        TextField(
          controller: _hardware,
          decoration: const InputDecoration(labelText: 'Donanım notu'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _health,
          decoration: const InputDecoration(labelText: 'Sistem sağlığı'),
          items: const [
            DropdownMenuItem(value: 'OK', child: Text('İyi')),
            DropdownMenuItem(value: 'WARNING', child: Text('Uyarı')),
          ],
          onChanged: (value) => setState(() => _health = value ?? _health),
        ),
        DropdownButtonFormField<String>(
          initialValue: _target,
          decoration: const InputDecoration(labelText: 'Hedef kitle'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Herkes')),
            DropdownMenuItem(value: 'ADVISOR', child: Text('Müşavirler')),
            DropdownMenuItem(value: 'CLIENT', child: Text('Mükellefler')),
          ],
          onChanged: (value) => setState(() => _target = value ?? _target),
        ),
        SwitchListTile(
          title: const Text('Bakım tamamlandı'),
          value: _maintenance,
          onChanged: (value) => setState(() => _maintenance = value),
        ),
        SwitchListTile(
          title: const Text('Antivirüs kontrolü'),
          value: _antivirus,
          onChanged: (value) => setState(() => _antivirus = value),
        ),
        SwitchListTile(
          title: const Text('Yapılandırma uygun'),
          value: _config,
          onChanged: (value) => setState(() => _config = value),
        ),
        SwitchListTile(
          title: const Text('Sürüm güncel'),
          value: _version,
          onChanged: (value) => setState(() => _version = value),
        ),
        SwitchListTile(
          title: const Text('Yayınla'),
          value: _published,
          onChanged: (value) => setState(() => _published = value),
        ),
        if (widget.existing == null)
          SwitchListTile(
            title: const Text('E-posta da gönder'),
            value: _sendEmail,
            onChanged: (value) => setState(() => _sendEmail = value),
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
