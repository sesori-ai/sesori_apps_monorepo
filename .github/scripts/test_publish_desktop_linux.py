"""Linux publication boundaries; inert packages plus a real disposable public-key fixture."""

import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import github_release_assets as public_assets
import publish_desktop_linux as publisher

SOURCE, TOOLING = "a" * 40, "b" * 40
REPO = "sesori-ai/sesori_apps_monorepo"
FINGERPRINT = publisher.TRUSTED_PRIMARY_FINGERPRINT
TAG = "v1.9.1-internal.1016"
WORKFLOWS = Path(__file__).resolve().parents[1] / "workflows"


def save(*, path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


class PublishLinuxTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / "prepared"
        self.args = dict(root=self.root, output=self.output, source_sha=SOURCE, tooling_sha=TOOLING,
                         repository=REPO, run_id=42, current_run_id=None, version="1.9.1", build_number=1016)
        save(path=self.root / "run.json", value={"id": 42, "repository": {"full_name": REPO},
             "path": ".github/workflows/desktop-qualification.yml", "event": "workflow_dispatch",
             "conclusion": "success", "head_sha": TOOLING, "head_branch": "main", "status": "completed"})
        for arch, machine in (("arm64", "aarch64"), ("x64", "x86_64")):
            packages = self.root / f"desktop-linux-packages-{arch}"
            packages.mkdir()
            evidence = self.root / f"desktop-linux-evidence-{arch}"
            bundle = evidence / "desktop-bundle"
            packaging = evidence / "desktop-linux-packaging"
            identity = {"os": "linux", "architecture": arch, "version": "1.9.1",
                        "buildNumber": 1016, "sourceSha": SOURCE}
            save(path=bundle / "bundle/bridge/desktop-bundle.json", value=identity)
            (bundle / "dart-defines.env").write_text(
                f"SESORI_DESKTOP_BUNDLE_IDENTITY={json.dumps(identity)}\nSESORI_DESKTOP_RELEASE_CHANNEL=internal\n")
            (bundle / "build-source-changes.patch").touch()
            artifacts = []
            for kind, extension in publisher.PACKAGE_EXTENSIONS.items():
                name = f"Sesori-linux-{arch}-1.9.1-1016.{extension}"
                data = f"inert {name}".encode()
                (packages / name).write_bytes(data)
                digest = hashlib.sha256(data).hexdigest()
                unsigned = "0" * 64 if kind == "rpm" else digest
                artifacts.append({"name": name, "bytes": len(data), "sha256": digest, "unsignedSha256": unsigned})
                save(path=packaging / kind / "packaging.json", value={
                    "packagerSourceSha": SOURCE, "bundle": {"identity": identity},
                    "package": {"name": name, "sha256": unsigned}})
            (packages / publisher.CHECKSUMS).write_text("".join(f"{a['sha256']}  {a['name']}\n" for a in artifacts))
            (packages / (publisher.CHECKSUMS + ".asc")).write_text("fixture signature")
            (packages / publisher.PUBLIC_KEY).write_text("fixture public key")
            save(path=packaging / "signed/signing.json", value={
                "identity": identity, "signerFingerprint": FINGERPRINT, "artifacts": artifacts,
                "checksumFile": publisher.CHECKSUMS, "publicKeyFile": publisher.PUBLIC_KEY})
            for fixture in publisher.FIXTURES:
                save(path=packaging / f"{fixture}-fixture.json", value={
                    "installedIdentity": identity, "architecture": arch, "containerMachine": machine,
                    **dict.fromkeys(publisher.FIXTURE_CHECKS, True)})
        self.uploads = []
        self.public = {"checksums.txt": b"core", "desktop-release.json": b"mac completion",
                       "sesori-linux-public.asc": b"core-owned key"}
        self.release = {"draft": False, "prerelease": True, "assets": [{"name": name} for name in self.public]}
        self.tag_source = SOURCE

    def github(self, *, arguments):
        if arguments == ["api", f"repos/{REPO}/releases/tags/{TAG}"]:
            return json.dumps(self.release)
        if arguments == ["api", f"repos/{REPO}/commits/{TAG}"]:
            return json.dumps({"sha": self.tag_source})
        self.assertEqual(arguments[:3], ["release", "upload", TAG])
        self.assertEqual(arguments[4:], ["--repo", REPO])
        path = Path(arguments[3])
        self.assertNotIn(path.name, self.public, "Never overwrite an existing release asset")
        self.uploads.append(path.name)
        self.public[path.name] = path.read_bytes()
        return ""

    def download(self, url, *, timeout):
        self.assertEqual(timeout, 60)
        prefix = f"https://github.com/{REPO}/releases/download/{TAG}/"
        self.assertTrue(url.startswith(prefix))
        return io.BytesIO(self.public[url.removeprefix(prefix)])

    def publish(self, **overrides):
        with patch.object(publisher, "github", side_effect=self.github), \
                patch.object(public_assets, "urlopen", side_effect=self.download), \
                patch.object(publisher, "verify_checksums") as verified, contextlib.redirect_stdout(io.StringIO()):
            publisher.publish(**(self.args | overrides))
        return verified

    def test_complete_native_set_publishes_linux_marker_last_without_touching_other_owners(self):
        original = self.public.copy()
        verified = self.publish()
        self.assertEqual(verified.call_count, 2)
        self.assertEqual(self.uploads[-1], publisher.MANIFEST)
        self.assertEqual(len(self.uploads), 12)
        metadata = json.loads(self.public[publisher.MANIFEST])
        self.assertEqual(metadata["sourceSha"], SOURCE)
        self.assertEqual(metadata["producerWorkflowSha"], TOOLING)
        self.assertEqual(metadata["channel"], "internal")
        self.assertEqual(metadata["signerFingerprint"], FINGERPRINT)
        self.assertTrue(all(call.kwargs["fingerprint"] == FINGERPRINT for call in verified.call_args_list))
        self.assertEqual({row["format"] for row in metadata["artifacts"]}, {"deb", "rpm", "appimage"})
        self.assertEqual(len(metadata["artifacts"]), 6)
        self.assertEqual(len(metadata["verificationFiles"]), 5)
        self.assertEqual({name: self.public[name] for name in original}, original)
        for arch in publisher.ARCHITECTURES:
            for suffix in ("", ".asc"):
                expected = self.root / f"desktop-linux-packages-{arch}" / (publisher.CHECKSUMS + suffix)
                self.assertEqual(self.public[f"desktop-linux-{arch}-checksums.txt{suffix}"], expected.read_bytes())

    def test_linux_completion_does_not_require_mac_completion(self):
        del self.public["desktop-release.json"]
        self.release["assets"] = [{"name": name} for name in self.public]
        self.publish()
        self.assertIn(publisher.MANIFEST, self.public)
        self.assertNotIn("desktop-release.json", self.public)

    def test_retry_is_byte_identical_and_never_replaces_delivered_assets(self):
        self.publish()
        self.release["assets"] = [{"name": name} for name in self.public]
        self.uploads.clear()
        self.publish(output=self.root / "retry")
        self.assertEqual(self.uploads, [])

    def test_conflicting_public_package_never_reaches_completion(self):
        name = "Sesori-linux-arm64-1.9.1-1016.deb"
        self.public[name] = b"different already delivered package"
        self.release["assets"].append({"name": name})
        with self.assertRaisesRegex(ValueError, "refusing replacement"):
            self.publish()
        self.assertEqual(self.uploads, [])
        self.assertNotIn(publisher.MANIFEST, self.public)

    def test_failed_anonymous_delivery_leaves_no_linux_completion(self):
        with patch.object(publisher, "public_sha256", return_value="0" * 64):
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                self.publish()
        self.assertEqual(len(self.uploads), 1)
        self.assertNotIn(publisher.MANIFEST, self.public)

    def test_existing_release_must_be_public_internal_and_exact_tag_source(self):
        for field in ("draft", "prerelease", "source"):
            with self.subTest(field=field):
                self.release.update(draft=field == "draft", prerelease=field != "prerelease")
                self.tag_source = TOOLING if field == "source" else SOURCE
                with self.assertRaisesRegex(ValueError, "internal release required|tag source differs"):
                    self.publish(output=self.root / field)
                self.assertEqual(self.uploads, [])

    def test_shared_identity_mismatch_and_private_ordinal_refused_before_network(self):
        for field, value in (("source_sha", "d" * 40), ("version", "1.9.2"), ("build_number", 147)):
            with self.subTest(field=field):
                with self.assertRaisesRegex(ValueError, "shared release identity"):
                    self.publish(**{field: value, "output": self.root / field})
                self.assertEqual(self.uploads, [])

    def test_untrusted_signer_is_refused_for_either_or_both_architectures(self):
        for targets in (("arm64",), ("x64",), publisher.ARCHITECTURES):
            with self.subTest(targets=targets):
                for arch in publisher.ARCHITECTURES:
                    path = self.root / f"desktop-linux-evidence-{arch}/desktop-linux-packaging/signed/signing.json"
                    value = json.loads(path.read_text())
                    # Even two agreeing reports cannot replace the repository's public trust anchor.
                    save(path=path, value=value | {"signerFingerprint": "D" * 40 if arch in targets else FINGERPRINT})
                with self.assertRaisesRegex(ValueError, "trusted primary fingerprint"):
                    self.publish(output=self.root / ("untrusted-" + "-".join(targets)))
                self.assertEqual(self.uploads, [])
                self.assertNotIn(publisher.MANIFEST, self.public)

    def test_stable_channel_cannot_be_relabeled_as_internal(self):
        for path in self.root.glob("*/desktop-bundle/dart-defines.env"):
            path.write_text(path.read_text().replace("CHANNEL=internal", "CHANNEL=stable"))
        with self.assertRaisesRegex(ValueError, "Only compiled internal"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_tampered_package_is_rejected_before_any_public_write(self):
        next(self.root.glob("desktop-linux-packages-arm64/*.deb")).write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_incomplete_native_fixture_is_rejected(self):
        path = self.root / "desktop-linux-evidence-x64/desktop-linux-packaging/fedora-44-fixture.json"
        value = json.loads(path.read_text())
        save(path=path, value=value | {"sameVersionReinstallVerified": False})
        with self.assertRaisesRegex(ValueError, "Incomplete fixture"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_failed_or_unrelated_in_progress_producer_is_rejected(self):
        path = self.root / "run.json"
        original = json.loads(path.read_text())
        for status, conclusion in (("completed", "failure"), ("in_progress", None)):
            save(path=path, value=original | {"status": status, "conclusion": conclusion})
            with self.assertRaisesRegex(ValueError, "successful producer"):
                self.publish()
        self.assertFalse(self.output.exists())

    def test_own_shared_in_progress_run_can_finish_after_its_native_dependencies(self):
        path = self.root / "run.json"
        value = json.loads(path.read_text()) | {"path": ".github/workflows/release-all-platforms.yml",
            "head_sha": SOURCE, "status": "in_progress", "conclusion": None}
        save(path=path, value=value)
        self.publish(current_run_id=42, tooling_sha=SOURCE)
        self.assertIn(publisher.MANIFEST, self.public)


class LinuxWorkflowTest(unittest.TestCase):
    def test_public_verification_instructions_match_the_repository_pin(self):
        instructions = (Path(__file__).resolve().parents[2] / "docs/desktop/linux-signing.md").read_text()
        self.assertIn(f"fingerprint={FINGERPRINT}\n", instructions)

    def test_internal_only_parallel_native_calls_preserve_core_and_macos(self):
        workflow = (WORKFLOWS / "release-all-platforms.yml").read_text()
        build = workflow.split("  desktop-linux:\n", 1)[1].split("  publish-desktop-linux:\n", 1)[0]
        for expected in ("mode: linux-packaging", "channel: internal", "secrets: inherit",
                         "source_sha: ${{ github.sha }}", "pull-requests: read"):
            self.assertIn(expected, build)
        self.assertIn("needs: [preflight, next-build-number, desktop-linux, finalize]", workflow)
        self.assertIn("needs: [preflight, next-build-number, ios, android, bridge]", workflow)
        self.assertIn("vars.DESKTOP_MACOS_PUBLICATION_ENABLED == 'true'", workflow)
        self.assertNotIn("desktop-linux-release.yml", (WORKFLOWS / "submit-release.yml").read_text())
        producer = (WORKFLOWS / "desktop-qualification.yml").read_text()
        self.assertIn("inputs.mode == 'linux-packaging' && 'linux' || 'other'", producer)
        linux = producer.split("  linux-distribution:\n", 1)[1].split("  tooling:\n", 1)[0]
        for expected in ("ref: ${{ inputs.source_sha || github.sha }}", "git merge-base --is-ancestor HEAD origin/main",
                         "${{ inputs.build_number || github.run_number }}", "build/desktop-bundle/dart-defines.env",
                         "'/.ci-workflow/'", ".ci-workflow/.github/scripts:/scripts:ro"):
            self.assertIn(expected, linux)
        self.assertIn("python .github/scripts/qualify_desktop.py bootstrap", linux)  # Product's SDK pin.
        self.assertIn("python .github/scripts/package_desktop_linux.py package", linux)  # Product's icon/plugins.

    def test_publisher_is_main_only_and_never_needs_signing_or_store_credentials(self):
        workflow = (WORKFLOWS / "desktop-linux-release.yml").read_text()
        self.assertIn('"$GITHUB_REF" == refs/heads/main', workflow)
        self.assertIn("pattern: desktop-linux-*", workflow)
        self.assertIn("run-id: ${{ inputs.packaging_run }}", workflow)
        for forbidden in ("secrets.", "environment:", "gh release create", "gh release edit", "store-production"):
            self.assertNotIn(forbidden, workflow)


@unittest.skipUnless(os.environ.get("SESORI_LINUX_SIGNING_TEST_REQUIRED") == "1"
                     or all(shutil.which(tool) for tool in ("gpg", "gpgv", "gpgconf")), "GnuPG required")
class PublicChecksumCryptoTest(unittest.TestCase):
    def test_real_signature_wrong_pin_and_tamper(self):
        # Short owned home avoids macOS agent socket limits in nested tool TMPDIRs.
        with tempfile.TemporaryDirectory(prefix="gpg-", dir="/tmp") as temporary:
            root = Path(temporary)
            home = root / "home"
            home.mkdir(mode=0o700)
            base = ["gpg", "--homedir", str(home), "--batch", "--pinentry-mode", "loopback", "--passphrase", ""]
            try:
                subprocess.run([*base, "--quick-generate-key", "Fixture <fixture@example.invalid>",
                                "ed25519", "cert", "1d"], check=True, capture_output=True)
                listing = subprocess.check_output([*base, "--with-colons", "--list-keys"], text=True)
                fingerprint = next(line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:"))
                subprocess.run([*base, "--quick-add-key", fingerprint, "ed25519", "sign", "1d"],
                               check=True, capture_output=True)
                (root / publisher.PUBLIC_KEY).write_bytes(subprocess.check_output([*base, "--armor", "--export"]))
                checksums = root / publisher.CHECKSUMS
                checksums.write_text("0" * 64 + "  inert-package.deb\n")
                subprocess.run([*base, "--armor", "--detach-sign", str(checksums)], check=True, capture_output=True)
                publisher.verify_checksums(packages=root, fingerprint=fingerprint)
                with self.assertRaisesRegex(ValueError, "Unexpected checksum signer"):
                    publisher.verify_checksums(packages=root, fingerprint=FINGERPRINT)
                checksums.write_text("tampered\n")
                with self.assertRaisesRegex(ValueError, "Public checksum signature verification failed") as caught:
                    publisher.verify_checksums(packages=root, fingerprint=fingerprint)
                self.assertIsInstance(caught.exception.__cause__, subprocess.CalledProcessError)
            finally:
                subprocess.run(["gpgconf", "--homedir", str(home), "--kill", "all"], check=True)


if __name__ == "__main__":
    unittest.main()
