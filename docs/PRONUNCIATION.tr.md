# Telaffuz sözlüğü ve metin hazırlama

**Ayarlar → Telaffuz sözlüğü** ekranında 158 hazır okunuş önerisi ve kişisel
kurallar bulunur. Liste Apple/telefonlar, marka ve uygulamalar, yapay zekâ ve
geliştirme, kısaltmalar/bağlantı ve günlük yabancı kelimelerden oluşur.

Örnekler: Apple → epıl, iPhone → ayfon, WhatsApp → vatsap, Google → gugıl,
ChatGPT → çet ci pi ti. Bunlar İngilizce fonetik yazının Türkçe harflerle
özgün yaklaşık karşılıklarıdır; yetkili bir telaffuz sözlüğünden kopyalanmış
veya EMA ile tek tek dinlenerek doğrulanmış bir veri kümesi değildir. Kullanıcı
duyduğu sonuca göre öneriyi düzeltebilir. Kaynak: EMA/pronunciations.json;
yeni sözlük ve hazırlama kodu Apache-2.0'dır, ek model veya ağ servisi yoktur.

## Kişisel kullanım

1. **+** ile metindeki kelimeyi/ifadeyi ve okunuşunu girin: `İphone` / `Ayfon`.
2. Hazır listedeki bir satıra dokunup değiştirince kişisel bir düzeltme oluşur.
3. Kuralı kapatırsanız aynı hazır kural da uygulanmaz. Kişisel kuralı silmek
   varsa hazır okunuşu geri getirir. Hazır listeyi topluca kapatabilirsiniz;
   kendi etkin kurallarınız çalışmaya devam eder.
4. Kişisel satıra dokunarak düzenleyin, kaydırarak silin. Arama iki alanı da arar.

Kurallar sonraki EMA isteğinin başında kopyalanır; süren okumayı, eski WAV/MP3
kayıtlarını veya özgün ekran/geçmiş/MP4 metnini değiştirmez. Apple önizlemesine
uygulanmaz. Kişisel sözlük uygulamanın UserDefaults alanında tutulur; iOS cihaz
yedeklemeleri sistem ayarlarına tabidir. Sözlük listesi tanılama raporuna eklenmez.

Tam kelime/ifade eşleşir; `AppleStore` içindeki `Apple` değiştirilmez. En uzun
ifade önceliklidir (`Google Drive` önce). Aynı ifadedeki kişisel kural hazır
kuralı geçersiz kılar. Yeni okunuş başka kurallardan tekrar geçirilmez. ASCII
markalar `iPhone`, `IPHONE`, `İphone` yazımlarını karşılar; Türkçe kelimelerde
`i` ve `ı` ayrımı korunur. `iPhone'um` gibi kesmeyle ayrılmış ekler sürdürülür.

En fazla 300 kişisel kural, kaynakta 64 ve okunuşta 128 karakter desteklenir.
Okunuş rakam/HTML/regex yerine Türkçe harflerle yazılır. Uzun açılımlar 8.000
karakter sınırına tabidir; mevcut ses süresi ve işlem sınırları da korunur.

## Noktalama ve biçimlendirme

Metin, WASM normalizer'a gönderilmeden önce yalnızca sentez kopyasında hazırlanır:

- Satır başındaki `1)`, `(1)`, `1.` gibi liste numaraları sayı ve kısa duraklamaya
  dönüşür. Madde imleri, onay kutuları ve Markdown başlık/alın­tı/vurgu işaretleri
  biçimlendirme olarak temizlenir; içerdikleri sözcükler korunur.
- Normal parantez/köşeli/süslü parantezler kısa ayraç olur; içindeki açıklama
  kalır. Eşleşen tırnaklar, ters tırnaklar ve dekoratif işaretler okunmaz.
- Markdown bağlantılarında etiket okunur. Ham URL, e-posta ve yaygın alan adları
  sözlükten korunur; `apple.com` içindeki Apple marka kuralına dönüşmez.
- Saat, ondalık, tarih, gruplanmış telefon ve basit sayısal işlemler korunur.
  Anlamlı eksi, artı, yüzde, para birimi ve eğik çizgi topluca silinmez.
- Emoji süslemeleri temizlenir; yinelenen noktalama sadeleştirilir. `&`, adreslerin
  dışında `ve` olur. `14:30` korunurken normal cümledeki iki nokta duraklama olur.

Bu bir düz yazı okuma hazırlayıcısıdır; tam bir Markdown/HTML, programlama dili
veya matematik yorumlayıcısı değildir. Karmaşık matematik ve kelime zamanlama
hizalaması kapsam dışıdır. `text-preparation.js` değişiklikleri WASM modelini veya
orijinal normalizer ikilisini değiştirmez.

## Doğrulama durumu

Bu takip değişikliği için kullanıcı isteğiyle test, derleme ve yeni paketleme
başlatılmadı. İsteğe bağlı regresyon örnekleri `tests/test-text-preparation.mjs`
ve SpeechCore telaffuz testleri altında tutulur; çalıştırıldıkları iddia edilmez.
