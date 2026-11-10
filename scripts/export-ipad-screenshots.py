#!/usr/bin/env python3
"""Export only our explicitly named XCTest attachments, without resizing pixels."""
import json
import re
import shutil
import struct
from pathlib import Path

EXPECTED = {"01-Olustur", "02-Gecmis", "03-Ayarlar", "04-Telaffuz"}


def validate_png(path, allow_alpha=False):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 26:
        raise ValueError(f"Not a PNG: {path}")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if (width, height, depth) != (2048, 2732, 8) or color not in ((2, 6) if allow_alpha else (2,)):
        raise ValueError(f"Expected opaque RGB 2048×2732 PNG: {path}; got {width, height, depth, color}")


def export(source, destination):
    manifest = json.loads((source / "manifest.json").read_text())
    found = {}
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith("EMA-iPad-"):
                continue
            matches = [expected for expected in EXPECTED
                       if re.match(r"^EMA-iPad-" + re.escape(expected) + r"(?:[_. -]|$)", name)]
            if len(matches) != 1:
                raise ValueError(f"Unexpected screenshot: {name}")
            name = matches[0]
            if name in found:
                raise ValueError(f"Unexpected/duplicate screenshot: {name}")
            path = (source / attachment["exportedFileName"]).resolve()
            if path.parent != source.resolve():
                raise ValueError("Attachment path escapes export folder")
            validate_png(path, allow_alpha=True)
            found[name] = path
    if set(found) != EXPECTED:
        raise ValueError(f"Missing screenshots: {EXPECTED - set(found)}")
    destination.mkdir(parents=True, exist_ok=True)
    for old in destination.glob("*.png"):
        old.unlink()
    for name, path in sorted(found.items()):
        shutil.copyfile(path, destination / f"{name}.png")
    print("Exported four native 2048×2732 Turkish iPad PNGs")


if __name__ == "__main__":
    export(Path("build/ipad-attachments"), Path("build/ipad-screenshots/tr"))
