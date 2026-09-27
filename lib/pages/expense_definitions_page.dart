import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class ExpenseDefinitionsPage extends StatefulWidget {
  const ExpenseDefinitionsPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<ExpenseDefinitionsPage> createState() => _ExpenseDefinitionsPageState();
}

class _ExpenseDefinitionsPageState extends State<ExpenseDefinitionsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.expenseCategories();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.createExpenseCategory(
        name: name,
        code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      );
      if (!mounted) return;
      _name.clear();
      _code.clear();
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kategori oluşturuldu.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}');
    if (id == null) return;
    final name = TextEditingController(text: '${item['name'] ?? ''}');
    final code = TextEditingController(text: '${item['code'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gider Kategorisi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Kategori adı'),
            ),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Kod (opsiyonel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final nextName = name.text.trim();
    final nextCode = code.text.trim();
    name.dispose();
    code.dispose();
    if (saved != true || nextName.isEmpty) return;
    await _update(id, {
      'name': nextName,
      'code': nextCode.isEmpty ? null : nextCode,
    });
  }

  Future<void> _update(int id, Map<String, dynamic> body) async {
    try {
      await widget.api.updateExpenseCategory(id, body);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kategori güncellendi.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ön Tanımlar')),
    body: RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageTitle(
            title: 'Gider Ön Tanımları',
            subtitle: 'Tekrar kullanılacak gider kategorilerini yönetin.',
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Kategori adı'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Kod (opsiyonel)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kategori Ekle'),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingState();
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_reload),
                  child: Text(
                    'Kategoriler yüklenemedi: ${snapshot.error} · Tekrar dene',
                  ),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'Kategori yok',
                  description: 'İlk gider kategorisini ekleyin.',
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Card(
                      child: ListTile(
                        title: Text('${item['name']}'),
                        subtitle: Text(
                          '${item['code'] ?? 'Kod yok'} · ${item['is_active'] == true ? 'Aktif' : 'Pasif'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (choice) {
                            if (choice == 'edit') {
                              _edit(item);
                            } else {
                              final id = int.tryParse('${item['id']}');
                              if (id != null) {
                                _update(id, {
                                  'is_active': item['is_active'] != true,
                                });
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Düzenle'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                item['is_active'] == true
                                    ? 'Pasife Al'
                                    : 'Aktifleştir',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
