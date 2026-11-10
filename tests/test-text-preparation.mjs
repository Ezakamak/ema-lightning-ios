// SPDX-License-Identifier: Apache-2.0
// Optional manual regression examples. Not executed automatically; no model or downloads.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const root = new URL('../App/Resources/EMA/', import.meta.url);
const source = await readFile(new URL('text-preparation.js', root), 'utf8');
const { prepareForSpeech, applyPronunciations } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const defaults = JSON.parse(await readFile(new URL('pronunciations.json', root), 'utf8'));
for (const [input, output] of [
  ['1) Şunu yap', '1, Şunu yap'],
  ['(2) Bunu dene', '2, Bunu dene'],
  ['- [x] **Tamam**', 'Tamam'],
  ['[x] Yapıldı', 'Yapıldı'],
  ['## Başlık', 'Başlık'],
  ['Metin (açıklama) [ek] {not}.', 'Metin, açıklama, ek, not.'],
  ['Merhaba 🎉 dünya 🇹🇷', 'Merhaba dünya'],
  ['2**3**4', '2**3**4'],
  ['x + 2 = 3', 'x + 2 = 3'],
  ['2 * (3 + 4)', '2 * (3 + 4)'],
  ['Saat 14:30, fiyat 125,50 TL; tarih 12/06/2026.', 'Saat 14:30, fiyat 125,50 TL, tarih 12/06/2026.'],
  ['[Bağlantı](https://example.com)', 'Bağlantı'],
]) assert.equal(prepareForSpeech(input), output, input);
assert.equal(prepareForSpeech('bugün İphone ve Apple aldım', defaults), 'bugün ayfon ve epıl aldım');
assert.equal(prepareForSpeech("iPhone'um iPhone’u", defaults), 'ayfonum ayfonu');
assert.equal(prepareForSpeech('Google Drive ve Google', defaults), 'gugıl drayv ve gugıl');
assert.equal(prepareForSpeech('Wi-Fi, USB-C, C++, C# ve Node.js', defaults), 'vay fay, yu es bi si, si plas plas, si şarp ve nod cey es');
assert.equal(prepareForSpeech('Apple apple.com https://apple.com/a?x=1&y=2 hello@apple.com', defaults),
  'epıl apple.com https://apple.com/a?x=1&y=2 hello@apple.com');
assert.equal(applyPronunciations('foo', [{word:'foo',pronunciation:'bar'},{word:'bar',pronunciation:'baz'}]), 'bar');
assert.equal(applyPronunciations('pineapple Apple AppleStore', [{word:'Apple',pronunciation:'epıl'}]), 'pineapple epıl AppleStore');
assert.equal(applyPronunciations('ışık IŞIK işik', [{word:'Işık',pronunciation:'aydınlık'}]), 'aydınlık aydınlık işik');
console.log('Text preparation examples passed.');
