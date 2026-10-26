import subprocess
import tempfile
import unittest
from pathlib import Path

import sign_desktop_update as signing


class SignDesktopUpdateTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.root = Path(self.scratch.name)
        self.key = self._key("update.pem", "ed25519")
        self.payload = self.root / "releases.stable.json"
        self.payload.write_text('{"Assets":[]}\n')

    def tearDown(self):
        self.scratch.cleanup()

    def _key(self, name: str, algorithm: str) -> Path:
        path = self.root / name
        subprocess.run(["openssl", "genpkey", "-algorithm", algorithm, "-out", str(path)], check=True,
                       capture_output=True)
        return path

    def test_signature_verifies_only_for_its_key_and_bytes(self):
        public_key = signing.public_key(key=self.key)
        signature = signing.sign(key=self.key, payload=self.payload)
        self.assertEqual(len(signing.base64.b64decode(public_key)), 32)
        self.assertTrue(signing.verify(public_key_b64=public_key, payload=self.payload, signature_b64=signature))

        other = signing.public_key(key=self._key("other.pem", "ed25519"))
        self.assertFalse(signing.verify(public_key_b64=other, payload=self.payload, signature_b64=signature))

        self.payload.write_text('{"Assets":[{"Version":"9.9.9"}]}\n')
        self.assertFalse(signing.verify(public_key_b64=public_key, payload=self.payload, signature_b64=signature))

        with self.assertRaisesRegex(RuntimeError, "could not check"):
            signing.verify(public_key_b64=public_key, payload=self.root / "missing.json", signature_b64=signature)

    def test_verifies_the_vector_the_desktop_feed_validator_checks(self):
        # client/module_desktop_core/test/repositories/desktop_update_feed_validator_test.dart checks the same files.
        vector = Path(__file__).resolve().parents[2] / "client/module_desktop_core/test/fixtures/desktop_update_feed"
        public_key = (vector / "public_key.txt").read_text().strip()
        signature = (vector / "releases.stable.json.sig").read_text().strip()
        self.assertTrue(signing.verify(public_key_b64=public_key, payload=vector / "releases.stable.json",
                                       signature_b64=signature))
        self.payload.write_bytes((vector / "releases.stable.json").read_bytes().replace(b"1.10.1", b"1.10.2"))
        self.assertFalse(signing.verify(public_key_b64=public_key, payload=self.payload, signature_b64=signature))

    def test_refuses_a_key_that_is_not_ed25519(self):
        with self.assertRaisesRegex(ValueError, "not an Ed25519 key"):
            signing.sign(key=self._key("rsa.pem", "rsa"), payload=self.payload)


if __name__ == "__main__":
    unittest.main()
