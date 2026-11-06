"""Source contracts: production promotion always replaces internal commit-message notes."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "submit-release.yml"
ANDROID_FASTFILE = ROOT / "client" / "app" / "android" / "fastlane" / "Fastfile"


class StoreReleaseNotesTest(unittest.TestCase):
    def test_android_release_notes_path_ignores_the_listing_publish_gate(self):
        android_job = WORKFLOW.read_text().split("\n  submit-android:\n", 1)[1].split("\n  submit-", 1)[0]
        line = next(l for l in android_job.splitlines() if l.strip().startswith("ANDROID_RELEASE_NOTES_PATH:"))
        self.assertIn("steps.cometa.outcome == 'success'", line)
        self.assertNotIn("steps.gate", line)
        self.assertIn("/store-metadata/android", line)

    def test_android_promotion_uploads_changelogs_whenever_release_notes_exist(self):
        lane = ANDROID_FASTFILE.read_text().split("lane :submit_android", 1)[1]
        self.assertIn('metadata_dir || metadata_dir_from_env("ANDROID_RELEASE_NOTES_PATH")', lane)
        self.assertIn("skip_upload_changelogs: release_notes_dir.nil?", lane)
        self.assertIn("skip_upload_metadata: !have_meta", lane)
        self.assertIn("play_opts[:metadata_path] = release_notes_dir if release_notes_dir", lane)


if __name__ == "__main__":
    unittest.main()
