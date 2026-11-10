# EMA Studio: oluşturma, geçmiş ve paylaşım

Oluştur ekranına en fazla 1.000 karakter yazıp **Oku**'ya dokunun. Gerçek EMA
sesi cihazda oluşturulur; metin ve WAV kaydı otomatik olarak yerel geçmişe
kaydedilir. Önizleme oynatması durdurulsa bile tamamlanmış ses geçmişte kalır.
Apple sesi Ayarlar'dan açıkça seçilebilen bir önizlemedir; EMA arşivine girmez.

Geçmiş'te arama yapın, bir kaydı açın, dinleyin, konum değiştirin, yeniden
adlandırın veya silin. Ayarlar'dan tüm kayıtları silebilirsiniz. Metin ve ses
geçmişi kişisel içeriktir; uygulama bunları geliştiriciye göndermez. iOS cihaz
yedeklemeleri sistem ayarlarınıza tabidir. Uygulamayı kaldırmak yerel arşivi siler.

- **MP3:** gerçek 128 kbps mono MP3. Kodlayıcı cihazda çalışır; internet gerekmez.
- **MP4:** H.264/AAC, 720×1280 (9:16), 12 fps; logo ve ses süresince ilerleyen
  metin kartları. EMA kelime zaman damgaları üretmediğinden cümle/kısa ifade
  süreleri karakter uzunluğuna göre yaklaşık hesaplanır. Kesin kelime hizalama
  veya ses tanıma yapıldığı iddia edilmez. Video içinde metin kalıcı olarak yer alır.

MP3/MP4'e dokununca hazırlık başlar ve iOS paylaşım ekranı açılır. WhatsApp,
Instagram veya Dosyalar gibi hedefleri iOS ve yüklü uygulamalar belirler;
hedef platformun boyut/süre sınırlamaları ve dosyayı yeniden kodlaması mümkündür.
Belli bir uygulamaya otomatik gönderim yapılmaz. Export iptal edilebilir.
Arka plana geçiş sürmekte olan export'u iptal eder; yarım dosya paylaşılmaz.
Geçici paylaşım dosyaları sonraki açılışlarda 24 saat sonra temizlenir.

**Geliştirici Modu** varsayılan olarak kapalıdır. Ayarlar'dan açıldığında
Oluştur ekranında 20 aşama, süreler ve ayrıntılı loglar görünür. Tanılama raporu
metin/ses içermemeye devam eder; geçmiş ve MP4 içeriği bundan farklı olarak
kullanıcının özellikle sakladığı/paylaştığı içeriktir.

Yeni kod Apache-2.0; ayrı JavaScript MP3 bileşeni LGPL-3.0'dır. Tam kaynak
arşivi ve değiştirme talimatları IPA içinde MP3/ altında, lisans ekranından
kaynak arşivi paylaşılabilir. Ayrıntılar: DEPENDENCIES.md.
