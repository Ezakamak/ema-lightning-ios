# Telaffuz v2: uygulama ve kalite raporu

Bu geliştirme PR #14'ün iki commit'ini aynen içerir. main üzerine uygulanır;
EMA Studio, ONNX dosyaları, WAV/MP3/MP4 dışa aktarma ve App Store gönderimi değiştirilmez.
Diğer uzak dallardaki teslimat/mağaza ekran görüntüsü işleri bu değişiklikle birleştirilmez.

## Veri ve fonetik değerlendirme

Başlangıç/etkin son sözlük: **158 / 158**. Bu kayıtlar değiştirilmedi.
40.000 aday ayrı, deterministik gzip JSONL olarak bulunur. Bunlar aktif sözlük değildir.
37.559 tek varyantlı otomatik öneri; 2.431 çok varyantlı; 10 bilinen Türkçe/işlev sözcüğü
çakışması nedeniyle reddedilmiş; 39.990 inceleme bekleyen; yeni doğrulanan **0**.
Sayılar `data/pronunciation/candidates.report.json` içinde de bulunur.

CMU kaynağı `74790861f652b15e4ac49015a90074ad62a27690` revizyonuna sabitlenmiştir.
SHA256: `81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22`.
Kaynak dili, ARPABET, tüm alternatifler, vurgu işaretleri, öneri, kategori, revizyon,
checksum, lisans, sezgisel güven ve inceleme durumu ayrı alanlardadır.
Güven puanı kalibre edilmiş olasılık veya işitsel başarı ölçümü değildir.

PR #14'teki dönüştürücü güvenilir bir G2P modeli değildir. /θ, ð, æ, ə, ɝ, w/
Türkçeye birebir taşınamaz; /ə/ için `ı`, /æ/ için `e` her bağlamda doğru değildir.
Bu nedenle ARPABET eşlemesi yalnızca inceleme önerisi olarak tutulur. Alternatifleri
silmek yerine artık saklar; İngilizce kaydın varlığını Türkçe kullanım kanıtı saymaz.
Vurgu EMA yazımına güvenilir biçimde aktarılamaz. Heceleme modeli, Fransızca/Almanca
G2P ve bağlam sınıflandırıcısı bu aşamada uygulanmadı; bunlara ilişkin başarı iddiası yoktur.
Alt dizeye dayalı teknoloji kategorisi yalnızca aday etiketi, yayın gerekçesi değildir.
Türkçe çakışma listesi kapsamlı değildir: listeye girmeyen bütün adaylar da inceleme bekler.

### Kaynak/lisans kararları (13 Kasım 2026)

| Kaynak | Koşullar ve kalite | Karar |
|---|---|---|
| [CMUdict](https://github.com/cmusphinx/cmudict) | Amerikan İngilizcesi ARPABET; sözcük türüne/bağlama göre varyant seçmez. BSD benzeri lisans, kaynakta bildirim ve ikili dağıtımda dokümantasyon bildirimi korunmalı. | Yalnızca aday havuzu. Tam lisans `data/pronunciation/CMUDICT-LICENSE`. |
| [Wiktionary Copyrights](https://en.wiktionary.org/wiki/Wiktionary:Copyrights) | CC BY-SA 4.0/GFDL; madde katkıcı atfı ve türev veri için ilgili paylaşım koşulları; seslerin ayrıca farklı lisansı olabilir. | Apache kod lisansının veri lisansı olduğunu varsaymadan ayrı veri paketi tasarlanmalı. Bu PR'a alınmadı. |
| [WikiPron](https://github.com/CUNY-CL/wikipron) | Çıkarım aracı Apache-2.0; Wiktionary verisinin lisansı bundan ayrıdır. Dil/lehçe ve dar/geniş IPA ayrımı gerekir. | Fransızca/Almanca/Türkçe için sonraki kaynak; veri içe alınmadı. |
| [Kaikki Türkçe](https://kaikki.org/trwiktionary/rawdata.html) | Wiktionary türevi; atıf ve veri lisansı korunmalı; her maddede IPA bulunmaz. | Çakışma ve yerleşik okunuş araştırması için aday kaynak; alınmadı. |
| Ticari sözlükler, marka sitelerindeki sesler | Toplu yeniden dağıtım izni doğrulanmadı. | İçe alınmaz. |

Markalar, uluslararası kısaltmalar, yer adları ve yerleşik alıntılar için Türkçe bağlamda
elle doğrulanmış bir kullanım listesi gereklidir. Kısaltmayı harf harf mi kelime olarak mı
okuyacağımızı CMU varlığı belirlemez. Mevcut 158 kural bu kategoriler için güvenli tabandır.
Yeni kurallar için kaynak, reviewer, Türkçe cümle örneği ve gerçek EMA dinleme sonucu kaydedilmeli.
Ses üretimi, doğru telaffuz kanıtı değildir. Bu PR'ın adayları için **işitsel doğrulama yapılmadı**.

## API/D1 yayın sözleşmesi

`0002_shards.sql` yalnızca yeni tablolar/trigger'lar ekler. v1 tabloları, snapshot'ları,
5.000 sınırı ve v1 uçları korunur. v2 uçları:

- `GET /api/v2/pronunciations/manifest`
- `GET /api/v2/pronunciations/chunks/<sha256>`

Manifest sürüm, locale, toplam kural sayısı, v1 ile aynı kanonik kural checksum'ı ve
parça başına ham UTF-8 SHA256, byte/kural sayısı taşır. Parçalar değişmez.
ETag koşullu manifest kontrolü ve hash adresli parçalar gereksiz indirmeyi önler.
Manifest 256 KiB, parça 256 KiB istemci tavanına sahiptir; üretici SQL statement
sınırları için parçaları 48.000 byte altında, toplamı 32 MB altında tutar.
En çok 100.000 kural ve 1.024 parça kabul edilir. Aşırı uzun kayıtlar/bütçe aşımı reddedilir.
D1 limit referansı: https://developers.cloudflare.com/d1/platform/limits/

`release-v2.js` yalnızca `status=verified`, `confidence>=0.95`, `reviewedBy` ve `provenance`
olan girdileri alır; normalize tekrarları reddeder. Bu alanlar bir insanın gerçekten
incelediğini kriptografik olarak ispatlamaz; yayıncı inceleme kanıtını kontrol etmelidir.
Üretici staging kanalını günceller; stable kanalına otomatik yayın yapmaz.

1. Hedef **yalnızca EMA** veritabanından dışa aktarılmış snapshot'ı güvenli yerde saklayın.
2. Önce izole test D1'de migration ve yayın SQL'ini çalıştırın. CI aynı Worker'ı Miniflare/D1 ile çalıştırır.
3. Gözden geçirilmiş JSON dizisi için `node scripts/release-v2.js reviewed.json 1 staging.sql`.
4. SQL'i sırayla içe alın. Parçalar sırasında kesilirse stable manifest değişmez. Release
   eklenirken tüm parçaların varlığı/boyutu/kural sayısı trigger ile denetlenir.
5. Türkçe bağlam, çakışma, lisans ve dinleme değerlendirmesinden sonra `promoteSQL(version)`
   çıktısını çalıştırın. Tek kanal-pointer statement'ı atomiktir. Önce staging, sonra stable.
6. Geri alma için eski onaylı içeriği **daha yüksek yeni sürüm** olarak yayınlayın. Eski
   pointer'a dönmek daha yüksek sürümü almış istemcilerde downgrade korumasına takılır.

Gerçek Cloudflare migration, Worker deploy veya canlı D1 import yapılmadı. Route ve
ayrı v2 rate limiter konfigürasyonu hazır; staging doğrulaması sonrası dağıtılmalı.
Başka Cloudflare projesine, R2/DNS/Casino kaynağına dokunulmadı.

## iOS ve eşleştirme

Mevcut arka plan açılış kontrolü kullanılır. v2 yoksa v1'e geri döner; v2 önbelleği
varken başarısız kontrol v1'e downgrade yapmaz. İndirme akışı kesin byte sınırına sahiptir.
Manifest/parça/snapshot doğrulaması bitmeden active dosya atomik rename ile değiştirilmez.
Önceki snapshot korunur; bozuk active dosyasında önceki doğrulanmış snapshot yüklenir.
Kesilmiş indirmeler aktif sözlüğü bozmaz; doğrulanmış parça dosyaları sonraki denemede kullanılır.
Başarısız ağ kontrolü günlük/backoff mekanizmasını korur. Diskte abandoned parçalar başarılı
aktivasyondan sonra temizlenir. Uzun süre hiç tamamlanmayan güncellemelerde disk kotası
ayrıca geliştirilmelidir. Büyük snapshot diskten okuma/hash işleri async yardımcıda yapılır.

Swift prefix indeksi yalnızca metinde bulunabilecek kuralları WebKit'e yollar. Kişisel
kayıt değişimi ve merkezi sürüm değişimi indeksi geçersizleştirir. JS iki trie kullanır;
Türkçe i/ı, ASCII markalarda İ, yatay boşluklu ifadeler, en uzun eşleşme, kesme eki ve
tek geçişli replacement korunur. Kişisel kapatma tombstone'ları mevcut Store mantığıyla
merkezi güncellemelerden önceliklidir. Ses isteği ilk await öncesinde kural snapshot'ını alır.

Sıcak eşleştirme tüm sözlüğü taramaz. İndeks ilk kullanımda kurulur; ilk büyük indeksin
MainActor üzerinde kurulması, Swift dizileri ve trie RAM'i gerçek cihazda ölçülmelidir.
Dar alfabe dışındaki Unicode harflerin çok karakterli büyük harf dönüşümleri için eski
regex ile tam eşdeğerlik henüz kanıtlanmadı. Paketli 158 kayıt regresyon kapsamındadır.

## Doğrulama

Mevcut pronunciation workflow genişletildi; ayrı derleme workflow'u çoğaltılmadı.
Worker/D1 atomik staging/rollback, 100k yayın bütçesi, tüm seed'ler, büyük trie,
veri tekrar üretimi, Swift Store ve v2 kesinti/bozuk parça/önceki cache testleri bulunur.
Mevcut gerçek EMA ONNX testi çalışırken güncelleme ve sonraki offline isteği denetler.
Son Actions sonuçları ve ölçümler PR açıklamasına/son rapora eklenecek.
