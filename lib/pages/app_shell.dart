import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_page.dart';
import 'dashboard_page.dart';
import 'data_pages.dart';
import 'entry_forms.dart';
import 'menu_page.dart';
import 'more_pages.dart';
import 'notification_center_page.dart';
import 'platform_pages.dart';

class FinkitShell extends StatefulWidget {
  const FinkitShell({super.key, required this.api, required this.onLogout});

  final FinkitApi api;
  final Future<void> Function() onLogout;

  @override
  State<FinkitShell> createState() => _FinkitShellState();
}

class _FinkitShellState extends State<FinkitShell> {
  int _index = 0;
  int _refreshKey = 0;
  String _userName = '';
  String _companyName = '';
  String _role = 'ADVISOR';
  int? _userId;
  int _unreadNotifications = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationEvents;
  Timer? _notificationPoll;
  int _lastSeenNotificationId = 0;

  @override
  void initState() {
    super.initState();
    // Alt gezinme çubuğu gizli kalsın (durum çubuğu görünür).
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
    _loadIdentity();
    _notificationEvents = AppNotifications.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'NEW_NOTIFICATION' || type == 'READ_MESSAGES') {
        _loadUnreadCount();
      }
    });
    // WebSocket kaçırılan olayları yakalamak için periyodik kontrol.
    _notificationPoll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationEvents?.cancel();
    _notificationPoll?.cancel();
    AppNotifications.instance.disconnect();
    super.dispose();
  }

  /// Sunucudaki yeni bildirimleri kontrol eder; yeniyse sistem bildirimi gösterir.
  Future<void> _checkNotifications() async {
    if (widget.api.demoMode) return;
    try {
      final items = await widget.api.notifications(pageSize: 5);
      if (items.isEmpty) return;
      final newestId = int.tryParse('${items.first['id']}') ?? 0;
      if (_lastSeenNotificationId == 0) {
        // İlk kontrolde geçmiş bildirimler için uyarı gösterilmez.
        _lastSeenNotificationId = newestId;
        return;
      }
      final fresh = items
          .where(
            (item) =>
                (int.tryParse('${item['id']}') ?? 0) >
                    _lastSeenNotificationId &&
                item['is_read'] != true,
          )
          .toList()
          .reversed;
      for (final item in fresh) {
        await AppNotifications.instance.show(
          title: item['title']?.toString() ?? 'Finkit bildirimi',
          body: item['message']?.toString() ?? '',
          payload: 'notification:${item['id']}',
        );
      }
      if (newestId > _lastSeenNotificationId) {
        _lastSeenNotificationId = newestId;
      }
      await _loadUnreadCount();
    } catch (_) {
      // Ağ hatasında sessizce beklenir, bir sonraki turda tekrar denenir.
    }
  }

  /// Üst barda oturum açan kullanıcının adı ve şirketi gösterilir.
  Future<void> _loadIdentity() async {
    if (widget.api.demoMode) {
      if (!mounted) return;
      setState(() {
        _userName = 'Demo Kullanıcı';
        _companyName = '';
        _role = 'ADVISOR';
      });
      return;
    }
    String? name;
    String? company;
    String? role;
    int? userId;
    try {
      final me = await widget.api.me();
      name = me['full_name']?.toString();
      role = me['role']?.toString();
      userId = int.tryParse('${me['id']}');
    } catch (_) {
      // Kullanıcı bilgisi alınamazsa mevcut değer korunur.
    }
    try {
      final entity = await widget.api.entity();
      // Ticari ad boş bırakılmışsa unvana düşülür.
      final trade = entity['trade_name']?.toString().trim();
      final legal = entity['legal_name']?.toString().trim();
      company = (trade != null && trade.isNotEmpty) ? trade : legal;
    } catch (_) {
      // Şirket bilgisi alınamazsa mevcut değer korunur.
    }
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _userName = name;
      if (company != null && company.isNotEmpty) _companyName = company;
      if (role != null && role.isNotEmpty) _role = role;
      _userId = userId;
    });
    if (userId != null) {
      AppNotifications.instance.connect(widget.api, userId);
      // İlk kontrolde mevcut bildirimler taban alınır (eski bildirim uyarısı yok).
      await _checkNotifications();
      await _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await widget.api.unreadNotificationCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {
      // Sayaç alınamazsa rozet gizli kalır.
    }
  }

  void _refresh() {
    setState(() => _refreshKey++);
    _loadIdentity();
    _loadUnreadCount();
  }

  bool get _isClient => _role.toUpperCase() == 'CLIENT';

  /// Kendi Scaffold'u olmayan gömülü sayfaları başlıkla sarar.
  Widget _wrapPage(String title, Widget body) => Scaffold(
    backgroundColor: FinkitColors.canvas,
    appBar: AppBar(title: Text(title)),
    body: body,
  );

  void _openNotifications() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => NotificationCenterPage(
              api: widget.api,
              refreshKey: _refreshKey,
            ),
          ),
        )
        .then((_) => _loadUnreadCount());
  }

  /// Rol bazlı menü: müşavir ve mükellef için ayrı özellik setleri.
  List<MenuSection> get _menuSections {
    final finances = MenuSection(
      title: 'Finans ve Muhasebe',
      entries: [
        MenuEntry(
          title: _isClient ? 'Satışlar' : 'Satış Faturaları',
          subtitle: 'Kesilen faturalar ve tahsilat durumu',
          icon: Icons.post_add_rounded,
          builder: (_) => _wrapPage(
            'Satış Faturaları',
            SalesPage(
              api: widget.api,
              refreshKey: _refreshKey,
              onQuickAction: _showQuickActions,
            ),
          ),
        ),
        MenuEntry(
          title: 'Giderler',
          subtitle: 'Gelen faturalar ve işletme giderleri',
          icon: Icons.receipt_long_outlined,
          builder: (_) => _wrapPage(
            'Giderler',
            ExpensesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Nakit ve Banka',
          subtitle: 'Kasa, banka hesapları ve hareketler',
          icon: Icons.account_balance_wallet_outlined,
          builder: (_) => _wrapPage(
            'Kasa ve Banka',
            CashPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        if (!_isClient)
          MenuEntry(
            title: 'Cari Hesaplar',
            subtitle: 'Müşteri ve tedarikçi bakiyeleri',
            icon: Icons.people_outline_rounded,
            builder: (_) => _wrapPage(
              'Cari Hesaplar',
              CustomersPage(api: widget.api, refreshKey: _refreshKey),
            ),
          ),
        if (!_isClient)
          MenuEntry(
            title: 'Harici Mükellefler',
            subtitle: 'Portala girmeyen takip mükellefleri',
            icon: Icons.folder_shared_outlined,
            builder: (_) =>
                ExternalClientsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        if (!_isClient)
          MenuEntry(
            title: 'Personel ve Bordro',
            subtitle: 'Çalışan, puantaj ve bordro işlemleri',
            icon: Icons.groups_2_outlined,
            builder: (_) => _wrapPage(
              'Personel ve Bordro',
              PayrollPage(api: widget.api, refreshKey: _refreshKey),
            ),
          ),
        MenuEntry(
          title: 'Raporlar',
          subtitle: 'Satış, KDV, nakit ve vade raporları',
          icon: Icons.insert_chart_outlined_rounded,
          builder: (_) =>
              DashboardReportsPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ],
    );

    final documents = MenuSection(
      title: 'Belgeler ve E-Belge',
      entries: [
        MenuEntry(
          title: _isClient ? 'Belgelerim' : 'Belgeler',
          subtitle: 'Beyanname, tahakkuk ve firma evrakları',
          icon: Icons.description_outlined,
          builder: (_) => DocumentsListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
            clientId: _userId,
          ),
        ),
        MenuEntry(
          title: 'E-Fatura',
          subtitle: 'Giden faturalar ve gelen kutusu',
          icon: Icons.receipt_outlined,
          builder: (_) => EInvoiceListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        if (!_isClient)
          MenuEntry(
            title: 'E-Belgeler',
            subtitle: 'Gönderilen ve gelen e-irsaliyeler',
            icon: Icons.local_shipping_outlined,
            builder: (_) =>
                DespatchListPage(api: widget.api, refreshKey: _refreshKey),
          ),
        MenuEntry(
          title: 'Duyurular',
          subtitle: 'Platform ve GİB duyuruları',
          icon: Icons.campaign_outlined,
          builder: (_) =>
              AnnouncementsListPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ],
    );

    final communication = MenuSection(
      title: 'İletişim',
      entries: [
        MenuEntry(
          title: 'Sohbet',
          subtitle: _isClient ? 'Müşavirimle yazışma' : 'Mükelleflerle yazışma',
          icon: Icons.chat_bubble_outline_rounded,
          builder: (_) => ChatListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        if (!_isClient)
          MenuEntry(
            title: 'Mail Gönder',
            subtitle: 'Toplu e-posta veya WhatsApp mesajı',
            icon: Icons.outgoing_mail,
            builder: (_) =>
                BulkMessagePage(api: widget.api, refreshKey: _refreshKey),
          ),
        if (!_isClient)
          MenuEntry(
            title: 'Forum',
            subtitle: 'Müşavirler arası bilgi paylaşımı',
            icon: Icons.forum_outlined,
            builder: (_) =>
                ForumListPage(api: widget.api, refreshKey: _refreshKey),
          ),
        MenuEntry(
          title: _isClient ? 'Müşavir Taleplerim' : 'Mükellef İstekleri',
          subtitle: _isClient
              ? 'Eşleşme talepleriniz'
              : 'Gelen eşleşme talepleri',
          icon: Icons.handshake_outlined,
          builder: (_) => MatchingListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        MenuEntry(
          title: 'Danışma',
          subtitle: _isClient
              ? 'Sorularım ve yanıtlar'
              : 'Yanıt bekleyen sorular',
          icon: Icons.question_answer_outlined,
          builder: (_) => DanismaListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        MenuEntry(
          title: 'Destek',
          subtitle: 'Destek taleplerim',
          icon: Icons.support_agent_outlined,
          builder: (_) =>
              SupportListPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ],
    );

    final planning = MenuSection(
      title: 'Planlama ve Araçlar',
      entries: [
        MenuEntry(
          title: 'Takvim ve Hatırlatıcılar',
          subtitle: 'Etkinlikler, beyanname tarihleri',
          icon: Icons.calendar_month_outlined,
          builder: (_) =>
              CalendarListPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Ödemeler',
          subtitle: _isClient ? 'Ödeme geçmişiniz' : 'Tahsilat kayıtları',
          icon: Icons.payments_outlined,
          builder: (_) => PaymentsListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        MenuEntry(
          title: 'Ek Ücretler',
          subtitle: 'Hizmet ve masraf kalemleri',
          icon: Icons.request_quote_outlined,
          builder: (_) => ExtraChargesListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        MenuEntry(
          title: 'Taksitler',
          subtitle: 'Vadeli ödeme planları',
          icon: Icons.calendar_view_month_outlined,
          builder: (_) => InstallmentsListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        if (!_isClient)
          MenuEntry(
            title: 'Şablonlar',
            subtitle: 'Hazır mesaj şablonları',
            icon: Icons.article_outlined,
            builder: (_) =>
                TemplatesListPage(api: widget.api, refreshKey: _refreshKey),
          ),
        MenuEntry(
          title: 'Hesaplama Yap',
          subtitle: 'KDV, stopaj ve maliyet hesapları',
          icon: Icons.calculate_outlined,
          builder: (_) => const CalculatorPage(),
        ),
        MenuEntry(
          title: 'Not Defteri',
          subtitle: 'Cihazınızda saklanan notlar',
          icon: Icons.sticky_note_2_outlined,
          builder: (_) => const NotesPage(),
        ),
        if (_isClient)
          MenuEntry(
            title: 'Kartlarım',
            subtitle: 'Kayıtlı ödeme kartları',
            icon: Icons.credit_card_outlined,
            builder: (_) =>
                StoredCardsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        if (!_isClient)
          MenuEntry(
            title: 'Giriş Bilgileri',
            subtitle: 'Mükellef kurum şifreleri kasası',
            icon: Icons.vpn_key_outlined,
            builder: (_) =>
                CredentialsPage(api: widget.api, refreshKey: _refreshKey),
          ),
      ],
    );

    final account = MenuSection(
      title: 'Hesap',
      entries: [
        MenuEntry(
          title: 'Profilim',
          subtitle: 'Hesap ve firma bilgileri',
          icon: Icons.person_outline_rounded,
          builder: (_) => ProfilePage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
          ),
        ),
        MenuEntry(
          title: 'Bildirimler',
          subtitle: 'Okunmamış bildirimler ve geçmiş',
          icon: Icons.notifications_none_rounded,
          badge: _unreadNotifications,
          builder: (_) =>
              NotificationCenterPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Ayarlar',
          subtitle: 'Bildirim tercihi ve sunucu bilgisi',
          icon: Icons.settings_outlined,
          builder: (_) =>
              SettingsPage(api: widget.api, onLogout: () => widget.onLogout()),
        ),
      ],
    );

    return [finances, documents, communication, planning, account];
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Raporlar')),
          body: ReportsPage(
            api: widget.api,
            refreshKey: _refreshKey,
            onOpenReport: (report) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportDetailPage(
                    api: widget.api,
                    report: report,
                    title: reportTitle(report),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openExpenses() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: FinkitColors.canvas,
          appBar: AppBar(title: const Text('Giderler')),
          body: ExpensesPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ),
    );
  }

  Future<void> _showQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => _QuickActionSheet(
        api: widget.api,
        onSales: () {
          Navigator.pop(sheetContext);
          setState(() => _index = 1);
        },
        onInvoice: () async {
          Navigator.pop(sheetContext);
          await _showSalesInvoiceForm();
        },
        onCustomer: () async {
          Navigator.pop(sheetContext);
          await _showCustomerForm();
        },
        onExpense: () async {
          Navigator.pop(sheetContext);
          await _showExpenseForm();
          _refresh();
        },
        onCollection: () async {
          Navigator.pop(sheetContext);
          await _showCollectionForm();
          _refresh();
        },
        onReports: () {
          Navigator.pop(sheetContext);
          _openReports();
        },
      ),
    );
  }

  Future<void> _showSalesInvoiceForm() async {
    final created = await showSalesInvoiceForm(context, widget.api);
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış faturası kaydedildi')),
      );
    }
    _refresh();
  }

  Future<void> _showCustomerForm() async {
    final created = await showPartnerForm(context, widget.api);
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cari kartı kaydedildi')));
    }
    _refresh();
  }

  Future<void> _showExpenseForm() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
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
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gider Ekle',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Açıklama gerekli'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Net Tutar',
                  prefixIcon: Icon(Icons.currency_lira_rounded),
                ),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Geçerli tutar girin'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await widget.api.createExpense(
                        description: description.text.trim(),
                        netAmount: double.parse(amount.text),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gider kaydedildi')),
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCollectionForm() async {
    final partners = await widget.api.partners();
    final accounts = await widget.api.accounts();
    if (!mounted) return;
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int? partnerId = partners.isNotEmpty ? partners.first['id'] as int? : null;
    int? accountId = accounts.isNotEmpty ? accounts.first['id'] as int? : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: FinkitColors.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tahsilat Al',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: partnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Müşteri',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: partners
                      .map(
                        (partner) => DropdownMenuItem<int>(
                          value: partner['id'] as int?,
                          child: Text(partner['name']?.toString() ?? 'Müşteri'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => partnerId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kasa / Banka',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem<int>(
                          value: account['id'] as int?,
                          child: Text(account['name']?.toString() ?? 'Hesap'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => accountId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tahsilat Tutarı',
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Geçerli tutar girin'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate() ||
                          partnerId == null) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(sheetContext);
                      try {
                        await widget.api.createCollection(
                          partnerId: partnerId!,
                          amount: double.parse(amount.text),
                          accountId: accountId,
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Tahsilat kaydedildi')),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    child: const Text('Tahsilatı Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page() {
    if (_index == 3) {
      return FeatureMenuPage(
        sections: _menuSections,
        onLogout: () => widget.onLogout(),
        roleLabel: _isClient ? 'Mükellef' : 'Müşavir',
      );
    }
    if (_isClient) {
      switch (_index) {
        case 1:
          return PaymentsListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: true,
          );
        case 2:
          return DocumentsListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: true,
            clientId: _userId,
          );
        default:
          return DashboardPage(
            api: widget.api,
            refreshKey: _refreshKey,
            onOpenSales: () => setState(() => _index = 1),
            onOpenExpenses: _openExpenses,
            onOpenCash: () => setState(() => _index = 2),
            onOpenReports: _openReports,
          );
      }
    }
    switch (_index) {
      case 1:
        return SalesPage(
          api: widget.api,
          refreshKey: _refreshKey,
          onQuickAction: _showQuickActions,
        );
      case 2:
        return CashPage(api: widget.api, refreshKey: _refreshKey);
      default:
        return DashboardPage(
          api: widget.api,
          refreshKey: _refreshKey,
          onOpenSales: () => setState(() => _index = 1),
          onOpenExpenses: _openExpenses,
          onOpenCash: () => setState(() => _index = 2),
          onOpenReports: _openReports,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Topbar(
              demoMode: widget.api.demoMode,
              userName: _userName,
              companyName: _companyName,
              unread: _unreadNotifications,
              onNotifications: _openNotifications,
              onRefresh: _refresh,
              onMenu: () => setState(() => _index = 3),
            ),
            Expanded(child: _page()),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        index: _index,
        onSelect: (value) => setState(() => _index = value),
        onAdd: _showQuickActions,
        labels: _isClient
            ? const ['Özet', 'Ödemeler', 'Belgeler', 'Menü']
            : const ['Özet', 'Faturalar', 'Kasa', 'Menü'],
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.demoMode,
    required this.userName,
    required this.companyName,
    required this.unread,
    required this.onNotifications,
    required this.onRefresh,
    required this.onMenu,
  });

  final bool demoMode;
  final String userName;
  final String companyName;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;
  final VoidCallback onMenu;

  /// "Musavir İsmi" -> "Mİ"; boşsa Finkit logosu kullanılır.
  String get _initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  String get _greeting {
    final first = userName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Merhaba' : 'Merhaba, $first';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: FinkitColors.canvas.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x99E7EAEF))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onMenu,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF292C33), Color(0xFF111216)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  demoMode
                      ? 'Demo modu'
                      : (companyName.isNotEmpty ? companyName : 'Finkit'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FinkitColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: onNotifications,
            tooltip: 'Bildirimler',
            icon: unread > 0
                ? Badge(
                    label: Text('$unread'),
                    backgroundColor: FinkitColors.danger,
                    child: const Icon(Icons.notifications_none_rounded),
                  )
                : const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.index,
    required this.onSelect,
    required this.onAdd,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(color: FinkitColors.canvas),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xE7E8EBEF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A131821),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _BottomItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: labels[0],
              active: index == 0,
              onTap: () => onSelect(0),
            ),
            _BottomItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: labels[1],
              active: index == 1,
              onTap: () => onSelect(1),
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: FinkitColors.ink,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x47101114),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            _BottomItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: labels[2],
              active: index == 2,
              onTap: () => onSelect(2),
            ),
            _BottomItem(
              icon: Icons.grid_view_rounded,
              activeIcon: Icons.grid_view_rounded,
              label: labels[3],
              active: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF0F2F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 21,
                color: active ? FinkitColors.ink : FinkitColors.mutedLight,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: active ? FinkitColors.ink : FinkitColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({
    required this.api,
    required this.onSales,
    required this.onInvoice,
    required this.onCustomer,
    required this.onExpense,
    required this.onCollection,
    required this.onReports,
  });

  final FinkitApi api;
  final VoidCallback onSales;
  final VoidCallback onInvoice;
  final VoidCallback onCustomer;
  final VoidCallback onExpense;
  final VoidCallback onCollection;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Yeni Fatura', Icons.post_add_rounded, onInvoice),
      ('Yeni Müşteri', Icons.person_add_alt_1_rounded, onCustomer),
      ('Gider Ekle', Icons.receipt_long_outlined, onExpense),
      ('Tahsilat', Icons.call_received_rounded, onCollection),
      ('Fatura Listesi', Icons.list_alt_rounded, onSales),
      ('Raporlar', Icons.insert_chart_outlined_rounded, onReports),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hızlı İşlem', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final action in actions)
                InkWell(
                  onTap: action.$3,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FinkitColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(action.$2, color: FinkitColors.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
