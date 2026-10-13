"""Offline contracts plus a disposable-key RPM/GPG integration fixture (never production keys)."""

import contextlib
import io
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sign_desktop_linux as signing

FINGERPRINT = "A" * 40
IDENTITY = {"os": "linux", "architecture": "x64", "version": "9.8.7", "buildNumber": 42, "sourceSha": "b" * 40}
WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"


def packages(*, root: Path, rpm: bytes = b"rpm fixture") -> None:
    for package_format, contents in (("deb", b"deb fixture"), ("rpm", rpm)):
        directory = root / package_format
        directory.mkdir(parents=True)
        path = directory / f"Sesori-linux-x64-9.8.7-42.{package_format}"
        path.write_bytes(contents)
        (directory / "packaging.json").write_text(json.dumps({
            "format": package_format, "bundle": {"identity": IDENTITY},
            "package": {"name": path.name, "sha256": signing.sha256(path=path), "bytes": len(contents)},
        }))


class LinuxSigningTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        packages(root=self.root)
        self.output = self.root / "signed"
        self.secrets = {signing.KEY_SECRET: "fixture private key", signing.PASSPHRASE_SECRET: "fixture passphrase"}

    def test_package_bytes_and_matching_identity_required(self):
        identity, paths = signing.load_packages(root=self.root)
        self.assertEqual(identity, IDENTITY)
        self.assertEqual(len(paths), 2)
        paths[0][0].write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "differs from qualified evidence"):
            signing.load_packages(root=self.root)

    def test_mixed_identity_or_path_refused(self):
        report_path = self.root / "rpm/packaging.json"
        original = json.loads(report_path.read_text())
        for changed, message in (({**original, "bundle": {"identity": {**IDENTITY, "buildNumber": 43}}},
                                  "identical bundle identity"),
                                 ({**original, "package": {**original["package"], "name": "../outside.rpm"}},
                                  "filename")):
            with self.subTest(message=message):
                report_path.write_text(json.dumps(changed))
                with self.assertRaisesRegex(ValueError, message):
                    signing.load_packages(root=self.root)

    def test_secret_configuration_and_existing_output_refuse_before_tools(self):
        cases = [({}, FINGERPRINT, "both protected"), (self.secrets, "short", "full primary")]
        for secrets, fingerprint, message in cases:
            with self.subTest(message=message), mock.patch.dict(os.environ, secrets, clear=True), \
                    mock.patch.object(signing, "run") as command:
                with self.assertRaisesRegex(ValueError, message):
                    signing.sign_packages(root=self.root, output=self.output, fingerprint=fingerprint)
                command.assert_not_called()
        self.output.mkdir()
        with mock.patch.dict(os.environ, self.secrets), mock.patch.object(signing, "run") as command:
            with self.assertRaises(FileExistsError):
                signing.sign_packages(root=self.root, output=self.output, fingerprint=FINGERPRINT)
            command.assert_not_called()

    def test_fingerprints_exclude_subkeys(self):
        listing = f"sec:::::::::\nfpr:::::::::{FINGERPRINT}:\nssb:::::::::\nfpr:::::::::{'B' * 40}:\n"
        self.assertEqual(signing.primary_fingerprints(listing=listing), [FINGERPRINT])

    def test_digest_only_rpm_is_not_accepted_as_signed(self):
        with mock.patch.object(signing, "run", return_value="Header SHA256 digest: OK\nPayload SHA256 digest: OK"):
            with self.assertRaisesRegex(ValueError, "no verified OpenPGP signature"):
                signing.verify_rpm(package=Path("fixture.rpm"), public_key=Path("public.asc"),
                                   database=self.root / "rpmdb", env={})

    def test_secrets_never_reach_child_environment_or_arguments_and_cleanup_runs(self):
        observed = []

        def fake_run(*, command, env, input_text=None):
            observed.append(command)
            self.assertNotIn(signing.KEY_SECRET, env)
            self.assertNotIn(signing.PASSPHRASE_SECRET, env)
            for secret in self.secrets.values():
                self.assertNotIn(secret, " ".join(command))
            if "--import" in command:
                self.assertEqual(input_text, self.secrets[signing.KEY_SECRET])
                raise subprocess.CalledProcessError(2, command, stderr="private diagnostic")
            return ""

        output = io.StringIO()
        with mock.patch.dict(os.environ, self.secrets), mock.patch.object(signing, "run", side_effect=fake_run), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            with self.assertRaises(subprocess.CalledProcessError):
                signing.sign_packages(root=self.root, output=self.output, fingerprint=FINGERPRINT)
        self.assertEqual(observed[-1][0], "gpgconf")
        self.assertFalse(Path(observed[-1][2]).parent.exists())
        self.assertEqual(output.getvalue(), "")
        self.assertFalse((self.output / "signing.json").exists())

    def test_workflow_is_main_only_secret_scoped_and_uploads_only_signed_outputs(self):
        workflow = WORKFLOW.read_text()
        linux = workflow.split("  linux-distribution:\n", 1)[1].split("\n  tooling:", 1)[0]
        self.assertIn("environment: linux-signing", linux)
        guard = '[[ "$GITHUB_REF" == refs/heads/main ]]'
        self.assertLess(linux.index(guard), linux.index("uses: actions/checkout@v6"))
        signing_step = linux.split("      - name: Sign and verify qualified Linux packages\n", 1)[1].split(
            "      - name:", 1)[0]
        self.assertIn("--network none", signing_step)
        for secret in (signing.KEY_SECRET, signing.PASSPHRASE_SECRET):
            self.assertEqual(workflow.count(f"secrets.{secret}"), 1)
            self.assertIn(f"secrets.{secret}", signing_step)
        self.assertNotIn("contents: write", linux)
        self.assertNotIn("gh release", linux)
        self.assertLess(linux.index("Build Linux signing tools without secrets"),
                        linux.index("Sign and verify qualified Linux packages"))
        upload = linux.split("      - name: Upload private signed packages\n", 1)[1].split("      - name:", 1)[0]
        self.assertIn("/signed/*.rpm", upload)
        self.assertIn("/signed/*.deb", upload)
        self.assertNotIn("packaging/deb/*.deb", upload)
        self.assertNotIn("private", upload.split("          path:", 1)[1])


@unittest.skipUnless(os.environ.get("SESORI_LINUX_SIGNING_TEST_REQUIRED") == "1",
                     "real GPG/RPM fixture runs inside the pinned Fedora signing image in CI")
class LinuxSigningIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ("gpg", "gpgconf", "rpm", "rpmsign", "rpmkeys", "rpmbuild", "sha256sum"):
            if shutil.which(tool) is None:
                raise RuntimeError(f"Required signing integration tool missing: {tool}")
        cls.temporary = tempfile.TemporaryDirectory(prefix="sesori-signing-fixture-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.home = cls.root / "fixture-key"
        cls.home.mkdir(mode=0o700)
        cls.env = {**os.environ, "GNUPGHOME": str(cls.home), "LC_ALL": "C"}
        cls.addClassCleanup(lambda: signing.run(
            command=["gpgconf", "--homedir", str(cls.home), "--kill", "all"], env=cls.env))
        cls.passphrase = "disposable CI fixture passphrase"
        signing.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                             "--quick-generate-key", "Sesori signing fixture <fixture@example.invalid>",
                             "rsa2048", "cert", "1d"], env=cls.env, input_text=cls.passphrase)
        listing = signing.run(command=["gpg", "--batch", "--with-colons", "--list-secret-keys"], env=cls.env)
        cls.fingerprint = signing.primary_fingerprints(listing=listing)[0]
        signing.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                             "--quick-add-key", cls.fingerprint, "rsa2048", "sign", "1d"],
                    env=cls.env, input_text=cls.passphrase)
        cls.secret = signing.run(
            command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0", "--armor",
                     "--export-secret-subkeys", cls.fingerprint], env=cls.env, input_text=cls.passphrase)
        spec = cls.root / "fixture.spec"
        spec.write_text("Name: sesori-desktop\nVersion: 9.8.7\nRelease: 42\nSummary: Signing fixture\n"
                        "License: MIT\nBuildArch: x86_64\n%description\nDisposable signing fixture\n"
                        "%install\nmkdir -p %{buildroot}/opt/sesori-desktop\n"
                        "printf 'fixture payload' > %{buildroot}/opt/sesori-desktop/fixture.txt\n"
                        "%files\n/opt/sesori-desktop\n")
        signing.run(command=["rpmbuild", "-bb", "--define", f"_topdir {cls.root / 'rpmbuild'}", str(spec)], env=cls.env)
        cls.rpm = next((cls.root / "rpmbuild/RPMS").rglob("*.rpm")).read_bytes()

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(temporary.cleanup)
        self.input = Path(temporary.name)
        packages(root=self.input, rpm=self.rpm)
        self.output = self.input / "signed"
        self.secrets = {signing.KEY_SECRET: self.secret, signing.PASSPHRASE_SECRET: self.passphrase}

    def test_real_subkey_signatures_public_verification_and_tamper_refusal(self):
        with mock.patch.dict(os.environ, self.secrets):
            try:
                report = signing.sign_packages(root=self.input, output=self.output, fingerprint=self.fingerprint)
            except subprocess.CalledProcessError as error:
                # Only this disposable-key fixture may show tool diagnostics; the
                # production signer deliberately does not print captured output.
                self.fail(f"Disposable-key signing failed: {error.stderr}")
        self.assertEqual(report["identity"], IDENTITY)
        self.assertEqual(report["signerFingerprint"], self.fingerprint)
        self.assertEqual({p.name for p in self.output.iterdir()}, {
            "Sesori-linux-x64-9.8.7-42.deb", "Sesori-linux-x64-9.8.7-42.rpm",
            signing.PUBLIC_KEY, signing.CHECKSUMS, f"{signing.CHECKSUMS}.asc", "signing.json",
        })
        for artifact in report["artifacts"]:
            self.assertEqual(signing.sha256(path=self.output / artifact["name"]), artifact["sha256"])
            original = self.input / Path(artifact["name"]).suffix[1:] / artifact["name"]
            self.assertEqual(signing.sha256(path=original), artifact["unsignedSha256"])
        deb = self.output / "Sesori-linux-x64-9.8.7-42.deb"
        self.assertEqual(deb.read_bytes(), b"deb fixture")
        check = ["sha256sum", "--check", signing.CHECKSUMS]
        subprocess.run(check, cwd=self.output, capture_output=True, check=True)
        deb.write_bytes(b"tampered")
        self.assertNotEqual(subprocess.run(check, cwd=self.output, capture_output=True).returncode, 0)
        checksums = self.output / signing.CHECKSUMS
        checksums.write_text(checksums.read_text() + "tampered\n")
        with self.assertRaises(subprocess.CalledProcessError):
            signing.run(command=["gpg", "--batch", "--verify", str(checksums) + ".asc", str(checksums)], env=self.env)
        rpm = self.output / "Sesori-linux-x64-9.8.7-42.rpm"
        data = bytearray(rpm.read_bytes())
        data[-1] ^= 1
        rpm.write_bytes(data)
        with self.assertRaises(subprocess.CalledProcessError):
            signing.verify_rpm(package=rpm, public_key=self.output / signing.PUBLIC_KEY,
                               database=self.input / "verify-rpmdb", env=self.env)

    def test_wrong_key_and_wrong_passphrase_never_complete(self):
        with mock.patch.dict(os.environ, self.secrets):
            with self.assertRaisesRegex(ValueError, "does not match"):
                signing.sign_packages(root=self.input, output=self.output, fingerprint=FINGERPRINT)
        self.assertFalse((self.output / "signing.json").exists())
        with mock.patch.dict(os.environ, {**self.secrets, signing.PASSPHRASE_SECRET: "wrong"}):
            with self.assertRaises(subprocess.CalledProcessError):
                signing.sign_packages(root=self.input, output=self.input / "bad-passphrase",
                                      fingerprint=self.fingerprint)
        self.assertFalse((self.input / "bad-passphrase/signing.json").exists())


if __name__ == "__main__":
    unittest.main()
