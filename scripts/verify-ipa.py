#!/usr/bin/env python3
"""Verify that the IPA contains the exact offline model/runtime/license payload."""
import hashlib
import json
import plistlib
from pathlib import Path
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None
    prefix = 'Payload/EMALightning.app/'
    assert not any('_CodeSignature/' in p or p.endswith('embedded.mobileprovision') for p in archive.namelist())
    manifest = json.loads(archive.read(prefix + 'EMA/ASSETS.json'))
    for entry in manifest['files']:
        data = archive.read(prefix + 'EMA/' + entry['path'])
        assert len(data) == entry['bytes'], entry['path']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
    for name in ['LICENSE', 'NOTICE']:
        assert archive.read(prefix + name + '.txt') == Path(name).read_bytes()
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    assert info['NSAppTransportSecurity']['NSAllowsLocalNetworking'] is True
    assert not info['NSAppTransportSecurity'].get('NSAllowsArbitraryLoads', False)
    print(f"Verified {len(manifest['files'])} bundled model/runtime/license assets in unsigned IPA.")

    mp3 = json.loads(archive.read(prefix + 'MP3/ASSETS.json'))
    for entry in mp3['files']:
        data = archive.read(prefix + 'MP3/' + entry['path'])
        assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
    assert archive.read(prefix + 'Brand/Logo-original.jpg') == Path('App/Resources/Brand/Logo-original.jpg').read_bytes()
    assert any(p.startswith(prefix + 'AppIcon') and p.endswith('.png') for p in archive.namelist()), 'Missing application icon'
    privacy = plistlib.loads(archive.read(prefix + 'PrivacyInfo.xcprivacy'))
    assert privacy['NSPrivacyTracking'] is False
    assert 'audio' in info['UIBackgroundModes']
    print(f"Verified {len(mp3['files'])} MP3 encoder/source/license assets, original logo, icon and privacy manifest.")
