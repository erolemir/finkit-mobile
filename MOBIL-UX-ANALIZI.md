# Mobil kullanılabilirlik incelemesi — 19.09.2026

## Bulgular ve değişiklikler

- **Geri gezinme:** Ana sekmelerde geçmiş tutulmuyordu; Android sistem gezinmesi hem Flutter hem native katmanda gizleniyordu. Sekme geçmişi, görünür geri düğmesi ve sistem geri desteği eklendi; native gizleme kaldırıldı.
- **Yanlış kısayollar:** Mükellef ana ekranındaki satış ve kasa kısayolları ödeme/belge sekmesine gidiyordu. Artık ilgili muhasebe ekranını açıyor.
- **Fatura ayrıntıları:** Satış detayı yalnızca liste özetini gösteriyordu. Gelen, iade ve ana ekran kartlarında eksik bağlantılar vardı. Ortak tam ekran detay; sunucudan kalem yükleme, müşteri/tedarikçi, tarihler, durum, tutar ve ödeme kırılımı sağlıyor. Uzun içerik kaydırılabilir; yükleme hatasında yeniden deneme var.
- **Tedarikçi eşleştirmesi:** Eksik tedarikçi yalnız hata bildirimi üretiyordu; sunucuda eşleştirme ucu da yoktu. Seçim/arama/yeni tedarikçi akışı, aynı faturaya dönüş ve ayrı onay adımı eklendi. Backend yalnız aynı firmaya ait aktif tedarikçiyi kabul eder; kapalı dönem ve kesinleşmiş belge korunur. Var olan request session ve bağlantı havuzu kullanılır.
- **Yeni gelen fatura:** Önce taslak kaydedilir ve inceleme ekranı açılır; onay açık kullanıcı işlemiyle yapılır.
- **E-faturalar:** Gelen/giden kartlar detay açar. Mevcut içerik uçlarından orijinal HTML belge görüntülenebilir; servis hatası ekranda yeniden denenebilir. Belge içeriğinde JavaScript kapalıdır.
- **Menü:** Sabit arama, Türkçe karakter toleransı, kategori filtreleri ve açılır bölümler eklendi. Raporlar tek kategoride toplandı. Rol bazlı erişim korunur.

## Doğrulama ve sınırlar

- İki rol için menü ekranları ve 360 piksel telefon yerleşimleri widget testleriyle tarandı. Fatura eşleştirme, onaydan vazgeçme, hata sonrası detayların korunması ve büyük metinle uzun fatura test edildi.
- Backend testleri firma izolasyonu, geçersiz/pasif cari, kapalı dönem, kesinleşmiş fatura ve mükerrer onay davranışını kapsar. SQLite testleri gerçek PostgreSQL eşzamanlı yük testinin yerine geçmez.
- Verilen hesaplarla ana sunucuda giriş başarılı; muhasebe fatura listeleri boş. Test sunucusunda mükellef girişi başarılı, müşavir girişi reddedildi. Gerçek hesapların faturalarını onaylayan/yazan bir test yapılmadı.
- APK mevcut test sunucusu varsayılanını korur; kayıtlı sunucu seçimi değişmez. Ana sunucu hesapları için giriş/ayarlar bölümünde `https://finkit.com.tr/api` seçilmelidir.
- Orijinal e-fatura görünümü sağlayıcının içerik döndürmesine bağlıdır. Boş hesaplarla gerçek belge üzerinde doğrulanamadı; fiziksel telefonda klavye ve WebView kontrolü gerekir.
