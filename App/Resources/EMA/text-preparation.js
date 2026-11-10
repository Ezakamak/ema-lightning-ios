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

export function applyPronunciations(text, rules = []) {
  if (!Array.isArray(rules) || rules.length > 512) throw new Error('Telaffuz sözlüğü sınırı aşıldı.');
  const entries = rules.map((rule) => {
    if (!rule || typeof rule.word !== 'string' || typeof rule.pronunciation !== 'string' ||
        !rule.word.trim() || rule.word.length > 128 || !rule.pronunciation.trim() || rule.pronunciation.length > 256)
      throw new Error('Geçersiz telaffuz kuralı.');
    return { ...rule, pattern: literalPattern(rule.word.normalize('NFC')) };
  }).sort((a, b) => b.word.length - a.word.length);
  if (!entries.length) return text;
  // A single replace pass: replacements never trigger another rule.
  const pattern = new RegExp(`(?<!${WORD})(${entries.map(e => e.pattern).join('|')})(?!${WORD})(?:['’]([\\p{L}]{1,12})(?!${WORD}))?`, 'gu');
  const exact = entries.map(e => new RegExp(`^(?:${e.pattern})$`, 'u'));
  return text.replace(pattern, (_, word, suffix = '') => {
    const index = exact.findIndex(re => re.test(word));
    return entries[index].pronunciation + suffix;
  });
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
