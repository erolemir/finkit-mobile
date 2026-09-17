# Finkit Mobil (Flutter)

Finkit ön muhasebe platformunun Android ve iOS uygulaması. Tek Flutter kod
tabanı kullanılır; Capacitor/WebView katmanı yoktur.

## Kapsam

- Giriş: müşavir (`ADVISOR`) ve mükellef (`CLIENT`) rolü, sunucu adresi seçimi,
  çevrimdışı demo modu.
- Panel: satış, gider, nakit ve özet metrikleri.
- Satışlar: satış faturası listesi, fatura kesinleştirme, fatura detayı.
- Giderler: gelen faturalar ve gider listesi.
- Nakit: kasa/banka hesapları ve nakit hareketleri.
- Cari: müşteri listesi, arama ve cari kartı oluşturma.
- Personel: çalışan listesi ve dönemsel bordro.
- Raporlar: satış, tahsilat, gider, ödeme, KDV, gelir-gider, nakit akışı, kasa,
  stok, vade yaşlandırma, bordro.
- Hızlı işlemler: yeni satış faturası, yeni cari, gider ekleme, tahsilat.

Yazma işlemleri `/api/accounting/*` uçlarını kullanır. Fatura kesinleştirme,
cari, stok ve KDV hareketini backend'de tek transaction içinde oluşturur;
uygulama bu hareketleri kendi tarafında tekrar üretmez.

## Gereksinimler

- Flutter 3.47 veya üzeri
- Android: Android SDK 36, NDK 28.2, CMake 3.22 (native asset'ler için)
- iOS: Xcode 16+ ve CocoaPods

## Çalıştırma

```bash
flutter pub get
flutter run
```

Test ortamı varsayılan sunucu adresi: `https://test.finkit.com.tr/api`
Giriş ekranından farklı bir sunucu adresi girilebilir.

## Doğrulama

```bash
dart analyze .
flutter test
# Gerçek backend'e karşı uçtan uca akış (giriş, cari, fatura, rapor):
$env:FINKIT_LIVE=1; flutter test test/live_api_test.dart
flutter build apk --release
```

`test/live_api_test.dart` ortam değişkeni verilmediğinde atlanır; böylece
ağsız ortamlarda test paketi kırılmaz.

## Android release derlemesi ve klasör yolu

Flutter'ın AOT derleyicisi Windows'ta Türkçe karakter içeren yollarda
(`Masaüstü` gibi) çalışmaz. Bu yüzden proje `C:\Users\emirh\dev\finkit-mobile`
altında tutulur. Projeyi taşımanız gerekirse ASCII karakterli bir yol seçin.

Paket kimliği: `com.finkit.mobile`
