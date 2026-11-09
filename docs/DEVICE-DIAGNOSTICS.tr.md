> Güncel Studio arayüzünde ayrıntılar için Ayarlar → Geliştirici Modu'nu açın.
> Ek kayıt-sayısı barı kaldırılmıştır; gerçek WebKit görünümü Oluştur sekmesinin
> 32×24 simgesinde bağlı kalır. Bu takip değişikliği henüz cihazda doğrulanmadı.

# Gerçek cihaz tanılama — 0.2.0

Oku’ya dokunulduğunda asenkron motor başlamadan önce ekranda **✅ Oku butonuna basıldı** görünür. EMA Motor Durumu panelini açarak 20 aşamanın durumunu, gerçek olaylarla ölçülen sürelerini ve zaman damgalı logları izleyin. Panel kapalıyken de dokunma alındısı ve mevcut aşama görünür. Logları Kopyala veya Tanılama Raporunu Paylaş ile raporu aktarabilirsiniz.

Rapor donanım model kodunu (benzersiz cihaz kimliği değil), iOS sürümü/build, uygulama sürümü/build, seçilen motoru, son başarılı ve ilk başarısız aşamayı, JS stack trace ve WebContent sonlandırma olaylarını içerir. Metnin tamamı, metin sözcükleri, ses verisi, cihaz adı, UUID’ler, yerel URL belirteçleri ve anahtarlar rapordan ayıklanır. Raporu paylaşmadan önce inceleyebilirsiniz; paylaşım yalnızca sizin başlattığınız iOS paylaşım ekranıyla yapılır.

## Düzeltilen kod yolları

- Form içindeki aynı HStack’te iki `.automatic` düğme yerine açık, bağımsız düğme stilleri kullanılır. Eski davranış ayrı DEBUG UI testinde yeniden üretilir; bu fiziksel cihazın kesin kök nedeni olduğu varsayılmaz.
- 1×1 arka plan WebView kaldırıldı. Üretim ve test aynı `InferenceHostView` ile gerçek, görünür viewport kullanır. `window`, `superview` ve boyut doğrulanmadan sayfa yüklenmez; bağlantı yoksa aşama 5 hata verir.
- `didFinish` tek başına bridge hazır demek değildir. Sayfa gezinmesi ve gerçek JS bridge hazır mesajı ayrı beklenir.
- Worker constructor/ready, WASM/ORT oturumları, normalizer ve her model ayrı gerçek olay üretir. WASM ancak ilk CPU ORT oturumu başarıyla oluştuğunda başarılı sayılır; normalizer/model aşamalarıyla süreleri örtüşebilir.
- Swift’in JS sonucu, sayfa ve host beklemeleri kendi continuation’larıyla yönetilir. Durdur, genel 180 s sınırı veya aşama süresi aşımı bunları doğrudan hata/iptalle sonlandırır. Eski istekten gelen event ve callback yeni isteği değiştiremez.
- Oynatıcı hazırlama ve `play()` sonucu kontrol edilir; son iki aşama yalnızca gerçek oynatma bittiğinde başarılı olur. Salt `render` testinde oynatılmayan aşamalar bekliyor kalır.

## Fiziksel cihazda deneme

Yeni IPA’yı kendi hesabınızla imzalayın. Sürüm 0.2.0, build 100 + Actions çalışma numarasıdır. EMA seçiliyken kısa bir Türkçe metinle Oku’ya dokunun. Alındı görünmeli; hata halinde panelde ilk hatayı ve ayrıntısını kontrol edin. Durdur sonrasında yeniden deneyin. Uçak modunda Wi-Fi/Bluetooth kapalı soğuk açılışı ayrıca deneyin. Raporu ilgili PR’a eklerken hangi adımda beklediğinizi belirtin.

Bu ortamda fiziksel iPhone 15 Pro Max / iOS 27 yoktur. Bildirilen cihazdaki kesin kök neden ve düzeltmenin o cihazda çalıştığı, cihaz raporu olmadan doğrulanmış sayılmaz. Simülatör sonucu bu eksikliği kapatmaz.
