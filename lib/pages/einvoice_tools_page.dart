import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class EInvoiceUblUploadPage extends StatefulWidget {
  const EInvoiceUblUploadPage({
    super.key,
    required this.api,
    required this.isClient,
    required this.documentType,
    this.medula = false,
  });

  final FinkitApi api;
  final bool isClient;
  final String documentType;
  final bool medula;

  @override
  State<EInvoiceUblUploadPage> createState() => _EInvoiceUblUploadPageState();
}

class _EInvoiceUblUploadPageState extends State<EInvoiceUblUploadPage> {
  PlatformFile? _file;
  bool _busy = false;
  String? _error;

  Future<void> _chooseFile() async {
    final file = await FilePickerPlatform.instance.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xml'],
    );
    if (file == null) return;
    setState(() {
      _file = file;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || _busy) return;
    final byteCount = file.lengthSync() ?? await file.length();
    if (!file.name.toLowerCase().endsWith('.xml') ||
        file.path == null ||
        byteCount == null ||
        byteCount > 5 * 1024 * 1024) {
      setState(() => _error = 'En fazla 5 MB boyutunda bir XML dosyası seçin.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('UBL Belgesini Gönder'),
        content: Text(
          '${file.name} sağlayıcıya gönderilecek. Belge türünü ve içeriğini kontrol ettiniz mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla ve Gönder'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.uploadElectronicInvoiceUbl(
        isClient: widget.isClient,
        documentType: widget.documentType,
        filePath: file.path!,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _file = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'UBL belgesi gönderildi. Durumu giden kutusunda kontrol edin.',
          ),
        ),
      );
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
        widget.medula
            ? 'Medula Fatura Yükleme'
            : widget.documentType == 'EARCHIVE'
            ? 'E-Arşiv Yükleme'
            : 'Fatura Yükleme',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageTitle(
          title: widget.medula
              ? 'Medula Fatura Yükleme'
              : widget.documentType == 'EARCHIVE'
              ? 'E-Arşiv XML Yükleme'
              : 'E-Fatura XML Yükleme',
          subtitle: widget.medula
              ? 'Medula sisteminden alınan UBL-TR XML dosyası'
              : 'UBL-TR standardında, en fazla 5 MB boyutunda tek XML belge',
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _chooseFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(_file?.name ?? 'XML Dosyası Seç'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _file == null || _busy ? null : _upload,
          icon: const Icon(Icons.send_outlined),
          label: Text(_busy ? 'Gönderiliyor…' : 'Belgeyi Yükle ve Gönder'),
        ),
      ],
    ),
  );
}

class EArchiveReportsPage extends StatefulWidget {
  const EArchiveReportsPage({
    super.key,
    required this.api,
    required this.isClient,
  });

  final FinkitApi api;
  final bool isClient;

  @override
  State<EArchiveReportsPage> createState() => _EArchiveReportsPageState();
}

class _EArchiveReportsPageState extends State<EArchiveReportsPage> {
  late DateTime _period;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _period = DateTime(DateTime.now().year, DateTime.now().month);
    _reload();
  }

  void _reload() {
    final month = _period.month.toString().padLeft(2, '0');
    final lastDay = DateTime(_period.year, _period.month + 1, 0).day;
    _future = widget.api.electronicArchiveReportItems(
      isClient: widget.isClient,
      startDate: '${_period.year}-$month-01',
      endDate: '${_period.year}-$month-${lastDay.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _choosePeriod() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'Rapor dönemini seçin',
    );
    if (chosen != null) {
      setState(() {
        _period = DateTime(chosen.year, chosen.month);
        _reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('E-Arşiv Raporları')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageTitle(
              title: 'E-Arşiv Raporları',
              subtitle: 'Seçili ayın belge ve raporlama durumları',
            ),
            OutlinedButton.icon(
              onPressed: _choosePeriod,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                '${_period.year}-${_period.month.toString().padLeft(2, '0')}',
              ),
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LoadingState()
            else if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(_reload),
                child: Text('Rapor alınamadı: ${snapshot.error}'),
              )
            else ...[
              Builder(
                builder: (context) {
                  final items = snapshot.data ?? const <Map<String, dynamic>>[];
                  final reported = items
                      .where((item) => item['status'] == 'REPORTED')
                      .length;
                  final cancelled = items
                      .where((item) => item['status'] == 'CANCELLED')
                      .length;
                  final total = items.fold<double>(
                    0,
                    (sum, item) =>
                        sum +
                        (double.tryParse('${item['payable_amount'] ?? 0}') ??
                            0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in <String, String>{
                        'Belge': '${items.length}',
                        'Raporlandı': '$reported',
                        'Rapor Bekliyor':
                            '${items.length - reported - cancelled}',
                        'İptal': '$cancelled',
                        'Toplam Tutar': total.toStringAsFixed(2),
                        'Raporlanma Oranı': items.isEmpty
                            ? '%0'
                            : '%${(reported / items.length * 100).round()}',
                      }.entries)
                        Card(
                          child: ListTile(
                            title: Text(entry.key),
                            trailing: Text(entry.value),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
