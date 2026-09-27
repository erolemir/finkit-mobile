import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AccountingAttachmentsPanel extends StatefulWidget {
  const AccountingAttachmentsPanel({
    super.key,
    required this.api,
    required this.relatedType,
    required this.records,
  });

  final FinkitApi api;
  final String relatedType;
  final List<({int id, String label})> records;

  @override
  State<AccountingAttachmentsPanel> createState() =>
      _AccountingAttachmentsPanelState();
}

class _AccountingAttachmentsPanelState
    extends State<AccountingAttachmentsPanel> {
  int? _selectedId;
  Future<List<Map<String, dynamic>>>? _files;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant AccountingAttachmentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedId != null &&
        !widget.records.any((record) => record.id == _selectedId)) {
      _selectedId = null;
      _files = null;
    } else if (_selectedId != null &&
        oldWidget.relatedType != widget.relatedType) {
      _load();
    }
  }

  void _load() {
    final id = _selectedId;
    _files = id == null
        ? null
        : widget.api.accountingAttachments(widget.relatedType, id);
  }

  Future<void> _upload() async {
    final id = _selectedId;
    if (id == null || _busy) return;
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked.isEmpty) return;
    final file = picked.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seçilen dosya okunamadı.')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.uploadAccountingAttachment(
        relatedType: widget.relatedType,
        relatedId: id,
        filePath: file.path!,
        fileName: file.name,
      );
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dosya yüklendi.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> file) async {
    final id = int.tryParse('${file['id']}');
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.api.downloadAccountingAttachment(id);
      final saved = await FilePicker.saveFile(
        fileName: '${file['file_name'] ?? 'dosya'}',
        bytes: bytes,
        mimeType: '${file['content_type'] ?? 'application/octet-stream'}',
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dosya kaydedildi.')));
      }
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
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dosya Ekleri', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          key: ValueKey(_selectedId),
          initialValue: _selectedId,
          decoration: const InputDecoration(labelText: 'Kayıt seçin'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Kayıt seçin')),
            for (final record in widget.records)
              DropdownMenuItem(value: record.id, child: Text(record.label)),
          ],
          onChanged: (value) => setState(() {
            _selectedId = value;
            _load();
          }),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _selectedId == null || _busy ? null : _upload,
          icon: const Icon(Icons.attach_file_rounded),
          label: const Text('Dosya Ekle'),
        ),
        if (_files case final files?)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: files,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingState();
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_load),
                  child: Text(
                    'Dosyalar alınamadı: ${snapshot.error} · Tekrar dene',
                  ),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const Text('Bu kayıt için dosya yok.');
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['file_name'] ?? 'Dosya'}'),
                      subtitle: Text(dateText(item['uploaded_at'])),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _download(item),
                        child: const Text('İndir'),
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
