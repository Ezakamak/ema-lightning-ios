#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:-0.3.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a version such as 0.3.0" >&2
  exit 1
fi
scripts/prepare-assets.sh
mkdir -p build
xcodebuild -version
xcodebuild -project EMALightning.xcodeproj -scheme EMALightning \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/EMALightning.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$((100 + ${GITHUB_RUN_NUMBER:-0}))" archive
app=build/EMALightning.xcarchive/Products/Applications/EMALightning.app
test -d "$app"
if [[ -d "$app/_CodeSignature" || -f "$app/embedded.mobileprovision" ]]; then
  echo "Unexpected signing material in unsigned archive" >&2
  exit 1
fi
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/EMALightning.app"
output="$PWD/build/EMALightning-${version}-unsigned.ipa"
rm -f "$output"
(cd "$stage" && /usr/bin/zip -qry "$output" Payload)
(cd build && shasum -a 256 "EMALightning-${version}-unsigned.ipa" > SHA256SUMS)
unzip -t "$output"
python3 scripts/verify-ipa.py "$output"
