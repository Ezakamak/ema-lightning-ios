#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/prepare-assets.sh
mkdir -p build
simulator="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; x=json.load(sys.stdin); print(next(d["udid"] for r,ds in x["devices"].items() if "iOS" in r for d in ds if "iPhone" in d["name"]))')"
# Compile tests before spending runner time on simulator boot. Test failures need no rebuild.
common=(-project EMALightning.xcodeproj -scheme EMALightning -configuration Debug
  -destination "platform=iOS Simulator,id=$simulator"
  IPHONEOS_DEPLOYMENT_TARGET=18.4 CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES)
# WebKit bug 293831: simulator-only deployment override; device builds remain iOS 17+.
xcodebuild "${common[@]}" build-for-testing
xcrun simctl boot "$simulator" || true
xcrun simctl bootstatus "$simulator" -b
xcodebuild "${common[@]}" -resultBundlePath build/EMAIntegration.xcresult \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 test-without-building
