import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from qualify_desktop_macos_upgrade import (
    load_candidate,
    normalized_lipo_architectures,
    require_fresh_native_runner,
    require_trusted_source,
    validate_installed_architectures,
    validate_upgrade,
)


WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"


class MacosUpgradeValidationTests(unittest.TestCase):
    def _fixture(
        self,
        *,
        root: Path,
        label: str,
        version: str,
        build_number: int,
        source_sha: str,
        architecture: str = "arm64",
        channel: str | None = None,
    ) -> dict:
        packages = root / label / "packages"
        evidence = root / label / "evidence"
        packaging = evidence / "desktop-macos-packaging"
        bundle = evidence / "desktop-bundle"
        packages.mkdir(parents=True)
        packaging.mkdir(parents=True)
        bundle.mkdir(parents=True)
        dmg_name = f"Sesori-macos-{architecture}.dmg"
        zip_name = f"Sesori-macos-{architecture}.zip"
        dmg = packages / dmg_name
        dmg.write_bytes(f"{label}-dmg".encode())
        (packages / zip_name).write_bytes(f"{label}-zip".encode())
        identity = {
            "version": version,
            "buildNumber": build_number,
            "sourceSha": source_sha,
            "os": "macos",
            "architecture": architecture,
        }
        (packaging / "desktop-bundle.json").write_text(json.dumps(identity))
        (packaging / "packaging.json").write_text(json.dumps({
            "packagerSourceSha": source_sha,
            "architecture": architecture,
            "artifacts": {
                dmg_name: hashlib.sha256(dmg.read_bytes()).hexdigest(),
                zip_name: hashlib.sha256((packages / zip_name).read_bytes()).hexdigest(),
            },
        }))
        for name in ("app", "dmg"):
            (packaging / f"{name}-notarization.json").write_text('{"status":"Accepted"}')
        (bundle / "build-source-changes.patch").write_bytes(b"")
        if channel is not None:
            (bundle / "dart-defines.env").write_text(
                "SESORI_DESKTOP_BUNDLE_IDENTITY=" + json.dumps(identity, separators=(",", ":")) + "\n"
                f"SESORI_DESKTOP_RELEASE_CHANNEL={channel}\n"
            )
        run_json = root / label / "run.json"
        run_json.write_text(json.dumps({
            "id": 100 if label == "previous" else 200,
            "repository": {"full_name": "sesori-ai/sesori_apps_monorepo"},
            "path": ".github/workflows/desktop-qualification.yml",
            "event": "workflow_dispatch",
            "conclusion": "success",
            "head_sha": source_sha,
        }))
        return {
            "label": label,
            "run_json": run_json,
            "packages": packages,
            "evidence": evidence,
            "architecture": architecture,
            "expected_channel": channel,
        }

    def test_accepts_strictly_newer_signed_package_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            previous = load_candidate(**self._fixture(
                root=root,
                label="previous",
                version="1.8.4",
                build_number=24,
                source_sha="a" * 40,
            ))
            current = load_candidate(**self._fixture(
                root=root,
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="stable",
            ))
            validate_upgrade(previous=previous, current=current)

    def test_rejects_same_or_older_release_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            previous = load_candidate(**self._fixture(
                root=root,
                label="previous",
                version="1.9.0",
                build_number=62,
                source_sha="a" * 40,
            ))
            current = load_candidate(**self._fixture(
                root=root,
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="stable",
            ))
            with self.assertRaisesRegex(ValueError, "strictly newer"):
                validate_upgrade(previous=previous, current=current)

    def test_rejects_tampered_dmg(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = self._fixture(
                root=root,
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="stable",
            )
            (fixture["packages"] / "Sesori-macos-arm64.dmg").write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "DMG digest differs"):
                load_candidate(**fixture)

    def test_rejects_wrong_compiled_channel(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = self._fixture(
                root=Path(directory),
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="internal",
            )
            fixture["expected_channel"] = "stable"
            with self.assertRaisesRegex(ValueError, "compiled channel differs"):
                load_candidate(**fixture)

    def test_rejects_dirty_producer_source(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = self._fixture(
                root=Path(directory),
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="stable",
            )
            (fixture["evidence"] / "desktop-bundle/build-source-changes.patch").write_text("diff")
            with self.assertRaisesRegex(ValueError, "source was not clean"):
                load_candidate(**fixture)

    def test_rejects_wrong_producer_workflow(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = self._fixture(
                root=Path(directory),
                label="current",
                version="1.9.0",
                build_number=62,
                source_sha="b" * 40,
                channel="stable",
            )
            run = json.loads(fixture["run_json"].read_text())
            run["path"] = ".github/workflows/untrusted.yml"
            fixture["run_json"].write_text(json.dumps(run))
            with self.assertRaisesRegex(ValueError, "wrong producer workflow"):
                load_candidate(**fixture)


class MacosUpgradeArchitectureTests(unittest.TestCase):
    def test_accepts_universal_gui_with_native_helper(self):
        validate_installed_architectures(
            label="previous",
            expected="arm64",
            gui_output="x86_64 arm64\n",
            helper_output="arm64\n",
        )
        self.assertEqual(normalized_lipo_architectures("x86_64 arm64\n"), {"x64", "arm64"})

    def test_rejects_wrong_helper_architecture(self):
        with self.assertRaisesRegex(ValueError, "helper architecture differs"):
            validate_installed_architectures(
                label="previous",
                expected="arm64",
                gui_output="x86_64 arm64",
                helper_output="x86_64",
            )

    def test_rejects_unknown_native_architecture(self):
        with self.assertRaisesRegex(ValueError, "unsupported architecture"):
            normalized_lipo_architectures("arm64 i386")


class MacosUpgradeSourceTrustTests(unittest.TestCase):
    def test_accepts_source_in_tooling_history(self):
        with patch("qualify_desktop_macos_upgrade.git_is_ancestor", return_value=True):
            self.assertEqual(
                require_trusted_source(source_sha="a" * 40, associated_pulls=[]),
                {"kind": "toolingAncestor"},
            )

    def test_accepts_source_from_merged_main_pull_request(self):
        merge_sha = "c" * 40
        associated_pulls = [{
            "number": 1503,
            "state": "closed",
            "merged_at": "2026-09-16T01:40:57Z",
            "merge_commit_sha": merge_sha,
            "base": {
                "ref": "main",
                "repo": {"full_name": "sesori-ai/sesori_apps_monorepo"},
            },
        }]
        with patch(
            "qualify_desktop_macos_upgrade.git_is_ancestor",
            side_effect=lambda *, source_sha: source_sha == merge_sha,
        ):
            self.assertEqual(
                require_trusted_source(source_sha="a" * 40, associated_pulls=associated_pulls),
                {
                    "kind": "mergedMainPullRequest",
                    "pullRequest": 1503,
                    "mergeCommitSha": merge_sha,
                },
            )

    def test_rejects_source_without_merged_main_acceptance(self):
        with patch("qualify_desktop_macos_upgrade.git_is_ancestor", return_value=False):
            with self.assertRaisesRegex(ValueError, "neither in trusted tooling history"):
                require_trusted_source(source_sha="a" * 40, associated_pulls=[])


class MacosUpgradeWorkflowTests(unittest.TestCase):
    def test_upgrade_job_is_credential_free_and_uses_selected_artifacts(self):
        workflow = WORKFLOW.read_text()
        job = workflow.split("  macos-upgrade:\n", 1)[1].split("\n  windows-distribution:", 1)[0]
        self.assertIn("      actions: read", job)
        self.assertIn("      pull-requests: read", job)
        self.assertIn('commits/$source/pulls', job)
        self.assertIn("--previous-pulls-json", job)
        self.assertIn("--current-pulls-json", job)
        self.assertIn("desktop-macos-packages-${{ matrix.arch }}", job)
        self.assertIn("desktop-macos-evidence-${{ matrix.arch }}", job)
        self.assertIn("qualify_desktop_macos_upgrade.py", job)
        self.assertNotIn("environment:", job)
        self.assertNotIn("secrets.", job)
        self.assertNotIn("contents: write", job)


class MacosUpgradeSafetyTests(unittest.TestCase):
    def test_local_host_refuses_before_process_or_file_checks(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), \
                patch("qualify_desktop_macos_upgrade.sys.platform", "darwin"), \
                patch("qualify_desktop_macos_upgrade.subprocess.check_output") as processes:
            with self.assertRaises(PermissionError):
                require_fresh_native_runner()
            processes.assert_not_called()

    def test_active_desktop_or_bridge_refuses(self):
        for command in (
            "123 /Applications/Sesori.app/Contents/MacOS/Sesori",
            "124 /Applications/Sesori.app/Contents/Helpers/bridge/bin/bridge",
            "125 /workspace/bridge/app/build/cli/bundle/bin/bridge",
        ):
            with self.subTest(command=command), \
                    patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), \
                    patch("qualify_desktop_macos_upgrade.sys.platform", "darwin"), \
                    patch("qualify_desktop_macos_upgrade.subprocess.check_output", return_value=command):
                with self.assertRaisesRegex(RuntimeError, "existing desktop/bridge"):
                    require_fresh_native_runner()

    def test_existing_shared_state_refuses_without_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shared = root / "shared"
            shared.mkdir()
            with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), \
                    patch("qualify_desktop_macos_upgrade.sys.platform", "darwin"), \
                    patch("qualify_desktop_macos_upgrade.subprocess.check_output", return_value=""), \
                    patch("qualify_desktop_macos_upgrade.APPLICATION", root / "app"), \
                    patch("qualify_desktop_macos_upgrade.REGISTRATION", root / "registration"), \
                    patch("qualify_desktop_macos_upgrade.SUPPORT_ROOT", root / "support"), \
                    patch("qualify_desktop_macos_upgrade.SHARED_DATA_ROOT", shared), \
                    patch("qualify_desktop_macos_upgrade.ATTACHMENTS_ROOT", root / "attachments"):
                with self.assertRaisesRegex(RuntimeError, "Existing shared Sesori data"):
                    require_fresh_native_runner()
            self.assertTrue(shared.is_dir())


if __name__ == "__main__":
    unittest.main()
