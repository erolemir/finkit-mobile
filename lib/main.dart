import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'pages/app_shell.dart';
import 'pages/login_page.dart';
import 'services/app_notifications.dart';
import 'services/background_sync.dart';
import 'services/system_ui.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Telefonun kendi alt gezinme çubuğunu gizle; durum çubuğu görünür kalır.
  await SystemUi.keepNavigationBarHidden();
  // Bildirim kanalı ve izinleri uygulama açılışında hazırlanır.
  await AppNotifications.instance.init();
  runApp(const FinkitMobileApp());
}

class FinkitMobileApp extends StatefulWidget {
  const FinkitMobileApp({super.key});

  @override
  State<FinkitMobileApp> createState() => _FinkitMobileAppState();
}

class _FinkitMobileAppState extends State<FinkitMobileApp>
    with WidgetsBindingObserver {
  final FinkitApi _api = FinkitApi();
  bool _ready = false;
  bool _authenticated = false;
  Timer? _maintenancePoll;
  bool _maintenanceMode = false;
  Map<String, dynamic>? _maintenanceNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Jeton yenilenemezse kullanıcı giriş ekranına döner.
    _api.onSessionExpired = () {
      if (mounted) setState(() => _authenticated = false);
    };
    _restore();
  }

  @override
  void dispose() {
    _maintenancePoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sistem bakım durumunu kontrol eder.
  ///
  /// Bakım başladığında açık oturum kapatılır; kullanıcı bakım saatinden önce
  /// e-posta ve bildirimle bilgilendirilmiş olur.
  Future<void> _checkMaintenance() async {
    try {
      final status = await _api.systemStatus();
      if (!mounted) return;
      final inMaintenance = status['maintenance_mode'] == true;
      if (inMaintenance && !_maintenanceMode && _authenticated) {
        await _logout();
        if (!mounted) return;
      }
      setState(() {
        _maintenanceMode = inMaintenance;
        _maintenanceNotice = inMaintenance ? null : status;
      });
    } catch (_) {
      // Ağ hatasında mevcut durum korunur.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama öne geldiğinde alt gezinme çubuğu yeniden gizlenir.
    if (state == AppLifecycleState.resumed) {
      SystemUi.keepNavigationBarHidden();
    }
  }

  @override
  void didChangeMetrics() {
    // Klavye açılıp kapandığında çubuk geri gelirse tekrar gizlenir.
    SystemUi.keepNavigationBarHidden();
  }

  Future<void> _restore() async {
    await _api.restore();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _authenticated = _api.token != null;
    });
    // Kayıtlı sunucu adresi yüklendikten SONRA bakım kontrolü başlatılır.
    await _checkMaintenance();
    // Bakım modu ve planlı bakım bilgisi dakikada bir kontrol edilir.
    _maintenancePoll = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkMaintenance(),
    );
  }

  Future<void> _logout() async {
    await BackgroundSync.cancelAll();
    await _api.logout();
    if (!mounted) return;
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finkit Mobil',
      theme: buildFinkitTheme(),
      home: !_ready
          ? const _SplashScreen()
          : _maintenanceMode
          ? _MaintenanceScreen(onRetry: _checkMaintenance)
          : _authenticated
          ? FinkitShell(
              api: _api,
              onLogout: _logout,
              maintenanceNotice: _maintenanceNotice,
            )
          : FinkitLoginPage(
              api: _api,
              onAuthenticated: () => setState(() => _authenticated = true),
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: FinkitColors.ink,
              child: Text(
                'F',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
            ),
            SizedBox(height: 18),
            CircularProgressIndicator(
              color: FinkitColors.ink,
              strokeWidth: 2.4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bakım modu açıkken gösterilen tam ekran.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF4E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  size: 38,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sistem Bakımda',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Finkit şu anda bakım modundadır. Bakım başladığında açık '
                'oturumunuz güvenli şekilde kapatıldı. Çalışmalarınız kaydedildi; '
                'bakım tamamlandığında tekrar giriş yapabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: FinkitColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tekrar Kontrol Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
