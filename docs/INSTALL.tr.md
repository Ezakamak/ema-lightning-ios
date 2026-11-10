# Türkçe kurulum

## Xcode ile geliştirme ve iPhone’a kurulum

1. macOS üzerinde Xcode 16 veya yenisini kurun ve ilk çalıştırma bileşenlerini tamamlayın.
2. `git clone https://github.com/Ezakamak/ema-lightning-ios.git` ardından `cd ema-lightning-ios` çalıştırın. Bir PR’ı deniyorsanız ilgili dalı ayrıca seçin.
3. `open EMALightning.xcodeproj` ile projeyi açın. `EMALightning` şemasını seçin.
4. Simülatörde iOS 17+ bir cihaz seçip Run çalıştırın. Gerçek cihaz için Signing & Capabilities altında kendi Team’inizi seçin ve gerekirse benzersiz Bundle Identifier kullanın. Kişisel imzalama değişikliklerini ortak depoya göndermeyin.
5. iPhone’da Geliştirici Modu’nu açın; Xcode’un istediği eşleştirme ve geliştirici güven adımlarını tamamlayın. Apple’ın ücretsiz hesap/provizyon kısıtlamaları geçerlidir.

Varsayılan motor **gerçek EMA Lightning ONNX** modelidir. Model, Türkçe normalizer ve CPU/WASM çalışma zamanı IPA’ya gömülüdür; ilk kullanımda internetten dosya indirilmez. İlk üretimde modeller yüklenir; sesin tamamı hazır olduğunda çalınır. Metin sınırı 1.000 karakterdir. Apple sistem sesi yalnızca motor seçicisindeki ayrı alternatiftir; EMA hatasında kendiliğinden devreye girmez.

Fiziksel iPhone’da uçak modu testi bu ortamda yapılamadı. Kurulumdan sonra uçak modunu açıp Wi-Fi/Bluetooth’u kapatın, uygulamayı tamamen kapatıp yeniden başlatın ve **EMA** seçiliyken ses üretin. Sonuçları cihaz/iOS sürümüyle Issue’a yazın. [Test kapsamı](TESTING.md).

Apple alternatifinde Türkçe ses bulunamazsa iOS erişilebilirlik konuşma/ses ayarlarından indirin; bu, EMA modeli için gerekli değildir.

## Unsigned IPA

Actions → iOS unsigned IPA → başarılı çalıştırma → `unsigned-ipa` artifact’ını indirin. Yayımlanmış sürümlerde Releases ekleri de kullanılabilir. Artifact ZIP’ini açın; IPA `build/` altındadır. Bütünlüğü doğrulayın:

```sh
cd build
shasum -a 256 -c SHA256SUMS
```

IPA imzasızdır: AirDrop veya Dosyalar üzerinden dokunarak yüklenemez. Kendi Apple hesabınız ve cihazınıza uygun provisioning ile güvenilir bir imzalama aracı kullanın veya yukarıdaki Xcode yöntemini tercih edin. Sertifikalarınızı ve parolalarınızı depoya/Issue’lara eklemeyin. Bu proje bir imzalama servisi sağlamaz.

Yerelde imzasız IPA: `scripts/build-unsigned-ipa.sh 0.1.0`. Test: `swift test --package-path Packages/SpeechCore`. Xcode ve iOS SDK gerektiğinden IPA derlemesi Linux üzerinde çalışmaz.
