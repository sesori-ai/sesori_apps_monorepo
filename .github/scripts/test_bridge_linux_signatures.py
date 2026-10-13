"""Linux CLI signing and existing-release publication contracts; no production credentials."""

import contextlib
import hashlib
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock
from urllib.parse import urlparse

import linux_signing as keys
import publish_bridge_linux_signatures as publication
import sign_bridge_linux as signing

REPOSITORY = "fixture/repository"
TAG = "v9.8.7-internal.42"
WORKFLOWS = Path(__file__).resolve().parents[1] / "workflows"


class BridgeLinuxSignaturesTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.input, self.output = self.root / "input", self.root / "signed"
        self.input.mkdir()
        self.output.mkdir()
        self.assets = {}
        for name in signing.ARCHIVES:
            content = b"inert CLI archive fixture: " + name.encode()
            (self.input / name).write_bytes(content)
            self.assets[name] = content
        self.assets["checksums.txt"] = "".join(
            f"{keys.sha256(path=self.input / name)}  {name}\n" for name in signing.ARCHIVES).encode()
        (self.output / keys.PUBLIC_KEY).write_text("fixture public key")
        for name in signing.ARCHIVES:
            (self.output / f"{name}.asc").write_text("fixture detached signature: " + name)
        self.report = {"schemaVersion": 1, "signerFingerprint": "A" * 40,
                       "publicKeyFile": keys.PUBLIC_KEY, "artifacts": [
                           {"name": name, "sha256": keys.sha256(path=self.input / name),
                            "signature": name + ".asc"} for name in signing.ARCHIVES]}
        (self.output / "signing.json").write_text(json.dumps(self.report))
        self.calls = []

    def release(self):
        return {"tag_name": TAG, "draft": False, "prerelease": True,
                "assets": [{"name": name, "size": len(data), "digest": "sha256:" + hashlib.sha256(data).hexdigest()}
                           for name, data in self.assets.items()]}

    def github(self, *, arguments):
        self.calls.append(arguments)
        if arguments == ["api", f"repos/{REPOSITORY}/releases/tags/{TAG}"]:
            return json.dumps(self.release())
        if arguments[:3] == ["release", "upload", TAG]:
            self.assertEqual(arguments[4:], ["--repo", REPOSITORY])
            path = Path(arguments[3])
            self.assertNotIn(path.name, self.assets, "existing assets must never be overwritten")
            self.assets[path.name] = path.read_bytes()
            return ""
        self.fail(f"Unexpected release mutation or command: {arguments}")

    def public_hash(self, *, url):
        self.assertTrue(url.startswith(f"https://github.com/{REPOSITORY}/releases/download/{TAG}/"))
        return hashlib.sha256(self.assets[Path(urlparse(url).path).name]).hexdigest()

    def publish(self):
        with mock.patch.object(publication, "github", side_effect=self.github), \
                mock.patch.object(publication, "public_sha256", side_effect=self.public_hash), \
                contextlib.redirect_stdout(io.StringIO()):
            publication.publish(repository=REPOSITORY, tag=TAG, root=self.output)

    def test_downloads_exact_public_bytes_and_matches_index_and_checksums(self):
        urls = []

        def retrieve(url, *, timeout):
            urls.append(url)
            self.assertEqual(timeout, 60)
            return io.BytesIO(self.assets[Path(urlparse(url).path).name])

        root = self.root / "download"
        with mock.patch.object(publication, "github", side_effect=self.github), \
                mock.patch.object(publication, "urlopen", side_effect=retrieve):
            publication.download(repository=REPOSITORY, tag=TAG, root=root)
        self.assertEqual(len(urls), 3)
        for name, expected in self.assets.items():
            self.assertEqual((root / name).read_bytes(), expected)

    def test_download_refuses_index_or_published_checksum_mismatch(self):
        original = self.release()
        with mock.patch.object(publication, "github", return_value=json.dumps(original)), \
                mock.patch.object(publication, "urlopen", return_value=io.BytesIO(b"tampered")):
            with self.assertRaisesRegex(ValueError, "index digest mismatch"):
                publication.download(repository=REPOSITORY, tag=TAG, root=self.root / "bad-index")
        self.assets["checksums.txt"] = ("0" * 64 + "  " + signing.ARCHIVES[0] + "\n").encode()
        with mock.patch.object(publication, "github", side_effect=self.github), \
                mock.patch.object(publication, "urlopen", side_effect=lambda url, **_: io.BytesIO(
                    self.assets[Path(urlparse(url).path).name])):
            with self.assertRaisesRegex(ValueError, "published Bridge checksums"):
                publication.download(repository=REPOSITORY, tag=TAG, root=self.root / "bad-checksum")

    def test_only_signature_assets_are_uploaded_and_same_byte_retry_is_safe(self):
        before = dict(self.assets)
        self.publish()
        self.assertEqual(set(self.assets) - set(before),
                         {keys.PUBLIC_KEY, *(name + ".asc" for name in signing.ARCHIVES)})
        self.assertEqual({name: self.assets[name] for name in before}, before)
        self.calls.clear()
        self.publish()
        self.assertEqual(len(self.calls), 1)  # Release read only; no reuploads.

    def test_failed_publish_job_can_retry_with_the_original_signatures(self):
        original = self.github
        failed = False

        def uncertain_upload(*, arguments):
            nonlocal failed
            result = original(arguments=arguments)
            if arguments[:2] == ["release", "upload"] and not failed:
                failed = True
                raise subprocess.CalledProcessError(1, ["gh", *arguments])
            return result

        with mock.patch.object(self, "github", side_effect=uncertain_upload):
            with self.assertRaises(subprocess.CalledProcessError):
                self.publish()
        self.publish()
        self.assertEqual(len([call for call in self.calls if call[:2] == ["release", "upload"]]), 3)

    def test_changed_archives_or_conflicting_signatures_are_never_replaced(self):
        name = signing.ARCHIVES[0]
        self.assets[name] = b"changed after signing"
        with self.assertRaisesRegex(ValueError, "changed after signing"):
            self.publish()
        self.assertFalse(any(call[:2] == ["release", "upload"] for call in self.calls))
        self.assets[name] = (self.input / name).read_bytes()
        self.assets[keys.PUBLIC_KEY] = b"different public key"
        with self.assertRaisesRegex(ValueError, "refusing replacement"):
            self.publish()
        self.assertEqual(self.assets[keys.PUBLIC_KEY], b"different public key")

    def test_invalid_tag_draft_or_desktop_records_are_refused(self):
        with mock.patch.object(publication, "github") as github:
            with self.assertRaisesRegex(ValueError, "existing shared"):
                publication.public_release(repository=REPOSITORY, tag="../other")
            github.assert_not_called()
        with mock.patch.object(publication, "github", return_value=json.dumps({**self.release(), "draft": True})):
            with self.assertRaisesRegex(ValueError, "existing public"):
                publication.public_release(repository=REPOSITORY, tag=TAG)
        self.report["artifacts"][0]["name"] = "Sesori-linux-x64.deb"
        (self.output / "signing.json").write_text(json.dumps(self.report))
        with self.assertRaisesRegex(ValueError, "two Linux Bridge"):
            self.publish()

    def test_missing_cpu_never_opens_the_key_and_signing_failure_never_completes(self):
        (self.input / signing.ARCHIVES[0]).unlink()
        with mock.patch.object(signing, "signing_key") as key:
            with self.assertRaisesRegex(ValueError, "Missing or empty"):
                signing.sign_archives(root=self.input, output=self.output, fingerprint="A" * 40)
            key.assert_not_called()
        (self.input / signing.ARCHIVES[0]).write_bytes(b"fixture")
        (self.output / "signing.json").unlink()
        key = mock.Mock()
        key.sign_detached.side_effect = subprocess.CalledProcessError(2, ["gpg"])
        with mock.patch.object(signing, "signing_key", return_value=contextlib.nullcontext(key)):
            with self.assertRaises(subprocess.CalledProcessError):
                signing.sign_archives(root=self.input, output=self.output, fingerprint="A" * 40)
        self.assertFalse((self.output / "signing.json").exists())

    def test_workflow_keeps_secrets_isolated_and_both_release_channels_publish_signatures(self):
        workflow = (WORKFLOWS / "_reusable-linux-cli-signing.yml").read_text()
        self.assertIn("environment: linux-signing", workflow)
        self.assertIn("contents: read", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertLess(workflow.index('[[ "$GITHUB_REF" == refs/heads/main ]]'),
                        workflow.index("uses: actions/checkout@v6"))
        signing_step = workflow.split("      - name: Sign unchanged archives", 1)[1].split("      - name:", 1)[0]
        self.assertIn("--network none", signing_step)
        self.assertIn("/.github/scripts:/scripts:ro", signing_step)
        for secret in (keys.KEY_SECRET, keys.PASSPHRASE_SECRET):
            self.assertEqual(workflow.count(f"secrets.{secret}"), 1)
            self.assertIn(f"secrets.{secret}", signing_step)
        self.assertLess(workflow.index("Build signing tools without secrets"),
                        workflow.index("Sign unchanged archives"))
        bridge = (WORKFLOWS / "_reusable-bridge-build.yml").read_text()
        self.assertIn("sign-linux:\n    needs: build\n"
                      "    uses: ./.github/workflows/_reusable-linux-cli-signing.yml", bridge)
        for filename in ("release-all-platforms.yml", "submit-release.yml"):
            release = (WORKFLOWS / filename).read_text()
            self.assertIn("artifacts/*.asc", release)
            self.assertIn("Verify public Linux archive signatures", release)
            self.assertIn('publish_bridge_linux_signatures.py publish', release)
        bootstrap = (WORKFLOWS / "sign-linux-release.yml").read_text()
        self.assertNotIn("store-production", bootstrap)
        self.assertNotIn("gh release create", bootstrap)
        self.assertNotIn("--clobber", bootstrap)


if __name__ == "__main__":
    unittest.main()
