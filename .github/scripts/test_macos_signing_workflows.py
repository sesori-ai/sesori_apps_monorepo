"""Bounded source contracts; live environment policy and signing need native probes."""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[1] / "workflows"


class MacosSigningWorkflowTest(unittest.TestCase):
    def test_signing_consumers_use_environment_not_caller_credentials(self):
        bridge = (WORKFLOWS / "_reusable-bridge-build.yml").read_text()
        desktop = (WORKFLOWS / "desktop-qualification.yml").read_text()
        self.assertIn("    environment: macos-signing\n", bridge)
        self.assertIn("    environment: macos-signing\n", desktop)
        header = bridge.split("jobs:", 1)[0]
        secret_block = header.split("    secrets:\n", 1)[1]
        expected_secrets = {
            "MACOS_CERT_P12_BASE64", "MACOS_CERT_PASSWORD", "MACOS_KEYCHAIN_PASSWORD",
        }
        declared_secrets = {
            line.strip().removesuffix(":")
            for line in secret_block.splitlines()
            if line.startswith("      ") and not line.startswith("        ")
        }
        self.assertEqual(declared_secrets, expected_secrets)
        self.assertNotIn("required: true", secret_block)
        for secret in expected_secrets:
            with self.subTest(declaration=secret):
                self.assertIn(f"      {secret}:\n        required: false", secret_block)
        for name in ("release-all-platforms.yml", "submit-release.yml", "verify-macos-signing.yml"):
            with self.subTest(workflow=name):
                caller = (WORKFLOWS / name).read_text()
                calls = caller.split("uses: ./.github/workflows/_reusable-bridge-build.yml")[1:]
                self.assertGreater(len(calls), 0)
                for index, call in enumerate(calls, start=1):
                    next_job = re.search(r"\n  [A-Za-z0-9_-]+:", call)
                    if next_job is not None:
                        call = call[:next_job.start()]
                    with self.subTest(workflow=name, call=index):
                        self.assertIn("\n    secrets: inherit\n", call)
                self.assertNotIn("secrets.MACOS_", caller)

    def test_main_guards_precede_mobile_or_release_jobs(self):
        release_all = (WORKFLOWS / "release-all-platforms.yml").read_text()
        submit = (WORKFLOWS / "submit-release.yml").read_text()
        guard = "if [[ \"$GITHUB_REF\" != 'refs/heads/main' ]]"
        self.assertLess(release_all.index(guard), release_all.index("  next-build-number:"))
        self.assertLess(submit.index(guard), submit.index("  submit-ios:"))

    def test_private_probe_has_no_release_or_mobile_upload_capability(self):
        probe = (WORKFLOWS / "verify-macos-signing.yml").read_text()
        guard = "if [[ \"$GITHUB_REF\" != 'refs/heads/main' ]]"
        self.assertLess(probe.index(guard), probe.index("uses: actions/checkout@v6"))
        self.assertIn("uses: ./.github/workflows/_reusable-bridge-build.yml", probe)
        self.assertEqual(probe.count("secrets: inherit"), 1)
        self.assertIn("  contents: read", probe)
        for forbidden in ("contents: write", "secrets.MACOS_", "_reusable-ios", "_reusable-android", "gh release"):
            self.assertNotIn(forbidden, probe)

    def test_qa_helper_signing_needs_no_notary_or_qa_credentials(self):
        script = WORKFLOWS.parent / "scripts/macos_signing_ci.sh"
        stub = '''
import base64, json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps({"name": name, "args": args, "signingSecretsPresent": any(
        name in os.environ for name in ("MACOS_CERT_P12_BASE64", "MACOS_CERT_PASSWORD", "MACOS_KEYCHAIN_PASSWORD")
    )}) + "\\n")
if name == "base64":
    pathlib.Path(args[args.index("-o") + 1]).write_bytes(base64.b64decode(sys.stdin.read()))
elif name == "security":
    if args[0] == "create-keychain": pathlib.Path(args[-1]).touch()
    if args[0] == "delete-keychain": pathlib.Path(args[-1]).unlink()
elif name == "xcrun":
    assert args[0] == "swiftc", "QA signing must not invoke notarization"
    pathlib.Path(args[args.index("-o") + 1]).write_bytes(b"fixture-helper")
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = root / "bin"
            binaries.mkdir()
            for command in ("security", "base64", "xcrun", "codesign"):
                path = binaries / command
                path.write_text(f"#!{sys.executable}\n" + stub)
                path.chmod(0o755)
            log = root / "commands.jsonl"
            result = subprocess.run(
                ["bash", str(script)], cwd=root, text=True, capture_output=True, timeout=15,
                env={
                    "PATH": f"{binaries}{os.pathsep}{os.defpath}",
                    "HOME": str(root),
                    "RUNNER_TEMP": str(root),
                    "COMMAND_LOG": str(log),
                    "MACOS_DISTRIBUTION_MODE": "macos-authenticated-upgrade-probe",
                    "MACOS_CERT_P12_BASE64": base64.b64encode(b"fixture-certificate").decode(),
                    "MACOS_CERT_PASSWORD": "fixture-certificate-password",
                    "MACOS_KEYCHAIN_PASSWORD": "fixture-keychain-password",
                    "APPLE_TEAM_ID": "FIXTURETEAM",
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            compiles = [call for call in commands if call["name"] == "xcrun"]
            self.assertEqual(len(compiles), 1)
            self.assertFalse(compiles[0]["signingSecretsPresent"])
            signatures = [call for call in commands if call["name"] == "codesign"]
            self.assertEqual(len(signatures), 2)
            self.assertIn("Developer ID Application: DigitalBlock Labs LTD (FIXTURETEAM)", signatures[0]["args"])
            self.assertIn("-R", signatures[1]["args"])
            requirement = '=anchor apple generic and certificate leaf[subject.OU] = "AQNCF7663C"'
            self.assertIn(requirement, signatures[1]["args"])
            # Exercise Apple's real parser without signing anything or accessing a private key.
            if sys.platform == "darwin":
                for source, expected_exit in (("=anchor apple", 0), (requirement, 3)):
                    native = subprocess.run(
                        ["/usr/bin/codesign", "--verify", "--strict", "-R", source, "/usr/bin/true"],
                        capture_output=True, text=True, timeout=15,
                    )
                    self.assertEqual(native.returncode, expected_exit, native.stderr)
            self.assertTrue((root / "build/desktop-macos-authenticated-upgrade/tools/keychain-writer").exists())
            self.assertFalse((root / "desktop-signing.keychain-db").exists())
            self.assertFalse((root / "desktop-signing.p12").exists())
            self.assertNotIn("fixture-certificate-password", result.stdout + result.stderr)
            self.assertNotIn("fixture-keychain-password", result.stdout + result.stderr)

    def test_bootstrap_is_retired(self):
        self.assertFalse((WORKFLOWS / "migrate-macos-signing-secrets.yml").exists())


if __name__ == "__main__":
    unittest.main()
