// SPDX-License-Identifier: Apache-2.0
// Prose formatting and literal pronunciation hints only. Original input is never edited.
const WORD = String.raw`[\p{L}\p{N}_]`;
const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const turkishLetters = /[çğıöşüÇĞÖŞÜ]/u;

function literalPattern(word) {
  const turkish = turkishLetters.test(word);
  return [...word].map((char) => {
    if (/\s/u.test(char)) return '[ \\t]+';
    if (!turkish && /[iIİ]/u.test(char)) return '[iIİ]';
    const low = char.toLocaleLowerCase('tr'), high = char.toLocaleUpperCase('tr');
    return low === high ? escape(char) : `(?:${escape(low)}|${escape(high)})`;
  }).join('');
}

// Two character tries preserve Turkish i/ı and ASCII-brand dotted-İ semantics.
const compiled = new WeakMap();
const boundary = ch => ch !== undefined && /[\p{L}\p{N}_]/u.test(ch);
const fold = (ch, tr) => /[ \t]/u.test(ch) ? ' ' :
  (!tr && /[iIİ]/u.test(ch) ? 'i' : ch.toLocaleLowerCase('tr'));
export function compilePronunciations(rules) {
  if (!Array.isArray(rules) || rules.length > 100300) throw Error('Telaffuz sözlüğü sınırı aşıldı.');
  const roots = [new Map(), new Map()];
  rules.forEach((r, order) => {
    if (!r || typeof r.word !== 'string' || typeof r.pronunciation !== 'string' ||
        !r.word.trim() || r.word.length > 128 || !r.pronunciation.trim() || r.pronunciation.length > 256)
      throw Error('Geçersiz telaffuz kuralı.');
    const word = r.word.normalize('NFC'), tr = turkishLetters.test(word);
    let node = roots[Number(tr)];
    for (const ch of word) {
      const c = fold(ch, tr);
      if (!node.has(c)) node.set(c, new Map());
      node = node.get(c);
    }
    const old = node.get(null);
    if (!old) node.set(null, {reading:r.pronunciation, length:r.word.length, order});
  });
  return text => {
    const chars = [...text]; let output = '';
    for (let i=0; i<chars.length;) {
      let best;
      if (!boundary(chars[i-1])) for (let mode=0; mode<2; mode++) {
        let node=roots[mode];
        for (let j=i; j<chars.length; j++) {
          const c=fold(chars[j], Boolean(mode));
          node=node.get(c); if (!node) break;
          // A literal space in a rule accepts one or more horizontal spaces.
          if (c===' ') while (/[ \t]/u.test(chars[j+1] ?? '') && !node.has(' ')) j++;
          const hit=node.get(null);
          if(hit && !boundary(chars[j+1]) && (!best || hit.length>best.length ||
              (hit.length===best.length && hit.order<best.order))) best={...hit,end:j+1};
        }
      }
      if (!best) { output+=chars[i++]; continue; }
      let end=best.end, suffix='';
      if (/[’']/u.test(chars[end] ?? '')) {
        let j=end+1; while(j<chars.length && /\p{L}/u.test(chars[j])) j++;
        if(j>end+1 && j-end-1<=12 && !boundary(chars[j])) {suffix=chars.slice(end+1,j).join('');end=j;}
      }
      output+=best.reading+suffix; i=end;
    }
    return output;
  };
}
export function applyPronunciations(text, rules = []) {
  let matcher=compiled.get(rules);
  if(!matcher) { matcher=compilePronunciations(rules); compiled.set(rules,matcher); }
  return matcher(text);
}

export function prepareForSpeech(input, rules = []) {
  let text = input.normalize('NFC')
    .replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069\ue000-\uf8ff]/gu, ' ')
    .replace(/\u200b/gu, ' ').replace(/[\u2060\ufeff]/gu, '')
    .replace(/[’‘ʼ´`]/gu, ch => ch === '`' ? '`' : "'")
    .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&quot;/gi, '"').replace(/&apos;/gi, "'");

  // Markdown has no spoken syntax: retain captions, inline code and paragraph text.
  text = text.replace(/^[ \t]*(?:`{3,}|~{3,})[\w+-]*[ \t]*$/gm, '')
    .replace(/!?\[([^\]\n]+)\]\((?:https?:\/\/|www\.|mailto:)[^\s)]*(?:[ \t]+"[^"\n]*")?\)/giu, '$1')
    .replace(/`([^`\n]+)`/gu, '$1')
    .replace(/(?<![\p{L}\p{N}_])\*\*([^\n]+?)\*\*(?![\p{L}\p{N}_])/gu, '$1').replace(/(?<![\p{L}\p{N}_])__([^\n]+?)__(?![\p{L}\p{N}_])/gu, '$1').replace(/~~([^\n]+?)~~/gu, '$1')
    .replace(/(?<![\p{L}\p{N}_*])([*_])([^\n*_]+?)\1(?![\p{L}\p{N}_*])/gu, '$2')
    .replace(/^[ \t]{0,3}#{1,6}[ \t]+/gm, '').replace(/^[ \t]*>+[ \t]?/gm, '')
    .replace(/^[ \t]*(?:-{3,}|_{3,}|\*{3,}|={3,})[ \t]*$/gm, '')
    .replace(/^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(?:\|[ \t]*:?-{3,}:?[ \t]*)+\|?[ \t]*$/gm, '');

  // Shield electronic addresses and numeric expressions before punctuation/dictionary changes.
  const protectedText = [];
  const protect = (value) => { protectedText.push(value); return String.fromCharCode(0xe000 + protectedText.length - 1); };
  text = text.replace(/\b(?:https?:\/\/|www\.)[^\s<>"“”]+/giu, match => {
    let body = match, tail = '';
    while (/[.,;!?]$/u.test(body)) { tail = body.slice(-1) + tail; body = body.slice(0, -1); }
    for (const [open, close] of [['(', ')'], ['[', ']'], ['{', '}']]) {
      while (body.endsWith(close) && [...body].filter(c => c === close).length > [...body].filter(c => c === open).length) {
        tail = close + tail; body = body.slice(0, -1);
      }
    }
    return protect(body) + tail;
  });
  text = text.replace(/[\p{L}\p{N}._%+-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+/gu, protect)
    .replace(/\b(?:[\p{L}\p{N}](?:[\p{L}\p{N}-]{0,62})\.)+(?:com|net|org|edu|gov|io|ai|app|dev|co|tr|uk|de|fr|me)\b(?:\/[^\s<>"“”]*)?/giu, protect);

  text = text.replace(/(?<![\p{L}\p{N}])(?:\+\d{1,3}[ \t-]*)?\(?\d{3,4}\)?[ \t-]+\d{3}[ \t-]+\d{2}[ \t-]+\d{2}(?!\d)/gu, protect);

  // Numbered list punctuation is layout, not a bracket or an ordinal instruction.
  text = text.replace(/^[ \t]*(?:(\d{1,3})[.)]|\((\d{1,3})\))[ \t]+(?=\S)/gm, (_, a, b) => `${a ?? b}, `)
    .replace(/^[ \t]*[-*+•◦▪▸►●][ \t]+(?:\[[ xX✓✔]\][ \t]*)?/gm, '')
    .replace(/^[ \t]*[☐☑✓✔][ \t]+/gm, '')
    .replace(/^[ \t]*\[[ xX✓✔]\][ \t]+/gm, '')
    .replace(/^[ \t]*([a-zA-ZçğıöşüÇĞİÖŞÜ])\)[ \t]+/gm, '$1, ');

  text = text.replace(/\([^()\n]+\)/gu, match => /^\([\d\s.,+\-−*\/×÷%=^]+\)$/u.test(match) && /[+\-−*\/×÷=^]/u.test(match) ? protect(match) : match)
    .replace(/(?<![\p{L}\p{N}_])(?:\d+(?:[.,]\d+)?|[a-zA-Z])(?:[ \t]*[+*\/=^×÷−-][ \t]*(?:\d+(?:[.,]\d+)?|[a-zA-Z]))+(?![\p{L}\p{N}_])/gu, match => /\d/u.test(match) ? protect(match) : match);

  text = applyPronunciations(text, rules);
  text = text.replace(/["“„«]([^"\n”»]+)["”»]/gu, ' $1 ')
    .replace(/(^|[^\p{L}\p{N}])'([^'\n]+)'(?=$|[^\p{L}\p{N}])/gu, '$1$2')
    .replace(/(?<!\d)["“”„«»]/gu, ' ')
    .replace(/[\(\[\{]/gu, ', ').replace(/[\)\]\}]/gu, ', ')
    .replace(/(^|[^\p{L}\p{N}])[@#](?=[\p{L}_])/gu, '$1')
    .replace(/[ \t]*\|[ \t]*/gu, ', ').replace(/&/gu, ' ve ')
    .replace(/[•◦▪▸►●★☆]/gu, ', ').replace(/`/gu, ' ')
    .replace(/(?<=[\p{L}])\*(?![\p{L}\p{N}*])|(?<![\p{L}\p{N}*])\*(?=[\p{L}])/gu, '')
    .replace(/(?<!\d):|:(?!\d)|;/gu, ', ')
    .replace(/\p{Extended_Pictographic}(?:\uFE0F|\p{Emoji_Modifier}|\u200D\p{Extended_Pictographic})*/gu, ' ')
    .replace(/\p{Regional_Indicator}{2}/gu, ' ').replace(/[\uFE0F\u20E3\u200D]/gu, '')
    .replace(/…|\.{2,}/gu, '. ').replace(/[!?]{2,}/gu, value => value.includes('?') ? '?' : '!')
    .replace(/\s*\n+\s*/gu, ', ').replace(/(?:,\s*){2,}/gu, ', ')
    .replace(/([.!?])\s*,\s*/gu, '$1 ').replace(/,\s*([.!?])/gu, '$1')
    .replace(/[ \t]+([,.!?])/gu, '$1')
    .replace(/^[\s,]+|[\s,]+$/gu, '').replace(/[ \t]+/gu, ' ');
  text = text.replace(/[\ue000-\uf8ff]/gu, ch => protectedText[ch.charCodeAt(0) - 0xe000] ?? ' ');
  if (text.length > 8000) throw new Error('Telaffuz kuralları metni çok uzattı. Uzun okunuşları kısaltın.');
  return text;
}
