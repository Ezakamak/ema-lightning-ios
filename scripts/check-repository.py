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
