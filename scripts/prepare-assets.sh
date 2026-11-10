#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Generated PNGs are committed so Actions does not need Pillow or redraw artwork.
# To regenerate after changing the original: python3 scripts/generate-app-icons.py
test -f App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
