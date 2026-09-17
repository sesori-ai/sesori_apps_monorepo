"""Bounded source contracts; live environment policy and signing need native probes."""
import re
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
                call = caller.split("uses: ./.github/workflows/_reusable-bridge-build.yml", 1)[1]
                next_job = re.search(r"\n  [A-Za-z0-9_-]+:", call)
                if next_job is not None:
                    call = call[:next_job.start()]
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

    def test_bootstrap_is_retired(self):
        self.assertFalse((WORKFLOWS / "migrate-macos-signing-secrets.yml").exists())


if __name__ == "__main__":
    unittest.main()
