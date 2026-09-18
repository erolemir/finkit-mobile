import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'chat_page.dart';
import 'data_pages.dart';
import 'entry_forms.dart';
import 'more_pages.dart';

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
            ],
          ),
        ),
      ),
    );
  }
}

/// Belgeler: müşavir tüm belgeleri, mükellef kendi belgelerini görür.
class DocumentsListPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final id = clientId;
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(isClient ? 'Belgelerim' : 'Belgeler')),
      body: ApiListPage(
        title: isClient ? 'Belgelerim' : 'Belgeler',
        subtitle:
            'Beyanname, tahakkuk ve firma evrakları tek listede toplanır.',
        refreshKey: refreshKey,
        loader: () => isClient && id != null
            ? api.clientDocuments(id)
            : api.allDocuments(),
        searchHint: 'Dosya adı veya tür ara',
        searchText: (item) =>
            '${item['file_name']} ${statusLabel(item['document_type']?.toString())}',
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
          return SummaryGrid(
            items: [
              SummaryItem('Toplam', '${items.length}', Icons.folder_outlined),
              SummaryItem(
                'Bu yıl',
                '$thisYear',
                Icons.event_available_outlined,
              ),
            ],
          );
        },
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.picture_as_pdf_outlined,
          title: _text(item['file_name'], 'Belge'),
          subtitle:
              '${statusLabel(item['document_type']?.toString())} · ${dateText(item['document_date'] ?? item['upload_date'])}',
          value: dateText(item['upload_date']),
          valueSubtitle: 'Yükleme',
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
                'PDF veya görsel seçin; belge mükellefin dosyasına eklenir.',
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final picked = await FilePickerPlatform.instance.pickFile(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                    );
                    final path = picked?.path;
                    if (path == null) return;
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    try {
                      await api.uploadDocument(
                        clientId: selectedClient!,
                        documentType: documentType,
                        filePath: path,
                        fileName: picked?.name,
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Belge yüklendi')),
                      );
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Dosya Seç ve Yükle'),
                ),
              ),
            ],
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
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: FinkitColors.canvas,
        appBar: AppBar(
          title: const Text('E-Fatura'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Giden'),
              Tab(text: 'Gelen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ApiListPage(
              title: 'Giden Faturalar',
              subtitle: 'Gönderilen e-fatura ve e-arşiv belgeleri.',
              refreshKey: refreshKey,
              loader: isClient
                  ? api.clientEinvoiceInvoices
                  : api.einvoiceInvoices,
              emptyIcon: Icons.upload_file_outlined,
              emptyTitle: 'Giden belge yok',
              emptyDescription: 'Gönderilmiş e-fatura bulunmuyor.',
              itemBuilder: (context, item) => DataRowCard(
                icon: Icons.receipt_long_outlined,
                title: _text(
                  item['invoice_number'] ?? item['number'] ?? item['uuid'],
                  'Fatura',
                ),
                subtitle:
                    '${_text(item['receiver_name'] ?? item['customer_name'] ?? item['status'], '')} · ${dateText(item['issue_date'] ?? item['created_at'])}',
                value: moneyText(
                  item['total'] ?? item['amount'] ?? item['payable_amount'],
                ),
                status: item['status']?.toString(),
              ),
            ),
            ApiListPage(
              title: 'Gelen Belgeler',
              subtitle: 'Size kesilen e-faturalar ve yanıt bekleyenler.',
              refreshKey: refreshKey,
              loader: isClient ? api.clientEinvoiceInbox : api.einvoiceInbox,
              emptyIcon: Icons.move_to_inbox_outlined,
              emptyTitle: 'Gelen belge yok',
              emptyDescription: 'Gelen kutusunda belge bulunmuyor.',
              itemBuilder: (context, item) => DataRowCard(
                icon: Icons.inbox_outlined,
                title: _text(
                  item['invoice_number'] ??
                      item['number'] ??
                      item['provider_id'] ??
                      item['uuid'],
                  'Belge',
                ),
                subtitle:
                    '${_text(item['sender_name'] ?? item['supplier_name'] ?? item['status'], '')} · ${dateText(item['issue_date'] ?? item['created_at'])}',
                value: moneyText(item['total'] ?? item['amount']),
                status: item['status']?.toString(),
              ),
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
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<CalendarListPage> createState() => _CalendarListPageState();
}

class _CalendarListPageState extends State<CalendarListPage> {
  /// Etkinlikten bir gün önce yerel bildirim planlar.
  Future<void> _scheduleReminders(List<Map<String, dynamic>> events) async {
    final now = DateTime.now();
    for (final event in events.take(40)) {
      if (event['is_notification_active'] == false) continue;
      final date = DateTime.tryParse('${event['event_date']}');
      if (date == null || date.isBefore(now)) continue;
      final remindAt = date.subtract(const Duration(days: 1));
      if (remindAt.isBefore(now)) continue;
      await AppNotifications.instance.scheduleAt(
        remindAt,
        title: 'Hatırlatıcı: ${event['title'] ?? 'Etkinlik'}',
        body: '${dateText(event['event_date'])} tarihinde etkinliğiniz var.',
        id:
            int.tryParse('${event['id']}') ??
            remindAt.millisecondsSinceEpoch.remainder(100000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Takvim ve Hatırlatıcılar')),
      body: ApiListPage(
        title: 'Takvim',
        subtitle: 'Etkinlikler ve hatırlatıcılar. Yaklaşan etkinlikler için bildirim planlanır.',
        refreshKey: widget.refreshKey,
        trailing: IconButton.filled(
          onPressed: () => _createReminderSheet(context),
          style: IconButton.styleFrom(
            backgroundColor: FinkitColors.ink,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Hatırlatıcı ekle',
          icon: const Icon(Icons.add_alarm_rounded),
        ),
        loader: () async {
          final events = await widget.api.calendarEvents();
          final rules = await widget.api.reminderRules();
          await _scheduleReminders(events);
          return [...events, ...rules];
        },
        emptyIcon: Icons.calendar_month_outlined,
        emptyTitle: 'Etkinlik yok',
        emptyDescription: 'Yaklaşan hatırlatıcı bulunmuyor.',
        itemBuilder: (context, item) {
          final isRule =
              item.containsKey('rule_type') ||
              item.containsKey('days_before') ||
              item.containsKey('interval_days');
          return DataRowCard(
            icon: isRule ? Icons.alarm_rounded : Icons.event_outlined,
            title: _text(
              item['title'] ?? item['name'] ?? item['rule_type'],
              isRule ? 'Hatırlatıcı kuralı' : 'Etkinlik',
            ),
            subtitle: _text(
              item['description'] ?? item['event_type'] ?? '',
              statusLabel(item['event_type']?.toString()),
            ),
            value: dateText(item['event_date'] ?? item['created_at']),
            valueSubtitle: isRule ? 'Kural' : 'Tarih',
            status: item['event_type']?.toString(),
          );
        },
      ),
    );
  }

  /// Yeni hatırlatıcı oluşturur ve telefondan bildirim planlar.
  Future<void> _createReminderSheet(BuildContext context) async {
    final title = TextEditingController();
    final description = TextEditingController();
    var when = DateTime.now().add(const Duration(days: 1));
    var saving = false;

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
                  'Yeni Hatırlatıcı',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
              Text(
                'Etkinlikten bir gün önce ve 15 dakika önce bildirim gönderilir.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
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
                            final text = title.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() => saving = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await widget.api.createCalendarEvent(
                                title: text,
                                description: description.text.trim().isEmpty
                                    ? null
                                    : description.text.trim(),
                                eventDate: when.toIso8601String(),
                              );
                              // Hem bir gün önceden hem de etkinlikten 15 dakika
                              // önce bildirim planlanır; kısa vadeli hatırlatıcılar
                              // da çalışsın diye ikinci bildirim eklenir.
                              final now = DateTime.now();
                              final dayBefore = when.subtract(
                                const Duration(days: 1),
                              );
                              if (dayBefore.isAfter(now)) {
                                await AppNotifications.instance.scheduleAt(
                                  dayBefore,
                                  title: 'Hatırlatıcı: $text',
                                  body:
                                      'Yarın ${dateText(when)} tarihinde etkinliğiniz var.',
                                  id:
                                      when.millisecondsSinceEpoch.remainder(
                                        100000,
                                      ),
                                );
                              }
                              final fifteenBefore = when.subtract(
                                const Duration(minutes: 15),
                              );
                              if (fifteenBefore.isAfter(now)) {
                                await AppNotifications.instance.scheduleAt(
                                  fifteenBefore,
                                  title: 'Hatırlatıcı: $text',
                                  body:
                                      '15 dakika sonra: ${dateText(when)} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                                  id:
                                      when.millisecondsSinceEpoch.remainder(
                                        100000,
                                      ) +
                                      1,
                                );
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Hatırlatıcı kaydedildi'),
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
                    label: Text(
                      saving ? 'Kaydediliyor…' : 'Hatırlatıcı Kaydet',
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

/// Mesaj şablonları.
class TemplatesListPage extends StatelessWidget {
  const TemplatesListPage({
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
      appBar: AppBar(title: const Text('Şablonlar')),
      body: ApiListPage(
        title: 'Mesaj Şablonları',
        subtitle: 'Mükelleflere gönderdiğiniz hazır mesajlar.',
        refreshKey: refreshKey,
        loader: api.messageTemplates,
        emptyIcon: Icons.article_outlined,
        emptyTitle: 'Şablon yok',
        emptyDescription: 'Henüz mesaj şablonu oluşturulmamış.',
        itemBuilder: (context, item) => DataRowCard(
          icon: Icons.article_outlined,
          title: _text(item['name'], 'Şablon'),
          subtitle: _text(item['content'], '').length > 70
              ? '${_text(item['content'], '').substring(0, 70)}…'
              : _text(item['content'], ''),
          value: statusLabel(item['template_type']?.toString()),
          valueSubtitle: 'Tür',
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
