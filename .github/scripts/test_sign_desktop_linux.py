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

import linux_signing as keys
import sign_bridge_linux as bridge_signing
import sign_desktop_linux as signing

FINGERPRINT = "A" * 40
IDENTITY = {"os": "linux", "architecture": "x64", "version": "9.8.7", "buildNumber": 42, "sourceSha": "b" * 40}
WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"


def packages(*, root: Path, rpm: bytes = b"rpm fixture") -> None:
    for package_format, contents in (("deb", b"deb fixture"), ("rpm", rpm), ("appimage", b"AppImage fixture")):
        directory = root / package_format
        directory.mkdir(parents=True)
        path = directory / f"Sesori-linux-x64-9.8.7-42.{signing.PACKAGE_EXTENSIONS[package_format]}"
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
        self.secrets = {keys.KEY_SECRET: "fixture private key", keys.PASSPHRASE_SECRET: "fixture passphrase"}

    def test_package_bytes_and_matching_identity_required(self):
        identity, paths = signing.load_packages(root=self.root)
        self.assertEqual(identity, IDENTITY)
        self.assertEqual([path.name for path, _ in paths], [
            "Sesori-linux-x64-9.8.7-42.deb", "Sesori-linux-x64-9.8.7-42.rpm", "Sesori-linux-x64-9.8.7-42.AppImage"])
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
                    mock.patch.object(keys, "run") as command:
                with self.assertRaisesRegex(ValueError, message):
                    signing.sign_packages(root=self.root, output=self.output, fingerprint=fingerprint)
                command.assert_not_called()
        self.output.mkdir()
        with mock.patch.dict(os.environ, self.secrets), mock.patch.object(keys, "run") as command:
            with self.assertRaises(FileExistsError):
                signing.sign_packages(root=self.root, output=self.output, fingerprint=FINGERPRINT)
            command.assert_not_called()

    def test_fingerprints_exclude_subkeys(self):
        listing = f"sec:::::::::\nfpr:::::::::{FINGERPRINT}:\nssb:::::::::\nfpr:::::::::{'B' * 40}:\n"
        self.assertEqual(keys.primary_fingerprints(listing=listing), [FINGERPRINT])

    def test_digest_only_rpm_is_not_accepted_as_signed(self):
        with mock.patch.object(signing, "run", return_value="Header SHA256 digest: OK\nPayload SHA256 digest: OK"):
            with self.assertRaisesRegex(ValueError, "no verified OpenPGP signature"):
                signing.verify_rpm(package=Path("fixture.rpm"), public_key=Path("public.asc"),
                                   database=self.root / "rpmdb", env={})

    def test_secrets_never_reach_child_environment_or_arguments_and_cleanup_runs(self):
        observed = []

        def fake_run(*, command, env, input_text=None):
            observed.append(command)
            self.assertNotIn(keys.KEY_SECRET, env)
            self.assertNotIn(keys.PASSPHRASE_SECRET, env)
            for secret in self.secrets.values():
                self.assertNotIn(secret, " ".join(command))
            if "--import" in command:
                self.assertEqual(input_text, self.secrets[keys.KEY_SECRET])
                raise subprocess.CalledProcessError(2, command, stderr="private diagnostic")
            return ""

        output = io.StringIO()
        with mock.patch.dict(os.environ, self.secrets), mock.patch.object(keys, "run", side_effect=fake_run), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            with self.assertRaises(subprocess.CalledProcessError):
                signing.sign_packages(root=self.root, output=self.output, fingerprint=FINGERPRINT)
        self.assertEqual(observed[-1][0], "gpgconf")
        self.assertFalse(Path(observed[-1][2]).parent.exists())
        self.assertEqual(output.getvalue(), "")
        self.assertFalse((self.output / "signing.json").exists())

    def test_cleanup_failure_retains_primary_error_and_removes_key_home(self):
        observed = []

        def fake_run(*, command, **kwargs):
            observed.append(command)
            if command[0] == "gpgconf":
                raise subprocess.CalledProcessError(2, command)
            return ""

        with mock.patch.dict(os.environ, self.secrets), mock.patch.object(keys, "run", side_effect=fake_run):
            with self.assertRaises(subprocess.CalledProcessError) as caught:
                signing.sign_packages(root=self.root, output=self.output, fingerprint=FINGERPRINT)
        self.assertIsInstance(caught.exception.__context__, ValueError)
        self.assertIn("does not match", str(caught.exception.__context__))
        self.assertFalse(Path(observed[-1][2]).parent.exists())
        self.assertFalse((self.output / "signing.json").exists())

    def test_documented_failed_export_never_updates_github_or_leaves_secret_file(self):
        docs = (WORKFLOW.parents[2] / "docs/desktop/linux-signing.md").read_text()
        setup = docs.split("## 2.", 1)[1].split("```bash\n", 1)[1].split("```", 1)[0]
        tools, temporary = self.root / "bin", self.root / "temporary"
        tools.mkdir()
        temporary.mkdir()
        calls = self.root / "github-calls"
        for name, body in (("gpg", "printf 'partial fixture export'; exit 1"),
                           ("gh", f"touch '{calls}'")):
            command = tools / name
            command.write_text(f"#!/bin/sh\n{body}\n")
            command.chmod(0o700)
        env = {**os.environ, "PATH": f"{tools}:{os.defpath}", "TMPDIR": str(temporary),
               "KEY_HOME": str(self.root / "unused"), "KEY_FPR": FINGERPRINT}
        result = subprocess.run(["/bin/bash", "-c", setup], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(calls.exists())
        self.assertEqual(list(temporary.iterdir()), [])
        self.assertNotIn("partial fixture export", result.stdout + result.stderr)

    def test_workflow_is_main_only_secret_scoped_and_uploads_only_signed_outputs(self):
        workflow = WORKFLOW.read_text()
        dockerfile = (WORKFLOW.parents[1] / "scripts/Dockerfile.linux-signing").read_text()
        self.assertEqual(dockerfile.count("FROM registry.fedoraproject.org/fedora@sha256:"), 1)
        self.assertNotIn("registry.fedoraproject.org/fedora@sha256:", workflow)
        linux = workflow.split("  linux-distribution:\n", 1)[1].split("\n  tooling:", 1)[0]
        resolve = linux.split("      - name: Resolve the shared Fedora base from the signing Dockerfile\n", 1)[1]
        script = resolve.split("        run: |\n", 1)[1].split("      - name:", 1)[0]
        tools = self.root / ".ci-workflow/.github/scripts"
        tools.mkdir(parents=True)
        (tools / "Dockerfile.linux-signing").write_text(dockerfile)
        env_file = self.root / "github-env"
        subprocess.run(["/bin/bash", "-c", script], check=True, cwd=self.root,
                       env={"PATH": os.defpath, "GITHUB_ENV": str(env_file)})
        expected_image = next(line.split()[1] for line in dockerfile.splitlines() if line.startswith("FROM "))
        self.assertEqual(env_file.read_text(), f"FEDORA_IMAGE={expected_image}\n")
        self.assertIn("environment: linux-signing", linux)
        guard = '[[ "$GITHUB_REF" == refs/heads/main ]]'
        self.assertLess(linux.index(guard), linux.index("uses: actions/checkout@v6"))
        signing_step = linux.split("      - name: Sign and verify qualified Linux packages\n", 1)[1].split(
            "      - name:", 1)[0]
        self.assertIn("--network none", signing_step)
        for secret in (keys.KEY_SECRET, keys.PASSPHRASE_SECRET):
            self.assertEqual(workflow.count(f"secrets.{secret}"), 1)
            self.assertIn(f"secrets.{secret}", signing_step)
        self.assertNotIn("contents: write", linux)
        self.assertNotIn("gh release", linux)
        self.assertLess(linux.index("Build Linux signing tools without secrets"),
                        linux.index("Sign and verify qualified Linux packages"))
        upload = linux.split("      - name: Upload private signed packages\n", 1)[1].split("      - name:", 1)[0]
        self.assertIn("/signed/*.rpm", upload)
        self.assertIn("/signed/*.deb", upload)
        self.assertIn("/signed/*.AppImage", upload)
        self.assertNotIn("packaging/deb/*.deb", upload)
        self.assertNotIn("private", upload.split("          path:", 1)[1])


@unittest.skipUnless(os.environ.get("SESORI_LINUX_SIGNING_TEST_REQUIRED") == "1",
                     "real GPG/RPM fixture runs inside the pinned Fedora signing image in CI")
class LinuxSigningIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ("gpg", "gpgv", "gpgconf", "rpm", "rpmsign", "rpmkeys", "rpmbuild", "sha256sum", "dnf"):
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
        cls.fingerprint = keys.primary_fingerprints(listing=listing)[0]
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
        self.secrets = {keys.KEY_SECRET: self.secret, keys.PASSPHRASE_SECRET: self.passphrase}

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
            "Sesori-linux-x64-9.8.7-42.deb", "Sesori-linux-x64-9.8.7-42.rpm", "Sesori-linux-x64-9.8.7-42.AppImage",
            signing.PUBLIC_KEY, signing.CHECKSUMS, f"{signing.CHECKSUMS}.asc", "signing.json",
        })
        for artifact in report["artifacts"]:
            self.assertEqual(signing.sha256(path=self.output / artifact["name"]), artifact["sha256"])
            original = self.input / Path(artifact["name"]).suffix[1:].lower() / artifact["name"]
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

    def test_dnf_refuses_unsigned_and_installs_reinstalls_removes_signed_rpm(self):
        with mock.patch.dict(os.environ, self.secrets):
            signing.sign_packages(root=self.input, output=self.output, fingerprint=self.fingerprint)
        public_home = self.input / "public-verification"
        public_home.mkdir(mode=0o700)
        public_env = {**os.environ, "GNUPGHOME": str(public_home), "LC_ALL": "C"}
        try:
            signing.run(command=["gpg", "--batch", "--dearmor", "--output", str(public_home / "public.gpg"),
                                 str(self.output / signing.PUBLIC_KEY)], env=public_env)
            signing.run(command=["gpgv", "--keyring", str(public_home / "public.gpg"),
                                 str(self.output / f"{signing.CHECKSUMS}.asc"),
                                 str(self.output / signing.CHECKSUMS)], env=public_env)
            install_root = self.input / "install-root"
            install_root.mkdir()
            signing.run(command=["rpm", "--root", str(install_root), "--initdb"], env=public_env)
            signing.run(command=["rpmkeys", "--root", str(install_root), "--import",
                                 str(self.output / signing.PUBLIC_KEY)], env=public_env)
            # The fresh install root has no repository configuration. DNF5 rejects
            # --disable-repo=* when there are no matching repositories to disable.
            dnf = ["dnf", "--installroot", str(install_root), "--releasever=44",
                   "--setopt=localpkg_gpgcheck=True", "--assumeyes"]
            name = "Sesori-linux-x64-9.8.7-42.rpm"
            with self.assertRaises(subprocess.CalledProcessError) as unsigned:
                signing.run(command=[*dnf, "install", str(self.input / "rpm" / name)], env=public_env)
            self.assertRegex(unsigned.exception.stdout + unsigned.exception.stderr, r"(?i)not signed|signature")
            payload = install_root / "opt/sesori-desktop/fixture.txt"
            self.assertFalse(payload.exists())
            signing.run(command=[*dnf, "install", str(self.output / name)], env=public_env)
            self.assertEqual(payload.read_text(), "fixture payload")
            signing.run(command=[*dnf, "reinstall", str(self.output / name)], env=public_env)
            self.assertEqual(payload.read_text(), "fixture payload")
            signing.run(command=[*dnf, "remove", "sesori-desktop"], env=public_env)
            self.assertFalse(payload.exists())
        except subprocess.CalledProcessError as error:
            self.fail(f"Disposable-key package-manager fixture failed: {error.stdout}\n{error.stderr}")

    def test_cli_archives_keep_their_bytes_and_verify_with_public_material_only(self):
        archives = self.input / "archives"
        archives.mkdir()
        for name in bridge_signing.ARCHIVES:
            (archives / name).write_bytes(b"inert archive fixture: " + name.encode())
        before = {p.name: p.read_bytes() for p in archives.iterdir()}
        with mock.patch.dict(os.environ, self.secrets):
            report = bridge_signing.sign_archives(root=archives, output=self.output, fingerprint=self.fingerprint)
        self.assertEqual(report["signerFingerprint"], self.fingerprint)
        public_home = self.input / "public-only-cli"
        public_home.mkdir(mode=0o700)
        public_env = {**os.environ, "GNUPGHOME": str(public_home), "LC_ALL": "C"}
        keyring = public_home / "public.gpg"
        keys.run(command=["gpg", "--batch", "--dearmor", "--output", str(keyring),
                          str(self.output / keys.PUBLIC_KEY)], env=public_env)
        self.assertEqual({p.name for p in self.output.iterdir()},
                         {keys.PUBLIC_KEY, "signing.json", *(name + ".asc" for name in bridge_signing.ARCHIVES)})
        # Execute the documented public verification without the user's real key or keyring.
        docs = (WORKFLOW.parents[2] / "docs/desktop/linux-signing.md").read_text()
        verify_script = docs.split("## 6.", 1)[1].split("```bash\n", 1)[1].split("```", 1)[0]
        verify_script = verify_script.replace("E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7", self.fingerprint)
        name = "sesori-bridge-linux-x64.tar.gz"
        shutil.copy2(archives / name, self.output / name)
        verified = subprocess.run(["/bin/bash", "-c", verify_script], cwd=self.output, capture_output=True, text=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        refused = subprocess.run(["/bin/bash", "-c", verify_script.replace(self.fingerprint, FINGERPRINT)],
                                 cwd=self.output, capture_output=True, text=True)
        self.assertNotEqual(refused.returncode, 0)
        for artifact in report["artifacts"]:
            source = archives / artifact["name"]
            signature = self.output / artifact["signature"]
            self.assertEqual(source.read_bytes(), before[source.name])
            self.assertEqual(keys.sha256(path=source), artifact["sha256"])
            verify = ["gpgv", "--keyring", str(keyring), str(signature), str(source)]
            keys.run(command=verify, env=public_env)
            source.write_bytes(b"tampered")
            with self.assertRaises(subprocess.CalledProcessError):
                keys.run(command=verify, env=public_env)
            source.write_bytes(before[source.name])
            signature.write_text("invalid fixture signature")
            with self.assertRaises(subprocess.CalledProcessError):
                keys.run(command=verify, env=public_env)
        with mock.patch.dict(os.environ, {**self.secrets, keys.PASSPHRASE_SECRET: "wrong"}):
            with self.assertRaises(subprocess.CalledProcessError):
                bridge_signing.sign_archives(root=archives, output=self.input / "bad-cli-passphrase",
                                             fingerprint=self.fingerprint)
        self.assertFalse((self.input / "bad-cli-passphrase/signing.json").exists())

    def test_wrong_key_and_wrong_passphrase_never_complete(self):
        with mock.patch.dict(os.environ, self.secrets):
            with self.assertRaisesRegex(ValueError, "does not match"):
                signing.sign_packages(root=self.input, output=self.output, fingerprint=FINGERPRINT)
        self.assertFalse((self.output / "signing.json").exists())
        with mock.patch.dict(os.environ, {**self.secrets, keys.PASSPHRASE_SECRET: "wrong"}):
            with self.assertRaises(subprocess.CalledProcessError):
                signing.sign_packages(root=self.input, output=self.input / "bad-passphrase",
                                      fingerprint=self.fingerprint)
        self.assertFalse((self.input / "bad-passphrase/signing.json").exists())


if __name__ == "__main__":
    unittest.main()
