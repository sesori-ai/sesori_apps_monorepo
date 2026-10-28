import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from probe_desktop_macos import probe


class MacProbeSafetyTests(unittest.TestCase):
    def test_local_launch_refuses_before_process_or_file_operations(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), \
                patch("probe_desktop_macos.sys.platform", "darwin"), \
                patch("probe_desktop_macos.subprocess.check_output") as processes:
            with self.assertRaises(PermissionError):
                probe(app=Path("app"), fixture=Path("fixture"), output=Path("output"))
            processes.assert_not_called()

    def test_active_desktop_or_bridge_refuses_without_installing_or_killing(self):
        for command in ["123 /Applications/Sesori.app/Contents/MacOS/Sesori",
                        "124 /Applications/Sesori.app/Contents/Helpers/bridge/bin/bridge",
                        "125 /workspace/bridge/app/build/cli/bundle/bin/bridge"]:
            with self.subTest(command=command), patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), \
                    patch("probe_desktop_macos.sys.platform", "darwin"), \
                    patch("probe_desktop_macos.subprocess.check_output", return_value=command), \
                    patch("probe_desktop_macos.execute") as execute:
                with self.assertRaisesRegex(RuntimeError, "existing desktop/bridge"):
                    probe(app=Path("app"), fixture=Path("fixture"), output=Path("output"))
                execute.assert_not_called()

    def test_missing_screen_fails_before_installation_or_platform_fixture(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "RUNNER_TEMP": directory}), \
                patch("probe_desktop_macos.sys.platform", "darwin"), \
                patch("probe_desktop_macos.subprocess.check_output", return_value=""), \
                patch("probe_desktop_macos.Path.exists", return_value=False), \
                patch("probe_desktop_macos.execute") as execute, \
                patch("probe_desktop_macos.probe_platform_fixture") as fixture, \
                patch("probe_desktop_macos.subprocess.run", return_value=subprocess.CompletedProcess(
                    args=["inspector"], returncode=2, stdout="SCREEN_COUNT 0\n", stderr="")):
            with self.assertRaisesRegex(RuntimeError, "BLOCKED.*no active screen"):
                probe(app=Path("app"), fixture=Path("fixture"), output=Path(directory) / "evidence")
            self.assertEqual(len(execute.call_args_list), 1)
            self.assertEqual(execute.call_args.kwargs["command"][:2], ["xcrun", "swiftc"])
            fixture.assert_not_called()

    def test_window_that_appears_after_startup_observation_passes(self):
        missing = subprocess.CompletedProcess(args=["inspector"], returncode=1, stdout="SCREEN_COUNT 1\n",
                                              stderr="No visible main window\n")
        shown = subprocess.CompletedProcess(args=["inspector"], returncode=0,
                                            stdout="SCREEN_COUNT 1\nWINDOW_ID 7\nWINDOW_SIZE 900x600\n", stderr="")
        host = subprocess.CompletedProcess(args=["inspector"], returncode=0, stdout="SCREEN_COUNT 1\n", stderr="")
        launcher = Mock()
        launcher.wait.side_effect = [subprocess.TimeoutExpired(cmd="open", timeout=15), 0]
        launcher.poll.side_effect = [None, None, 0]
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "RUNNER_TEMP": directory}), \
                patch("probe_desktop_macos.sys.platform", "darwin"), \
                patch("probe_desktop_macos.subprocess.check_output", side_effect=["", "123\n"]), \
                patch("probe_desktop_macos.Path.exists", return_value=False), \
                patch("probe_desktop_macos.execute"), \
                patch("probe_desktop_macos.shutil.copyfile"), \
                patch("probe_desktop_macos.shutil.rmtree"), \
                patch("probe_desktop_macos.subprocess.Popen", return_value=launcher), \
                patch("probe_desktop_macos.os.kill"), \
                patch("probe_desktop_macos.time.sleep") as sleep, \
                patch("probe_desktop_macos.subprocess.run", side_effect=[host, missing, missing, shown]) as inspector:
            probe(app=Path("app"), fixture=None, output=Path(directory) / "evidence")
            self.assertEqual(inspector.call_count, 4)
            self.assertEqual([call.args for call in sleep.call_args_list], [(2.0,), (2.0,)])
            self.assertIn("ATTEMPT 3\nSCREEN_COUNT 1\nWINDOW_ID 7",
                          (Path(directory) / "evidence/window.log").read_text())

    def test_existing_login_registration_refuses_without_mutation(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), \
                patch("probe_desktop_macos.sys.platform", "darwin"), \
                patch("probe_desktop_macos.subprocess.check_output", return_value=""), \
                patch("probe_desktop_macos.Path.exists", return_value=True), \
                patch("probe_desktop_macos.execute") as execute:
            with self.assertRaisesRegex(RuntimeError, "Existing login registration"):
                probe(app=Path("app"), fixture=Path("fixture"), output=Path("output"))
            execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
