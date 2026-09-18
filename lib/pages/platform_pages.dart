import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'data_pages.dart';

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
class ClientsListPage extends StatelessWidget {
  const ClientsListPage({
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
      appBar: AppBar(title: const Text('Mükellefler')),
      body: ApiListPage(
        title: 'Mükellefler',
        subtitle: 'Cari kartları, ödeme durumu ve iletişim bilgileri.',
        refreshKey: refreshKey,
        loader: api.clients,
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
        subtitle: 'Etkinlikler, beyanname tarihleri ve hatırlatıcılar.',
        refreshKey: widget.refreshKey,
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
        ),
      ),
    );
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
        ),
      ),
    );
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
        ),
      ),
    );
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
              const PageTitle(
                title: 'Profilim',
                subtitle: 'Hesap ve firma bilgileriniz.',
              ),
              SurfaceCard(child: Column(children: rows)),
            ],
          );
        },
      ),
    );
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
