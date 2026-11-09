#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep the supplied original image unchanged in source. Generate the iOS icon on Actions.
sips -s format png -z 1024 1024 App/Resources/Brand/Logo-original.jpg \
  --out App/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
