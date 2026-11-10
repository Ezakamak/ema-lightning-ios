#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
export_screenshots() {
xcrun xcresulttool export attachments --path build/iPadScreenshots.xcresult --output-path build/ipad-attachments
python3 scripts/export-ipad-screenshots.py
swift scripts/opaque-screenshots.swift build/ipad-screenshots/tr/*.png
python3 - <<'PYTHON'
import importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location("exporter", "scripts/export-ipad-screenshots.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for path in Path("build/ipad-screenshots/tr").glob("*.png"):
    module.validate_png(path)
PYTHON
}

# Recover already captured XCTest attachments without another simulator build.
if [[ -n "${RECOVERY_RUN_ID:-}" ]]; then
  [[ "$RECOVERY_RUN_ID" =~ ^[0-9]+$ ]]
  gh run download "$RECOVERY_RUN_ID" --repo "$GITHUB_REPOSITORY"     --name ipad-screenshot-diagnostics --dir build
  export_screenshots
  exit 0
fi
xcodebuild -version
# Create a fresh, isolated simulator; never reuse an iPhone or a user's data.
runtime="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
r = [r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-") and tuple(map(int, r["version"].split("."))) >= (18, 4)]
if not r: sys.exit("An installed iOS 18.4+ runtime is required")
print(max(r, key=lambda r: tuple(map(int, r["version"].split("."))))["identifier"])
')"
device_type="$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
matches = [d for d in json.load(sys.stdin)["devicetypes"] if "iPad Pro" in d["name"] and "12.9" in d["name"] and "6th generation" in d["name"]]
if not matches: sys.exit("No iPad Pro 12.9-inch 6th generation device type installed")
print(sorted(matches, key=lambda d: ("8GB" not in d["name"], d["identifier"]))[0]["identifier"])
')"
echo "Using device type: $device_type; runtime: $runtime"
simulator="$(xcrun simctl create EMA-AppStore-iPad "$device_type" "$runtime")"
cleanup() {
  xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true
  xcrun simctl delete "$simulator" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$simulator"
xcrun simctl bootstatus "$simulator" -b
xcrun simctl ui "$simulator" appearance light
xcrun simctl status_bar "$simulator" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
scripts/prepare-assets.sh
# Simulator-only override for the existing WebKit workaround (see test-ios-integration.sh).
export TEST_RUNNER_EMA_IPAD_SCREENSHOTS=1
xcodebuild test -project EMALightning.xcodeproj -scheme EMALightning \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator" \
  -resultBundlePath build/iPadScreenshots.xcresult \
  -only-testing:SpeechUITests/IPadAppStoreScreenshotTests \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
  -maximum-test-execution-time-allowance 180 \
  IPHONEOS_DEPLOYMENT_TARGET=18.4 CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
  2>&1 | tee build/ipad-screenshots.log
export_screenshots
