import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.api, this.systemOnly = false});

  final FinkitApi api;
  final bool systemOnly;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  String _role = '';
  String _status = '';
  int _page = 1;
  bool _busy = false;

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
      '/admin/users',
      query: {
        'page': '$_page',
        'page_size': '20',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        'role': widget.systemOnly ? 'ADMIN' : _role,
        if (_status.isNotEmpty) 'is_banned': _status,
      },
    );
  }

  void _filter() => setState(() {
    _page = 1;
    _reload();
  });

  Future<void> _detail(Map<String, dynamic> summary) async {
    final id = (summary['id'] as num).toInt();
    Map<String, dynamic> user = summary;
    List<Map<String, dynamic>> logs = [];
    try {
      final results = await Future.wait([
        widget.api.adminGet('/admin/users/$id'),
        widget.api.adminGet(
          '/admin/logs',
          query: {'user_id': '$id', 'page_size': '10'},
        ),
      ]);
      user = results[0];
      logs = (results[1]['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ayrıntı alınamadı: $error')));
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '${user['full_name'] ?? user['email']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final key in [
              'id',
              'email',
              'role',
              'phone_number',
              'created_at',
              'is_banned',
              'banned_at',
              'ban_reason',
            ])
              if (user[key] != null)
                ListTile(
                  dense: true,
                  title: Text(key),
                  subtitle: Text('${user[key]}'),
                ),
            const Divider(),
            Text(
              'Son işlemler',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (logs.isEmpty) const Text('İşlem kaydı bulunamadı.'),
            for (final log in logs)
              ListTile(
                dense: true,
                title: Text('${log['action'] ?? 'İşlem'}'),
                subtitle: Text(
                  '${log['created_at'] ?? ''} · ${log['path'] ?? ''}',
                ),
              ),
            if (user['role'] != 'ADMIN') ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  user['is_banned'] == true
                      ? Icons.lock_open_outlined
                      : Icons.block_outlined,
                ),
                title: Text(
                  user['is_banned'] == true
                      ? 'Yasağı kaldır'
                      : 'Hesabı yasakla',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _ban(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Kullanıcıyı sil'),
                onTap: () {
                  Navigator.pop(context);
                  _delete(user);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _ban(Map<String, dynamic> user) async {
    if (_busy) return;
    final banned = user['is_banned'] == true;
    var reasonText = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(banned ? 'Yasağı kaldır' : 'Hesabı yasakla'),
        content: banned
            ? Text('${user['full_name']} hesabının yasağı kaldırılsın mı?')
            : TextField(
                onChanged: (value) => reasonText = value,
                decoration: const InputDecoration(
                  labelText: 'Yasaklama gerekçesi',
                ),
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
    reasonText = reasonText.trim();
    if (approved != true || (!banned && reasonText.isEmpty)) return;
    setState(() => _busy = true);
    try {
      final id = (user['id'] as num).toInt();
      await widget.api.adminPost(
        '/admin/users/$id/${banned ? 'unban' : 'ban'}',
        banned ? const {} : {'reason': reasonText},
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    if (_busy) return;
    final name = '${user['full_name'] ?? user['email']}'.trim();
    var confirmationText = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Onaylamak için "$name" yazın.'),
            TextField(
              onChanged: (value) => confirmationText = value,
              decoration: const InputDecoration(
                labelText: 'Ad soyad / e-posta',
              ),
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
    final matched =
        confirmationText.trim().replaceAll(RegExp(r'\s+'), ' ') ==
        name.replaceAll(RegExp(r'\s+'), ' ');
    if (approved != true) return;
    if (!matched) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Onay metni eşleşmedi.')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.adminDelete('/admin/users/${user['id']}');
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final rows = (snapshot.data?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final total = int.tryParse('${snapshot.data?['total']}') ?? rows.length;
      return RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageTitle(
              title: widget.systemOnly ? 'Kullanıcılar' : 'Üyeler',
              subtitle: '$total kayıt',
            ),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Ad veya e-posta ara',
                suffixIcon: IconButton(
                  tooltip: 'Ara',
                  onPressed: _filter,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _filter(),
            ),
            if (!widget.systemOnly) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tümü')),
                  DropdownMenuItem(value: 'ADVISOR', child: Text('Müşavir')),
                  DropdownMenuItem(value: 'CLIENT', child: Text('Mükellef')),
                ],
                onChanged: (value) => setState(() {
                  _role = value ?? '';
                  _page = 1;
                  _reload();
                }),
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tümü')),
                DropdownMenuItem(value: 'false', child: Text('Aktif')),
                DropdownMenuItem(value: 'true', child: Text('Yasaklı')),
              ],
              onChanged: (value) => setState(() {
                _status = value ?? '';
                _page = 1;
                _reload();
              }),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text('Kayıtlar alınamadı: ${snapshot.error}'),
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const EmptyState(
                icon: Icons.people_outline,
                title: 'Kullanıcı bulunamadı',
                description: 'Seçili filtrelerde kayıt yok.',
              )
            else
              for (final user in rows)
                Card(
                  child: ListTile(
                    title: Text('${user['full_name'] ?? user['email']}'),
                    subtitle: Text(
                      '${user['email']} · ${user['role']} · ${user['is_banned'] == true ? 'Yasaklı' : 'Aktif'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _detail(user),
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
                      '$_page · $total kullanıcı',
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
