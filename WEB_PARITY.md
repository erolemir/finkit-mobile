# Finkit web → Flutter işlem eşlik matrisi

Kaynak sürümler: web `9e43d37`, API `5c1750c`, mobil başlangıç `d8c5e33`.
Durumlar: **Var** (mevcut mobilde işlem çalışıyor), **Kısmi** (yalnız bir kısmı var), **Eksik**, **Kapalı** (web de kapalı), **Yer tutucu**. Bir sayfayı **Var** yapmak için yalnız listeyi göstermek yetmez; aşağıdaki bütün çalışan işlemler mobilde doğrulanır. Müşavir ve mükellef için aynı muhasebe API'si kullanılsa da rol, izin ve ödeme kilidi ayrı test edilir.

## Müşavir ve mükellef: işletme yönetimi

| Web bölümü | Çalışan web işlemleri | Başlangıç mobil durumu | API |
|---|---|---|---|
| KDV Hesaplama | Dönem seçme, hesaplanan/devreden/ödenecek KDV kırılımı | Kısmi: KDV raporu var | `/accounting/vat-calculation` |
| Müşteriler / Tedarikçiler | Liste/filtre, cari oluştur/düzenle/arşivle, detay ve gelen/giden fatura geçmişi | Kısmi: liste/oluştur/detay | `/accounting/partners*` |
| Hizmetler / Stok Ana Sayfa | Ürün/hizmet oluştur/düzenle/sil, fiyat/KDV/maliyet, stok özeti, ürün geçmişi | Kısmi: liste/oluştur/stok | `/accounting/products*`, `/accounting/stock/*` |
| Depolar | Liste/oluştur/düzenle, stok hareketi ve depolar arası transfer | Kısmi: liste/oluştur/transfer | `/accounting/warehouses*`, `/accounting/stock/*` |
| Satış Faturaları | Filtre, çok kalemli taslak, iade referansı, kesinleştir/iptal/kopyala, irsaliye bağla, belge/içerik ayrıntısı | Kısmi: basit form/liste/kesinleştir/iptal | `/accounting/sales-invoices*` |
| Tahsilatlar | Filtre, oluştur/düzenle/sil, avans/faturaya dağıtma, ödeme ve kasa eşleşmesi | Kısmi: liste/oluştur | `/accounting/collections*` |
| Teklifler | Oluştur, durum değiştir, kopyala/revize et, faturaya dönüştür | Kısmi: oluştur/durum/dönüştür | `/accounting/quotes*` |
| Gelir ve Giderler | Dönem özeti; satış/iade ve alış giderlerini fatura/kalem bazında grupla; ödeme durumunu göster; manuel gider oluştur/düzenle/sil | Kısmi: düz gider listesi ve oluşturma; gruplama/düzenleme üzerinde çalışılıyor | `/accounting/expenses/grouped`, `/accounting/expenses*`, `/accounting/sales-invoices` |
| Ön Tanımlar | Gider kategorisi oluştur/düzenle/aktiflik | Kısmi: kategori oluştur | `/accounting/expense-categories*` |
| Gelen Faturalar | Filtre, tedarikçi eşleştirme, kalem ürün/depo eşleştirme veya yeni ürün, tüm kalemleri stoklaştırma ya da giderleştirme, içerik/ekler | Kısmi: liste, tedarikçi eşleme, kesinleştirme | `/accounting/purchase-invoices*`, `/accounting/attachments*` |
| Tedarikçi Ödemeleri | Ödeme/avans oluşturma, faturaya dağıtma, hesap bağlantısı | Kısmi: liste/oluştur | `/accounting/supplier-payments*` |
| Kasa ve Bankalar | Hesap oluşturma, hareket/virman, TCMB kuru getirme ve görüntüleme | Kısmi: hesap/hareket oluşturma | `/accounting/financial-*`, `/accounting/exchange-rates*` |
| Çekler ve Senetler | Oluşturma, tahsil/ciro/teminat/protesto olayları | Kısmi: liste/oluştur/olay | `/accounting/checks-notes*` |
| Raporlar | Vade, KDV, kasa, nakit akışı ve diğer web raporları; dönem/filtre/görsel kırılım/dışa aktarma | Kısmi: temel raporlar | `/accounting/reports/*`, `/accounting/vat-calculation` |
| Personel ve Bordro | Web menüsünde V1.1 kapsamında kullanıma kapalı | Kapalı; mevcut mobil ekleri sunucu yeteneğine göre ayrıca korunacak | `/accounting/capabilities` |

## E-belge ve fatura oluşturma

| Web bölümü | Çalışan web işlemleri | Başlangıç mobil durumu | API |
|---|---|---|---|
| E-Fatura Gelen/Giden | Ayrı kutular; arama/filtre; detay, PDF/HTML/UBL, durum yenileme, gelen faturaya kabul/ret, iptal | Kısmi: liste ve HTML | `/einvoice/*`, `/client-einvoice/*` |
| E-Arşiv | Ayrı fatura listesi, oluşturma, taslak, UBL yükleme, iptal ve dönem raporu | Kısmi: birleşik listede görüntüleme | aynı e-belge uçları |
| Fatura Oluştur | Alıcı/mükellef kontrolü, numara önizleme, çok satır, tüm çalışan fatura tipleri, KDV/tevkifat/istisna/YTB/ek vergi, iade referansı, hesap/şablon önizlemesi, taslak ve açık gönderim onayı | Eksik | `/einvoice/invoices`, `/client-einvoice/invoices`, `/number-preview`, `/check-user` |
| Taslaklar | Hesaba özel sunucu taslağı kaydet/aç/düzenle/sil ve gönderim sonrası kaldırma | Eksik | `/invoice-workspace/drafts*` + gönderim API'si |
| UBL / Medula | E-Fatura ve E-Arşiv UBL yükleme/gönderme; Medula yolu | Eksik | `/invoices/upload-ubl` |
| E-Belge Ayarları | İzibiz hesabı tanımlama/doğrulama, test hesabı, numara/seri ayarı | Kısmi: hesap okuma | `/account`, `/account/verify`, `/test-account/*` |
| E-İrsaliye, E-SMM, E-Müstahsil | Oluşturma, gelen/giden liste, PDF/HTML/UBL, durum yenileme, iptal | Kısmi: irsaliye listesi | `/einvoice/despatches*`, `/einvoice/esmm*`, `/einvoice/emm*` |

## Panel, ödeme ve ortak araçlar

| Web bölümü | Çalışan web işlemleri | Başlangıç mobil durumu | API |
|---|---|---|---|
| Müşavir Mükellefler | Ekle/düzenle/sil, dış mükellef, ödeme linki, ilişki ve ödeme ayrıntısı | Kısmi | `/clients*`, `/external-clients*` |
| Belgeler | Yükle/indir/sil, tür/tarih/kişi filtreleri, toplu yükleme ve bildirim | Kısmi: yükleme/liste | `/documents*` |
| Müşavir Tahsilatlar | Tahsilat/ek ücret/taksit/geçmiş, manuel ödeme, filtre/Excel | Kısmi: temel ödeme/ek ücret | `/payments*`, `/extra-charges*`, `/installments*` |
| Mükellef Ödemelerim / Kartlarım | Abonelik/hizmet/ek ücret/taksit ödeme, kayıtlı kart ekle/sil, otomatik ödeme talimatı | Kısmi: PayTR ve kartlar; otomatik ödeme eksik | `/paytr*`, `/auto-payment*` |
| Mükellef erişim kilidi | Abonelik bitişi veya gecikmiş hizmet ücreti halinde yalnız ödeme sayfaları | Eksik; politika kodlanıyor | `/clients/me` |
| Alt kullanıcılar | Liste/oluştur/düzenle/sil, modül ve işlem izinleri, sahibin kimliği, menü ve API kısıtları | Eksik; menü politikası kodlanıyor | `/sub-users*`, `/users/me` |
| Sohbet / Mail / Forum / Eşleşme | Mesaj/ek, okundu bilgisi, toplu gönderim, forum işlemleri ve eşleşme kabulü | Kısmi | `/chat*`, `/notifications*`, `/forum*`, `/matching*` |
| Takvim / Hatırlatıcılar | Etkinlik ve kural oluştur/düzenle/sil, GİB tarihi, bildirim | Kısmi: etkinlik CRUD, mükellef hedefi, ay/gün ızgarası, GİB tarihleri, ödeme vadesi, etkinlik şablonları ve kural CRUD mobilde var; webdeki ayrıntılı gün görünümü ve gerçek bildirim davranışı cihazda doğrulanacak | `/calendar*`, `/reminder-rules*`, `/general/gib-tax-calendar` |
| Şablonlar / Giriş Bilgileri / Destek | Şablon CRUD, şifre kasası, destek talebi ve yanıtları | Kısmi: mesaj şablonu oluştur/düzenle/sil/kopyala eklendi; giriş kasası ve destek gerçek API/cihaz doğrulaması açık | `/advisors/templates*`, `/credentials*`, `/support*` |
| Not Defteri | Hesap bazlı yerel not, düzenleme, kategori, renk, sabitleme, yapılacaklar, arama | Kısmi: eski mobil yalnız ekleme ve dokununca silme | Web ve mobil yerel depolama |
| Sistem Güncellemeleri / Hesaplama | Güncelleme okuma, hesaplama araçları | Var/Kısmi | `/system-updates` |

## Yönetici ve giriş öncesi

| Web bölümü | Çalışan web işlemleri | Başlangıç mobil durumu | API |
|---|---|---|---|
| Yönetici paneli | Özet ve istatistikler | Eksik | `/admin/dashboard` |
| Üyeler / Kullanıcılar | Liste/arama/detay, yasakla/aç, sil, işlem geçmişi | Eksik | `/admin/users*`, `/admin/logs*` |
| Müşavirler / Mükellefler | Liste/detay, danışma ve ödeme muafiyeti, bağlantılı kayıtlar | Eksik | `/admin/advisors*`, `/admin/clients*` |
| Değişiklikler / Onaylar | Müşavir değişimi, mükellef ve müşavir onay/ret | Eksik | `/admin/advisor-change-requests*`, `/admin/*approvals*` |
| Finans / Ödeme Logları | Özet, abonelik, hizmet ücreti, ödeme ayrıntısı ve iade | Eksik | `/admin/financial/*`, `/admin/payment-logs`, `/admin/payments/*/refund` |
| Transfer / SMS / Danışmanlık | Transfer yeniden dene, SMS ayrıntısı/iptali/gönderimi, danışmanlık geri bildirimleri | Kısmi: transfer listesi/durum filtresi ve yalnız banka iadesi/yerel IBAN hatasında tekrar eylemi; SMS ve danışmanlık işlemleri var. Transfer kalıcı claim ve yeni takip numarasıyla güvenli yerel teste alındı; gerçek PayTR mutabakatı bekliyor | `/admin/platform-transfers*`, `/admin/sms-*`, `/danisma/admin/*` |
| Duyuru / Sistem Güncellemesi / Destek | Liste/oluştur/düzenle/sil, e-posta gönderimi, destek durumu | Eksik | `/admin/announcements*`, `/admin/system-updates*`, `/admin/support*` |
| Ayarlar / Loglar | Ayar ve bakım modu, denetim listesi/arama/istatistik | Eksik | `/admin/settings`, `/admin/maintenance*`, `/admin/logs*` |
| Kayıt / doğrulama / şifre | Rol bazlı kayıt, ön kontrol, e-posta doğrulama, şifre sıfırlama | Eksik | `/auth/*` |
| Şirket kurulum | Webdeki çok adımlı kurulum ve ödeme/pending akışı | Eksik | `/company-setup*` |

Webdeki `Mobil Uygulama` ve `Yakında` tanıtım/yer tutucuları mobil hedefe dahil değildir. Webde fiyat listesi bileşeni V1.1'de kapalı, banka ekstresi bileşeni kullanıma kapalı, dönem kapanışı ise kapalı bordro sayfasının içinde; bunlar eşlik zorunluluğu değildir. Mobilin ek çalışan araçları, API yeteneği ve rol izinleri uygunsa ayrı alt bölümde korunur.

Derleme sınırı: varsayılan release yalnız `https://finkit.com.tr/api` kullanır ve test sunucusundaki kayıtlı oturumu taşımaz. Test için imzalı release derlemesi yapılacaksa açıkça `--dart-define=FINKIT_TEST_BUILD=true --dart-define=FINKIT_API_BASE_URL=https://test.finkit.com.tr/api` verilir. Debug derlemesi varsayılan test API'si ve sunucu seçim menüsüyle çalışır.

## Güncel kabul durumu

`1.7.2+10` ara sürümü kullanıcı isteğiyle `main`/`dev` dallarına ve Android APK'ya çıkarılıyor. Aşağıdaki **Kısmi** satırlar kapanmış kabul edilmiyor; gerçek PayTR/İzibiz ve fiziksel cihaz doğrulaması sonraki eşlik çalışmasında sürecek.

Yukarıdaki üçüncü sütun başlangıç fotoğrafıdır. Aşağıdaki satırlar uygulanan işlemlerin güncel durumunu gösterir; **Kısmi** olan hiçbir bölüm yayın için kapanmış sayılmaz.

| Bölüm | Mobilde doğrulanan çalışan işlemler | Açık fark / doğrulama | Durum |
|---|---|---|---|
| Satış faturaları | Sunucu araması, belge/ödeme/tür/müşteri/tarih filtresi ve sayfalama; çok kalemli taslak; iade referansı; kaynak, kur, depo, iskonto, KDV, tevkifat ve istisna alanları; onay, iptal, kopya, irsaliye bağı; sağlayıcı HTML/PDF/UBL alma | Sağlayıcı PDF fiziksel cihazda açma ve eski oturum/veri geçişi; Android gerçek cihaz ve iOS denemesi | Kısmi |
| Gelen faturalar | Sunucu araması, tedarikçi/belge/ödeme/tarih filtresi, sayfalama ve gelen kutusu senkronu; çok kalemli manuel taslak, numara/kaynak/tür/kur/vergi/kategori alanları; tedarikçi ve bütün kalemlerin stok veya gider işlemi; sağlayıcı HTML/PDF/UBL alma | Gerçek sağlayıcı ve cihaz denemesi; alış iadesi ve bütün muhasebe etkilerinin bütünleşme testi | Kısmi |
| Teklifler | Sunucu araması/filtre/sayfalama, çok kalemli taslak, kalem ayrıntısı, durum, kopya, revizyon ve faturaya çevirme | Gerçek cihaz ve tüm rol/izin senaryoları | Kısmi |
| Tahsilat / tedarikçi ödemesi | Sunucu filtre/sayfalama; fatura dağıtımı veya avans; ödeme yöntemi ve kasa bağlantısı; tahsilat düzenleme/silme; tekrar çağrı anahtarı | Sağlayıcı/hesap akışları ve bütün hata/tekrar denemelerinin gerçek cihaz doğrulaması | Kısmi |
| E-belge | Ayrı gelen/giden E-Fatura/E-Arşiv kutuları; taslak/gönderim/iptal/yanıt/durum; UBL/Medula; E-İrsaliye, E-SMM, E-Müstahsil; test bypass gönderimi | Yerel PDF düzeltmesi test API'ye dağıtılmadı; gerçek İzibiz ve Android/iOS dosya doğrulaması bekliyor | Kısmi |
| Muhasebe raporları | Webdeki tarih aralığı, bu ay/geçen ay/bu çeyrek/bu yıl, tahakkuk/nakit esası, özet ve kırılım; Excel/PDF dışa aktarma API'si ve mobil kaydetme eklendi. Test API'sinde ve Android emülatörünün İndirilenler klasöründe XLSX/PDF dosya imzaları doğrulandı. | Fiziksel Android/iOS kaydetme ve bütün rapor türleri sınanacak; webde kapalı bordro raporu ayrıca eşlik şartı değil. | Kısmi |
| Yönetici destek talepleri | Sunucu araması/durum filtresi/sayfalama, tam talep ayrıntısı, durum ve yönetici notu güncelleme, onaylı silme eklendi. | Yönetici test hesabı ve bildirimden ayrıntıya geçiş ile cihaz doğrulaması eksik. | Kısmi |
| Yönetici finansı | Gelir özeti, aylık abonelik/hizmet karşılaştırması, abonelik durumu, müşavir bazında mükellef hizmet ücretleri, sayfalama ve tüm satırları CSV dışa aktarma eklendi. | Yönetici test hesabı, gerçek API ve Android/iOS kaydetme doğrulaması eksik. | Kısmi |
| Yönetici SMS | Tarih filtresi ve sayfalı sipariş listesi, mesaj ayrıntısı/durumları, gönderim sürerken onaylı iptal ve hedefli/özel numaralı gönderim için ikinci onay eklendi. SMS sağlayıcısından önce DB havuz bağlantısı serbest bırakılıyor. | Yönetici test hesabı ve gerçek SMS test sağlayıcısı doğrulaması eksik; gerçek gönderim yapılmadı. | Kısmi |
| Yönetici log takibi | Olay istatistikleri, kategori/rol/yöntem/kullanıcı/tarih/arama filtreleri, sayfalama, ayrıntı ve CSV dışa aktarma eklendi; küçük ekran filtre/ayrıntı widget testinde doğrulandı. | Yönetici test hesabıyla gerçek API ve Android/iOS CSV kaydı doğrulaması eksik. | Kısmi |
| Yönetici üyeler / kullanıcılar | İşletme üyeleri ve yalnız yönetici kullanıcıları ayrı sunucu rol filtresiyle listeleniyor; arama, yasak durumu, sayfalama, sunucu ayrıntısı ve son işlem geçmişi eklendi. Yasaklama gerekçesi ve isim eşleşmeli silme onayı küçük ekran testinde doğrulandı. | Yönetici hesabıyla gerçek API ve silme/ban yetki senaryosu doğrulaması eksik. | Kısmi |
| Yönetici müşavirler / mükellefler | Müşavir listesinde mükellef sayısı/gelire göre sıralama, sunucu ayrıntısı ve bağlı mükellefler; mükellef listesinde iç kullanıcı adı/e-posta ve bağlı müşavir görünümü, danışma/ödeme muafiyeti değişimi ve ad eşleşmeli silme eklendi. Küçük ekran ayrıntı testi geçti. | Yönetici hesabıyla gerçek API ve durum değişimi/silme senaryosu doğrulaması eksik. | Kısmi |
| Yönetici danışmanlık | Soru arama/sayfalama, tam soru ve yanıt içeriği, gelir/yanıt/iade istatistikleri, geri bildirim türü/durum filtresi ve notlu, açık onaylı iade kararı eklendi. Widget testi soru, istatistik ve onay akışını doğruladı. | Yönetici test hesabıyla gerçek API doğrulaması ve PayTR ile fiili para iadesi bağı ayrı kontrol edilmeli; mevcut danışmanlık endpoint'i iade karar durumunu kaydediyor. | Kısmi |
| Kasa ve bankalar | Webdeki ad/tür/banka/şube/IBAN/para birimi/açılış bakiyesi formu ile hesap/banka/IBAN, tür ve para birimi filtreleri eklendi. Bakiyeler farklı para birimleri arasında toplanmıyor; küçük ekran form/bakiye widget testleri ve Android emülatörde test API'li liste açılışı geçti. | Hareket, silme ve mutabakat işlemlerinin gerçek API/cihaz doğrulaması eksik. | Kısmi |

## Uygulama durumu (devam ediyor)

Bu bölüm başlangıç durumunu değil, `codex/web-parity` dalındaki güncel işi kaydeder. **Kısmi** satırlar sürüm kabulünü karşılamaz.

| İşlem | Güncel durum | Kalan doğrulama veya iş |
|---|---|---|
| Rol menüsü, alt kullanıcı ve ödeme kilidi | Kısmi | Üç rolün bütün web işlem izinleri ve bildirim yönlendirmesi gerçek hesaplarla doğrulanacak. |
| KDV hesaplama ve gider ön tanımları | Kısmi | Bütün filtre/dışa aktarma ve gerçek API/cihaz senaryoları doğrulanacak. Fiyat listesi ve dönem kapanışı webde kapalı. |
| Gelir ve Giderler | Kısmi | Fatura bazlı gider/gelir grupları, satır ve ödeme durumu, tahakkuk/nakit özeti, manuel gider düzenleme/silme ve gider eki seçme/yükleme/indirme eklendi. Dosya seçimi widget, ek API'sinin DB havuzu yerel testte doğrulandı; tam filtre, dosya kaydı ve gerçek API/cihaz akışı açık. |
| Not Defteri | Var | Yerel not oluşturma/düzenleme, kategori, renk, sabitleme, yapılacaklar, arama, onaylı silme ve eski ortak notları seçerek içe alma eklendi. Hesap/rol değişiminde notların ayrılması ve nota dokunmanın silmemesi widget testinde doğrulandı; eski silen ekran kaldırıldı. Android emülatörde yeni not kaydı açıldı. |
| E-Fatura/E-Arşiv gelen-giden, durum, iptal, yanıt | Kısmi | HTML/PDF/UBL, durum/tarih/alıcı kimliği filtresi ve sunucu sayfalaması eklendi. Test İzibiz bypass hesabında E-Arşiv gönderimi, liste, detay ve HTML/UBL doğrulandı; test PDF'nin HTML dönmesi backend'de düzeltildi ama test ortamına henüz dağıtılmadı. Gerçek sağlayıcı doğrulaması eksik. |
| E-Fatura/E-Arşiv oluşturma, taslak, açık onay, UBL/Medula yükleme | Kısmi | Ek vergi/stopaj alanları, vergi hesaplaması, cari ve ürün kataloğu seçimi ve çoklu YTB iade referansı eklendi; tam fatura tip kuralları ve sağlayıcı bütünleşmesi eksik. |
| E-Belge ayarları ve E-Arşiv aylık raporu | Kısmi | Test hesabı açma/kapatma eklendi; E-Arşiv raporu artık aylık belgelerin bütün sunucu sayfalarını topluyor ve 101 belgeli yerel HTTP testiyle doğrulandı. Hesap ayarları rol bazında gerçek API ile doğrulanacak; yüksek hacimli rapor performansı ve cihaz denemesi açık. |
| E-İrsaliye, E-SMM ve E-Müstahsil | Kısmi | Giden/gelen irsaliye, makbuz listesi, oluşturma, durum, iptal ve HTML/PDF/UBL eklendi. Test bypass makbuz detayının yanlışlıkla mikroservise gitmesi ve PDF/UBL isteğinin HTML dönmesi backend'de düzeltildi; dağıtım ve gerçek sağlayıcı doğrulanacak. |
| Gelen alış faturasında stok/gider seçimi | Kısmi | Kalem bazlı seçim, depo/ürün ve gider işlemi bağlandı; gerçek API ve kısmi işlem sonrası tekrar deneme sınanacak. |
| Yönetici, kayıt ve alt kullanıcı | Kısmi | Şirket kurulumu, şifre sıfırlama, e-posta doğrulama ve Android/iOS bağlantı altyapısı eklendi; yönetici işlem formları, Android cihaz doğrulaması, Apple Team ID gerektiren site ilişki dosyası ve iOS cihaz testi eksik. |
| Yönetici PayTR ödeme iadesi | Kısmi | Kalıcı intent, tek açık iade ve belirsiz sonuçta PayTR durum sorgusu ile referans/tutar eşleme eklendi. Gerçek test sağlayıcısı, tamamlanmayan kayıtların takibi ve koordineli yayın doğrulaması eksik. |
| Kasa döviz kurları | Kısmi | TCMB kuru görüntüleme/getirme ve havuz bağlantısı düzeltmesi eklendi; gerçek TCMB/test API doğrulaması ve hesap işlemleri eksik. |
| Cari kart ve tahsilat | Kısmi | Detaydan düzenleme/arşivleme, giden/gelen sayfalı fatura geçmişi ve müşteri seçili tahsilat akışı eklendi; alt kayıtları düzenleme ve gerçek API doğrulaması eksik. |
| Tahsilat kaydı ve dağıtımı | Kısmi | Fatura/avans seçimi, tutar, yöntem, kasa, referans, düzenleme/silme onayı, tarih/arama filtresi ve sayfalama eklendi; gerçek API, çoklu dağıtım ve bütün müşteri/kasa filtreleri doğrulanacak. |
| Tedarikçi ödemesi | Kısmi | Fatura/avans seçimi, kalan tutar, yöntem, kasa, tarih/referans/not, arama ve sunucu filtresi/sayfalama eklendi. Çoklu fatura dağıtımı, numara araması ve 200 kayıt üzeri sayfalı seçim widget testinde doğrulandı; ödeme tutarını aşan dağıtım istemcide reddediliyor. Test API'de 1 TL avans ve aynı işlem anahtarıyla tekrar deneme doğrulandı. Çoklu dağıtımın gerçek API/cihaz doğrulaması ve ödeme üstü dağıtımı reddeden backend düzeltmesinin dağıtımı eksik. |
| Teklifler | Kısmi | Webdeki arama/durum/müşteri/tarih filtresi, sunucu sayfalaması, kalem ayrıntısı, çok kalemli form, iskonto/vergi alanları, durum geçişi, kopyalama/revizyon/iptal ve faturaya dönüştürme eklendi. Test API'de durum geçişi, revizyon ve iki kalemli toplam doğrulandı; ürün eşlemesi ve faturaya dönüştürme gerçek akışı sınanacak. |
| Belgeler | Kısmi | Tür, kişi ve ay filtresi, önizleme bağlantısı, yetkili indirme, onaylı silme, tarihli toplu PDF yükleme ve yükleme sonrası yenileme eklendi; gerçek Drive içeriği, dosya kaydı ve bildirim sınanacak. |
| Ürün/hizmet ve stok geçmişi | Kısmi | Kart düzenleme/silme, depo bakiyesi, hareket, alış/satış geçmişi, açılış stoğu ve KDV dâhil fiyat girişi eklendi; bütün filtreler ve gerçek API doğrulaması eksik. |
| Depo kartları | Kısmi | Adres/ilçe alanları, düzenleme ve onaylı pasifleştirme eklendi; stok transferi ve depo hareketleriyle gerçek API doğrulaması eksik. |
| Mükellef kayıtlı kart ve otomatik ödeme | Kısmi | Kart silme onayı, abonelik/hizmet için kart seçerek talimat açma/kapatma ve bağımsız kart kaydı eklendi. Kart kaydı küçük doğrulama tutarını açık onayla PayTR formuna yönlendiriyor. Kart kaydı ve normal ödeme dönüşü, yönlendirme URL'sini başarı saymadan sunucu durumunu gecikme/yeniden denemeyle doğruluyor. Callback ödeme/bildirim kaydını aynı transaction'da tutuyor, dış bildirim commit sonrasında gönderiliyor. Küçük ekran onayı, API sözleşmesi, callback gecikmesi ve DB havuzu test edildi; gerçek PayTR test sağlayıcısı, iade/kart tokenı ve cihaz akışı eksik. |
| Yönetici duyuru ve sistem güncellemesi | Kısmi | Oluşturma, düzenleme, silme, hedef kitle, yayın/durum ve açık onaylı SMS/e-posta gönderimi eklendi; gerçek servis ve tüm yönetici kayıt işlemleri doğrulanacak. |
| Yönetici ayar ve bakım | Kısmi | Abonelik ücreti, kayıt/e-posta anahtarları, bakım planı/iptali/başlatma/bitirme ve açık onay eklendi; gerçek ortam davranışı doğrulanacak. |
| Takvim, GİB ve hatırlatıcılar | Kısmi | Etkinlik oluştur/düzenle/sil, müşavir mükellef hedefi, ay ve gün ızgarası, GİB tarihleri, ödeme vadesi, şablon oluştur/kullan/sil ve SMS/e-posta kuralı oluştur/düzenle/aktiflik/sil eklendi. Webdeki gün ayrıntıları, yerel bildirimlerin cihazda zamanlaması ve rol bazlı gerçek API sınanacak. |
| Müşavir mesaj şablonları | Kısmi | E-posta/SMS/WhatsApp şablonu oluşturma, düzenleme, arama, içerik kopyalama ve onaylı silme eklendi; küçük ekran oluştur/düzenle/sil testi geçti. Gerçek API, belge yükleme ve hatırlatma şablonu seçimiyle bütünleşme doğrulanacak. |
| Yönetici platform transferleri | Kısmi | Liste ve sunucu durum filtresi var. Backend talimatı dış çağrıdan önce koşullu claim/commit ediyor, ağ beklerken havuz bağlantısını bırakıyor; belirsiz sonucu kilitli tutuyor. Kesin BOUNCED veya gönderilmemiş yerel IBAN hatası için eski takip no korunup yeni kayda yeni `trans_id` veriliyor; mobil yalnız bu durumlarda tekrar gösteriyor. Havuz/çift çağrı/callback yarışı test edildi. 035 migration test DB'de uygulandı ve indeks doğrulandı; canlı DB ön kontrolü, kod dağıtımı, gerçek PayTR callback ve mutabakat doğrulaması açık. |
| Bordro ve web yer tutucuları | Webde kullanıma kapalı / webde yer tutucu | Mobil eşlik hedefi dışında. |
