import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets.dart';

/// The web notes are local to a browser profile. Mobile notes stay local to
/// this device and are isolated by signed-in account and role.
class FullNotesPage extends StatefulWidget {
  const FullNotesPage({super.key, required this.userId, required this.role});

  final int userId;
  final String role;

  @override
  State<FullNotesPage> createState() => _FullNotesPageState();
}

class _FullNotesPageState extends State<FullNotesPage> {
  static const categories = <String, String>{
    'all': 'Tüm Notlar',
    'general': 'Genel',
    'personal': 'Kişisel',
    'work': 'İş & Meslek',
    'payment': 'Ödemeler',
    'taxes': 'Vergi & Beyanname',
    'invoices': 'Fatura & Makbuz',
    'meetings': 'Toplantı & Görüşme',
    'bank': 'Banka & Finans',
  };
  static const colors = <String, Color>{
    'yellow': Color(0xFFFFF2C7),
    'blue': Color(0xFFDDEEFF),
    'green': Color(0xFFDCF7DF),
    'red': Color(0xFFFFE0DE),
    'purple': Color(0xFFEEE4FF),
  };

  final _search = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  String _category = 'all';
  bool _loading = true;
  bool _legacyAvailable = false;

  String get _storageKey =>
      'finkit_notes_${widget.role.toLowerCase()}_${widget.userId}';
  String get _legacyImportKey => '${_storageKey}_legacy_imported';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FullNotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.role != widget.role) {
      _notes = [];
      _category = 'all';
      _search.clear();
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      return (data as List)
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notes = _decode(prefs.getString(_storageKey));
      _legacyAvailable =
          prefs.getBool(_legacyImportKey) != true &&
          _decode(prefs.getString('finkit_notes')).isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_notes));
  }

  Future<void> _importLegacy() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eski notları aktar'),
        content: const Text(
          'Eski mobil sürüm notları hesaplara ayırmıyordu. Bu cihazdaki eski notları şu an açık olan hesaba aktarmak ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktar'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final prefs = await SharedPreferences.getInstance();
    final legacy = _decode(prefs.getString('finkit_notes'));
    setState(() {
      _notes = [
        ..._notes,
        for (final item in legacy)
          {
            'id': '${DateTime.now().microsecondsSinceEpoch}-${item.hashCode}',
            'title': item['title'] ?? 'Not',
            'content': item['body'] ?? '',
            'color': 'yellow',
            'isPinned': false,
            'category': 'general',
            'todoList': <Map<String, dynamic>>[],
            'created_at':
                item['created_at'] ?? DateTime.now().toIso8601String(),
          },
      ];
      _legacyAvailable = false;
    });
    await _save();
    await prefs.setBool(_legacyImportKey, true);
    // Keep the old key for other accounts until the owner explicitly clears it.
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _NoteEditor(initial: existing),
    );
    if (updated == null) return;
    setState(() {
      if (existing == null) {
        _notes.insert(0, updated);
      } else {
        final index = _notes.indexWhere((note) => note['id'] == existing['id']);
        if (index >= 0) _notes[index] = updated;
      }
    });
    await _save();
  }

  Future<void> _delete(Map<String, dynamic> note) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu Sil'),
        content: Text('“${note['title']}” notu silinsin mi?'),
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
    if (approved != true) return;
    setState(() => _notes.removeWhere((item) => item['id'] == note['id']));
    await _save();
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    setState(() => note['isPinned'] = note['isPinned'] != true);
    await _save();
  }

  Future<void> _toggleTask(Map<String, dynamic> note, int index) async {
    final tasks = (note['todoList'] as List).whereType<Map>().toList();
    tasks[index]['done'] = tasks[index]['done'] != true;
    setState(() => note['todoList'] = tasks);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final notes =
        _notes.where((note) {
          if (_category != 'all' && note['category'] != _category) return false;
          return '${note['title']} ${note['content']}'.toLowerCase().contains(
            query,
          );
        }).toList()..sort((a, b) {
          if (a['isPinned'] == true && b['isPinned'] != true) return -1;
          if (b['isPinned'] == true && a['isPinned'] != true) return 1;
          return '${b['created_at']}'.compareTo('${a['created_at']}');
        });
    return Scaffold(
      appBar: AppBar(title: const Text('Not Defteri')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Notlarda ara',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in categories.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(category.value),
                            selected: _category == category.key,
                            onSelected: (_) =>
                                setState(() => _category = category.key),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_legacyAvailable)
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Eski notları aktar'),
                    subtitle: const Text('Önceki sürümün ortak cihaz notları'),
                    onTap: _importLegacy,
                  ),
                if (notes.isEmpty)
                  const EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Not bulunamadı',
                    description: 'Yeni not oluşturun veya filtreyi değiştirin.',
                  ),
                for (final note in notes)
                  Card(
                    color: colors['${note['color']}'] ?? colors['yellow'],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${note['title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: note['isPinned'] == true
                                    ? 'Sabitlemeyi kaldır'
                                    : 'Sabitle',
                                icon: Icon(
                                  note['isPinned'] == true
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                ),
                                onPressed: () => _togglePin(note),
                              ),
                              IconButton(
                                tooltip: 'Düzenle',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(note),
                              ),
                              IconButton(
                                tooltip: 'Sil',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(note),
                              ),
                            ],
                          ),
                          if ('${note['content']}'.trim().isNotEmpty)
                            Text('${note['content']}'),
                          for (
                            var i = 0;
                            i < (note['todoList'] as List? ?? const []).length;
                            i++
                          )
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value:
                                  (note['todoList'] as List)[i]['done'] == true,
                              title: Text(
                                '${(note['todoList'] as List)[i]['text']}',
                              ),
                              onChanged: (_) => _toggleTask(note, i),
                            ),
                          Text(
                            categories['${note['category']}'] ?? 'Genel',
                            style: const TextStyle(fontSize: 11),
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

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  final _newTask = TextEditingController();
  late String _category;
  late String _color;
  late bool _pinned;
  late List<Map<String, dynamic>> _tasks;

  @override
  void initState() {
    super.initState();
    final note = widget.initial;
    _title = TextEditingController(text: '${note?['title'] ?? ''}');
    _content = TextEditingController(text: '${note?['content'] ?? ''}');
    _category = '${note?['category'] ?? 'general'}';
    _color = '${note?['color'] ?? 'yellow'}';
    _pinned = note?['isPinned'] == true;
    _tasks = (note?['todoList'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _newTask.dispose();
    super.dispose();
  }

  void _addTask() {
    if (_newTask.text.trim().isEmpty) return;
    setState(
      () => _tasks.add({
        'id': '${DateTime.now().microsecondsSinceEpoch}',
        'text': _newTask.text.trim(),
        'done': false,
      }),
    );
    _newTask.clear();
  }

  void _save() {
    if (_title.text.trim().isEmpty &&
        _content.text.trim().isEmpty &&
        _tasks.isEmpty)
      return;
    Navigator.pop(context, {
      'id': widget.initial?['id'] ?? '${DateTime.now().microsecondsSinceEpoch}',
      'title': _title.text.trim().isEmpty ? 'Not' : _title.text.trim(),
      'content': _content.text.trim(),
      'color': _color,
      'isPinned': _pinned,
      'category': _category,
      'todoList': _tasks,
      'created_at':
          widget.initial?['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'Yeni Not' : 'Notu Düzenle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            TextField(
              controller: _content,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'İçerik'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final item in _FullNotesPageState.categories.entries)
                  if (item.key != 'all')
                    DropdownMenuItem(value: item.key, child: Text(item.value)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? 'general'),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _FullNotesPageState.colors.entries)
                  ChoiceChip(
                    label: const Text('●'),
                    backgroundColor: entry.value,
                    selectedColor: entry.value,
                    selected: _color == entry.key,
                    onSelected: (_) => setState(() => _color = entry.key),
                  ),
              ],
            ),
            SwitchListTile(
              title: const Text('Sabitle'),
              value: _pinned,
              onChanged: (value) => setState(() => _pinned = value),
            ),
            const Text(
              'Yapılacaklar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (var i = 0; i < _tasks.length; i++)
              ListTile(
                leading: Checkbox(
                  value: _tasks[i]['done'] == true,
                  onChanged: (value) =>
                      setState(() => _tasks[i]['done'] = value == true),
                ),
                title: TextFormField(
                  key: ValueKey(_tasks[i]['id']),
                  initialValue: '${_tasks[i]['text']}',
                  onChanged: (value) => _tasks[i]['text'] = value,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _tasks.removeAt(i)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTask,
                    decoration: const InputDecoration(labelText: 'Yeni görev'),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                IconButton(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
