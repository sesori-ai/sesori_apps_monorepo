import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from qualify_desktop_macos_upgrade import (
    PINNED_RETAINED_BASELINES,
    load_candidate,
    normalized_lipo_architectures,
    require_fresh_native_runner,
    require_trusted_source,
    validate_installed_architectures,
    validate_upgrade,
)


WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"
QUITTER = Path(__file__).with_name("quit_desktop_macos.swift")


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

    def test_accepts_missing_channel_only_for_retained_baseline(self):
        with tempfile.TemporaryDirectory() as directory:
            baseline = PINNED_RETAINED_BASELINES[35042335424]
            fixture = self._fixture(
                root=Path(directory),
                label="previous",
                version="1.8.4",
                build_number=24,
                source_sha=baseline["sourceSha"],
            )
            selected_run = json.loads(fixture["run_json"].read_text())
            selected_run["id"] = 35042335424
            fixture["run_json"].write_text(json.dumps(selected_run))
            fixture["expected_channel"] = "stable"
            fixture["allow_missing_channel"] = True
            load_candidate(**fixture)

            unpinned = self._fixture(
                root=Path(directory),
                label="unpinned",
                version="1.8.4",
                build_number=24,
                source_sha="a" * 40,
            )
            unpinned["expected_channel"] = "stable"
            unpinned["allow_missing_channel"] = True
            with self.assertRaisesRegex(ValueError, "channel evidence is missing"):
                load_candidate(**unpinned)

    def test_rejects_notarization_or_identity_mismatch(self):
        for mismatch in ("notarization", "source", "compiled"):
            with self.subTest(mismatch=mismatch), tempfile.TemporaryDirectory() as directory:
                fixture = self._fixture(
                    root=Path(directory),
                    label="current",
                    version="1.9.0",
                    build_number=62,
                    source_sha="b" * 40,
                    channel="stable",
                )
                if mismatch == "notarization":
                    packaging = fixture["evidence"] / "desktop-macos-packaging"
                    (packaging / "app-notarization.json").write_text('{"status":"Rejected"}')
                    message = "app notarization was not accepted"
                elif mismatch == "source":
                    identity_path = fixture["evidence"] / "desktop-macos-packaging/desktop-bundle.json"
                    identity = json.loads(identity_path.read_text())
                    identity["sourceSha"] = "c" * 40
                    identity_path.write_text(json.dumps(identity))
                    message = "identity source differs from run"
                else:
                    defines_path = fixture["evidence"] / "desktop-bundle/dart-defines.env"
                    lines = defines_path.read_text().splitlines()
                    compiled = json.loads(lines[0].split("=", 1)[1])
                    compiled["buildNumber"] = 63
                    lines[0] = "SESORI_DESKTOP_BUNDLE_IDENTITY=" + json.dumps(compiled, separators=(",", ":"))
                    defines_path.write_text("\n".join(lines) + "\n")
                    message = "compiled identity differs"
                with self.assertRaisesRegex(ValueError, message):
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
    def test_accepts_source_in_main_history(self):
        with patch("qualify_desktop_macos_upgrade.git_is_main_ancestor", return_value=True):
            self.assertEqual(
                require_trusted_source(run_id=200, source_sha="a" * 40, associated_pulls=[]),
                {"kind": "mainAncestor"},
            )

    def test_accepts_only_exact_pinned_retained_baseline(self):
        baseline = PINNED_RETAINED_BASELINES[35042335424]
        associated_pulls = [{
            "number": baseline["pullRequest"],
            "state": "closed",
            "merged_at": "2026-09-16T01:40:57Z",
            "merge_commit_sha": baseline["mergeCommitSha"],
            "base": {
                "ref": "main",
                "repo": {"full_name": "sesori-ai/sesori_apps_monorepo"},
            },
        }]
        with patch(
            "qualify_desktop_macos_upgrade.git_is_main_ancestor",
            side_effect=lambda *, source_sha: source_sha == baseline["mergeCommitSha"],
        ):
            self.assertEqual(
                require_trusted_source(
                    run_id=35042335424,
                    source_sha=baseline["sourceSha"],
                    associated_pulls=associated_pulls,
                ),
                {
                    "kind": "pinnedRetainedBaseline",
                    "sourceTree": baseline["sourceTree"],
                    "pullRequest": 1503,
                    "mergeCommitSha": baseline["mergeCommitSha"],
                },
            )

    def test_rejects_arbitrary_intermediate_pull_request_source(self):
        with patch("qualify_desktop_macos_upgrade.git_is_main_ancestor", return_value=False):
            with self.assertRaisesRegex(ValueError, "neither in main history nor an exact pinned"):
                require_trusted_source(run_id=42, source_sha="a" * 40, associated_pulls=[])


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
        self.assertIn("macOS upgrade qualification must be dispatched from main", job)
        self.assertNotIn("environment:", job)
        self.assertNotIn("secrets.", job)
        self.assertNotIn("contents: write", job)

    def test_quit_lookup_uses_hit_tested_status_anchored_menu(self):
        quitter = QUITTER.read_text()
        self.assertIn("AXUIElementCopyElementAtPosition(", quitter)
        self.assertIn("AXUIElementCreateSystemWide()", quitter)
        self.assertIn("hitTest(at: point)", quitter)
        self.assertIn("processIdentifier(candidate) == pid", quitter)
        self.assertIn("stringAttribute(candidate, kAXRoleAttribute as CFString) == kAXMenuRole", quitter)
        self.assertIn("isAnchored(candidate, to: statusFrame)", quitter)
        self.assertIn("processIdentifier($0) == pid", quitter)
        self.assertIn(
            "if let trayMenu = visibleTrayMenu(\n"
            "            ownedBy: pid,\n"
            "            anchoredTo: statusFrame,\n"
            "            reportHits: attempt == 0 || attempt == 50\n"
            "        ), let quitItem = quitItem(in: trayMenu, ownedBy: pid)",
            quitter,
        )
        self.assertNotIn("CGEvent(", quitter)
        self.assertNotIn("postKey(", quitter)
        self.assertNotIn("quitItems(from:", quitter)
        self.assertNotIn("menus(from:", quitter)
        press = quitter.index("AXUIElementPerformAction(statusItem")
        self.assertLess(press, quitter.rindex("visibleTrayMenu("))


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
