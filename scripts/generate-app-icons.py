#!/usr/bin/env python3
"""Resize the supplied original artwork into opaque Apple app icons (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageOps

root = Path(__file__).resolve().parent.parent
source = root / 'App/Resources/Brand/Logo-original.jpg'
target = root / 'App/Assets.xcassets/AppIcon.appiconset'
target.mkdir(parents=True, exist_ok=True)
with Image.open(source) as original:
    # Preserve the full original artwork and aspect ratio. No redraw or cropping.
    image = ImageOps.pad(ImageOps.exif_transpose(original).convert('RGB'),
                         (1024, 1024), method=Image.Resampling.LANCZOS, color='black')
entries = []
for idiom, sizes in [
    ('iphone', {'20': [2, 3], '29': [2, 3], '40': [2, 3], '60': [2, 3]}),
    ('ipad', {'20': [1, 2], '29': [1, 2], '40': [1, 2], '76': [1, 2], '83.5': [2]}),
    ('ios-marketing', {'1024': [1]}),
]:
    for size, scales in sizes.items():
        for scale in scales:
            pixels = int(float(size) * scale)
            filename = f'Icon-{pixels}.png'
            image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(target / filename)
            entries.append({'idiom': idiom, 'size': f'{size}x{size}',
                            'scale': f'{scale}x', 'filename': filename})
(target / 'Contents.json').write_text(json.dumps({
    'images': entries, 'info': {'author': 'xcode', 'version': 1},
}, indent=2) + '\n')
print('Generated original artwork in all iPhone, iPad and 1024px App Store sizes.')
