import 'package:flutter/services.dart';

/// Telefonun kendi alt gezinme çubuğunu (geri/home/uygulamalar) gizli tutar.
///
/// Android tarafında `MainActivity` bunu native olarak uygular; Flutter tarafı
/// uygulama öne geldiğinde ve klavye açılıp kapandığında tekrar uygular, çünkü
/// bazı üretici yazılımları çubuğu bu durumlarda geri getiriyor.
class SystemUi {
  const SystemUi._();

  static Future<void> keepNavigationBarHidden() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top],
    );
  }
}
