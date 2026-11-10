#!/usr/bin/env python3
"""Check packaging/provenance contracts without requiring Xcode."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
required = [
    'LICENSE', 'NOTICE', 'README.md', 'CONTRIBUTING.md', 'CHANGELOG.md',
    'docs/INSTALL.tr.md', 'docs/INSTALL.en.md', 'docs/DEPENDENCIES.md',
    'licenses/upstream/ema-lightning-LICENSE',
    'licenses/upstream/ema-lightning-web-LICENSE',
    'licenses/upstream/ema-lightning-web-NOTICE',
    'licenses/upstream/normalizer-tr-THIRD_PARTY_NOTICES.md',
]
for name in required:
    assert (root / name).is_file(), f'Missing {name}'
for name in ['LICENSE', 'NOTICE']:
    assert (root / name).read_bytes() == (root / f'App/Resources/{name}.txt').read_bytes(), name
readme = (root / 'README.md').read_text()
assert 'Canberk Aslan' in readme and 'Özcan Çelik' in readme
project = (root / 'EMALightning.xcodeproj/project.pbxproj').read_text()
for source in (root / 'App').rglob('*.swift'):
    assert str(source.relative_to(root)) in project, f'Unregistered source {source}'
ids = re.findall(r'^([0-9A-F]{24}) =', project, re.M)
assert len(ids) == len(set(ids)), 'Duplicate Xcode object ID'
for reference in re.findall(r'\b[0-9A-F]{24}\b', project):
    assert reference in ids, f'Unresolved Xcode reference {reference}'
ET.parse(root / 'EMALightning.xcodeproj/xcshareddata/xcschemes/EMALightning.xcscheme')
assert 'XCRemoteSwiftPackageReference' not in project, 'Audit new remote dependency first'
print('Repository packaging and provenance checks passed.')

# Every byte of model/runtime/license payload must match the reviewed asset inventory.
import hashlib
import json
assets = root / 'App/Resources/EMA'
manifest = json.loads((assets / 'ASSETS.json').read_text())
recorded = {entry['path'] for entry in manifest['files']}
actual = {str(p.relative_to(assets)) for p in assets.rglob('*') if p.is_file() and p.name != 'ASSETS.json'}
assert actual == recorded, 'Asset inventory is incomplete'
for entry in manifest['files']:
    data = (assets / entry['path']).read_bytes()
    assert len(data) == entry['bytes'], entry['path']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
for name in ['models/text.onnx', 'models/sound.onnx', 'models/decoder.onnx',
             'models/normalizer.wasm', 'runtime/ort.wasm.min.mjs',
             'runtime/ort-wasm-simd-threaded.mjs', 'runtime/ort-wasm-simd-threaded.wasm']:
    assert name in recorded, f'Missing inference dependency {name}'
assert 'http' not in (assets / 'bridge.js').read_text()
assert 'http' not in (assets / 'worker.js').read_text()
assert 'https://cdn' not in (assets / 'tts.js').read_text()
print('Bundled model/runtime/license hashes verified.')

# Studio encoder is a separately loaded LGPL component, with full source in the IPA.
mp3 = root / 'App/Resources/MP3'
mp3_manifest = json.loads((mp3 / 'ASSETS.json').read_text())
assert mp3_manifest['license'] == 'LGPL-3.0'
recorded = {entry['path'] for entry in mp3_manifest['files']}
assert recorded == {p.name for p in mp3.iterdir() if p.is_file() and p.name != 'ASSETS.json'}
for entry in mp3_manifest['files']:
    data = (mp3 / entry['path']).read_bytes()
    assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
for name in ['lame.all.js', 'lamejs-1.2.1-source.tgz', 'COPYING', 'COPYING.LESSER', 'REPLACEMENT.md']:
    assert name in recorded, name
import base64
source = (mp3 / 'lamejs-1.2.1-source.tgz').read_bytes()
assert 'sha512-' + base64.b64encode(hashlib.sha512(source).digest()).decode() == mp3_manifest['npm_integrity']
assert (root / 'App/Resources/Brand/Logo-original.jpg').is_file()
assert (root / 'App/Resources/PrivacyInfo.xcprivacy').is_file()
print('Studio encoder source, licenses, integrity and brand/privacy resources verified.')

# Fail before a macOS build if App Store delivery metadata regresses.
import plistlib
import struct
info = plistlib.loads((root / 'App/Resources/Info.plist').read_bytes())
assert set(info['UISupportedInterfaceOrientations']) == {
    'UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight',
}, 'iPad multitasking requires all four orientations'
icons = root / 'App/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((icons / 'Contents.json').read_text())['images']:
    png = (icons / entry['filename']).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n', entry['filename']
    width, height, depth, color_type = struct.unpack('>IIBB', png[16:26])
    expected = int(float(entry['size'].split('x')[0]) * int(entry['scale'][0]))
    assert (width, height) == (expected, expected), entry['filename']
    assert depth == 8 and color_type == 2, 'App icons must be opaque RGB PNGs'
assert 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' in project
print('App Store icon dimensions, opacity and orientation metadata verified.')
