import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_client.dart';

/// Finkit bildirim servisi.
///
/// - Sunucudan gelen gerçek zamanlı olayları (yeni bildirim, yeni mesaj)
///   WebSocket üzerinden dinler ve sistem bildirimi olarak gösterir.
/// - Hatırlatıcılar için zamanlanmış yerel bildirim kurar.
/// - Uygulama içi bildirim merkezini beslemek için olay yayınlar.
class AppNotifications {
  AppNotifications._();

  static final AppNotifications instance = AppNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  FinkitApi? _api;
  int? _userId;
  bool _initialized = false;
  bool _connected = false;
  bool _enabled = true;

  static const String _channelId = 'finkit_bildirim';
  static const String _enabledKey = 'finkit_notifications_enabled';
  static const String _channelName = 'Finkit Bildirimleri';
  static const String _channelDescription =
      'Ödeme, tahsilat, hatırlatıcı ve belge bildirimleri';

  /// Arka plan izolatında çalışırken izin isteme çağrısı yapılmaz; arka planda
  /// Activity olmadığı için bu çağrı hata verir (izinler zaten alınmıştır).
  static bool runningInBackgroundIsolate = false;

  /// Uygulama içi dinleyiciler için olay akışı.
  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isConnected => _connected;

  /// Kullanıcı bildirimleri kapattıysa sistem bildirimi gösterilmez.
  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Bildirim servisine bağlı kullanıcının kimliği (mesaj baloncukları için).
  int? get currentUserId => _userId;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      // Bölge bulunamazsa varsayılan UTC kullanılır.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        _events.add({
          'type': 'NOTIFICATION_TAPPED',
          'payload': response.payload,
        });
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    if (!runningInBackgroundIsolate) {
      try {
        await androidPlugin?.requestNotificationsPermission();
      } catch (_) {
        // İzin isteme desteklenmiyorsa (eski Android) sessizce devam edilir.
      }
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    await init();
    if (!_enabled) return;
    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  /// Belirtilen zamanda bildirim göster (hatırlatıcılar için).
  Future<void> scheduleAt(
    DateTime when, {
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    await init();
    if (!_enabled) return;
    if (when.isBefore(DateTime.now())) return;
    final scheduled = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id ?? when.millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (error) {
      // Zamanlama başarısız olursa bildirim sessizce atlanır; sebep loglanır.
      debugPrint('Hatırlatıcı planlanamadı: $error');
    }
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Sunucudaki gerçek zamanlı olay akışına bağlanır.
  void connect(FinkitApi api, int userId) {
    _api = api;
    _userId = userId;
    debugPrint(
      'Bildirim WS: connect çağrıldı (demo=${api.demoMode}, '
      'token=${api.token != null}, user=$userId)',
    );
    if (api.demoMode || api.token == null) return;
    _openSocket();
  }

  void _openSocket() {
    final api = _api;
    final userId = _userId;
    final token = api?.token;
    if (api == null || userId == null || token == null) return;

    _closeSocket();

    final wsBase = api.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse(
      '$wsBase/chat/ws/$userId?token=${Uri.encodeComponent(token)}',
    );
    try {
      debugPrint('Bildirim WS: bağlanıyor -> $uri');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleFrame,
        onDone: () {
          debugPrint('Bildirim WS: bağlantı kapandı');
          _scheduleReconnect();
        },
        onError: (Object error) {
          debugPrint('Bildirim WS hatası: $error');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      _connected = true;
    } catch (error) {
      debugPrint('Bildirim WS kurulamadı: $error');
      _scheduleReconnect();
    }
  }

  void _closeSocket() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void _scheduleReconnect() {
    _connected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), _openSocket);
  }

  void _handleFrame(dynamic frame) {
    if (frame is! String) return;
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map) return;
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = data['type']?.toString() ?? '';
    debugPrint('Bildirim WS olayı: $type');
    switch (type) {
      case 'NEW_NOTIFICATION':
        final title = data['title']?.toString() ?? 'Finkit bildirimi';
        final message = data['message']?.toString() ?? '';
        show(title: title, body: message, payload: 'notification');
        break;
      case 'NEW_MESSAGE':
        final content = data['content']?.toString() ?? 'Yeni mesajınız var';
        show(
          title: 'Yeni mesaj',
          body: content,
          payload: 'chat:${data['sender_id']}',
        );
        break;
      default:
        break;
    }
    _events.add(data);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeSocket();
    _api = null;
    _userId = null;
  }

  /// Firebase Cloud Messaging jetonunu sunucuya kaydeder.
  ///
  /// Firebase yapılandırması (google-services.json) projeye eklenip
  /// `firebase_messaging` bağımlılığı eklendiğinde çağrılmalıdır.
  Future<void> registerDeviceToken(
    FinkitApi api, {
    required String deviceToken,
  }) async {
    try {
      await api.registerDeviceToken(
        deviceToken: deviceToken,
        platform: defaultTargetPlatform.name,
      );
    } catch (_) {
      // Jeton kaydı başarısız olursa uygulama akışı bozulmaz.
    }
  }
}
