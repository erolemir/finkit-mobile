import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';

class CalendarTemplatesPage extends StatefulWidget {
  const CalendarTemplatesPage({super.key, required this.api});

  final FinkitApi api;

  @override
  State<CalendarTemplatesPage> createState() => _CalendarTemplatesPageState();
}

class _CalendarTemplatesPageState extends State<CalendarTemplatesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
    _future = widget.api.eventTemplates();
  });

  Future<void> _create() async {
    var title = '';
    var description = '';
    var offsetText = '1';
    var type = 'CLIENT';
    var saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Etkinlik Şablonu',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Şablon Adı'),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: offsetText,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kaç Gün Sonra?',
                  ),
                  onChanged: (value) => offsetText = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Etkinlik Türü'),
                  items: const [
                    DropdownMenuItem(
                      value: 'CLIENT',
                      child: Text('Mükellef Etkinliği'),
                    ),
                    DropdownMenuItem(value: 'PERSONAL', child: Text('Kişisel')),
                    DropdownMenuItem(value: 'ALL', child: Text('Genel Duyuru')),
                  ],
                  onChanged: (value) => type = value ?? 'CLIENT',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                  ),
                  onChanged: (value) => description = value,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final offset = int.tryParse(offsetText.trim());
                          if (title.trim().isEmpty ||
                              offset == null ||
                              offset < 0) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Ad ve geçerli gün sayısı girin'),
                              ),
                            );
                            return;
                          }
                          refresh(() => saving = true);
                          try {
                            await widget.api.createEventTemplate(
                              title: title.trim(),
                              daysOffset: offset,
                              description: description.trim().isEmpty
                                  ? null
                                  : description.trim(),
                              eventType: type,
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, true);
                            }
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            refresh(() => saving = false);
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                  child: Text(saving ? 'Kaydediliyor…' : 'Şablonu Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şablonu sil'),
        content: Text('${item['title']} şablonu silinsin mi?'),
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
    if (approved != true || !mounted) return;
    try {
      await widget.api.deleteEventTemplate(int.parse('${item['id']}'));
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Etkinlik Şablonları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Şablon Oluştur'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.article_outlined,
              title: 'Şablon yok',
              description:
                  'Sık kullandığınız etkinlikler için şablon oluşturun.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['title'] ?? 'Şablon'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '+${item['days_offset'] ?? 0} gün · ${item['event_type'] ?? ''}',
                                style: const TextStyle(
                                  color: FinkitColors.muted,
                                ),
                              ),
                              if ('${item['description'] ?? ''}'.isNotEmpty)
                                Text(
                                  '${item['description']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Şablonu sil',
                          onPressed: () => _delete(item),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
