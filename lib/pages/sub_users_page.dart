import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class SubUsersPage extends StatefulWidget {
  const SubUsersPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<SubUsersPage> createState() => _SubUsersPageState();
}

class _SubUsersPageState extends State<SubUsersPage> {
  late Future<List<Map<String, dynamic>>> _users;
  late Future<Map<String, dynamic>> _modules;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _users = widget.api.subUsers();
    _modules = widget.api.subUserModules();
  }

  Future<void> _openForm([Map<String, dynamic>? user]) async {
    final modules = await _modules;
    if (!mounted) return;
    final name = TextEditingController(text: '${user?['full_name'] ?? ''}');
    final email = TextEditingController(text: '${user?['email'] ?? ''}');
    final password = TextEditingController();
    final rawPermissions = user?['module_permissions'];
    final permissions = <String, Set<String>>{};
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        if (entry.value is List) {
          permissions['${entry.key}'] = (entry.value as List)
              .map((action) => '$action')
              .toSet();
        }
      }
    }
    String? error;
    bool saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.77,
              child: ListView(
                children: [
                  Text(
                    user == null
                        ? 'Alt Kullanıcı Ekle'
                        : 'Alt Kullanıcı Düzenle',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: user == null
                          ? 'Şifre'
                          : 'Yeni şifre (opsiyonel)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Modül ve işlem izinleri',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  for (final module in modules.entries) ...[
                    const Divider(),
                    Text(
                      '${module.value}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final action in const [
                          'read',
                          'create',
                          'update',
                          'delete',
                        ])
                          FilterChip(
                            label: Text(
                              const {
                                'read': 'Gör',
                                'create': 'Ekle',
                                'update': 'Düzenle',
                                'delete': 'Sil',
                              }[action]!,
                            ),
                            selected:
                                permissions['${module.key}']?.contains(
                                  action,
                                ) ??
                                false,
                            onSelected: (selected) => update(() {
                              final values = permissions.putIfAbsent(
                                '${module.key}',
                                () => <String>{},
                              );
                              if (selected) {
                                values.add(action);
                              } else {
                                values.remove(action);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(sheetContext).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (name.text.trim().length < 2 ||
                                !email.text.contains('@') ||
                                (user == null && password.text.length < 10)) {
                              update(
                                () => error = 'Ad soyad, geçerli e-posta ve en az 10 karakterli şifre girin.',
                              );
                              return;
                            }
                            update(() {
                              saving = true;
                              error = null;
                            });
                            final body = <String, dynamic>{
                              'full_name': name.text.trim(),
                              'email': email.text.trim(),
                              if (password.text.isNotEmpty)
                                'password': password.text,
                              'module_permissions': {
                                for (final entry in permissions.entries)
                                  if (entry.value.isNotEmpty)
                                    entry.key: entry.value.toList(),
                              },
                            };
                            try {
                              if (user == null) {
                                await widget.api.createSubUser(body);
                              } else {
                                await widget.api.updateSubUser(
                                  int.parse('${user['id']}'),
                                  body,
                                );
                              }
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext, true);
                            } catch (failure) {
                              if (sheetContext.mounted)
                                update(() => error = '$failure');
                            } finally {
                              if (sheetContext.mounted)
                                update(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    email.dispose();
    password.dispose();
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alt Kullanıcıyı Sil'),
        content: Text(
          '${user['full_name']} erişimi kaldırılacak. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.api.deleteSubUser(int.parse('${user['id']}'));
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _toggle(Map<String, dynamic> user) async {
    try {
      await widget.api.updateSubUser(int.parse('${user['id']}'), {
        'is_active': user['is_active'] != true,
      });
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alt Kullanıcılar')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _users,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(
              title: 'Alt Kullanıcılar',
              subtitle: 'Ekip üyeleri ve işlem izinleri',
              trailing: IconButton.filled(
                tooltip: 'Alt kullanıcı ekle',
                onPressed: () => _openForm(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text(
                  'Kullanıcılar alınamadı: ${snapshot.error} · Tekrar dene',
                ),
              )
            else if (snapshot.data!.isEmpty)
              const EmptyState(
                icon: Icons.groups_outlined,
                title: 'Alt kullanıcı yok',
                description: 'Ekip üyesi ekleyebilirsiniz.',
              )
            else
              for (final user in snapshot.data!)
                Card(
                  child: ListTile(
                    title: Text('${user['full_name']}'),
                    subtitle: Text(
                      '${user['email']} · ${user['is_active'] == true ? 'Aktif' : 'Pasif'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) {
                        if (choice == 'edit') _openForm(user);
                        if (choice == 'toggle') _toggle(user);
                        if (choice == 'delete') _delete(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Düzenle'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            user['is_active'] == true
                                ? 'Pasife Al'
                                : 'Aktifleştir',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Sil'),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
