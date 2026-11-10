#!/usr/bin/env python3
"""Only the existing iOS version's tr / 12.9-inch iPad screenshot set is writable."""
import hashlib
import json
import os
from pathlib import Path
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from importlib.util import module_from_spec, spec_from_file_location

API = "https://api.appstoreconnect.apple.com/v1"
DISPLAY_TYPE = "APP_IPAD_PRO_3GEN_129"
BUNDLE_ID = "net.ekatech.ema-lightning-ios.627Y9N4Q6P"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
spec = spec_from_file_location("exporter", Path(__file__).with_name("export-ipad-screenshots.py"))
exporter = module_from_spec(spec)
spec.loader.exec_module(exporter)


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing {name}")
    return value


class Client:
    def __init__(self):
        import jwt
        now = int(time.time())
        self.token = jwt.encode(
            {"iss": required("ASC_ISSUER_ID"), "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
            required("ASC_PRIVATE_KEY"), algorithm="ES256", headers={"kid": required("ASC_KEY_ID"), "typ": "JWT"})

    def call(self, method, path, body=None):
        url = path if path.startswith(API + "/") else API + path
        if not url.startswith(API + "/"):
            raise ValueError("Unexpected API URL")
        data = json.dumps(body).encode() if body is not None else None
        request = Request(url, data=data, method=method, headers={
            "Authorization": "Bearer " + self.token, "Content-Type": "application/json"})
        try:
            with urlopen(request, timeout=60) as response:
                content = response.read()
                return json.loads(content) if content else {}
        except HTTPError as error:
            # Do not log auth headers, signed asset URLs or private key material.
            raise RuntimeError(f"ASC {method} failed with HTTP {error.code}") from None

    def list(self, path, **filters):
        url = path + "?" + urlencode({"limit": 200, **filters})
        result = []
        while url:
            page = self.call("GET", url)
            result.extend(page["data"])
            url = page.get("links", {}).get("next")
        return result


def resource(kind, attributes, **relationships):
    return {"data": {"type": kind, "attributes": attributes, "relationships": {
        key: {"data": {"type": value[0], "id": value[1]}} for key, value in relationships.items()}}}


def main():
    paths = sorted(Path("build/ipad-screenshots/tr").glob("*.png"))
    if {p.stem for p in paths} != exporter.EXPECTED:
        raise ValueError("Expected exactly four named iPad PNGs")
    for path in paths:
        exporter.validate_png(path)
    version_string = required("ASC_APP_VERSION")
    app_id = required("ASC_APP_ID")
    client = Client()
    app = client.call("GET", f"/apps/{app_id}")["data"]
    if app["attributes"]["bundleId"] != BUNDLE_ID:
        raise ValueError("ASC_APP_ID does not belong to EMA Lightning; nothing uploaded")
    versions = client.list(f"/apps/{app_id}/appStoreVersions", **{
        "filter[platform]": "IOS", "filter[versionString]": version_string})
    if len(versions) != 1 or versions[0]["attributes"]["appStoreState"] not in EDITABLE:
        raise ValueError("Choose an existing editable iOS App Store version; no version will be created")
    locales = client.list(f'/appStoreVersions/{versions[0]["id"]}/appStoreVersionLocalizations')
    locales = [loc for loc in locales if loc["attributes"]["locale"] == "tr"]
    if len(locales) != 1:
        raise ValueError("The selected version must already have a Turkish (tr) localization")
    sets = client.list(f'/appStoreVersionLocalizations/{locales[0]["id"]}/appScreenshotSets')
    sets = [s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE]
    if len(sets) > 1:
        raise ValueError("Ambiguous iPad screenshot set")
    if sets:
        set_id = sets[0]["id"]
    else:
        created = client.call("POST", "/appScreenshotSets", resource(
            "appScreenshotSets", {"screenshotDisplayType": DISPLAY_TYPE},
            appStoreVersionLocalization=("appStoreVersionLocalizations", locales[0]["id"])))
        set_id = created["data"]["id"]
    original = client.list(f"/appScreenshotSets/{set_id}/appScreenshots")
    # Keep old images until ALL replacements are processed. Apple allows 10 per set.
    if len(original) + len(paths) > 10:
        raise ValueError("Not enough staging slots: leave at most 6 images in this tr iPad set before retrying; nothing deleted")
    staged = []
    committed = False
    try:
        for path in paths:
            data = path.read_bytes()
            item = client.call("POST", "/appScreenshots", resource(
                "appScreenshots", {"fileName": path.name, "fileSize": len(data)},
                appScreenshotSet=("appScreenshotSets", set_id)))["data"]
            screenshot_id = item["id"]
            staged.append(screenshot_id)
            for operation in item["attributes"]["uploadOperations"]:
                if not operation["url"].startswith("https://"):
                    raise ValueError("Upload operation must use HTTPS")
                offset, length = operation["offset"], operation["length"]
                request = Request(operation["url"], data=data[offset:offset + length],
                                  method=operation["method"], headers={h["name"]: h["value"] for h in operation["requestHeaders"]})
                # Signed asset URL: never send the ASC bearer token to the upload host.
                with urlopen(request, timeout=120) as response:
                    response.read()
            client.call("PATCH", f"/appScreenshots/{screenshot_id}", {"data": {
                "type": "appScreenshots", "id": screenshot_id, "attributes": {
                    "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
            for _ in range(60):
                state = client.call("GET", f"/appScreenshots/{screenshot_id}")["data"]["attributes"]["assetDeliveryState"]["state"]
                if state == "COMPLETE":
                    break
                if state == "FAILED":
                    raise RuntimeError(f"Apple rejected {path.name}")
                time.sleep(3)
            else:
                raise TimeoutError(f"Apple processing timed out for {path.name}")
        # All IDs below came from the exact tr/iPad set, never another locale or iPhone.
        committed = True
        for old in original:
            client.call("DELETE", f'/appScreenshots/{old["id"]}')
        client.call("PATCH", f"/appScreenshotSets/{set_id}/relationships/appScreenshots", {
            "data": [{"type": "appScreenshots", "id": sid} for sid in staged]})
    finally:
        if not committed:
            for sid in staged:
                try:
                    client.call("DELETE", f"/appScreenshots/{sid}")
                except Exception:
                    print("Could not clean a staged iPad screenshot; inspect the selected tr iPad set before retrying")
    print(f"Uploaded four Turkish iPad screenshots to iOS {version_string}; no binary or metadata submitted")


if __name__ == "__main__":
    main()
