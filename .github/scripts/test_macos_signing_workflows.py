"""Bounded source contracts; live environment policy and signing need native probes."""
from pathlib import Path
import unittest

WORKFLOWS = Path(__file__).resolve().parents[1] / "workflows"


class MacosSigningWorkflowTest(unittest.TestCase):
    def test_signing_consumers_use_environment_not_caller_credentials(self):
        bridge = (WORKFLOWS / "_reusable-bridge-build.yml").read_text()
        desktop = (WORKFLOWS / "desktop-qualification.yml").read_text()
        self.assertIn("    environment: macos-signing\n", bridge)
        self.assertIn("    environment: macos-signing\n", desktop)
        self.assertNotIn("    secrets:\n", bridge.split("jobs:", 1)[0])
        for name in ("release-all-platforms.yml", "submit-release.yml", "verify-macos-signing.yml"):
            with self.subTest(workflow=name):
                self.assertNotIn("secrets.MACOS_", (WORKFLOWS / name).read_text())

    def test_main_guards_precede_mobile_or_release_jobs(self):
        release_all = (WORKFLOWS / "release-all-platforms.yml").read_text()
        submit = (WORKFLOWS / "submit-release.yml").read_text()
        guard = "if [[ \"$GITHUB_REF\" != 'refs/heads/main' ]]"
        self.assertLess(release_all.index(guard), release_all.index("  next-build-number:"))
        self.assertLess(submit.index(guard), submit.index("  submit-ios:"))

    def test_private_probe_has_no_release_or_mobile_upload_capability(self):
        probe = (WORKFLOWS / "verify-macos-signing.yml").read_text()
        self.assertIn("if: github.ref == 'refs/heads/main'", probe)
        self.assertIn("uses: ./.github/workflows/_reusable-bridge-build.yml", probe)
        self.assertIn("  contents: read", probe)
        for forbidden in ("contents: write", "secrets:", "_reusable-ios", "_reusable-android", "gh release"):
            self.assertNotIn(forbidden, probe)

    def test_bootstrap_is_retired(self):
        self.assertFalse((WORKFLOWS / "migrate-macos-signing-secrets.yml").exists())


if __name__ == "__main__":
    unittest.main()
