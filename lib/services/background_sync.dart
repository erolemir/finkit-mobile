import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api_client.dart';
import 'app_notifications.dart';

/// Android WorkManager ile periyodik bildirim kontrolü.
///
/// Uygulama kapalıyken de (yaklaşık 15 dakikada bir) sunucudaki yeni
/// bildirimler çekilir ve sistem bildirimi olarak gösterilir. Firebase
/// yapılandırması gerektirmez.
class BackgroundSync {
  static const String taskName = 'finkitBildirimKontrol';
  static const String periodicUniqueName = 'finkit.bildirim.periodic';
  static const String oneOffUniqueName = 'finkit.bildirim.oneoff';

  /// Son gösterilen bildirim kimliği (ön plan ve arka plan ortak kullanır).
  static const String lastSeenKey = 'finkit_bg_last_notification';

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Workmanager().initialize(notificationCallbackDispatcher);
    _initialized = true;
  }

  /// Periyodik kontrolü kaydeder (giriş sonrası çağrılır).
  static Future<void> registerPeriodic() async {
    try {
      await _ensureInitialized();
      await Workmanager().registerPeriodicTask(
        periodicUniqueName,
        taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (error) {
      debugPrint('Arka plan görevi kaydedilemedi: $error');
    }
  }

  /// Kısa süreli tek seferlik kontrol (test ve elle tetikleme için).
  static Future<void> runOnce({
    Duration delay = const Duration(seconds: 10),
  }) async {
    try {
      await _ensureInitialized();
      await Workmanager().registerOneOffTask(
        oneOffUniqueName,
        taskName,
        initialDelay: delay,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (error) {
      debugPrint('Tek seferlik görev kaydedilemedi: $error');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _ensureInitialized();
      await Workmanager().cancelByUniqueName(periodicUniqueName);
      await Workmanager().cancelByUniqueName(oneOffUniqueName);
    } catch (error) {
      debugPrint('Arka plan görevi iptal edilemedi: $error');
    }
  }

  /// Ön planda görülen en yeni bildirim kimliğini işaretler.
  static Future<void> markSeen(int notificationId) async {
    if (notificationId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastSeenKey, notificationId);
  }

  /// Kayıtlı oturumla yeni bildirimleri kontrol eder.
  static Future<void> checkNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('finkit_notifications_enabled') ?? true)) return;

    final api = await FinkitApi.fromStoredSession();
    if (api == null) {
      debugPrint('Arka plan: kayıtlı oturum bulunamadı');
      return;
    }

    final items = await api.notifications(pageSize: 5);
    if (items.isEmpty) {
      debugPrint('Arka plan: bildirim listesi boş');
      return;
    }

    final newestId = int.tryParse('${items.first['id']}') ?? 0;
    final lastSeen = prefs.getInt(lastSeenKey) ?? 0;
    debugPrint('Arka plan: en yeni=$newestId, son görülen=$lastSeen');
    if (lastSeen == 0 || newestId <= lastSeen) {
      if (lastSeen == 0) await prefs.setInt(lastSeenKey, newestId);
      return;
    }

    final fresh = items
        .where(
          (item) =>
              (int.tryParse('${item['id']}') ?? 0) > lastSeen &&
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
    debugPrint('Arka plan: ${fresh.length} yeni bildirim gösterildi');
    await prefs.setInt(lastSeenKey, newestId);
  }
}

/// Arka plan izolatında çalışan görev dağıtıcısı.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await BackgroundSync.checkNotifications();
    } catch (error) {
      debugPrint('Arka plan bildirim kontrolü hatası: $error');
    }
    return true;
  });
}
