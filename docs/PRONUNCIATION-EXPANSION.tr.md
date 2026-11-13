# EMA Lightning: büyük telaffuz sözlüğü genişletmesi (araştırma ve güvenli yayın tasarımı)

Durum: **Araştırma / TASLAK. Üretimde etkin değil.**

## Bulgular

- Mevcut uygulamada 158 paketlenmiş telaffuz kuralı ve Cloudflare D1 üzerinde merkezî sözlük senkronizasyonu bulunuyor.
- Mevcut API sözleşmesi **schema v1**, **5.000 kural** ve **1.048.576 bayt** üst sınırıyla çalışır.
- iOS: App/Features/Settings/PronunciationSyncService.swift (CentralDictionary.validate, 1 MiB, central-v1.json).
- Worker: cloudflare/pronunciation-api/src/dictionary.js (validate), scripts/import.js (tek JSON snapshot), src/index.js (tek yanıt).
- On binlerce satırın v1 sözlüğüne doğrudan eklenmesi, eski istemcilerin yanıtı reddetmesine neden olur.

## Kaynak araştırması

- Carnegie Mellon University, **CMU Pronouncing Dictionary**: https://github.com/cmusphinx/cmudict
  - İngilizce ARPABET telaffuzları; ticari kullanım serbest; kaynak belirtimi isteniyor.
  - İngilizce fonemlerin Türkçe harflere dönüştürülmesi sadece **yaklaşık aday** üretir; duyularak doğrulanmış Türkçe okunuş üretmez.
- Wiktionary / Wiktextract: https://kaikki.org/dictionary/ ; **CC BY-SA ve GFDL** yükümlülükleri ayrı değerlendirilmeden kaynak veri birleştirilmesin.
- CMUdict Python paketinin lisansı, yeniden dağıtılan CMU veri dosyasının koşullarından ayrı ele alınmalıdır.

## Veri üretimi — güvenli taslak

scripts/generate-pronunciation-candidates.py, yerel CMUdict kurulumu kullanarak yaklaşık okunuş adaylarını JSONL inceleme listesine yazar.

Bütün adaylar **UNVERIFIED_DO_NOT_IMPORT** durumundadır. Betik bir D1 import dosyası üretmez, Worker'ı yayımlamaz, iOS uygulamasını değiştirmez.

Türkçe eşsesli/aynı yazılışlı terimleri korumak için kısa ve günlük sözcükler dışarıda tutulur. Bu filtre tek başına yeterli değildir; özellikle "normal", "model", "program", "format", "market", "alarm" gibi yerleşik Türkçe sözcüklere İngilizce telaffuz **zorlanmamalıdır**.

## Genişletme yol haritası

1. **Önceliklendir:** Türkçede yabancı okunan marka, yazılım, ürün, kısaltma, teknik ifade ve gerçekten kullanılan alıntı kelimeleri belirle. İngilizce sözlükteki her kelimeyi otomatik ekleme.
2. **Doğrula:** fonetik kaynak + mümkünse telaffuz ses kaydı + gerçek EMA ONNX çıktısı. Varyantlı/homograf kelimelerde tek bağlamsız kural oluşturma. Kural başına kaynak ve inceleme durumu sakla.
3. **Çakışmaları ölç:** Mevcut 158 kuralı ve sık kullanılan Türkçe cümleler üzerinde regresyon; kişisel override/tombstone önceliği korunmalı.
4. **v2 tasarla:** Yalnızca onaylanmış kayıtlarla D1'dde sürümlenmiş yayın; manifest + ETag/304 + parça bazlı SHA-256; küçük (örn. 250–500 KiB) snapshot parçaları; tek parçada 1000 kuraldan az.
5. **Güvenli istemci:** v2 manifesti indirip tüm değişen parçaları doğruladıktan sonra atomik etkinleştir. Bozuk/eksik indirmede eski sözlüğü koru; çevrimdışı ONNX sentezini bekletme.
6. **Performans:** 40 bin kuralı her sentezde baştan taramak yerine indeksle; bellek, CPU, başlatma ve pil etkisini fiziksel iPhone'da ölç.
7. **Geriye uyumluluk:** /api/v1 ve central-v1.json davranışı aynı kalsın; v2 dağıtılmadan 5000+ kuralı v1 istemcilerine gönderme. Staging D1 ve Worker ile testsiz üretim yayını yapma.
8. **Kademeli yayın:** onaylı 50–200 → 1000 → 5000 → 10.000+; checksum, offline, bozuk parça, eski sürüme dönmeme ve kişisel kural regresyon testleri; geri alma planı.

## Kapsam dışı

- Bu PR, **40.000 okunuşun doğrulandığını iddia etmez**.
- Üretim D1 verisi ve mevcut 158 kural **değişmez**.
- Test, cihaz içi ses doğrulaması veya imzalı IPA derlemesi bu araştırma değişikliği kapsamında **çalıştırılmaz**.
- GitHub Actions kotası/cihaz test maliyeti için mevcut repo talimatları geçerlidir.
