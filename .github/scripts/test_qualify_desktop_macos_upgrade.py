import hashlib
import inspect
import json
import os
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from qualify_desktop_macos_upgrade import (
    INSTALLED_HELPER,
    PINNED_RETAINED_BASELINES,
    installed_helper_processes,
    launch_and_quit,
    load_candidate,
    normalized_lipo_architectures,
    record_helper_off_observation,
    require_fresh_native_runner,
    require_trusted_source,
    validate_installed_architectures,
    validate_upgrade,
    wait_for_visible_window,
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


class MacosUpgradeWindowTests(unittest.TestCase):
    def test_wait_retries_until_owned_window_is_visible(self):
        missing = Mock(returncode=1, stdout="SCREEN_COUNT 1\n", stderr="No visible main window\n")
        visible = Mock(returncode=0, stdout="SCREEN_COUNT 1\nWINDOW_ID 42\n", stderr="")
        launcher = Mock()
        launcher.poll.return_value = None
        with tempfile.TemporaryDirectory() as temp, \
                patch("qualify_desktop_macos_upgrade.subprocess.run", side_effect=[missing, visible]) as run, \
                patch(
                    "qualify_desktop_macos_upgrade.time.monotonic",
                    side_effect=[100.0, 100.0, 101.0, 102.0],
                ), \
                patch("qualify_desktop_macos_upgrade.time.sleep") as sleep:
            output = Path(temp)
            self.assertEqual(
                wait_for_visible_window(
                    label="current",
                    inspector=Path("window-inspector"),
                    app_pid=42,
                    launcher=launcher,
                    output=output,
                ),
                "42",
            )
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args_list[0].kwargs["timeout"], 45.0)
            self.assertEqual(run.call_args_list[1].kwargs["timeout"], 43.0)
            sleep.assert_called_once_with(1.0)
            window_log = (output / "current-window.log").read_text(encoding="utf-8")
            self.assertIn("ATTEMPT 1", window_log)
            self.assertIn("ATTEMPT 2", window_log)
            self.assertIn("WINDOW_ID 42", window_log)

    def test_wait_refuses_inactive_screen_and_preserves_attempt(self):
        blocked = Mock(returncode=2, stdout="SCREEN_COUNT 0\n", stderr="")
        launcher = Mock()
        with tempfile.TemporaryDirectory() as temp, \
                patch("qualify_desktop_macos_upgrade.subprocess.run", return_value=blocked), \
                patch("qualify_desktop_macos_upgrade.time.monotonic", return_value=100.0), \
                patch("qualify_desktop_macos_upgrade.time.sleep") as sleep:
            output = Path(temp)
            with self.assertRaisesRegex(RuntimeError, "native runner has no active screen"):
                wait_for_visible_window(
                    label="current",
                    inspector=Path("window-inspector"),
                    app_pid=42,
                    launcher=launcher,
                    output=output,
                )
            self.assertIn("ATTEMPT 1", (output / "current-window.log").read_text(encoding="utf-8"))
            launcher.poll.assert_not_called()
            sleep.assert_not_called()

    def test_wait_refuses_process_exit_and_preserves_attempt(self):
        missing = Mock(returncode=1, stdout="SCREEN_COUNT 1\n", stderr="No visible main window\n")
        launcher = Mock()
        launcher.poll.return_value = 0
        with tempfile.TemporaryDirectory() as temp, \
                patch("qualify_desktop_macos_upgrade.subprocess.run", return_value=missing), \
                patch("qualify_desktop_macos_upgrade.time.monotonic", return_value=100.0), \
                patch("qualify_desktop_macos_upgrade.time.sleep") as sleep:
            output = Path(temp)
            with self.assertRaisesRegex(RuntimeError, "exited before showing a visible main window"):
                wait_for_visible_window(
                    label="current",
                    inspector=Path("window-inspector"),
                    app_pid=42,
                    launcher=launcher,
                    output=output,
                )
            self.assertIn("ATTEMPT 1", (output / "current-window.log").read_text(encoding="utf-8"))
            sleep.assert_not_called()

    def test_wait_refuses_deadline_and_preserves_attempt(self):
        missing = Mock(returncode=1, stdout="SCREEN_COUNT 1\n", stderr="No visible main window\n")
        launcher = Mock()
        launcher.poll.return_value = None
        with tempfile.TemporaryDirectory() as temp, \
                patch("qualify_desktop_macos_upgrade.subprocess.run", return_value=missing), \
                patch("qualify_desktop_macos_upgrade.time.monotonic", side_effect=[100.0, 100.0, 145.0]), \
                patch("qualify_desktop_macos_upgrade.time.sleep") as sleep:
            output = Path(temp)
            with self.assertRaisesRegex(RuntimeError, "no visible main window after 45 seconds"):
                wait_for_visible_window(
                    label="current",
                    inspector=Path("window-inspector"),
                    app_pid=42,
                    launcher=launcher,
                    output=output,
                )
            self.assertIn("ATTEMPT 1", (output / "current-window.log").read_text(encoding="utf-8"))
            sleep.assert_not_called()

    def test_wait_bounds_hung_inspector_and_preserves_partial_output(self):
        launcher = Mock()
        timeout = subprocess.TimeoutExpired(
            cmd=["window-inspector", "42"],
            timeout=45.0,
            output="partial stdout\n",
            stderr="partial stderr\n",
        )
        with tempfile.TemporaryDirectory() as temp, \
                patch("qualify_desktop_macos_upgrade.subprocess.run", side_effect=timeout), \
                patch("qualify_desktop_macos_upgrade.time.monotonic", return_value=100.0), \
                patch("qualify_desktop_macos_upgrade.time.sleep") as sleep:
            output = Path(temp)
            with self.assertRaisesRegex(RuntimeError, "no visible main window after 45 seconds"):
                wait_for_visible_window(
                    label="current",
                    inspector=Path("window-inspector"),
                    app_pid=42,
                    launcher=launcher,
                    output=output,
                )
            window_log = (output / "current-window.log").read_text(encoding="utf-8")
            self.assertIn("ATTEMPT 1", window_log)
            self.assertIn("INSPECTOR_TIMEOUT", window_log)
            self.assertIn("partial stdout", window_log)
            self.assertIn("partial stderr", window_log)
            launcher.poll.assert_not_called()
            sleep.assert_not_called()


class MacosUpgradeHelperProcessTests(unittest.TestCase):
    def test_launch_observes_helper_before_invoking_quit(self):
        source = inspect.getsource(launch_and_quit)
        observation = source.index("record_helper_off_observation(label=label, output=output)")
        quit_invocation = source.index("quit_result = subprocess.run")

        self.assertLess(observation, quit_invocation)

    def test_live_observation_matches_only_exact_installed_helper(self):
        helper = f"124 {INSTALLED_HELPER} --control-url=http://127.0.0.1:9000"
        processes = "\n".join([
            "123 /Applications/Sesori.app/Contents/MacOS/Sesori",
            helper,
            "125 /workspace/bridge/app/build/cli/bundle/bin/bridge",
            f"126 {INSTALLED_HELPER}-copy",
        ])

        with patch("qualify_desktop_macos_upgrade.subprocess.check_output", return_value=processes):
            self.assertEqual(installed_helper_processes(), helper)

    def test_live_observation_records_absence_and_refuses_running_helper(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with patch("qualify_desktop_macos_upgrade.subprocess.check_output", return_value=""):
                record_helper_off_observation(label="previous", output=output)
            self.assertEqual((output / "previous-helper-off.log").read_text(), "NO_INSTALLED_HELPER\n")

            helper = f"124 {INSTALLED_HELPER} --control-url=http://127.0.0.1:9000"
            with patch("qualify_desktop_macos_upgrade.subprocess.check_output", return_value=helper), \
                    self.assertRaisesRegex(RuntimeError, "helper ran despite persisted Bridge Off intent"):
                record_helper_off_observation(label="current", output=output)
            self.assertEqual((output / "current-helper-off.log").read_text(), f"{helper}\n")


class MacosUpgradeWorkflowTests(unittest.TestCase):
    def test_upgrade_job_is_credential_free_and_uses_selected_artifacts(self):
        workflow = WORKFLOW.read_text()
        job = workflow.split("  macos-upgrade:\n", 1)[1].split("\n  macos-authenticated-upgrade:", 1)[0]
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
        self.assertIn("mouseType: .leftMouseDown", quitter)
        self.assertIn("mouseType: .leftMouseUp", quitter)
        self.assertIn("processIdentifier(statusItem) == pid", quitter)
        self.assertIn("statusFrame.width >= 4", quitter)
        self.assertIn("statusFrame.width <= 100", quitter)
        self.assertIn("statusFrame.height >= 4", quitter)
        self.assertIn("statusFrame.height <= 64", quitter)
        self.assertIn("statusFrame.minY >= 0", quitter)
        self.assertIn("statusFrame.maxY <= 80", quitter)
        self.assertIn("CGPoint(x: statusFrame.midX, y: statusFrame.midY)", quitter)
        self.assertIn(
            "guard actions.contains(kAXPressAction),\n"
            "          let statusFrame = clickStatusItem(statusItem, ownedBy: pid)",
            quitter,
        )
        self.assertNotIn("keyboardEventSource", quitter)
        self.assertNotIn("postKey(", quitter)
        self.assertNotIn("quitItems(from:", quitter)
        self.assertNotIn("menus(from:", quitter)
        click = quitter.index("clickStatusItem(statusItem, ownedBy: pid)")
        self.assertLess(click, quitter.rindex("visibleTrayMenu("))


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
