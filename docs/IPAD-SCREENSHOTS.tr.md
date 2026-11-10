# Otomatik Türkçe iPad App Store ekran görüntüleri

GitHub → Actions → **iPad App Store screenshots** → **Run workflow**.
`upload=false` varsayılanıyla hiçbir Apple secret gerekmez. İşlem bitince
**ipad-app-store-tr** artifact ZIP’ini indir. Dört ekran içerir:
Oluştur (uygulamanın kendi örnek metni), Geçmiş (yeni kurulumdaki boş durum),
Ayarlar ve Telaffuz sözlüğü (hazır kurallar). Sahte kayıt/ses oluşturulmaz.

Workflow macOS 15 / Xcode 16.4 üzerinde yeni bir **iPad Pro 12.9-inch (6th generation)**
simülatörü oluşturur; yüklü iOS 18.4+ çalışma zamanını seçer. UI testlerinin
`IPadAppStoreScreenshotTests` sınıfını çalıştırır. Diğer UI/inference testleri
çalıştırılmaz. UI dili `tr`, bölge `tr_TR`, yön portre, görünüm açıktır.
Durum çubuğu sabitlenir. Uygulamanın gerçek ekranları XCTest ile yakalanır;
yeniden boyutlandırma, pazarlama çerçevesi veya ekran taklidi kullanılmaz.
PNG’lerin gereksiz alfa kanalı macOS CoreGraphics ile kaldırılır.

Çıktı: **2048 × 2732 piksel, opak RGB PNG**. Bu ölçü Apple’ın 12.9/13 inç iPad
screenshot gereksinimlerinde kabul edilir. API görüntü sınıfı
`APP_IPAD_PRO_3GEN_129` olarak sabittir.
[Apple boyut tablosu](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/).
Boyut/format ya da dört beklenen ekranın doğrulaması başarısızsa yükleme yapılmaz.
Ekran kayıtları `ipad-screenshot-diagnostics` artifact’inde `.xcresult` ve
xcodebuild günlüğü olarak ayrıca saklanır. PNG’ler 30, tanılama 7 gün tutulur.

## İsteğe bağlı yalnızca ekran görüntüsü yükleme

`upload=true` seç ve `app_version` alanına App Store Connect’te **zaten bulunan**
iOS sürümünü gir (ör. `0.3.0`). Bu sürümün Türkçe (`tr`) yerelleştirmesi mevcut
olmalıdır. Sürüm düzenlenebilir durumda olmalıdır: Prepare for Submission,
Developer Rejected, Rejected veya Metadata Rejected. Canlı/yayında ya da
incelemedeki sürüm değiştirilemez; Apple’da önce düzenlenebilir sürüm hazırla.
Workflow yeni sürüm/yerelleştirme oluşturmaz, binary ilişkilendirmez ve incelemeye göndermez.

Yükleyici yalnızca bu sürümün **tr / APP_IPAD_PRO_3GEN_129** setindeki görselleri
yeniler. Diğer iPad boyutları, diğer diller, iPhone ekran görüntüleri, uygulama
açıklamaları, anahtar kelimeler, önizleme videoları ve diğer metadata korunur.
Yeni iPad seti yoksa yalnızca o set oluşturulur. Yeni dört görsel işlenip COMPLETE
olmadan eski görseller silinmez. Hazırlık sırasında hata olursa yeni geçici görseller
silinmeye çalışılır; mevcut görseller korunur. Apple işlemleri atomik değildir:
eski görselleri silme/sıralama aşamasındaki bir API hatasında artifact’ten yeniden
çalıştırılabilir; App Store Connect’te ilgili seti kontrol et.

Apple bir sette en fazla 10 görsele izin verir. Güvenli geçici yükleme için mevcut
tr iPad setinde en fazla **6** görsel olmalı; daha fazlaysa workflow hiçbir mevcut
görseli silmeden durur. Bu durumda yalnızca ilgili iPad setinde yer açıp tekrar
çalıştır. Başarılı çalışmanın ardından sette dört yeni görsel kalır.

**IPA, archive, signing certificate, provisioning profile, TestFlight upload veya
yeni build gerekmez.** Sadece simülatör uygulaması ve UI test runner’ı derlenir.
Bu workflow mevcut IPA/TestFlight workflow’larından bağımsızdır. Yeniden çalıştırma
yeni ekran görüntülerini yakalar; indirilmiş PNG’leri aynı Python yükleyicisiyle,
repo kökünde `build/ipad-screenshots/tr/` altına koyarak da build yapmadan yükleyebilirsin:

```sh
python3 -m pip install -r scripts/screenshot-upload-requirements.txt
# Aşağıdaki değerleri güvenli ortam değişkenleri üzerinden sağla.
python3 scripts/upload-ipad-screenshots.py
```

## GitHub Secrets

Repository → Settings → Secrets and variables → Actions → New repository secret.
Yalnızca `upload=true` için gerekir; anahtarları chate, repoya veya artifact’e yazma.

| Secret | Değer |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect ekip API anahtarının Key ID’si |
| `ASC_ISSUER_ID` | Aynı ekip anahtarının Issuer ID’si |
| `ASC_PRIVATE_KEY` | `.p8` dosyasının tam metni; BEGIN/END satırları ve gerçek satır sonları dahil (base64 değil) |
| `ASC_APP_ID` | EMA Lightning’in App Store Connect sayısındaki sayısal Apple ID’si; bundle ID değil |

App Store Connect → Users and Access → Integrations → App Store Connect API
bölümünden **App Manager** rolü olan ekip anahtarı oluştur.
Anahtarın doğru Apple ekibine/uygulamaya erişmesi gerekir. Mevcut TestFlight
secret’ları aynı ekip anahtarına aitse yeniden kullanılabilir. `APPLE_TEAM_ID`,
Apple hesabı parolası ve sertifika secret’ları bu akışta kullanılmaz.
`ASC_APP_VERSION` secret değildir: workflow `app_version` girdisinden aktarır;
yerel yüklemede ortam değişkeni olarak verilir. API anahtarı yalnızca upload
job’unda bulunur; `.p8` dosyası diske yazılmaz.

## Bakım ve doğrulama

Xcode/runtime runner imajından kaldırılırsa `DEVELOPER_DIR` ve gerekirse cihaz
türünü güncelle. Desteklenmeyen ekran ölçüleriyle sessiz devam edilmez. Yeni ekran
eklerken UI testindeki attachment adlarını ve Python `EXPECTED` listesini birlikte
güncelle. App Store metadata klasörleri bu otomasyona girdi değildir.

Uploader’ın kapsam/geri alma testleri `tests/test_ipad_screenshot_upload.py`
dosyasında bulunur ve capture öncesi Actions job’unda çalışır. İlk macOS çalışması
henüz yapılmadı; gerçek simulator başarısı ve Apple API yüklemesi ancak ilgili
Actions çalışmasıyla doğrulanabilir.

## Yakalanmış test görsellerini kurtarma

UI testi tamamlanmış ama son PNG işlemi veya artifact adımı kesilmişse,
`recovery_run_id` alanına önceki Actions çalışma numarasını gir. Bu yol önceki
`ipad-screenshot-diagnostics` artifact’indeki `.xcresult` içinden dört isimli
ekranı çıkarır ve aynı boyut/format kontrollerini uygulayarak normal PNG artifact’ini
oluşturur. Yeniden derleme/simülatör açılışı yapılmaz. Bu alan boşken uygulama
her zaman yeniden açılır ve yeni ekran görüntüleri yakalanır.
