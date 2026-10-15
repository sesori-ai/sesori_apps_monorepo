"""Publication ordering, immutable retries, selection and authority boundaries; no cloud writes."""

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
from urllib.error import HTTPError

import publish_linux_repository as publisher

SCRIPTS = Path(__file__).resolve().parent


class RepositoryPublicationTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.files = {
            publisher.PUBLIC_KEY: b"public fixture key",
            "apt/pool/internal/amd64/package.deb": b"immutable package",
            "apt/dists/internal/main/binary-amd64/by-hash/SHA256/hash": b"immutable index",
            "apt/dists/internal/main/binary-amd64/Packages": b"mutable index",
            "rpm/internal/x86_64/repodata/repomd.xml": b"<repomd><revision>9.8.7-42</revision></repomd>",
            "rpm/internal/x86_64/repodata/repomd.xml.asc": b"RPM signature",
            "apt/dists/internal/Release": b"Release",
            "apt/dists/internal/Release.gpg": b"APT detached signature",
            "apt/dists/internal/InRelease": b"APT cleartext signature",
        }
        for name, data in self.files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.report = {"version": "9.8.7", "buildNumber": 42,
                       "files": [{"name": name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
                                 for name, data in self.files.items()]}
        self.remote = {}
        self.writes = []
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(publisher, "verify", return_value=self.report).start()
        mock.patch.object(publisher, "public_bytes", side_effect=lambda *, name: self.remote.get(name)).start()
        mock.patch.object(publisher, "public_digest", side_effect=self.digest).start()
        mock.patch.object(publisher.subprocess, "run", side_effect=self.upload).start()

    def digest(self, *, name):
        return hashlib.sha256(self.remote[name]).hexdigest() if name in self.remote else None

    def upload(self, command, **kwargs):
        self.assertEqual(command[:3], ["gcloud", "storage", "cp"])
        self.assertTrue(kwargs["check"])
        name = command[4].removeprefix(f"gs://{publisher.BUCKET}/")
        self.assertEqual("--if-generation-match=0" in command, publisher.publication_order(name=name) == 1)
        self.writes.append(name)
        self.remote[name] = Path(command[3]).read_bytes()
        return subprocess.CompletedProcess(command, 0)

    def test_content_first_inrelease_last_and_retry_does_not_replace_identical_objects(self):
        self.remote["apt/pool/internal/amd64/old-package.deb"] = b"retained old payload"
        publisher.publish(root=self.root)
        self.assertEqual(self.writes[-1], "apt/dists/internal/InRelease")
        orders = [publisher.publication_order(name=name) for name in self.writes]
        self.assertEqual(orders, sorted(orders))
        self.assertEqual(self.remote["apt/pool/internal/amd64/old-package.deb"], b"retained old payload")
        self.writes.clear()
        publisher.publish(root=self.root)
        self.assertEqual(self.writes, [])

    def test_conflicting_immutable_bytes_refuse_before_entrypoint_updates(self):
        self.remote["apt/pool/internal/amd64/package.deb"] = b"conflicting bytes"
        with self.assertRaisesRegex(ValueError, "Conflicting immutable"):
            publisher.publish(root=self.root)
        self.assertFalse(any(publisher.publication_order(name=name) >= 3 for name in self.writes))

    def test_failed_anonymous_delivery_never_completes_entrypoints(self):
        with mock.patch.object(publisher, "public_digest", return_value=None):
            with self.assertRaisesRegex(ValueError, "Anonymous delivery differs"):
                publisher.publish(root=self.root)
        self.assertEqual(len(self.writes), 1)
        self.assertNotIn("apt/dists/internal/InRelease", self.remote)

    def test_old_failed_run_cannot_downgrade_either_partially_published_architecture(self):
        for advanced in ("aarch64", "x86_64"):
            with self.subTest(advanced=advanced):
                self.remote.clear()
                self.writes.clear()
                for arch in ("aarch64", "x86_64"):
                    revision = 43 if arch == advanced else 42
                    self.remote[f"rpm/internal/{arch}/repodata/repomd.xml"] = (
                        f"<repomd><revision>9.8.7-{revision}</revision></repomd>".encode())
                with self.assertRaisesRegex(ValueError, "downgrade"):
                    publisher.publish(root=self.root)
                self.assertEqual(self.writes, [])

    def test_verification_failure_prevents_any_publication(self):
        with mock.patch.object(publisher, "verify", side_effect=ValueError("bad signature")):
            with self.assertRaisesRegex(ValueError, "bad signature"):
                publisher.publish(root=self.root)
        self.assertEqual(self.writes, [])


class RepositoryDownloadTest(unittest.TestCase):
    def test_selects_newest_completed_internal_not_stable_incomplete_or_republished_older_build(self):
        release = lambda tag, complete=True, **extra: {
            "tag_name": tag, "draft": False, "prerelease": True,
            "assets": [{"name": publisher.MANIFEST}] if complete else [], **extra}
        releases = [release("v9.8.7-internal.43"), release("v9.8.7-internal.42"),
                    release("v9.8.7-internal.44", complete=False), release("v10.0.0", prerelease=False),
                    release("v9.8.7-internal.45", draft=True)]
        version, number = "9.8.7", 43
        metadata = {"repository": publisher.REPOSITORY, "tag": "v9.8.7-internal.43",
                    "version": version, "buildNumber": number, "sourceSha": "b" * 40}
        files = {publisher.MANIFEST: json.dumps(metadata).encode(), publisher.PUBLIC_DESKTOP_KEY: b"public key"}
        for arch in publisher.ARCHITECTURES:
            for kind in ("deb", "rpm"):
                files[f"Sesori-linux-{arch}-{version}-{number}.{kind}"] = f"{arch}-{kind}".encode()
            for suffix in ("", ".asc"):
                files[f"desktop-linux-{arch}-checksums.txt{suffix}"] = f"{arch}-{suffix}".encode()
        releases[0]["assets"] = [
            {"name": name, "size": len(data), "digest": f"sha256:{hashlib.sha256(data).hexdigest()}"}
            for name, data in files.items()]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "download"
            responses = [json.dumps([releases]), json.dumps({"sha": "b" * 40})]
            with mock.patch.object(publisher, "github", side_effect=responses), \
                    mock.patch.object(publisher, "fetch", side_effect=lambda *, url, output: output.write_bytes(
                        files[url.rsplit("/", 1)[1]])), \
                    mock.patch.object(publisher, "verify_release", return_value=metadata) as verify:
                publisher.download(output=root)
            verify.assert_called_once_with(root=root, channel=publisher.Channel.INTERNAL,
                                           fingerprint=publisher.TRUSTED_PRIMARY_FINGERPRINT)
            self.assertEqual({path.name for path in root.iterdir()}, files.keys())

    def test_missing_completed_release_refuses_instead_of_bootstrapping_unqualified_assets(self):
        with mock.patch.object(publisher, "github", return_value="[[]]"), tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "No completed public"):
                publisher.download(output=Path(directory) / "input")

    def test_only_http_404_means_object_absent(self):
        for operation in (publisher.public_bytes, publisher.public_digest):
            for status in (403, 404, 500):
                with self.subTest(operation=operation.__name__, status=status):
                    error = HTTPError("https://example.invalid", status, "fixture", {}, None)
                    with mock.patch.object(publisher, "urlopen", side_effect=error):
                        if status == 404:
                            self.assertIsNone(operation(name="fixture"))
                        else:
                            with self.assertRaises(HTTPError):
                                operation(name="fixture")


class RepositoryWorkflowTest(unittest.TestCase):
    def test_bootstrap_refusal_preserves_error_and_explains_scoped_prerequisite(self):
        with tempfile.TemporaryDirectory() as directory:
            gcloud = Path(directory) / "gcloud"
            gcloud.write_text("#!/bin/sh\ncase \"$*\" in *--member=allUsers*) "
                              "echo 'fixture: sharing policy denied' >&2; exit 1;; esac\n")
            gcloud.chmod(0o700)
            result = subprocess.run(["/bin/bash", str(SCRIPTS / "provision_linux_repository.sh")],
                                    env={"PATH": directory}, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertIn("fixture: sharing policy denied", result.stderr)
        self.assertIn("resources created above remain", result.stderr)
        self.assertIn("bucket-only tag/policy prerequisite", result.stderr)
        self.assertIn("retry only the failed binding", result.stderr)

    def test_separate_signing_and_scoped_cloud_authority_with_weekly_refresh(self):
        workflow = (SCRIPTS.parent / "workflows/linux-repository.yml").read_text()
        sign, publish = workflow.split("\n  publish:\n")
        self.assertIn("environment: linux-signing", sign)
        self.assertIn("--network none", sign)
        self.assertLess(sign.index("docker build"), sign.index("LINUX_GPG_PRIVATE_KEY:"))
        self.assertNotIn("google-github-actions/auth", sign)
        self.assertNotIn("LINUX_GPG_PRIVATE_KEY", publish)
        self.assertNotIn("LINUX_GPG_PASSPHRASE", publish)
        self.assertIn("id-token: write", publish)
        self.assertIn("schedule:", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertNotIn("release create", workflow)
        self.assertNotIn("store-production", workflow)
        setup = (SCRIPTS / "provision_linux_repository.sh").read_text()
        self.assertIn("assertion.ref == 'refs/heads/main'", setup)
        self.assertIn("assertion.repository_id == '1187455604'", setup)
        self.assertIn("job_workflow_ref", setup)
        self.assertIn("linux-repository.yml@refs/heads/main", setup)
        self.assertIn(f"bucket={publisher.BUCKET}", setup)
        self.assertNotIn("projects add-iam-policy-binding", setup)
        self.assertIn("--role=roles/storage.objectUser", setup)
        parent = (SCRIPTS.parent / "workflows/desktop-linux-release.yml").read_text().split("\n  repositories:\n")[1]
        self.assertIn("needs: publish", parent)
        self.assertIn("secrets: inherit", parent)
        self.assertIn("id-token: write", parent)


if __name__ == "__main__":
    unittest.main()
