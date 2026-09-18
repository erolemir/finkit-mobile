import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'pages/app_shell.dart';
import 'pages/login_page.dart';
import 'services/app_notifications.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Telefonun kendi alt gezinme çubuğunu gizle; durum çubuğu görünür kalır.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  // Bildirim kanalı ve izinleri uygulama açılışında hazırlanır.
  await AppNotifications.instance.init();
  runApp(const FinkitMobileApp());
}

class FinkitMobileApp extends StatefulWidget {
  const FinkitMobileApp({super.key});

  @override
  State<FinkitMobileApp> createState() => _FinkitMobileAppState();
}

class _FinkitMobileAppState extends State<FinkitMobileApp> {
  final FinkitApi _api = FinkitApi();
  bool _ready = false;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    // Jeton yenilenemezse kullanıcı giriş ekranına döner.
    _api.onSessionExpired = () {
      if (mounted) setState(() => _authenticated = false);
    };
    _restore();
  }

  Future<void> _restore() async {
    await _api.restore();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _authenticated = _api.token != null;
    });
  }

  Future<void> _logout() async {
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
          : _authenticated
          ? FinkitShell(api: _api, onLogout: _logout)
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
