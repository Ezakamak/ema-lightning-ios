#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
simulator="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; x=json.load(sys.stdin); print(next(d["udid"] for r,ds in x["devices"].items() if "iOS" in r for d in ds if "iPhone" in d["name"]))')"
# WebKit bug 293831: iOS 18.5 simulator lacks the back-deployment overlay.
# Apply the documented deployment-target workaround to TEST builds only.
# Device archives retain the project minimum (iOS 17).
xcodebuild -project EMALightning.xcodeproj -scheme EMALightning \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator" \
  -resultBundlePath build/EMAIntegration.xcresult \
  -parallel-testing-enabled NO IPHONEOS_DEPLOYMENT_TARGET=18.4 CODE_SIGNING_ALLOWED=NO test
