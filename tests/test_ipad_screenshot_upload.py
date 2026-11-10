"""API isolation/rollback checks; executed in Actions, without Apple credentials."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("upload", Path(__file__).resolve().parents[1] / "scripts/upload-ipad-screenshots.py")
upload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upload)


class FakeClient:
    state = "PREPARE_FOR_SUBMISSION"
    fail = False
    count = 1

    def __init__(self):
        self.calls = []
        self.serial = 0

    def list(self, path, **filters):
        if path.endswith("/appStoreVersions"):
            return [{"id": "version", "attributes": {"appStoreState": self.state}}]
        if path.endswith("/appStoreVersionLocalizations"):
            return [{"id": "turkish", "attributes": {"locale": "tr"}},
                    {"id": "english", "attributes": {"locale": "en-US"}}]
        if path.endswith("/appScreenshotSets"):
            return [{"id": "ipad", "attributes": {"screenshotDisplayType": upload.DISPLAY_TYPE}},
                    {"id": "iphone", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}}]
        if path == "/appScreenshotSets/ipad/appScreenshots":
            return [{"id": f"old-ipad-{n}"} for n in range(self.count)]
        raise AssertionError(path)

    def call(self, method, path, body=None):
        self.calls.append((method, path, body))
        if path == "/apps/test":
            return {"data": {"attributes": {"bundleId": upload.BUNDLE_ID}}}
        if method == "POST":
            self.serial += 1
            return {"data": {"id": f"new-{self.serial}", "attributes": {"uploadOperations": []}}}
        if method == "GET":
            return {"data": {"attributes": {"assetDeliveryState": {"state": "FAILED" if self.fail else "COMPLETE"}}}}
        return {}


class UploadScopeTests(unittest.TestCase):
    def invoke(self, client):
        paths = [Path(name + ".png") for name in sorted(["01-Olustur", "02-Gecmis", "03-Ayarlar", "04-Telaffuz"])]
        with patch.object(upload, "Client", return_value=client), \
             patch.object(upload, "required", return_value="test"), \
             patch.object(Path, "glob", return_value=paths), \
             patch.object(Path, "read_bytes", return_value=b"test PNG"), \
             patch.object(upload.exporter, "validate_png"):
            upload.main()

    def test_only_exact_turkish_ipad_set_is_replaced(self):
        client = FakeClient()
        self.invoke(client)
        deletes = [path for method, path, _ in client.calls if method == "DELETE"]
        self.assertEqual(deletes, ["/appScreenshots/old-ipad-0"])
        self.assertEqual(client.calls[-1][1], "/appScreenshotSets/ipad/relationships/appScreenshots")
        for method, path, body in client.calls:
            self.assertTrue(method == "GET" or path.startswith(("/appScreenshots", "/appScreenshotSets/ipad/")))
            self.assertNotIn("iphone", str(body))
            self.assertNotIn("english", str(body))
        complete = [i for i, (method, _, _) in enumerate(client.calls) if method == "GET"]
        delete = next(i for i, (method, _, _) in enumerate(client.calls) if method == "DELETE")
        self.assertGreater(delete, max(complete))

    def test_processing_failure_preserves_originals(self):
        client = FakeClient()
        client.fail = True
        with self.assertRaises(RuntimeError):
            self.invoke(client)
        self.assertEqual([p for m, p, _ in client.calls if m == "DELETE"], ["/appScreenshots/new-1"])

    def test_live_version_has_no_mutations(self):
        client = FakeClient()
        client.state = "READY_FOR_SALE"
        with self.assertRaises(ValueError):
            self.invoke(client)
        self.assertFalse(any(m != "GET" for m, _, _ in client.calls))

    def test_capacity_failure_has_no_mutations(self):
        client = FakeClient()
        client.count = 7
        with self.assertRaises(ValueError):
            self.invoke(client)
        self.assertFalse(any(m != "GET" for m, _, _ in client.calls))
