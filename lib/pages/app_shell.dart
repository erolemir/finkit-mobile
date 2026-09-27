import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../access_policy.dart';
import '../api_client.dart';
import '../services/app_notifications.dart';
import '../services/background_sync.dart';
import '../theme.dart';
import '../widgets.dart';
import 'accounting_pages.dart';
import 'admin_pages.dart';
import 'admin_announcements_page.dart';
import 'admin_system_updates_page.dart';
import 'admin_settings_page.dart';
import 'admin_support_page.dart';
import 'admin_financial_page.dart';
import 'admin_sms_page.dart';
import 'admin_logs_page.dart';
import 'admin_users_page.dart';
import 'admin_danisma_page.dart';
import 'chat_page.dart';
import 'dashboard_page.dart';
import 'data_pages.dart';
import 'entry_forms.dart';
import 'expense_groups_page.dart';
import 'expense_definitions_page.dart';
import 'einvoice_composer_page.dart';
import 'einvoice_tools_page.dart';
import 'einvoice_settings_page.dart';
import 'extra_documents_page.dart';
import 'full_notes_page.dart';
import 'menu_page.dart';
import 'more_pages.dart';
import 'notification_center_page.dart';
import 'platform_pages.dart';
import 'system_updates_page.dart';
import 'sub_users_page.dart';
import 'vat_calculation_page.dart';

class FinkitShell extends StatefulWidget {
  const FinkitShell({
    super.key,
    required this.api,
    required this.onLogout,
    this.maintenanceNotice,
  });

  final FinkitApi api;
  final Future<void> Function() onLogout;

  /// Planlanan bakım bilgisi (varsa üstte uyarı şeridi gösterilir).
  final Map<String, dynamic>? maintenanceNotice;

  @override
  State<FinkitShell> createState() => _FinkitShellState();
}

class _FinkitShellState extends State<FinkitShell> {
  int _index = 0;
  final List<int> _tabHistory = [];

  void _selectTab(int index) {
    if (index == _index) return;
    final view = index == 0
        ? (_isClient ? 'home' : 'dashboard')
        : index == 1
        ? (_isClient ? 'payments' : 'accounting-sales-invoices')
        : index == 2
        ? (_isClient ? 'documents' : 'accounting-cash-accounts')
        : 'menu';
    if (index != 3 && !_accessPolicy.canOpenView(view)) {
      if (_accessPolicy.isPaymentLocked) {
        setState(() => _index = 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu sayfaya erişim yetkiniz yok.')),
        );
      }
      return;
    }
    setState(() {
      _tabHistory.add(_index);
      _index = index;
    });
  }

  void _goBack() => setState(() {
    _index = _tabHistory.isEmpty ? 0 : _tabHistory.removeLast();
  });

  void _openSales() {
    if (!_accessPolicy.canOpenView('accounting-sales-invoices')) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _wrapPage(
          'Satış Faturaları',
          SalesPage(
            api: widget.api,
            refreshKey: _refreshKey,
            onQuickAction: _showQuickActions,
          ),
        ),
      ),
    );
  }

  void _openCash() {
    if (!_accessPolicy.canOpenView('accounting-cash-accounts')) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _wrapPage(
          'Kasa ve Banka',
          CashPage(api: widget.api, refreshKey: _refreshKey),
        ),
      ),
    );
  }

  int _refreshKey = 0;
  String _userName = '';
  String _companyName = '';
  String _role = 'ADVISOR';
  AppAccessPolicy _accessPolicy = const AppAccessPolicy(role: 'ADVISOR');
  bool _identityReady = false;
  String? _identityError;
  int? _userId;
  int _unreadNotifications = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationEvents;
  Timer? _notificationPoll;
  int _lastSeenNotificationId = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        await BackgroundSync.markSeen(newestId);
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
      await BackgroundSync.markSeen(newestId);
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
        // Demo modunda rol, testlerin mükellef menüsünü de açabilmesi için
        // api üzerinden ayarlanabilir.
        _role = widget.api.role?.toUpperCase() ?? 'ADVISOR';
        _accessPolicy = AppAccessPolicy(role: _role);
        _identityReady = true;
      });
      return;
    }
    String? name;
    String? company;
    String? role;
    int? userId;
    Map<String, dynamic>? me;
    try {
      me = await widget.api.me();
      name = me['full_name']?.toString();
      role = me['role']?.toString();
      userId = int.tryParse('${me['id']}');
    } catch (error) {
      if (mounted) setState(() => _identityError = '$error');
      return;
    }
    if (role?.toUpperCase() == 'CLIENT') {
      try {
        final profile = await widget.api.clientProfile();
        _accessPolicy = AppAccessPolicy.fromUser(me, client: profile);
      } catch (error) {
        if (mounted) setState(() => _identityError = '$error');
        return;
      }
    } else {
      _accessPolicy = AppAccessPolicy.fromUser(me);
    }
    if (role?.toUpperCase() != 'ADMIN') {
      try {
        final entity = await widget.api.entity();
        final trade = entity['trade_name']?.toString().trim();
        final legal = entity['legal_name']?.toString().trim();
        company = (trade != null && trade.isNotEmpty) ? trade : legal;
      } catch (_) {
        // Şirket bilgisi alınamazsa mevcut değer korunur.
      }
    }
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _userName = name;
      if (company != null && company.isNotEmpty) _companyName = company;
      if (role != null && role.isNotEmpty) _role = role;
      _userId = userId;
      _identityReady = true;
      _identityError = null;
    });
    if (userId != null) {
      AppNotifications.instance.connect(widget.api, userId);
      // Uygulama kapalıyken de bildirim gelebilmesi için periyodik görev.
      await BackgroundSync.registerPeriodic();
      // Test derlemesinde kısa süreli tek seferlik kontrol tetiklenir.
      if (const bool.fromEnvironment('FINKIT_BG_TEST')) {
        await BackgroundSync.runOnce(delay: const Duration(seconds: 20));
      }
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
    setState(() {
      _refreshKey++;
      _identityReady = false;
      _identityError = null;
    });
    _loadIdentity();
    _loadUnreadCount();
  }

  bool get _isClient => _role.toUpperCase() == 'CLIENT';
  bool get _isAdmin => _role.toUpperCase() == 'ADMIN';

  String? _viewForMenuTitle(String title) => switch (title) {
    'Mükellefler' => 'clients',
    'Belgeler' || 'Belgelerim' => 'documents',
    'Tahsilatlar' ||
    'Ödemeler' ||
    'Ek Ücretler' ||
    'Taksitler' ||
    'Kartlarım' => 'payments',
    'E-Fatura ve E-Arşiv' || 'E-Belgeler' => 'einvoice',
    'Sohbet' => 'chat',
    'Mail Gönder' => 'messages',
    'Forum' => 'forum',
    'Mükellef İstekleri' || 'Müşavir Taleplerim' => 'matching',
    'Takvim ve Hatırlatıcılar' => 'calendar',
    'Şablonlar' => 'templates',
    'Hatırlatma Kuralları' => 'rules',
    'Hızlı Giriş Aracı' => 'credentials',
    'Destek' => 'support',
    'Bildirimler' || 'Duyurular' => 'notifications',
    'Profilim' => 'profile',
    'Ayarlar' => 'settings',
    'Not Defteri' => 'notes',
    'Hesaplama Yap' => 'calculator',
    'Sistem Güncellemeleri' => 'system-updates',
    'Danışma' || 'Harici Mükellefler' => null,
    _ => 'accounting-$title',
  };

  bool _canOpenMenuEntry(MenuEntry entry) {
    final view = entry.viewId ?? _viewForMenuTitle(entry.title);
    if (_accessPolicy.isPaymentLocked) return view == 'payments';
    if (view == null) {
      return !_accessPolicy.isSubUser && !_accessPolicy.isPaymentLocked;
    }
    return _accessPolicy.canOpenView(view);
  }

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

  /// Planlanan bakım varsa gösterilecek uyarı metni.
  String? get _maintenanceNoticeText {
    final notice = widget.maintenanceNotice;
    if (notice == null) return null;
    if (notice['maintenance_mode'] == true) return null;
    final when = notice['scheduled_at_tr']?.toString().trim();
    final scheduledAt = notice['scheduled_at']?.toString().trim();
    if ((when == null || when.isEmpty) &&
        (scheduledAt == null || scheduledAt.isEmpty)) {
      return null;
    }
    final label = (when != null && when.isNotEmpty)
        ? when
        : dateText(scheduledAt);
    return 'Planlı sistem bakımı: $label (TR). Bakım saatinde açık oturumlar '
        'kapatılacaktır; çalışmalarınızı kaydetmeyi unutmayın.';
  }

  /// Rol bazlı menü: müşavir ve mükellef için ayrı özellik setleri.
  List<MenuSection> get _menuSections {
    if (_isAdmin) {
      MenuEntry adminEntry(AdminModule module) => MenuEntry(
        title: module.title,
        subtitle: 'Yönetim kayıtları ve işlemleri',
        icon: Icons.admin_panel_settings_outlined,
        builder: (_) => _wrapPage(module.title, switch (module.id) {
          'announcements' => AdminAnnouncementsPage(api: widget.api),
          'system-updates' => AdminSystemUpdatesPage(api: widget.api),
          'settings' => AdminSettingsPage(api: widget.api),
          'support' => AdminSupportPage(api: widget.api),
          'financial' => AdminFinancialPage(api: widget.api),
          'sms-reports' => AdminSmsPage(api: widget.api),
          'logs' => AdminLogsPage(api: widget.api),
          'users' => AdminUsersPage(api: widget.api),
          'system-users' => AdminUsersPage(api: widget.api, systemOnly: true),
          'danisma' => AdminDanismaPage(api: widget.api),
          _ => AdminResourcePage(api: widget.api, module: module),
        }),
      );
      return [
        MenuSection(
          title: 'Genel',
          entries: [
            MenuEntry(
              title: 'Panel',
              subtitle: 'Yönetim özeti',
              icon: Icons.dashboard_outlined,
              builder: (_) =>
                  _wrapPage('Panel', AdminOverviewPage(api: widget.api)),
            ),
          ],
        ),
        MenuSection(
          title: 'Yönetim',
          entries: adminModules
              .where(
                (module) => const {
                  'users',
                  'advisors',
                  'clients',
                  'advisor-changes',
                  'approvals',
                  'advisor-approvals',
                  'financial',
                  'payments',
                  'transfers',
                  'sms-reports',
                  'danisma',
                }.contains(module.id),
              )
              .map(adminEntry)
              .toList(),
        ),
        MenuSection(
          title: 'Sistem',
          entries: adminModules
              .where(
                (module) => const {
                  'system-updates',
                  'announcements',
                  'support',
                  'system-users',
                  'settings',
                  'logs',
                }.contains(module.id),
              )
              .map(adminEntry)
              .toList(),
        ),
      ];
    }
    // Satışlar: cari kartlar, ürün/hizmet, depo-stok, teklif ve satış belgeleri.
    final sales = MenuSection(
      title: 'Satışlar',
      entries: [
        MenuEntry(
          title: 'Müşteriler',
          subtitle: 'Müşteri kartları ve cari bakiyeler',
          icon: Icons.people_outline_rounded,
          builder: (_) => _wrapPage(
            'Müşteriler',
            CustomersPage(
              api: widget.api,
              refreshKey: _refreshKey,
              partnerType: 'CUSTOMER',
            ),
          ),
        ),
        MenuEntry(
          title: 'Ürün ve Hizmetler',
          subtitle: 'Fiyat, KDV oranı ve stok maliyeti',
          icon: Icons.inventory_2_outlined,
          builder: (_) => _wrapPage(
            'Ürün ve Hizmetler',
            ProductsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Depolar ve Stok',
          subtitle: 'Depo bazlı miktar ve stok değeri',
          icon: Icons.warehouse_outlined,
          builder: (_) => _wrapPage(
            'Depolar ve Stok',
            StockPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Depo Tanımları',
          subtitle: 'Şube ve depo kayıtları',
          icon: Icons.add_business_outlined,
          builder: (_) => _wrapPage(
            'Depolar',
            WarehousesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Teklifler',
          subtitle: 'Teklif hazırlayın ve faturaya çevirin',
          icon: Icons.request_quote_outlined,
          builder: (_) => _wrapPage(
            'Teklifler',
            QuotesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Satış Faturaları',
          subtitle: 'E-Fatura, E-Arşiv ve manuel satış kayıtları',
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
          title: 'İade Faturaları',
          subtitle: 'E-Fatura, E-Arşiv ve manuel iade kayıtları',
          icon: Icons.assignment_return_outlined,
          builder: (_) => _wrapPage(
            'İade Faturaları',
            SalesReturnsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Tahsilatlar',
          subtitle: 'Müşteri tahsilatları ve avanslar',
          icon: Icons.call_received_rounded,
          builder: (_) => _wrapPage(
            'Tahsilatlar',
            CollectionsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Satış Raporu',
          subtitle: 'Ciro, KDV, iade ve müşteri kırılımı',
          icon: Icons.trending_up_rounded,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'sales',
            title: 'Satış Raporu',
          ),
        ),
        MenuEntry(
          title: 'Tahsilat Raporu',
          subtitle: 'Tahsil edilen, bekleyen ve gecikmiş',
          icon: Icons.call_received_rounded,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'collections',
            title: 'Tahsilat Raporu',
          ),
        ),
        MenuEntry(
          title: 'Gelir-Gider Raporu',
          subtitle: 'Tahakkuk ve nakit görünümü',
          icon: Icons.auto_graph_rounded,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'income-expense',
            title: 'Gelir-Gider Raporu',
          ),
        ),
      ],
    );

    // Giderler: işletme giderleri, tedarikçi faturaları, personel ve vergi.
    final expenseSection = MenuSection(
      title: 'Giderler',
      entries: [
        MenuEntry(
          title: 'Gider Listesi',
          subtitle: 'Kira, yakıt, danışmanlık ve diğer giderler',
          icon: Icons.receipt_long_outlined,
          builder: (_) => _wrapPage(
            'Gider Listesi',
            ExpenseGroupsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Gelen Faturalar',
          subtitle: 'E-Fatura, E-Arşiv ve manuel alış kayıtları',
          icon: Icons.inbox_outlined,
          builder: (_) => _wrapPage(
            'Gelen Faturalar',
            PurchaseInvoicesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Tedarikçiler',
          subtitle: 'Tedarikçi kartları ve borç bakiyesi',
          icon: Icons.local_shipping_outlined,
          builder: (_) => _wrapPage(
            'Tedarikçiler',
            CustomersPage(
              api: widget.api,
              refreshKey: _refreshKey,
              partnerType: 'SUPPLIER',
            ),
          ),
        ),
        MenuEntry(
          title: 'Çalışanlar',
          subtitle: 'Personel kartı, ücret ve avans',
          icon: Icons.groups_2_outlined,
          builder: (_) => _wrapPage(
            'Çalışanlar',
            EmployeesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Bordro ve Puantaj',
          subtitle: 'Dönemsel bordro ve işveren maliyeti',
          icon: Icons.badge_outlined,
          builder: (_) => _wrapPage(
            'Bordro ve Puantaj',
            PayrollPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Gider Raporu',
          subtitle: 'Kategori, tedarikçi ve ödeme durumu',
          icon: Icons.summarize_outlined,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'expenses',
            title: 'Gider Raporu',
          ),
        ),
        MenuEntry(
          title: 'Ödemeler Raporu',
          subtitle: 'Tedarikçi, personel ve vergi ödemeleri',
          icon: Icons.payments_outlined,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'payments',
            title: 'Ödemeler Raporu',
          ),
        ),
        MenuEntry(
          title: 'Tedarikçi Ödemeleri',
          subtitle: 'Ödeme kaydı oluştur ve faturaya dağıt',
          icon: Icons.price_check_rounded,
          builder: (_) => _wrapPage(
            'Tedarikçi Ödemeleri',
            SupplierPaymentsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'KDV Raporu',
          subtitle: 'KDV1 taslağı, tevkifat ve devreden',
          icon: Icons.percent_rounded,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'vat',
            title: 'KDV Raporu',
          ),
        ),
      ],
    );

    // Nakit: kasa/banka, çek-senet ve nakit raporları.
    final cash = MenuSection(
      title: 'Nakit',
      entries: [
        MenuEntry(
          title: 'Kasa ve Bankalar',
          subtitle: 'Hesap bakiyeleri ve hareketler',
          icon: Icons.account_balance_wallet_outlined,
          builder: (_) => _wrapPage(
            'Kasa ve Bankalar',
            FinancialAccountsPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Kasa Hareketleri',
          subtitle: 'Giriş, çıkış ve virman kayıtları',
          icon: Icons.swap_horiz_rounded,
          builder: (_) => _wrapPage(
            'Kasa ve Banka',
            CashPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Çekler ve Senetler',
          subtitle: 'Portföy, tahsil, teminat ve protesto',
          icon: Icons.receipt_outlined,
          builder: (_) => _wrapPage(
            'Çekler ve Senetler',
            ChecksNotesPage(api: widget.api, refreshKey: _refreshKey),
          ),
        ),
        MenuEntry(
          title: 'Kasa Raporu',
          subtitle: 'Hesap bazlı açılış, giriş, çıkış, kapanış',
          icon: Icons.account_balance_wallet_outlined,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'cash-register',
            title: 'Kasa Raporu',
          ),
        ),
        MenuEntry(
          title: 'Nakit Akış Raporu',
          subtitle: 'Giriş-çıkış ve vade projeksiyonu',
          icon: Icons.waterfall_chart_rounded,
          builder: (_) => ReportDetailPage(
            api: widget.api,
            report: 'cash-flow',
            title: 'Nakit Akış Raporu',
          ),
        ),
      ],
    );

    // Müşavir araçları: mükellef listesi, kurum giriş bilgileri ve takip kayıtları.
    final advisorTools = MenuSection(
      title: 'Müşavir Araçları',
      entries: [
        MenuEntry(
          title: 'Mükellefler',
          subtitle: 'Mükellef kartları, ödeme durumu ve iletişim',
          icon: Icons.badge_outlined,
          builder: (_) =>
              ClientsListPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Hızlı Giriş Aracı',
          subtitle: 'Mükellef kurum şifreleri kasası',
          icon: Icons.vpn_key_outlined,
          builder: (_) =>
              CredentialsPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Harici Mükellefler',
          subtitle: 'Portala girmeyen takip mükellefleri',
          icon: Icons.folder_shared_outlined,
          builder: (_) =>
              ExternalClientsPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Şablonlar',
          subtitle: 'Hazır mesaj şablonları',
          icon: Icons.article_outlined,
          builder: (_) =>
              TemplatesListPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Hatırlatma Kuralları',
          subtitle: 'Vadesi yaklaşan ödemeler için otomatik hatırlatma',
          icon: Icons.notifications_active_outlined,
          builder: (_) => ReminderRulesPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isSubUser: _accessPolicy.isSubUser,
          ),
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
          title: 'E-Fatura ve E-Arşiv',
          subtitle: 'Giden E-Fatura / E-Arşiv ve gelen E-Faturalar',
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
            subtitle: 'E-İrsaliye, E-SMM ve E-Müstahsil',
            icon: Icons.local_shipping_outlined,
            builder: (_) => ExtraDocumentsPage(api: widget.api),
          ),
        MenuEntry(
          title: 'Duyurular',
          subtitle: 'Platform ve GİB duyuruları',
          icon: Icons.campaign_outlined,
          builder: (_) =>
              AnnouncementsListPage(api: widget.api, refreshKey: _refreshKey),
        ),
        MenuEntry(
          title: 'Sistem Güncellemeleri',
          subtitle: 'Finkit güncellemeleri ve sistem sağlık durumu',
          icon: Icons.system_update_alt_rounded,
          builder: (_) =>
              SystemUpdatesPage(api: widget.api, refreshKey: _refreshKey),
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
          builder: (_) => CalendarListPage(
            api: widget.api,
            refreshKey: _refreshKey,
            isClient: _isClient,
            userId: _userId,
          ),
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
          builder: (_) => FullNotesPage(userId: _userId ?? 0, role: _role),
        ),
        if (_isClient)
          MenuEntry(
            title: 'Kartlarım',
            subtitle: 'Kayıtlı ödeme kartları',
            icon: Icons.credit_card_outlined,
            builder: (_) =>
                StoredCardsPage(api: widget.api, refreshKey: _refreshKey),
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

    MenuEntry from(
      MenuSection section,
      String source,
      String label,
      String view,
    ) => section.entries
        .firstWhere((entry) => entry.title == source)
        .renamed(label, view);
    MenuSection group(
      String title,
      List<MenuEntry> entries, {
      String? parent,
    }) => MenuSection(title: title, entries: entries, parentTitle: parent);
    MenuEntry report(String label, String slug, String view) => MenuEntry(
      title: label,
      subtitle: 'Dönem ve durum filtreleriyle rapor',
      icon: Icons.insert_chart_outlined_rounded,
      viewId: view,
      builder: (_) =>
          ReportDetailPage(api: widget.api, report: slug, title: label),
    );
    MenuEntry invoiceBox(
      String label,
      String view, {
      bool incoming = false,
      bool archive = false,
    }) => MenuEntry(
      title: label,
      subtitle: archive
          ? 'E-Arşiv belgeleri'
          : incoming
          ? 'Gelen E-Faturalar'
          : 'Gönderilen E-Faturalar',
      icon: archive
          ? Icons.archive_outlined
          : incoming
          ? Icons.inbox_outlined
          : Icons.outbox_outlined,
      viewId: view,
      builder: (_) => EInvoiceListPage(
        api: widget.api,
        refreshKey: _refreshKey,
        isClient: _isClient,
        initialIndex: incoming ? 1 : 0,
        documentType: archive ? 'EARCHIVE' : 'EINVOICE',
      ),
    );
    MenuEntry invoiceComposer(String label, String view, String type) =>
        MenuEntry(
          title: label,
          subtitle: 'Belge oluştur, taslağı kaydet ve onaylayarak gönder',
          icon: Icons.post_add_outlined,
          viewId: view,
          builder: (_) => EInvoiceComposerPage(
            api: widget.api,
            isClient: _isClient,
            documentType: type,
          ),
        );
    MenuEntry invoiceDrafts(String label, String view, String type) =>
        MenuEntry(
          title: label,
          subtitle: 'Kayıtlı taslakları düzenle veya gönder',
          icon: Icons.drafts_outlined,
          viewId: view,
          builder: (_) => EInvoiceDraftsPage(
            api: widget.api,
            isClient: _isClient,
            documentType: type,
          ),
        );
    MenuEntry invoiceUpload(
      String label,
      String view,
      String type, {
      bool medula = false,
    }) => MenuEntry(
      title: label,
      subtitle: 'UBL-TR XML belgesi yükle',
      icon: Icons.upload_file_outlined,
      viewId: view,
      builder: (_) => EInvoiceUblUploadPage(
        api: widget.api,
        isClient: _isClient,
        documentType: type,
        medula: medula,
      ),
    );
    final main = group('Genel', [
      MenuEntry(
        title: _isClient ? 'Ana Sayfa' : 'Panel',
        subtitle: 'Genel durum ve son hareketler',
        icon: Icons.dashboard_outlined,
        viewId: _isClient ? 'home' : 'dashboard',
        builder: (_) => _wrapPage(
          _isClient ? 'Ana Sayfa' : 'Panel',
          DashboardPage(
            api: widget.api,
            refreshKey: _refreshKey,
            onOpenSales: _openSales,
            onOpenExpenses: _openExpenses,
            onOpenCash: _openCash,
            onOpenReports: _openReports,
          ),
        ),
      ),
      if (!_isClient)
        from(advisorTools, 'Mükellefler', 'Mükellefler', 'clients'),
      if (_isClient) from(planning, 'Ödemeler', 'Ödemelerim', 'payments'),
      from(
        documents,
        _isClient ? 'Belgelerim' : 'Belgeler',
        _isClient ? 'Belgelerim' : 'Belgeler',
        'documents',
      ),
      if (!_isClient) from(planning, 'Ödemeler', 'Tahsilatlar', 'payments'),
    ]);
    const business = 'İşletme Yönetimi';
    final sections = <MenuSection>[
      main,
      group('KDV Hesaplama', [
        MenuEntry(
          title: 'KDV Hesaplama',
          subtitle: 'Döneme göre ödenecek ve devreden KDV',
          icon: Icons.percent_rounded,
          viewId: 'accounting-vat-calculation',
          builder: (_) => VatCalculationPage(api: widget.api),
        ),
      ], parent: business),
      group('Müşteri Yönetimi', [
        from(sales, 'Müşteriler', 'Müşteriler', 'accounting-sales-partners'),
      ], parent: business),
      group('Satış Modülü', [
        from(
          sales,
          'Ürün ve Hizmetler',
          'Hizmetler',
          'accounting-sales-services',
        ),
        from(
          sales,
          'Satış Faturaları',
          'Satış Faturaları',
          'accounting-sales-invoices',
        ),
      ], parent: business),
      group('Stok Modülü', [
        from(sales, 'Depolar ve Stok', 'Stok Ana Sayfa', 'accounting-stock'),
        from(sales, 'Depo Tanımları', 'Depolar', 'accounting-stock-warehouses'),
      ], parent: business),
      group('Tahsilat Modülü', [
        from(
          sales,
          'Tahsilatlar',
          'Tahsilatlar',
          'accounting-sales-collections',
        ),
      ], parent: business),
      group('Teklif Modülü', [
        from(sales, 'Teklifler', 'Teklifler', 'accounting-sales-quotes'),
      ], parent: business),
      group('Gelir - Gider Modülü', [
        from(
          expenseSection,
          'Gider Listesi',
          'Gelir ve Giderler',
          'accounting-expenses-expenses',
        ),
        from(
          expenseSection,
          'Tedarikçiler',
          'Tedarikçiler',
          'accounting-expenses-suppliers',
        ),
        from(
          expenseSection,
          'Tedarikçi Ödemeleri',
          'Ödemeler',
          'accounting-expenses-payments',
        ),
        MenuEntry(
          title: 'Ön Tanımlar',
          subtitle: 'Gider kategorilerini yönetin',
          icon: Icons.category_outlined,
          viewId: 'accounting-expenses-definitions',
          builder: (_) => ExpenseDefinitionsPage(api: widget.api),
        ),
      ], parent: business),
      group('Nakit ve Banka', [
        from(
          cash,
          'Kasa ve Bankalar',
          'Kasa ve Bankalar',
          'accounting-cash-accounts',
        ),
        from(
          cash,
          'Kasa Hareketleri',
          'Nakit Hareketleri',
          'accounting-cash-transactions',
        ),
        from(
          cash,
          'Çekler ve Senetler',
          'Çekler ve Senetler',
          'accounting-cash-checks',
        ),
      ], parent: business),
      group('Raporlar', [
        report('Vade Yaşlandırma', 'aging', 'accounting-reports-aging'),
        report('KDV Raporu', 'vat', 'accounting-reports-vat'),
        report(
          'Kasa ve Banka Özeti',
          'cash-register',
          'accounting-reports-cash-register',
        ),
        report('Nakit Akışı', 'cash-flow', 'accounting-reports-cash-flow'),
      ], parent: business),
      group('Fatura / E-Fatura', [
        invoiceBox('Gelen Kutusu', 'einvoice-inbox', incoming: true),
        invoiceBox('Giden Kutusu', 'einvoice-outbox'),
        invoiceComposer('E-Fatura Oluştur', 'einvoice-create', 'EINVOICE'),
        invoiceDrafts('Taslak Faturalar', 'einvoice-drafts', 'EINVOICE'),
        invoiceUpload('Fatura Yükleme', 'einvoice-upload', 'EINVOICE'),
        invoiceUpload(
          'Medula Fatura Yükleme',
          'einvoice-medula-upload',
          'EINVOICE',
          medula: true,
        ),
        MenuEntry(
          title: 'Fatura Ayarları',
          subtitle: 'İzibiz hesabı, seri ve gönderici bilgileri',
          icon: Icons.tune_outlined,
          viewId: 'einvoice-settings',
          builder: (_) =>
              EInvoiceSettingsPage(api: widget.api, isClient: _isClient),
        ),
      ], parent: business),
      group('Fatura / E-Arşiv', [
        invoiceBox('E-Arşiv Faturalar', 'earchive-invoices', archive: true),
        invoiceComposer('E-Arşiv Oluştur', 'earchive-create', 'EARCHIVE'),
        invoiceDrafts('Taslak Faturalar', 'earchive-drafts', 'EARCHIVE'),
        invoiceUpload('E-Arşiv Yükle', 'earchive-upload', 'EARCHIVE'),
        MenuEntry(
          title: 'E-Arşiv Raporları',
          subtitle: 'Aylık belge ve raporlama durumları',
          icon: Icons.assessment_outlined,
          viewId: 'earchive-reports',
          builder: (_) =>
              EArchiveReportsPage(api: widget.api, isClient: _isClient),
        ),
      ], parent: business),
      if (!_isClient)
        group('Diğer E-Belgeler', [
          from(
            documents,
            'E-Belgeler',
            'E-İrsaliye, E-SMM ve Diğerleri',
            'edocuments',
          ),
        ], parent: business),
      if (!_isClient)
        group('İletişim', [
          from(communication, 'Sohbet', 'Sohbet', 'chat'),
          from(communication, 'Mail Gönder', 'Mail Gönder', 'messages'),
          from(communication, 'Forum', 'Forum', 'forum'),
          from(
            communication,
            'Mükellef İstekleri',
            'Mükellef İstekleri',
            'matching',
          ),
        ]),
      group(_isClient ? 'Hesap' : 'Araçlar', [
        if (_isClient) from(planning, 'Kartlarım', 'Kartlarım', 'stored-cards'),
        from(
          documents,
          'Sistem Güncellemeleri',
          'Sistem Güncellemeleri',
          'system-updates',
        ),
        if (!_isClient)
          from(
            advisorTools,
            'Hızlı Giriş Aracı',
            'Giriş Bilgileri',
            'credentials',
          ),
        from(
          planning,
          'Takvim ve Hatırlatıcılar',
          _isClient ? 'Takvim & GİB' : 'Takvim',
          'calendar',
        ),
        if (_isClient)
          MenuEntry(
            title: 'Hatırlatıcılar',
            subtitle: 'Ödeme hatırlatma kurallarım',
            icon: Icons.notifications_active_outlined,
            viewId: 'reminders',
            builder: (_) => ReminderRulesPage(
              api: widget.api,
              refreshKey: _refreshKey,
              isClient: true,
            ),
          ),
        if (!_isClient)
          from(advisorTools, 'Şablonlar', 'Şablonlar', 'templates'),
        if (!_isClient)
          from(advisorTools, 'Hatırlatma Kuralları', 'Kurallar', 'rules'),
        from(planning, 'Hesaplama Yap', 'Hesaplama Yap', 'calculator'),
        from(planning, 'Not Defteri', 'Not Defteri', 'notes'),
        if (_isClient) from(account, 'Profilim', 'Profilim', 'profile'),
        if (!_isClient) from(account, 'Ayarlar', 'Ayarlar', 'settings'),
        MenuEntry(
          title: 'Alt Kullanıcılar',
          subtitle: 'Ekip üyeleri ve işlem izinleri',
          icon: Icons.groups_outlined,
          viewId: 'sub-users',
          builder: (_) => SubUsersPage(api: widget.api),
        ),
        from(communication, 'Destek', 'Destek', 'support'),
      ]),
      group('Diğer', [
        if (!_isClient)
          from(
            advisorTools,
            'Harici Mükellefler',
            'Harici Mükellefler',
            'clients',
          ),
        from(planning, 'Ek Ücretler', 'Ek Ücretler', 'payment-extra-charge'),
        from(planning, 'Taksitler', 'Taksitler', 'payment-installment'),
        MenuEntry(
          title: 'Tüm Raporlar',
          subtitle: 'Ek işletme raporları',
          icon: Icons.insert_chart_outlined_rounded,
          viewId: 'accounting-reports',
          builder: (_) =>
              DashboardReportsPage(api: widget.api, refreshKey: _refreshKey),
        ),
        from(
          expenseSection,
          'Çalışanlar',
          'Çalışanlar',
          'accounting-payroll-employees',
        ),
        from(
          expenseSection,
          'Bordro ve Puantaj',
          'Bordro ve Puantaj',
          'accounting-payroll-payroll',
        ),
        from(sales, 'Satış Raporu', 'Satış Raporu', 'accounting-reports-sales'),
        from(
          expenseSection,
          'Gider Raporu',
          'Gider Raporu',
          'accounting-reports-expenses',
        ),
        from(account, 'Profilim', 'Profilim', 'profile'),
        from(communication, 'Sohbet', 'Sohbet', 'chat'),
        from(communication, 'Danışma', 'Danışma', 'matching'),
        from(documents, 'Duyurular', 'Duyurular', 'notifications'),
        from(account, 'Bildirimler', 'Bildirimler', 'notifications'),
        from(
          sales,
          'İade Faturaları',
          'İade Faturaları',
          'accounting-sales-invoices',
        ),
        from(
          expenseSection,
          'Gelen Faturalar',
          'Gelen Faturalar',
          'accounting-expenses-expenses',
        ),
      ]),
    ];
    return [
      for (final section in sections)
        if (section.entries.any(_canOpenMenuEntry))
          MenuSection(
            title: section.title,
            parentTitle: section.parentTitle,
            entries: section.entries.where(_canOpenMenuEntry).toList(),
          ),
    ];
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
          body: ExpenseGroupsPage(api: widget.api, refreshKey: _refreshKey),
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
          _openSales();
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
    final created = await showExpenseEntryForm(context, widget.api);
    if (created && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gider kaydedildi')));
    }
  }

  Future<void> _showCollectionForm() async {
    final created = await showCollectionEntryForm(context, widget.api);
    if (created && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tahsilat kaydedildi')));
    }
  }

  Widget _page() {
    if (_accessPolicy.isPaymentLocked) {
      return PaymentsListPage(
        api: widget.api,
        refreshKey: _refreshKey,
        isClient: true,
      );
    }
    if (_index == 3) {
      return FeatureMenuPage(
        sections: _menuSections,
        onLogout: () => widget.onLogout(),
        roleLabel: _isAdmin
            ? 'Yönetici'
            : _isClient
            ? 'Mükellef'
            : 'Müşavir',
      );
    }
    if (_isAdmin) {
      if (_index == 1) {
        return AdminResourcePage(api: widget.api, module: adminModules.first);
      }
      if (_index == 2) {
        return AdminResourcePage(
          api: widget.api,
          module: adminModules.firstWhere((module) => module.id == 'financial'),
        );
      }
      return AdminOverviewPage(api: widget.api);
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
            onOpenSales: _openSales,
            onOpenExpenses: _openExpenses,
            onOpenCash: _openCash,
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
          onOpenSales: _openSales,
          onOpenExpenses: _openExpenses,
          onOpenCash: _openCash,
          onOpenReports: _openReports,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_identityReady) {
      return Scaffold(
        body: Center(
          child: _identityError == null
              ? const LoadingState()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Oturum bilgileri alınamadı: $_identityError'),
                    TextButton(
                      onPressed: _loadIdentity,
                      child: const Text('Tekrar Dene'),
                    ),
                    TextButton(
                      onPressed: widget.onLogout,
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (_accessPolicy.isPaymentLocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ödemelerim'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Çıkış Yap',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: PaymentsListPage(
          api: widget.api,
          refreshKey: _refreshKey,
          isClient: true,
        ),
      );
    }
    return PopScope(
      canPop: _index == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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
                onMenu: () => _selectTab(3),
                onBack: _index != 0 || _tabHistory.isNotEmpty ? _goBack : null,
              ),
              if (_maintenanceNoticeText != null)
                _MaintenanceStrip(text: _maintenanceNoticeText!),
              Expanded(child: _page()),
            ],
          ),
        ),
        bottomNavigationBar: _BottomNavigation(
          index: _index,
          onSelect: _selectTab,
          onAdd: _showQuickActions,
          labels: _isClient
              ? const ['Özet', 'Ödemeler', 'Belgeler', 'Menü']
              : _isAdmin
              ? const ['Özet', 'Üyeler', 'Finans', 'Menü']
              : const ['Özet', 'Faturalar', 'Kasa', 'Menü'],
        ),
      ),
    );
  }
}

/// Planlanan bakım bilgisini gösteren uyarı şeridi.
class _MaintenanceStrip extends StatelessWidget {
  const _MaintenanceStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4E0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    this.onBack,
  });

  final bool demoMode;
  final String userName;
  final String companyName;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;
  final VoidCallback onMenu;
  final VoidCallback? onBack;

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
          if (onBack != null) BackButton(onPressed: onBack),
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
