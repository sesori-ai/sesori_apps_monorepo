"""Exercise the release gate against local Git fixtures; never contact the stores."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / ".github/scripts/check_internal_release.sh"
ATTEMPT_REF = "refs/tags/internal-release-attempt"


class InternalReleaseGateTest(unittest.TestCase):
    def setUp(self) -> None:
        # Keep all fixtures inside the caller's checkout, not another worktree.
        fixture = tempfile.TemporaryDirectory(prefix=".release-gate-test-", dir=ROOT)
        self.addCleanup(fixture.cleanup)
        self.fixture = Path(fixture.name)
        self.repo = self.fixture / "repo"
        self.origin = self.fixture / "origin.git"
        self.output = self.fixture / "output"
        self.summary = self.fixture / "summary"
        self.repo.mkdir()
        self.git(args=["init", "--bare", str(self.origin)])
        self.git(args=["init", "--initial-branch=main"])
        self.git(args=["config", "user.name", "Release Gate Test"])
        self.git(args=["config", "user.email", "release-gate@example.invalid"])
        self.git(args=["config", "commit.gpgsign", "false"])
        self.git(args=["config", "tag.gpgsign", "false"])
        self.git(args=["remote", "add", "origin", str(self.origin)])
        self.commit(path="client/app/lib/app.dart")

    def git(self, *, args: list[str]) -> str:
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True, text=True, capture_output=True
        ).stdout.strip()

    def commit(self, *, path: str) -> str:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a") as file:
            file.write("change\n")
        self.git(args=["add", path])
        self.git(args=["commit", "-m", f"Change {path}"])
        return self.git(args=["rev-parse", "HEAD"])

    def tag(self, *, name: str, annotated: bool = False) -> None:
        args = ["tag", "-a", name, "-m", name] if annotated else ["tag", name]
        self.git(args=args)
        self.git(args=["push", "origin", f"refs/tags/{name}"])

    def attempt_sha(self) -> str:
        return self.git(
            args=["--git-dir", str(self.origin), "for-each-ref", "--format=%(objectname)", ATTEMPT_REF]
        )

    def run_gate(
        self, *, event: str = "schedule", ref: str = "refs/heads/main", succeeds: bool = True
    ) -> tuple[str, str]:
        # Model checkout@v6 fetch-depth: 0, refreshing the moving remote tag.
        self.git(args=["fetch", "origin", "+refs/tags/*:refs/tags/*"])
        self.output.write_text("")
        self.summary.write_text("")
        result = subprocess.run(
            ["bash", str(GATE)],
            cwd=self.repo,
            env={
                **os.environ,
                "GITHUB_EVENT_NAME": event,
                "GITHUB_REF": ref,
                "GITHUB_SHA": self.git(args=["rev-parse", "HEAD"]),
                "GITHUB_OUTPUT": str(self.output),
                "GITHUB_STEP_SUMMARY": str(self.summary),
            },
            text=True,
            capture_output=True,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return self.output.read_text(), self.summary.read_text()

    def test_first_run_without_release_history_builds_and_records_attempt(self) -> None:
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=true\n")
        self.assertEqual(self.attempt_sha(), self.git(args=["rev-parse", "HEAD"]))
        self.assertEqual(self.git(args=["tag", "--list", "v*"]), "")

    def test_failed_or_cancelled_attempt_is_not_retried(self) -> None:
        self.run_gate()
        # No success tag: simulate a version/store/build failure or cancellation.
        output, summary = self.run_gate()
        self.assertEqual(output, "should_release=false\n")
        self.assertIn("already attempted", summary)
        self.assertIn("Run workflow", summary)

    def test_annotated_internal_release_on_head_is_skipped(self) -> None:
        self.tag(name="v1.2.3-internal.42", annotated=True)
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=false\n")
        self.assertEqual(self.attempt_sha(), "")

    def test_stable_release_on_head_is_skipped(self) -> None:
        self.tag(name="v1.2.3")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=false\n")

    def test_unrelated_tag_does_not_block_a_build(self) -> None:
        self.tag(name="docs-checkpoint")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=true\n")

    def test_new_product_commit_after_failure_builds_and_moves_marker(self) -> None:
        self.run_gate()
        sha = self.commit(path="client/module_core/lib/core.dart")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=true\n")
        self.assertEqual(self.attempt_sha(), sha)

    def test_product_change_before_a_docs_only_tip_is_not_lost(self) -> None:
        self.run_gate()
        self.commit(path="shared/sesori_shared/lib/model.dart")
        sha = self.commit(path="docs/notes.md")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=true\n")
        self.assertEqual(self.attempt_sha(), sha)

    def test_irrelevant_changes_after_failure_do_not_retry_or_move_marker(self) -> None:
        self.run_gate()
        attempted = self.attempt_sha()
        for path in [
            "docs/notes.md",
            "client/desktop/lib/app.dart",
            "client/module_desktop_core/lib/core.dart",
            ".github/workflows/desktop-ci.yml",
        ]:
            with self.subTest(path=path):
                self.commit(path=path)
                output, _ = self.run_gate()
                self.assertEqual(output, "should_release=false\n")
                self.assertEqual(self.attempt_sha(), attempted)

    def test_bootstrap_from_release_skips_unrelated_changes(self) -> None:
        self.tag(name="v1.2.3-internal.42", annotated=True)
        self.commit(path="docs/notes.md")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=false\n")
        self.assertEqual(self.attempt_sha(), "")

    def test_bootstrap_from_release_builds_product_changes(self) -> None:
        self.tag(name="v1.2.3")
        self.commit(path="bridge/app/lib/bridge.dart")
        output, _ = self.run_gate()
        self.assertEqual(output, "should_release=true\n")

    def test_release_automation_fixes_allow_another_attempt(self) -> None:
        self.run_gate()
        for path in [
            ".github/workflows/release-all-platforms.yml",
            ".github/workflows/_reusable-ios-testflight.yml",
            ".github/scripts/check_internal_release.sh",
            ".tool-versions",
            "tool/generate_release_notes.dart",
        ]:
            with self.subTest(path=path):
                sha = self.commit(path=path)
                output, _ = self.run_gate()
                self.assertEqual(output, "should_release=true\n")
                self.assertEqual(self.attempt_sha(), sha)

    def test_manual_run_retries_an_attempted_commit(self) -> None:
        self.run_gate()
        output, _ = self.run_gate(event="workflow_dispatch")
        self.assertEqual(output, "should_release=true\n")

    def test_manual_run_can_rebuild_a_tagged_commit(self) -> None:
        self.tag(name="v1.2.3-internal.42", annotated=True)
        output, _ = self.run_gate(event="workflow_dispatch")
        self.assertEqual(output, "should_release=true\n")

    def test_manual_branch_run_does_not_change_main_checkpoint(self) -> None:
        self.run_gate()
        main_attempt = self.attempt_sha()
        self.commit(path="client/app/lib/app.dart")
        output, _ = self.run_gate(event="workflow_dispatch", ref="refs/heads/feature")
        self.assertEqual(output, "should_release=true\n")
        self.assertEqual(self.attempt_sha(), main_attempt)

    def test_marker_push_failure_prevents_building(self) -> None:
        self.git(args=["remote", "set-url", "--push", "origin", str(self.fixture / "missing.git")])
        output, _ = self.run_gate(succeeds=False)
        self.assertNotIn("should_release=true", output)
        self.assertEqual(self.attempt_sha(), "")


if __name__ == "__main__":
    unittest.main()
