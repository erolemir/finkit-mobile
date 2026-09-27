import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'chat_page.dart';
import 'calendar_templates_page.dart';
import 'data_pages.dart';
import 'entry_forms.dart';
import 'more_pages.dart';
import 'electronic_invoice_box.dart';

/// Rapor listesi ve detayını birlikte açan sarmalayıcı ekran.
class DashboardReportsPage extends StatelessWidget {
  const DashboardReportsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Raporlar')),
      body: ReportsPage(
        api: api,
        refreshKey: refreshKey,
        onOpenReport: (report) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReportDetailPage(
                api: api,
                report: report,
                title: reportTitle(report),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _text(dynamic value, [String fallback = '—']) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

List<String> _labels(Map<String, dynamic> item) =>
    item.keys.map((key) => key.toString()).toList(growable: false);

/// Müşavir tarafındaki mükellef listesi.
class ClientsListPage extends StatefulWidget {
  const ClientsListPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ClientsListPage> createState() => _ClientsListPageState();
}

class _ClientsListPageState extends State<ClientsListPage> {
  int _localRefresh = 0;

  Future<void> _addClient() async {
    final password = await showClientForm(context, widget.api);
    if (!mounted) return;
    setState(() => _localRefresh++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          password == null
              ? 'Mükellef kaydedildi'
              : 'Mükellef kaydedildi. Geçici şifre gösterildi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Mükellefler')),
      body: ApiListPage(
        title: 'Mükellefler',
        subtitle: 'Cari kartları, ödeme durumu ve iletişim bilgileri.',
        refreshKey: widget.refreshKey + _localRefresh,
        loader: widget.api.clients,
        trailing: IconButton.filled(
          tooltip: 'Yeni mükellef',
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          onPressed: _addClient,
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
        searchHint: 'Ünvan, yetkili veya vergi no ara',
        searchText: (item) =>
            '${item['company_title']} ${item['user']?['full_name']} ${item['tax_no']}',
        emptyIcon: Icons.people_outline_rounded,
        emptyTitle: 'Mükellef yok',
        emptyDescription: 'Henüz mükellef eklenmemiş.',
        summaryBuilder: (items) {
          final active = items
              .where((item) => item['payment_status'] == 'PAID')
              .length;
          final totalFee = items.fold<double>(
            0,
            (sum, item) =>
                sum + (double.tryParse('${item['monthly_fee'] ?? 0}') ?? 0),
          );
          return SummaryGrid(
            items: [
              SummaryItem(
                'Mükellef',
                '${items.length}',
                Icons.groups_2_outlined,
              ),
              SummaryItem('Ödemesi güncel', '$active', Icons.verified_outlined),
              SummaryItem(
                'Aylık ücret',
                moneyText(totalFee),
                Icons.payments_outlined,
              ),
            ],
          );
        },
        itemBuilder: (context, item) {
          final user = item['user'] is Map
              ? Map<String, dynamic>.from(item['user'] as Map)
              : const <String, dynamic>{};
          return DataRowCard(
            icon: Icons.business_outlined,
            title: _text(item['company_title'], 'Mükellef'),
            subtitle:
                '${_text(user['full_name'], 'Yetkili')} · ${_text(user['email'], '')}',
            value: moneyText(item['monthly_fee']),
            valueSubtitle: 'Aylık ücret',
            status: item['payment_status']?.toString(),
            onTap: () => _showDetail(context, item),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> item) {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'] as Map)
        : const <String, dynamic>{};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(item['company_title'], 'Mükellef'),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _text(user['full_name'], ''),
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Column(
                  children: [
                    _InfoRow('E-posta', _text(user['email'])),
                    _InfoRow('Telefon', _text(user['phone_number'])),
                    _InfoRow('Vergi No', _text(item['tax_no'])),
                    _InfoRow('TCKN', _text(item['tckn'])),
                    _InfoRow('Şehir', _text(user['city'])),
                    _InfoRow('Aylık Ücret', moneyText(item['monthly_fee'])),
                    _InfoRow(
                      'Ödeme Durumu',
                      statusLabel(item['payment_status']?.toString()),
                    ),
                    _InfoRow('Müşavir Kodu', _text(item['advisor_unique_id'])),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final userId = int.tryParse('${item['user_id']}');
                        if (userId == null) return;
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatThreadPage(
                              api: widget.api,
                              otherUserId: userId,
                              title: _text(item['company_title'], 'Mükellef'),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Sohbet'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CredentialsPage(
                              api: widget.api,
                              refreshKey: widget.refreshKey,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('Giriş Bilgileri'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final clientId = int.tryParse('${item['user_id']}');
                        if (clientId == null) return;
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(sheetContext);
                        try {
                          final link = await widget.api.generatePaymentLink(
                            clientId,
                          );
                          final url =
                              link['payment_url']?.toString() ??
                              link['url']?.toString() ??
                              link['link']?.toString() ??
                              link.toString();
                          await Clipboard.setData(ClipboardData(text: url));
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Ödeme linki kopyalandı: $url'),
                            ),
                          );
                        } catch (error) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Ödeme Linki'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final clientId = int.tryParse('${item['user_id']}');
                        final user = item['user'] is Map
                            ? Map<String, dynamic>.from(item['user'] as Map)
                            : const <String, dynamic>{};
                        if (clientId == null) return;
                        Navigator.pop(sheetContext);
                        final updated = await showClientEditForm(
                          context,
                          widget.api,
                          clientId: clientId,
                          companyTitle: _text(item['company_title'], ''),
                          fullName: _text(user['full_name'], ''),
                          phoneNumber: _text(user['phone_number'], ''),
                          taxNumber: _text(item['tax_no'], ''),
                          monthlyFee:
                              double.tryParse('${item['monthly_fee']}') ?? 0,
                          paymentDueDay:
                              int.tryParse('${item['payment_due_day']}') ?? 1,
                        );
                        if (updated && mounted) setState(() => _localRefresh++);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Düzenle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Belgeler: müşavir tüm belgeleri, mükellef kendi belgelerini görür.
class DocumentsListPage extends StatefulWidget {
  const DocumentsListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
    this.clientId,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;
  final int? clientId;

  @override
  State<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  FinkitApi get api => widget.api;
  bool get isClient => widget.isClient;
  int? get clientId => widget.clientId;
  int _localRefresh = 0;
  String _typeFilter = '';
  String _ownerFilter = '';
  String _monthFilter = '';

  bool _matchesFilters(Map<String, dynamic> item) {
    if (_typeFilter.isNotEmpty && item['document_type'] != _typeFilter)
      return false;
    if (_ownerFilter.isNotEmpty) {
      final owner = item['external_client_id'] != null
          ? 'external:${item['external_client_id']}'
          : 'client:${item['client_id']}';
      if (owner != _ownerFilter) return false;
    }
    if (_monthFilter.isNotEmpty &&
        !'${item['document_date'] ?? item['upload_date'] ?? ''}'.startsWith(
          _monthFilter,
        ))
      return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final id = clientId;
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(isClient ? 'Belgelerim' : 'Belgeler')),
      body: ApiListPage(
        title: isClient ? 'Belgelerim' : 'Belgeler',
        subtitle:
            'Beyanname, tahakkuk ve firma evrakları tek listede toplanır.',
        refreshKey: widget.refreshKey + _localRefresh,
        loader: () => isClient && id != null
            ? api.clientDocuments(id)
            : api.allDocuments(),
        searchHint: 'Dosya adı veya tür ara',
        searchText: (item) =>
            '${item['file_name']} ${_documentTypes[item['document_type']] ?? item['document_type']}',
        filter: _matchesFilters,
        emptyIcon: Icons.description_outlined,
        emptyTitle: 'Belge bulunamadı',
        emptyDescription: 'Yüklenmiş belge yok.',
        summaryBuilder: (items) {
          final currentYear = DateTime.now().year.toString();
          final thisYear = items
              .where(
                (item) =>
                    '${item['document_date'] ?? item['upload_date'] ?? ''}'
                        .startsWith(currentYear),
              )
              .length;
          final types =
              items.map((e) => '${e['document_type']}').toSet().toList()
                ..sort();
          final owners =
              items
                  .map(
                    (e) => e['external_client_id'] != null
                        ? 'external:${e['external_client_id']}'
                        : 'client:${e['client_id']}',
                  )
                  .where((e) => !e.endsWith('null'))
                  .toSet()
                  .toList()
                ..sort();
          final months =
              items
                  .map((e) => '${e['document_date'] ?? e['upload_date'] ?? ''}')
                  .where((e) => e.length >= 7)
                  .map((e) => e.substring(0, 7))
                  .toSet()
                  .toList()
                ..sort((a, b) => b.compareTo(a));
          return Column(
            children: [
              SummaryGrid(
                items: [
                  SummaryItem(
                    'Toplam',
                    '${items.length}',
                    Icons.folder_outlined,
                  ),
                  SummaryItem(
                    'Bu yıl',
                    '$thisYear',
                    Icons.event_available_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _typeFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Belge türü'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tüm türler')),
                  ...types.map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(
                        _documentTypes[type] ?? type,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _typeFilter = value ?? ''),
              ),
              if (!isClient) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _ownerFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mükellef'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tüm mükellefler'),
                    ),
                    ...owners.map(
                      (owner) => DropdownMenuItem(
                        value: owner,
                        child: Text(
                          owner.startsWith('external:')
                              ? 'Harici mükellef #${owner.split(':').last}'
                              : 'Mükellef #${owner.split(':').last}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _ownerFilter = value ?? ''),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _monthFilter,
                decoration: const InputDecoration(labelText: 'Belge ayı'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tüm aylar')),
                  ...months.map(
                    (month) =>
                        DropdownMenuItem(value: month, child: Text(month)),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _monthFilter = value ?? ''),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.picture_as_pdf_outlined,
          title: _text(item['file_name'], 'Belge'),
          subtitle:
              '${_documentTypes[item['document_type']] ?? item['document_type'] ?? 'Belge'} · ${dateText(item['document_date'] ?? item['upload_date'])}',
          value: dateText(item['upload_date']),
          valueSubtitle: 'Yükleme',
          onTap: () => _openDocument(item),
        ),
        trailing: IconButton.filled(
          onPressed: () => _uploadSheet(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Belge yükle',
          icon: const Icon(Icons.upload_file_rounded),
        ),
      ),
    );
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final id = (document['id'] as num?)?.toInt();
    if (id == null) return;
    final name = '${document['file_name'] ?? 'Belge'}';
    final companyTypes = const {
      'FIRMA_EVRAK',
      'IMZA_SIRKULERI',
      'VERGI_LEVHASI',
      'TICARET_SICIL',
      'ANA_SOZLESME',
      'FAALIYET_BELGESI',
    };
    final canDelete =
        !isClient || companyTypes.contains(document['document_type']);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${_documentTypes[document['document_type']] ?? document['document_type'] ?? 'Belge'} · ${dateText(document['document_date'] ?? document['upload_date'])}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Önizle'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final url = await api.documentPreviewUrl(id);
                  final opened = await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened) throw ApiException('Önizleme açılamadı');
                } catch (error) {
                  if (mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$error')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('İndir'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final bytes = await api.downloadDocument(id);
                  final safeName = name.replaceAll(
                    RegExp(r'[\\/:*?"<>|]'),
                    '_',
                  );
                  final saved = await FilePicker.saveFile(
                    fileName: safeName,
                    bytes: bytes,
                    mimeType: safeName.toLowerCase().endsWith('.pdf')
                        ? 'application/pdf'
                        : 'application/octet-stream',
                  );
                  if (saved != null && mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Belge kaydedildi.')),
                    );
                } catch (error) {
                  if (mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$error')));
                }
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Sil'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Belgeyi sil'),
                      content: Text('$name silinsin mi?'),
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
                  if (confirmed != true) return;
                  try {
                    await api.deleteDocument(id);
                    if (mounted) setState(() => _localRefresh++);
                  } catch (error) {
                    if (mounted)
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$error')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  static const _documentTypes = <String, String>{
    'KDV1_BEYANNAME': 'KDV Beyannamesi',
    'KDV1_TAHAKKUK': 'KDV Tahakkuku',
    'MUHSGK_BEYANNAME': 'Muhtasar Beyanname',
    'MUHSGK_TAHAKKUK': 'Muhtasar Tahakkuk',
    'GGECICI_BEYANNAME': 'Geçici Vergi Beyannamesi',
    'GGECICI_TAHAKKUK': 'Geçici Vergi Tahakkuku',
    'KURUMLAR_BEYANNAME': 'Kurumlar Beyannamesi',
    'KURUMLAR_TAHAKKUK': 'Kurumlar Tahakkuku',
    'BABS': 'BA-BS Formu',
    'DAMGA': 'Damga Vergisi',
    'FIRMA_EVRAK': 'Firma Evrakı',
    'IMZA_SIRKULERI': 'İmza Sirküleri',
    'VERGI_LEVHASI': 'Vergi Levhası',
    'TICARET_SICIL': 'Ticaret Sicil',
    'ANA_SOZLESME': 'Ana Sözleşme',
    'FAALIYET_BELGESI': 'Faaliyet Belgesi',
    'DIGER': 'Diğer',
  };

  /// Belge yükleme: mükellef ve belge türü seçilir, dosya telefondan seçilir.
  Future<void> _uploadSheet(BuildContext context) async {
    var selectedClient = clientId;
    var documentType = _documentTypes.keys.first;
    var documentDate = '';
    var uploading = false;
    List<Map<String, dynamic>> clients = const [];
    if (!isClient) {
      try {
        clients = await api.clients();
        if (clients.isNotEmpty) {
          selectedClient ??= int.tryParse('${clients.first['user_id']}');
        }
      } catch (_) {
        // Mükellef listesi alınamazsa yükleme yapılamaz.
      }
    }
    if (!context.mounted) return;
    if (selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir mükellef seçmelisiniz.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belge Yükle',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bir veya daha fazla PDF seçin; belgeler mükellefin dosyasına eklenir.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (!isClient && clients.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: selectedClient,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mükellef',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: clients
                        .map(
                          (client) => DropdownMenuItem<int>(
                            value: int.tryParse('${client['user_id']}'),
                            child: Text(
                              client['company_title']?.toString() ?? 'Mükellef',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheetState(() => selectedClient = value),
                  ),
                if (!isClient && clients.isNotEmpty) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: documentType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Belge Türü',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _documentTypes.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => documentType = value ?? documentType),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Belge tarihi (YYYY-AA-GG, isteğe bağlı)',
                  ),
                  onChanged: (value) => documentDate = value.trim(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (documentDate.isNotEmpty &&
                                  !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                      .hasMatch(documentDate)) {
                                throw ArgumentError(
                                  'Tarih YYYY-AA-GG biçiminde olmalı',
                                );
                              }
                              final picked = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const ['pdf'],
                              );
                              if (picked.isEmpty) return;
                              final paths = picked
                                  .map((file) => file.path)
                                  .whereType<String>()
                                  .toList();
                              if (paths.length != picked.length) {
                                throw ApiException(
                                  'Seçilen PDF dosyaları okunamadı',
                                );
                              }
                              if (sheetContext.mounted)
                                setSheetState(() => uploading = true);
                              final uploaded = await api.uploadDocuments(
                                clientId: selectedClient!,
                                documentType: documentType,
                                filePaths: paths,
                                documentDate: documentDate,
                              );
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${uploaded.length} belge yüklendi',
                                  ),
                                ),
                              );
                              if (mounted) setState(() => _localRefresh++);
                            } catch (error) {
                              if (sheetContext.mounted)
                                setSheetState(() => uploading = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      uploading
                          ? 'Yükleniyor...'
                          : 'PDF Dosyalarını Seç ve Yükle',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tahsilatlar (müşavir) ve Ödemelerim (mükellef).
class PaymentsListPage extends StatelessWidget {
  const PaymentsListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(isClient ? 'Ödemelerim' : 'Tahsilatlar')),
      body: ApiListPage(
        title: isClient ? 'Ödemelerim' : 'Tahsilatlar',
        subtitle: isClient
            ? 'Abonelik, müşavirlik ücreti ve ek ücret ödemeleriniz.'
            : 'Tahsil edilen ödemeler, ek ücretler ve taksitler.',
        refreshKey: refreshKey,
        trailing: isClient
            ? IconButton.filled(
                onPressed: () => _startPayment(context),
                style: IconButton.styleFrom(
                  backgroundColor: FinkitColors.ink,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Ödeme yap',
                icon: const Icon(Icons.credit_card_rounded),
              )
            : IconButton.filled(
                onPressed: () => _manualPaymentSheet(context),
                style: IconButton.styleFrom(
                  backgroundColor: FinkitColors.ink,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Ödeme kaydet',
                icon: const Icon(Icons.add_card_rounded),
              ),
        loader: () async {
          final items = isClient
              ? await api.myPayments()
              : await api.paymentHistory();
          return items;
        },
        searchHint: 'Açıklama veya dönem ara',
        searchText: (item) =>
            '${item['description']} ${item['period_month']} ${item['payment_method']}',
        emptyIcon: Icons.payments_outlined,
        emptyTitle: 'Ödeme kaydı yok',
        emptyDescription: 'Bu dönemde ödeme hareketi bulunmuyor.',
        summaryBuilder: (items) {
          final paid = items
              .where((item) => item['status'] == 'PAID')
              .fold<double>(
                0,
                (sum, item) =>
                    sum + (double.tryParse('${item['amount'] ?? 0}') ?? 0),
              );
          return SummaryGrid(
            items: [
              SummaryItem(
                'Kayıt',
                '${items.length}',
                Icons.receipt_long_outlined,
              ),
              SummaryItem(
                'Tahsil edilen',
                moneyText(paid),
                Icons.savings_outlined,
              ),
            ],
          );
        },
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.payments_outlined,
          title: _text(item['description'] ?? item['payment_purpose'], 'Ödeme'),
          subtitle:
              '${dateText(item['payment_date'])} · ${statusLabel(item['payment_method']?.toString())}',
          value: moneyText(item['amount']),
          valueSubtitle: statusLabel(item['status']?.toString()),
          status: item['status']?.toString(),
        ),
      ),
    );
  }

  /// Uygulama içi PayTR ödeme akışı; başarısız olursa web paneli önerilir.
  Future<void> _startPayment(BuildContext context, {int? extraChargeId}) =>
      startInAppPayment(context, api, extraChargeId: extraChargeId);

  /// Müşavir elle ödeme (nakit/havale) kaydeder.
  Future<void> _manualPaymentSheet(BuildContext context) async {
    List<Map<String, dynamic>> clients = const [];
    try {
      clients = await api.clients();
    } catch (_) {
      // Mükellef listesi alınamazsa kayıt yapılamaz.
    }
    if (!context.mounted) return;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce mükellef eklemelisiniz.')),
      );
      return;
    }
    var clientId = int.tryParse('${clients.first['user_id']}');
    final amount = TextEditingController();
    final description = TextEditingController();
    var method = 'havale_eft';
    var status = 'PAID';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ödeme Kaydet',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mükellef',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: clients
                      .map(
                        (client) => DropdownMenuItem<int>(
                          value: int.tryParse('${client['user_id']}'),
                          child: Text(
                            _text(client['company_title'], 'Mükellef'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => clientId = value ?? clientId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tutar (₺)',
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ödeme Yöntemi',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'nakit', child: Text('Nakit')),
                    DropdownMenuItem(
                      value: 'havale_eft',
                      child: Text('Havale / EFT'),
                    ),
                    DropdownMenuItem(
                      value: 'kredi_karti',
                      child: Text('Kredi kartı'),
                    ),
                    DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => method = value ?? method),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'PAID', label: Text('Ödendi')),
                    ButtonSegment(value: 'PENDING', label: Text('Bekliyor')),
                  ],
                  selected: {status},
                  onSelectionChanged: (value) =>
                      setSheetState(() => status = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final parsed = double.tryParse(
                        amount.text.replaceAll(',', '.'),
                      );
                      if (clientId == null || parsed == null || parsed <= 0) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await api.createManualPayment(
                          clientId: clientId!,
                          amount: parsed,
                          paymentMethod: method,
                          paymentStatus: status,
                          description: description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Ödeme kaydedildi')),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Ödemeyi Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amount.dispose();
    description.dispose();
  }
}

/// E-Fatura: müşavir kendi hesabını, mükellef kendi gelen kutusunu görür.
class EInvoiceListPage extends StatelessWidget {
  const EInvoiceListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
    this.initialIndex = 0,
    this.documentType = 'EINVOICE',
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;
  final int initialIndex;
  final String documentType;

  @override
  Widget build(BuildContext context) {
    final isArchive = documentType == 'EARCHIVE';
    return DefaultTabController(
      length: isArchive ? 1 : 2,
      initialIndex: isArchive ? 0 : initialIndex,
      child: Scaffold(
        backgroundColor: FinkitColors.canvas,
        appBar: AppBar(
          title: Text(isArchive ? 'E-Arşiv Faturalar' : 'E-Fatura'),
          bottom: TabBar(
            tabs: [
              Tab(text: isArchive ? 'E-Arşiv' : 'Giden'),
              if (!isArchive) const Tab(text: 'Gelen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ElectronicInvoiceBox(
              api: api,
              isClient: isClient,
              incoming: false,
              documentType: documentType,
              refreshKey: refreshKey,
            ),
            if (!isArchive)
              ElectronicInvoiceBox(
                api: api,
                isClient: isClient,
                incoming: true,
                documentType: documentType,
                refreshKey: refreshKey,
              ),
          ],
        ),
      ),
    );
  }
}

/// Takvim: etkinlikler ve hatırlatıcı kuralları.
///
/// Yaklaşan etkinlikler için telefondan sistem bildirimi planlanır.
class CalendarListPage extends StatefulWidget {
  const CalendarListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    this.isClient = false,
    this.userId,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;
  final int? userId;

  @override
  State<CalendarListPage> createState() => _CalendarListPageState();
}

class _CalendarListPageState extends State<CalendarListPage> {
  int _localRefresh = 0;
  bool _showGib = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  void _reload() => setState(() => _localRefresh++);

  int _notificationId(int eventId, int offset) =>
      1000000 + eventId * 2 + offset;

  Future<void> _cancelEventNotifications(int eventId) async {
    await AppNotifications.instance.cancel(_notificationId(eventId, 0));
    await AppNotifications.instance.cancel(_notificationId(eventId, 1));
  }

  /// Yenilenen etkinliğin eski bildirimlerini kaldırıp iki zamanı planlar.
  Future<void> _scheduleReminders(List<Map<String, dynamic>> events) async {
    final now = DateTime.now();
    for (final event in events.take(40)) {
      final eventId = int.tryParse('${event['id']}');
      if (eventId == null) continue;
      await _cancelEventNotifications(eventId);
      if (event['is_notification_active'] == false) continue;
      final date = DateTime.tryParse('${event['event_date']}');
      if (date == null || date.isBefore(now)) continue;
      final remindAt = date.subtract(const Duration(days: 1));
      if (remindAt.isAfter(now)) {
        await AppNotifications.instance.scheduleAt(
          remindAt,
          title: 'Hatırlatıcı: ${event['title'] ?? 'Etkinlik'}',
          body: '${dateText(event['event_date'])} tarihinde etkinliğiniz var.',
          id: _notificationId(eventId, 0),
        );
      }
      final shortlyBefore = date.subtract(const Duration(minutes: 15));
      if (shortlyBefore.isAfter(now)) {
        await AppNotifications.instance.scheduleAt(
          shortlyBefore,
          title: 'Hatırlatıcı: ${event['title'] ?? 'Etkinlik'}',
          body: 'Etkinliğiniz 15 dakika sonra başlayacak.',
          id: _notificationId(eventId, 1),
        );
      }
    }
  }

  Future<void> _showEventDetails(
    Map<String, dynamic> item, {
    required bool canManage,
  }) async {
    final isGib = item['_is_gib'] == true;
    final isDue = item['_is_due'] == true;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(item['title'])),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarih: ${dateText(item[isGib ? 'stopdate' : 'event_date'])}',
              ),
              if (_text(item['description'], '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${item['description']}'),
              ],
              if (isGib && _text(item['period'], '').isNotEmpty)
                Text('Dönem: ${item['period']}'),
              if (isDue && item['monthly_fee'] != null)
                Text('Aylık ücret: ${item['monthly_fee']} TL'),
              if (!isGib && !isDue)
                Text(
                  'Bildirim: ${item['is_notification_active'] == false ? 'Kapalı' : 'Açık'}',
                ),
            ],
          ),
        ),
        actions: [
          if (canManage)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              child: const Text('Sil'),
            ),
          if (canManage)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Text('Düzenle'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _createReminderSheet(context, event: item);
      return;
    }
    if (action != 'delete') return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Etkinliği sil'),
        content: Text('${item['title']} etkinliği silinsin mi?'),
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
      final id = int.parse('${item['id']}');
      await widget.api.deleteCalendarEvent(id);
      await _cancelEventNotifications(id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Etkinlik silindi')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _monthGrid(List<Map<String, dynamic>> items) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
    const weekdayNames = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final date = DateTime.tryParse(
        '${item[item['_is_gib'] == true ? 'stopdate' : 'event_date']}',
      );
      if (date == null ||
          date.year != _month.year ||
          date.month != _month.month) {
        continue;
      }
      byDay.putIfAbsent(date.day, () => []).add(item);
    }
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final name in weekdayNames)
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FinkitColors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final day = index - firstWeekday + 1;
              if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
              final dayItems = byDay[day] ?? [];
              return InkWell(
                key: ValueKey('calendar-day-$day'),
                onTap: () => _showDay(day, dayItems),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: dayItems.isEmpty
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    if (dayItems.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayItems.any((item) => item['_is_gib'] == true))
                            const _CalendarDot(Colors.red),
                          if (dayItems.any((item) => item['_is_due'] == true))
                            const _CalendarDot(Colors.blue),
                          if (dayItems.any(
                            (item) =>
                                item['_is_gib'] != true &&
                                item['_is_due'] != true,
                          ))
                            const _CalendarDot(Colors.green),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDay(int day, List<Map<String, dynamic>> items) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              '$day ${_monthNames[_month.month - 1]} ${_month.year}',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty) const Text('Bu gün için kayıt yok.'),
            for (final item in items)
              ListTile(
                title: Text('${item['title'] ?? 'Kayıt'}'),
                subtitle: Text(
                  item['_is_gib'] == true
                      ? 'GİB vergi tarihi'
                      : item['_is_due'] == true
                      ? 'Ödeme vadesi'
                      : 'Etkinlik',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEventDetails(item, canManage: _canManage(item));
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _canManage(Map<String, dynamic> item) =>
      item['_is_gib'] != true &&
      item['_is_due'] != true &&
      (!widget.isClient ||
          (widget.userId != null &&
              int.tryParse('${item['target_client_id']}') == widget.userId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(
        title: const Text('Takvim ve Hatırlatıcılar'),
        actions: [
          IconButton(
            tooltip: 'Etkinlik şablonları',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CalendarTemplatesPage(api: widget.api),
              ),
            ),
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      ),
      body: ApiListPage(
        title: 'Takvim',
        subtitle: 'Etkinlikler ve hatırlatıcılar. Yaklaşan etkinlikler için bildirim planlanır.',
        refreshKey: widget.refreshKey + _localRefresh,
        trailing: IconButton.filled(
          onPressed: () => _createReminderSheet(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Etkinlik ekle',
          icon: const Icon(Icons.add_alarm_rounded),
        ),
        loader: () async {
          final events = await widget.api.calendarEvents();
          await _scheduleReminders(events);
          final start = DateTime(_month.year, _month.month, 1);
          final end = DateTime(_month.year, _month.month + 1, 0);
          String day(DateTime value) =>
              '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
          final dueDates = <Map<String, dynamic>>[];
          try {
            final clients = widget.isClient
                ? [await widget.api.clientProfile()]
                : await widget.api.clients();
            for (final client in clients) {
              final dueDay = int.tryParse('${client['payment_due_day']}');
              if (dueDay == null || dueDay < 1 || dueDay > end.day) continue;
              dueDates.add({
                '_is_due': true,
                'title': '${client['company_title'] ?? 'Hizmet'} ödeme vadesi',
                'description': client['payment_status'] ?? 'Ödeme günü',
                'event_date': DateTime(
                  _month.year,
                  _month.month,
                  dueDay,
                ).toIso8601String(),
                'monthly_fee': client['monthly_fee'],
              });
            }
          } catch (_) {
            // Vade katmanı yüklenemese de kişisel etkinlikler görünür.
          }
          if (!_showGib) return [...events, ...dueDates];
          try {
            final taxDates = await widget.api.gibTaxCalendar(
              startDate: day(start),
              endDate: day(end),
            );
            return [
              ...events,
              ...dueDates,
              ...taxDates.map((item) => {...item, '_is_gib': true}),
            ];
          } catch (_) {
            // Vergi takvimi sağlayıcısı erişilemese de kişisel takvim açılır.
            return [...events, ...dueDates];
          }
        },
        trailingActions: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Önceki ay',
                  onPressed: _month.year <= 2020 && _month.month == 1
                      ? null
                      : () {
                          _month = DateTime(_month.year, _month.month - 1);
                          _reload();
                        },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki ay',
                  onPressed: _month.year >= 2099 && _month.month == 12
                      ? null
                      : () {
                          _month = DateTime(_month.year, _month.month + 1);
                          _reload();
                        },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                FilterChip(
                  label: const Text('GİB'),
                  selected: _showGib,
                  onSelected: (value) {
                    _showGib = value;
                    _reload();
                  },
                ),
              ],
            ),
          ),
        ],
        filter: (item) {
          final value = item['_is_gib'] == true
              ? item['stopdate']
              : item['event_date'];
          final day = DateTime.tryParse('$value');
          return day != null &&
              day.year == _month.year &&
              day.month == _month.month;
        },
        searchHint: 'Etkinlik veya vergi tarihi ara',
        searchText: (item) =>
            '${item['title'] ?? ''} ${item['description'] ?? ''}',
        summaryBuilder: _monthGrid,
        emptyIcon: Icons.calendar_month_outlined,
        emptyTitle: 'Etkinlik yok',
        emptyDescription: 'Yaklaşan hatırlatıcı bulunmuyor.',
        itemBuilder: (context, item) {
          final isGib = item['_is_gib'] == true;
          final isDue = item['_is_due'] == true;
          return DataRowCard(
            icon: isGib
                ? Icons.account_balance_outlined
                : isDue
                ? Icons.payments_outlined
                : Icons.event_outlined,
            title: _text(
              item['title'],
              isGib
                  ? 'GİB vergi tarihi'
                  : isDue
                  ? 'Ödeme vadesi'
                  : 'Etkinlik',
            ),
            subtitle: _text(
              item['description'] ?? item['event_type'] ?? '',
              statusLabel(item['event_type']?.toString()),
            ),
            value: dateText(item[isGib ? 'stopdate' : 'event_date']),
            valueSubtitle: isGib
                ? 'Son gün'
                : isDue
                ? 'Vade'
                : 'Tarih',
            status: item['event_type']?.toString(),
            onTap: () => _showEventDetails(item, canManage: _canManage(item)),
          );
        },
      ),
    );
  }

  /// Etkinlik ekler veya mevcut etkinliği düzenler.
  Future<void> _createReminderSheet(
    BuildContext context, {
    Map<String, dynamic>? event,
  }) async {
    var title = event?['title']?.toString() ?? '';
    var description = event?['description']?.toString() ?? '';
    var when =
        DateTime.tryParse('${event?['event_date']}') ??
        DateTime.now().add(const Duration(days: 1));
    var eventType = event?['event_type']?.toString() ?? 'PERSONAL';
    var target = event?['target_external_client_id'] != null
        ? 'external:${event!['target_external_client_id']}'
        : event?['target_client_id'] != null
        ? 'client:${event!['target_client_id']}'
        : '';
    var notificationActive = event?['is_notification_active'] != false;
    var saving = false;
    String selectedTemplate = '';
    final clients = widget.isClient
        ? <Map<String, dynamic>>[]
        : await widget.api.clients().catchError(
            (_) => <Map<String, dynamic>>[],
          );
    final externalClients = widget.isClient
        ? <Map<String, dynamic>>[]
        : await widget.api.externalClients().catchError(
            (_) => <Map<String, dynamic>>[],
          );
    final templates = event == null
        ? await widget.api.eventTemplates().catchError(
            (_) => <Map<String, dynamic>>[],
          )
        : <Map<String, dynamic>>[];
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event == null ? 'Yeni Etkinlik' : 'Etkinliği Düzenle',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Etkinlikten bir gün önce ve 15 dakika önce bildirim gönderilir.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (event == null && templates.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Şablon Kullan',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Şablon seçiniz'),
                      ),
                      for (final template in templates)
                        DropdownMenuItem(
                          value: '${template['id']}',
                          child: Text(
                            '${template['title']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      final template = templates
                          .where((item) => '${item['id']}' == value)
                          .firstOrNull;
                      if (template == null) return;
                      setSheetState(() {
                        selectedTemplate = value ?? '';
                        title = '${template['title'] ?? ''}';
                        description = '${template['description'] ?? ''}';
                        eventType = '${template['event_type'] ?? 'PERSONAL'}';
                        final base = DateTime.now();
                        final offset =
                            int.tryParse('${template['days_offset']}') ?? 0;
                        when = DateTime(
                          base.year,
                          base.month,
                          base.day + offset,
                          9,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: ValueKey('event_title_$selectedTemplate'),
                  initialValue: title,
                  onChanged: (value) => title = value,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('event_description_$selectedTemplate'),
                  initialValue: description,
                  onChanged: (value) => description = value,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                if (!widget.isClient) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('event_type_$selectedTemplate'),
                    isExpanded: true,
                    initialValue:
                        ['PERSONAL', 'ALL', 'CLIENT'].contains(eventType)
                        ? eventType
                        : 'PERSONAL',
                    decoration: const InputDecoration(labelText: 'Görünürlük'),
                    items: const [
                      DropdownMenuItem(
                        value: 'PERSONAL',
                        child: Text('Kişisel'),
                      ),
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text('Tüm mükellefler'),
                      ),
                      DropdownMenuItem(
                        value: 'CLIENT',
                        child: Text('Belirli mükellef'),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() {
                      eventType = value ?? 'PERSONAL';
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (eventType == 'CLIENT') ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: target.isEmpty ? '' : target,
                      decoration: const InputDecoration(labelText: 'Mükellef'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Seçiniz'),
                        ),
                        if (target.isNotEmpty &&
                            !clients.any(
                              (client) =>
                                  'client:${client['user_id']}' == target,
                            ) &&
                            !externalClients.any(
                              (client) => 'external:${client['id']}' == target,
                            ))
                          DropdownMenuItem(
                            value: target,
                            child: const Text('Mevcut mükellef'),
                          ),
                        for (final client in clients)
                          if (client['user_id'] != null)
                            DropdownMenuItem(
                              value: 'client:${client['user_id']}',
                              child: Text(
                                _text(
                                  client['company_title'] ??
                                      client['full_name'],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        for (final client in externalClients)
                          if (client['id'] != null)
                            DropdownMenuItem(
                              value: 'external:${client['id']}',
                              child: Text(
                                '[Harici] ${_text(client['company_title'] ?? client['name'])}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                      onChanged: (value) => target = value ?? '',
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bildirim gönder'),
                  value: notificationActive,
                  onChanged: (value) =>
                      setSheetState(() => notificationActive = value),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: sheetContext,
                      initialDate: when,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date == null) return;
                    if (!sheetContext.mounted) return;
                    final time = await showTimePicker(
                      context: sheetContext,
                      initialTime: TimeOfDay.fromDateTime(when),
                    );
                    setSheetState(() {
                      when = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time?.hour ?? 9,
                        time?.minute ?? 0,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tarih ve Saat',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      '${dateText(when)} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final text = title.trim();
                            if (text.isEmpty) return;
                            if (!widget.isClient &&
                                eventType == 'CLIENT' &&
                                target.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mükellef seçin')),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final descriptionValue = description.trim();
                              if (event == null) {
                                await widget.api.createCalendarEvent(
                                  title: text,
                                  description: descriptionValue.isEmpty
                                      ? null
                                      : descriptionValue,
                                  eventDate: when.toIso8601String(),
                                  eventType: widget.isClient
                                      ? 'CLIENT'
                                      : eventType,
                                  targetClientId:
                                      eventType == 'CLIENT' &&
                                          target.startsWith('client:')
                                      ? int.tryParse(target.substring(7))
                                      : null,
                                  targetExternalClientId:
                                      eventType == 'CLIENT' &&
                                          target.startsWith('external:')
                                      ? int.tryParse(target.substring(9))
                                      : null,
                                  isNotificationActive: notificationActive,
                                );
                              } else {
                                await widget.api.updateCalendarEvent(
                                  int.parse('${event['id']}'),
                                  title: text,
                                  description: descriptionValue.isEmpty
                                      ? null
                                      : descriptionValue,
                                  eventDate: when.toIso8601String(),
                                  eventType: widget.isClient
                                      ? 'CLIENT'
                                      : eventType,
                                  targetClientId:
                                      eventType == 'CLIENT' &&
                                          target.startsWith('client:')
                                      ? int.tryParse(target.substring(7))
                                      : null,
                                  targetExternalClientId:
                                      eventType == 'CLIENT' &&
                                          target.startsWith('external:')
                                      ? int.tryParse(target.substring(9))
                                      : null,
                                  isNotificationActive: notificationActive,
                                );
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) _reload();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    event == null
                                        ? 'Etkinlik kaydedildi'
                                        : 'Etkinlik güncellendi',
                                  ),
                                ),
                              );
                            } catch (error) {
                              setSheetState(() => saving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Mesaj şablonları.
class TemplatesListPage extends StatefulWidget {
  const TemplatesListPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<TemplatesListPage> createState() => _TemplatesListPageState();
}

class _TemplatesListPageState extends State<TemplatesListPage> {
  int _localRefresh = 0;

  void _reload() => setState(() => _localRefresh++);

  Future<void> _form([Map<String, dynamic>? template]) async {
    var name = '${template?['name'] ?? ''}';
    var content = '${template?['content'] ?? ''}';
    var type = '${template?['template_type'] ?? 'email'}';
    var contentRevision = 0;
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
                  template == null ? 'Yeni Şablon' : 'Şablonu Düzenle',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Şablon Adı'),
                  onChanged: (value) => name = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ['email', 'sms', 'whatsapp'].contains(type)
                      ? type
                      : 'email',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tür'),
                  items: const [
                    DropdownMenuItem(value: 'email', child: Text('E-posta')),
                    DropdownMenuItem(value: 'sms', child: Text('SMS')),
                    DropdownMenuItem(
                      value: 'whatsapp',
                      child: Text('WhatsApp'),
                    ),
                  ],
                  onChanged: (value) => type = value ?? 'email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('template_content_$contentRevision'),
                  initialValue: content,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'İçerik'),
                  onChanged: (value) => content = value,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final variable in const [
                      '[Ad]',
                      '[Ay]',
                      '[Borc]',
                      '[OdemeLinki]',
                      '[Tarih]',
                    ])
                      ActionChip(
                        label: Text(variable),
                        onPressed: () => refresh(() {
                          content += variable;
                          contentRevision++;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.trim().isEmpty || content.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Ad ve içerik gerekli'),
                              ),
                            );
                            return;
                          }
                          refresh(() => saving = true);
                          try {
                            await widget.api.saveMessageTemplate(
                              id: template == null
                                  ? null
                                  : int.parse('${template['id']}'),
                              name: name.trim(),
                              content: content.trim(),
                              type: type,
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
                  child: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Map<String, dynamic> template) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şablonu sil'),
        content: Text('${template['name']} şablonu silinsin mi?'),
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
      await widget.api.deleteMessageTemplate(int.parse('${template['id']}'));
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
      appBar: AppBar(title: const Text('Şablonlar')),
      body: ApiListPage(
        title: 'Mesaj Şablonları',
        subtitle: 'Mükelleflere gönderdiğiniz hazır mesajlar.',
        refreshKey: widget.refreshKey + _localRefresh,
        loader: widget.api.messageTemplates,
        trailing: IconButton.filled(
          tooltip: 'Yeni şablon',
          onPressed: () => _form(),
          icon: const Icon(Icons.add_rounded),
        ),
        searchHint: 'Şablon ara',
        searchText: (item) => '${item['name'] ?? ''} ${item['content'] ?? ''}',
        emptyIcon: Icons.article_outlined,
        emptyTitle: 'Şablon yok',
        emptyDescription: 'Henüz mesaj şablonu oluşturulmamış.',
        itemBuilder: (context, item) => SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(item['name'], 'Şablon'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                statusLabel(item['template_type']?.toString()),
                style: const TextStyle(color: FinkitColors.muted),
              ),
              const SizedBox(height: 8),
              Text(_text(item['content'], '')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: '${item['content'] ?? ''}'),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İçerik kopyalandı')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Kopyala'),
                  ),
                  TextButton.icon(
                    onPressed: () => _form(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Düzenle'),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Sil'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destek talepleri.
class SupportListPage extends StatelessWidget {
  const SupportListPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Destek')),
      body: ApiListPage(
        title: 'Destek Talepleri',
        subtitle: 'Destek ekibine ilettiğiniz talepler ve yanıtlar.',
        refreshKey: refreshKey,
        trailing: IconButton.filled(
          onPressed: () => _createTicket(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Yeni destek talebi',
          icon: const Icon(Icons.add_comment_outlined),
        ),
        loader: api.supportTickets,
        emptyIcon: Icons.support_agent_outlined,
        emptyTitle: 'Talep yok',
        emptyDescription: 'Henüz destek talebi oluşturmadınız.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.support_agent_outlined,
          title: _text(item['subject'], 'Destek talebi'),
          subtitle:
              '${_text(item['message'], '').split(' ').take(8).join(' ')} · ${dateText(item['created_at'])}',
          value: statusLabel(item['status']?.toString()),
          valueSubtitle: 'Durum',
          status: item['status']?.toString(),
        ),
      ),
    );
  }

  Future<void> _createTicket(BuildContext context) async {
    final subject = TextEditingController();
    final message = TextEditingController();
    String name = '';
    String contact = '';
    try {
      final me = await api.me();
      name = me['full_name']?.toString() ?? '';
      contact = me['email']?.toString() ?? '';
    } catch (_) {
      // Kullanıcı bilgisi alınamazsa alanlar boş kalır.
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni Destek Talebi',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: subject,
              decoration: const InputDecoration(
                labelText: 'Konu',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mesaj',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (subject.text.trim().isEmpty ||
                      message.text.trim().isEmpty) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await api.createSupportTicket(
                      name: name.isEmpty ? 'Finkit Kullanıcı' : name,
                      contact: contact.isEmpty ? 'uygulama' : contact,
                      subject: subject.text.trim(),
                      message: message.text.trim(),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Talebiniz iletildi')),
                    );
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Talebi Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    message.dispose();
  }
}

/// Forum konuları.
class ForumListPage extends StatelessWidget {
  const ForumListPage({super.key, required this.api, required this.refreshKey});

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Forum')),
      body: ApiListPage(
        title: 'Forum',
        subtitle: 'Müşavirler arası soru, cevap ve deneyim paylaşımı.',
        refreshKey: refreshKey,
        trailing: IconButton.filled(
          onPressed: () => _createTopic(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Yeni konu',
          icon: const Icon(Icons.add_rounded),
        ),
        loader: api.forumTopics,
        emptyIcon: Icons.forum_outlined,
        emptyTitle: 'Konu yok',
        emptyDescription: 'Henüz forum konusu açılmamış.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.forum_outlined,
          title: _text(item['title'], 'Konu'),
          subtitle:
              '${_text(item['author_name'] ?? item['category_name'], '')} · ${dateText(item['created_at'])}',
          value: '${item['post_count'] ?? item['reply_count'] ?? 0}',
          valueSubtitle: 'Yanıt',
          onTap: () {
            final topicId = int.tryParse('${item['id']}');
            if (topicId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForumTopicPage(
                  api: api,
                  topicId: topicId,
                  title: _text(item['title'], 'Konu'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createTopic(BuildContext context) async {
    final title = TextEditingController();
    final content = TextEditingController();
    List<Map<String, dynamic>> categories = const [];
    try {
      categories = await api.forumCategories();
    } catch (_) {
      // Kategori alınamazsa konu açılamaz.
    }
    if (!context.mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forum kategorisi bulunamadı.')),
      );
      return;
    }
    var categoryId = int.tryParse('${categories.first['id']}');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni Forum Konusu',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<int>(
                        value: int.tryParse('${category['id']}'),
                        child: Text(
                          _text(category['name'], 'Kategori'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setSheetState(() => categoryId = value ?? categoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'İçerik',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (categoryId == null ||
                        title.text.trim().isEmpty ||
                        content.text.trim().isEmpty) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await api.createForumTopic(
                        categoryId: categoryId!,
                        title: title.text.trim(),
                        content: content.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Konu açıldı')),
                      );
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Konuyu Aç'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();
    content.dispose();
  }
}

/// Duyurular ve GİB haberleri.
class AnnouncementsListPage extends StatelessWidget {
  const AnnouncementsListPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Duyurular')),
      body: ApiListPage(
        title: 'Duyurular',
        subtitle: 'Platform ve GİB duyuruları.',
        refreshKey: refreshKey,
        loader: () async {
          final platform = await api.announcements();
          final gib = await api.gibAnnouncements();
          return [...platform, ...gib];
        },
        emptyIcon: Icons.campaign_outlined,
        emptyTitle: 'Duyuru yok',
        emptyDescription: 'Şu anda yayınlanmış duyuru bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.campaign_outlined,
          title: _text(item['title'], 'Duyuru'),
          subtitle: _text(item['content'] ?? item['summary'], ''),
          value: dateText(item['created_at'] ?? item['publish_date']),
          valueSubtitle: 'Tarih',
        ),
      ),
    );
  }
}

/// Ek ücretler.
class ExtraChargesListPage extends StatelessWidget {
  const ExtraChargesListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Ek Ücretler')),
      body: ApiListPage(
        title: 'Ek Ücretler',
        subtitle: 'Müşavirlik dışındaki hizmet ve masraf kalemleri.',
        refreshKey: refreshKey,
        trailing: isClient
            ? null
            : IconButton.filled(
                onPressed: () => _createCharge(context),
                style: IconButton.styleFrom(
                  backgroundColor: FinkitColors.ink,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Ek ücret ekle',
                icon: const Icon(Icons.add_rounded),
              ),
        loader: isClient ? api.myExtraCharges : api.extraCharges,
        emptyIcon: Icons.request_quote_outlined,
        emptyTitle: 'Ek ücret yok',
        emptyDescription: 'Tanımlanmış ek ücret bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.request_quote_outlined,
          title: _text(item['name'], 'Ek ücret'),
          subtitle:
              '${_text(item['description'], '')} · Vade ${dateText(item['due_date'])}',
          value: moneyText(item['amount']),
          valueSubtitle: statusLabel(item['status']?.toString()),
          status: item['status']?.toString(),
          onTap: isClient && item['status'] == 'PENDING'
              ? () {
                  final id = int.tryParse('${item['id']}');
                  if (id != null) {
                    startInAppPayment(context, api, extraChargeId: id);
                  }
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _createCharge(BuildContext context) async {
    List<Map<String, dynamic>> clients = const [];
    try {
      clients = await api.clients();
    } catch (_) {
      // Mükellef listesi alınamazsa kayıt yapılamaz.
    }
    if (!context.mounted) return;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce mükellef eklemelisiniz.')),
      );
      return;
    }
    var clientId = int.tryParse('${clients.first['user_id']}');
    final name = TextEditingController();
    final amount = TextEditingController();
    final description = TextEditingController();
    var dueDate = DateTime.now().add(const Duration(days: 15));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Ek Ücret',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mükellef',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: clients
                      .map(
                        (client) => DropdownMenuItem<int>(
                          value: int.tryParse('${client['user_id']}'),
                          child: Text(
                            _text(client['company_title'], 'Mükellef'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => clientId = value ?? clientId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Ücret Adı',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tutar (₺)',
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() => dueDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Vade Tarihi',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(dateText(dueDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final parsed = double.tryParse(
                        amount.text.replaceAll(',', '.'),
                      );
                      if (clientId == null ||
                          parsed == null ||
                          parsed <= 0 ||
                          name.text.trim().isEmpty) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await api.createExtraCharge(
                          clientId: clientId!,
                          name: name.text.trim(),
                          amount: parsed,
                          dueDate: dueDate,
                          description: description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Ek ücret kaydedildi')),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Ek Ücreti Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    amount.dispose();
    description.dispose();
  }
}

/// Taksit planları.
class InstallmentsListPage extends StatelessWidget {
  const InstallmentsListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Taksitler')),
      body: ApiListPage(
        title: 'Taksit Planları',
        subtitle: 'Vadeli ödeme planları ve taksit durumları.',
        refreshKey: refreshKey,
        loader: isClient ? api.myInstallments : api.installments,
        emptyIcon: Icons.calendar_view_month_outlined,
        emptyTitle: 'Taksit planı yok',
        emptyDescription: 'Aktif taksit planı bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.calendar_view_month_outlined,
          title: _text(item['title'] ?? item['name'], 'Taksit planı'),
          subtitle:
              '${item['installment_count'] ?? item['count'] ?? ''} taksit · ${statusLabel(item['status']?.toString())}',
          value: moneyText(item['total_amount'] ?? item['amount']),
          valueSubtitle: 'Toplam',
          status: item['status']?.toString(),
        ),
      ),
    );
  }
}

/// Mükellef istekleri (müşavir) veya danışman arama (mükellef).
class MatchingListPage extends StatelessWidget {
  const MatchingListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(
        title: Text(isClient ? 'Müşavir Taleplerim' : 'Mükellef İstekleri'),
      ),
      body: ApiListPage(
        title: isClient ? 'Müşavir Taleplerim' : 'Mükellef İstekleri',
        subtitle: isClient
            ? 'Eşleşme taleplerinizin durumu.'
            : 'Gelen mükellef eşleşme talepleri.',
        refreshKey: refreshKey,
        loader: isClient ? api.myMatchRequests : api.incomingMatchRequests,
        emptyIcon: Icons.handshake_outlined,
        emptyTitle: 'Talep yok',
        emptyDescription: 'Bekleyen eşleşme talebi bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.handshake_outlined,
          title: _text(
            item['advisor_name'] ?? item['client_name'] ?? item['title'],
            'Eşleşme talebi',
          ),
          subtitle:
              '${_text(item['message'] ?? item['note'], '')} · ${dateText(item['created_at'])}',
          value: statusLabel(item['status']?.toString()),
          valueSubtitle: 'Durum',
          status: item['status']?.toString(),
        ),
      ),
    );
  }
}

/// Danışma soruları.
class DanismaListPage extends StatelessWidget {
  const DanismaListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Danışma')),
      body: ApiListPage(
        title: isClient ? 'Sorularım' : 'Danışma Soruları',
        subtitle: isClient
            ? 'Müşavirlere sorduğunuz sorular ve yanıtları.'
            : 'Yanıt bekleyen danışma soruları.',
        refreshKey: refreshKey,
        trailing: IconButton.filled(
          onPressed: () => _createQuestion(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Soru sor',
          icon: const Icon(Icons.help_outline_rounded),
        ),
        loader: isClient ? api.myDanismaQuestions : api.danismaQuestions,
        emptyIcon: Icons.question_answer_outlined,
        emptyTitle: 'Soru yok',
        emptyDescription: 'Listelenecek soru bulunmuyor.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.question_answer_outlined,
          title: _text(item['title'] ?? item['question'], 'Soru'),
          subtitle:
              '${_text(item['category_name'], '')} · ${dateText(item['created_at'])}',
          value: '${item['answer_count'] ?? 0}',
          valueSubtitle: 'Yanıt',
          status: item['status']?.toString(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DanismaQuestionPage(
                api: api,
                question: item,
                isClient: isClient,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createQuestion(BuildContext context) async {
    final title = TextEditingController();
    final content = TextEditingController();
    List<Map<String, dynamic>> categories = const [];
    try {
      categories = await api.danismaCategories();
    } catch (_) {
      // Kategoriler alınamazsa soru kategorisiz açılır.
    }
    if (!context.mounted) return;
    var categoryId = categories.isNotEmpty
        ? int.tryParse('${categories.first['id']}')
        : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danışma Sorusu',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Sorunuz seçtiğiniz kategoride müşavirlere iletilir.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              if (categories.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem<int>(
                          value: int.tryParse('${category['id']}'),
                          child: Text(
                            _text(category['name'], 'Kategori'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => categoryId = value ?? categoryId),
                ),
              if (categories.isNotEmpty) const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Sorunuz',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (title.text.trim().isEmpty ||
                        content.text.trim().isEmpty) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await api.createDanismaQuestion(
                        title: title.text.trim(),
                        content: content.text.trim(),
                        categoryId: categoryId,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Sorunuz gönderildi')),
                      );
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Soruyu Gönder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();
    content.dispose();
  }
}

/// Profil ve hesap bilgileri.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  void _load() {
    _future = () async {
      final user = await widget.api.me();
      Map<String, dynamic> details = const {};
      try {
        details = widget.isClient
            ? await widget.api.clientProfile()
            : await widget.api.advisorProfile();
      } catch (_) {
        // Profil detayı alınamazsa temel kullanıcı bilgisi gösterilir.
      }
      return {'user': user, 'details': details};
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Profilim')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }
          final user = Map<String, dynamic>.from(
            snapshot.data?['user'] as Map? ?? const {},
          );
          final details = Map<String, dynamic>.from(
            snapshot.data?['details'] as Map? ?? const {},
          );
          final rows = <Widget>[
            _InfoRow('Ad Soyad', _text(user['full_name'])),
            _InfoRow('E-posta', _text(user['email'])),
            _InfoRow('Telefon', _text(user['phone_number'])),
            _InfoRow('Şehir', _text(user['city'])),
            _InfoRow('Rol', statusLabel(user['role']?.toString())),
          ];
          for (final key in _labels(details)) {
            if (const {
              'id',
              'user_id',
              'user',
              'advisor_id',
              'created_at',
              'updated_at',
            }.contains(key)) {
              continue;
            }
            final value = details[key];
            if (value == null || value is Map || value is List) continue;
            rows.add(_InfoRow(_humanize(key), _text(value)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              PageTitle(
                title: 'Profilim',
                subtitle: 'Hesap ve firma bilgileriniz.',
                trailing: IconButton.filled(
                  onPressed: () => _edit(user),
                  style: IconButton.styleFrom(
                    backgroundColor: FinkitColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Bilgileri düzenle',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
              SurfaceCard(child: Column(children: rows)),
            ],
          );
        },
      ),
    );
  }

  /// Ad, telefon ve şehir bilgilerini günceller.
  Future<void> _edit(Map<String, dynamic> user) async {
    final fullName = TextEditingController(
      text: user['full_name']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: user['phone_number']?.toString() ?? '',
    );
    final city = TextEditingController(text: user['city']?.toString() ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bilgileri Düzenle',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: fullName,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: city,
              decoration: const InputDecoration(
                labelText: 'Şehir',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.api.updateProfile(
                      fullName: fullName.text.trim().isEmpty
                          ? null
                          : fullName.text.trim(),
                      phoneNumber: phone.text.trim().isEmpty
                          ? null
                          : phone.text.trim(),
                      city: city.text.trim().isEmpty ? null : city.text.trim(),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profil güncellendi')),
                    );
                    _load();
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
    fullName.dispose();
    phone.dispose();
    city.dispose();
  }

  String _humanize(String key) {
    const map = {
      'full_name': 'Ad Soyad',
      'company_title': 'Firma Ünvanı',
      'tax_no': 'Vergi No',
      'tckn': 'TCKN',
      'monthly_fee': 'Aylık Ücret',
      'payment_status': 'Ödeme Durumu',
      'advisor_unique_id': 'Müşavir Kodu',
      'office_name': 'Ofis Adı',
      'phone': 'Telefon',
      'city': 'Şehir',
      'district': 'İlçe',
      'address': 'Adres',
      'email': 'E-posta',
      'nace_code': 'NACE Kodu',
    };
    return map[key] ?? key.replaceAll('_', ' ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: FinkitColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
