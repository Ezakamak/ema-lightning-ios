#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate UNVERIFIED English-to-Turkish pronunciation candidates for human review.

Never feed this output directly to a live D1 dictionary, IPA, or v1 importer.
Dependencies (research-only): python -m pip install cmudict spacy
Source: CMU Pronouncing Dictionary, Carnegie Mellon University.
https://github.com/cmusphinx/cmudict (CMU data can be used commercially; credit requested)
"""
import argparse
import difflib
import json
import re
import unicodedata
from pathlib import Path

MAP = {
    "AA":"a","AE":"e","AH":"a","AO":"o","AW":"au","AY":"ay",
    "B":"b","CH":"ç","D":"d","DH":"d","EH":"e","ER":"ır","EY":"ey",
    "F":"f","G":"g","HH":"h","IH":"i","IY":"i","JH":"c","K":"k",
    "L":"l","M":"m","N":"n","NG":"ng","OW":"o","OY":"oy","P":"p",
    "R":"r","S":"s","SH":"ş","T":"t","TH":"t","UH":"u","UW":"u",
    "V":"v","W":"v","Y":"y","Z":"z","ZH":"j",
}
APPROXIMATE = {"AE","TH","DH","ER","AH","OW","W","AW","AO","ZH"}
TURKISH_COLLISIONS = {
    "model","normal","program","format","market","alarm","salon","motor",
    "internet","social","final","total","ideal","oral","roman","radar",
    "pilot","metal","global","local","portal","legal","viral","modem",
    "robot","organ","panel","tempo","video","audio","metro","taksi",
    "sistem","server","safari","forum","kamera","telefon","foto",
    "futbol","tenis","basket","festival","otomatik","plastik",
}
TECH_PARTS = (
    "software","hardware","computer","server","network","internet","mobile",
    "digital","virtual","browser","security","crypto","database","coding",
    "developer","technology","micro","media","audio","video","gaming",
    "machine","learning","science","smart","phone","cloud","stream",
    "design","image","camera","photo","pixel","wallet","music","display",
    "synth","robot","console","processor","memory","platform","signal",
    "online","offline","backup","download","upload","graphic","project",
    "engine","apple","search","email","social","privacy","sound","neural",
    "neuron","studio","code","web","data",
)

def approximate(phonemes):
    parts, warnings = [], set()
    for symbol in phonemes:
        base = re.sub(r"\d$", "", symbol)
        if base not in MAP:
            return None, []
        if base in APPROXIMATE:
            warnings.add(base)
        parts.append("ı" if symbol == "AH0" else MAP[base])
    return "".join(parts), sorted(warnings)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="build/ema-pronunciation-candidates.jsonl")
    parser.add_argument("--limit", type=int, default=40000)
    args = parser.parse_args()
    if not (1 <= args.limit <= 100000):
        parser.error("--limit must be between 1 and 100000")
    try:
        import cmudict
        from spacy.lang.en.stop_words import STOP_WORDS as english_stop
        from spacy.lang.tr.stop_words import STOP_WORDS as turkish_stop
    except ImportError:
        parser.error("research-only deps missing: pip install cmudict spacy")
    root = Path(__file__).resolve().parents[1]
    existing = json.loads((root / "App/Resources/EMA/pronunciations.json").read_text(encoding="utf-8"))
    old = {unicodedata.normalize("NFC", r["word"]).casefold() for r in existing}
    items = []
    for word, variants in cmudict.dict().items():
        word = word.lower()
        if not re.fullmatch(r"[a-z]{5,15}", word):
            continue
        if word in old or word in english_stop or word in turkish_stop or word in TURKISH_COLLISIONS:
            continue
        if len({tuple(x) for x in variants}) != 1:
            continue
        reading, warnings = approximate(variants[0])
        if not reading or not re.fullmatch(r"[a-zçğıöşü]+", reading):
            continue
        if difflib.SequenceMatcher(None, word, reading).ratio() >= 0.91:
            continue
        tech = any(fragment in word for fragment in TECH_PARTS)
        items.append({
            "word": word,
            "candidate_pronunciation": reading,
            "source_arpabet": " ".join(variants[0]),
            "category_candidate": "Teknik terim" if tech else "İngilizce",
            "uncertain_phonemes": warnings,
            "status": "UNVERIFIED_DO_NOT_IMPORT",
            "source": "Carnegie Mellon Pronouncing Dictionary",
            "source_url": "https://github.com/cmusphinx/cmudict",
        })
    items.sort(key=lambda x: (
        x["category_candidate"] != "Teknik terim",
        len(x["uncertain_phonemes"]),
        abs(len(x["word"])-8),
        x["word"],
    ))
    items = items[:args.limit]
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as stream:
        for item in items:
            stream.write(json.dumps(item, ensure_ascii=False, sort_keys=True)+"\n")
    print(f"Wrote {len(items)} unverified candidates: {output}")
    print("NOT published. Review phonetics, actual Turkish usage, collisions and EMA audio first.")

if __name__ == "__main__":
    main()
