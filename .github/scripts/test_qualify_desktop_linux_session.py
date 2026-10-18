"""Driver contracts, not substitutes for native desktop session evidence."""

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import qualify_desktop_linux_session as qualification


MENU_OCR = """level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
1\t1\t0\t0\t0\t0\t0\t0\t206\t218\t-1\t
5\t1\t1\t1\t1\t1\t13\t11\t37\t13\t85.6\tOpen
5\t1\t1\t1\t1\t2\t55\t10\t42\t11\t90.6\tSesori
5\t1\t1\t4\t3\t1\t13\t194\t29\t13\t93.3\tQuit
5\t1\t1\t4\t3\t2\t47\t194\t42\t11\t92.7\tSesori
"""


class LinuxSessionQualificationTest(unittest.TestCase):
    def test_preparation_preserves_sources_and_requires_increasing_package_versions(self):
        for old_build, new_build, same_source, accepted in ((1, 2, False, True), (2, 1, False, False),
                                                            (1, 1, False, False), (1, 2, True, True),
                                                            (1, 1, True, False)):
            with self.subTest(old=old_build, new=new_build, same_source=same_source):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    output_file = root / "github-output"

                    for label, build in (("previous", old_build), ("current", new_build)):
                        identity = (root / label
                                    / "desktop-linux-evidence-x64/desktop-bundle/bundle/bridge/desktop-bundle.json")
                        identity.parent.mkdir(parents=True)
                        identity.write_text(json.dumps({
                            "version": "9.8.7", "buildNumber": build,
                            "sourceSha": "a" * 40 if label == "previous" or same_source else "b" * 40}))

                    def prepare_signed(**arguments):
                        return {"version": arguments["version"], "buildNumber": arguments["build_number"],
                                "sourceSha": arguments["source_sha"]}

                    with mock.patch.object(qualification, "prepare_signed", autospec=True,
                                           side_effect=prepare_signed) as prepare, \
                            mock.patch.object(qualification, "verify_release") as verify, \
                            mock.patch.object(qualification, "github", return_value='{"id": 1}') as github, \
                            mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(output_file)}):
                        arguments = {"inputs": root, "output": root / "prepared", "previous": 11,
                                     "current": 22, "tooling_sha": "c" * 40}
                        if accepted:
                            qualification.prepare(**arguments)
                            self.assertIn("previous_source=" + "a" * 40, output_file.read_text())
                            self.assertIn("current_source=" + ("a" if same_source else "b") * 40,
                                          output_file.read_text())
                        else:
                            with self.assertRaises(ValueError):
                                qualification.prepare(**arguments)
                            self.assertFalse(output_file.exists())
                    self.assertEqual([call.kwargs["run_id"] for call in prepare.call_args_list], [11, 22])
                    self.assertTrue(all(call.kwargs["current_run_id"] is None for call in prepare.call_args_list))
                    self.assertEqual([call.kwargs["arguments"][-1].split("/")[-1]
                                      for call in github.call_args_list], ["11", "22"])
                    self.assertEqual(verify.call_count, 2)
                    self.assertTrue(all(call.kwargs["fingerprint"] == qualification.TRUSTED_PRIMARY_FINGERPRINT
                                        for call in verify.call_args_list))

    def test_workstation_root_and_wrong_cpu_refused_before_any_native_operation(self):
        cases = (("Darwin", "true", 501, "x86_64", "disposable Linux"),
                 ("Linux", "false", 1001, "x86_64", "disposable Linux"),
                 ("Linux", "true", 0, "x86_64", "never root"),
                 ("Linux", "true", 1001, "aarch64", "CPU emulation"))
        for system, actions, uid, machine, message in cases:
            with self.subTest(system=system, actions=actions, uid=uid, machine=machine), \
                    mock.patch.object(qualification.platform, "system", return_value=system), \
                    mock.patch.object(qualification.platform, "machine", return_value=machine), \
                    mock.patch.object(qualification.os, "geteuid", return_value=uid), \
                    mock.patch.dict(os.environ, {"GITHUB_ACTIONS": actions}), \
                    mock.patch.object(qualification.subprocess, "Popen") as process:
                with self.assertRaisesRegex(ValueError, message):
                    qualification.exercise(inputs=Path("unused"), probes=Path("unused"), output=Path("unused"),
                                           desktop=qualification.Desktop.GNOME, architecture="x64")
                process.assert_not_called()

    def test_quit_text_coordinates_use_actual_word_bounds_and_window_origin(self):
        self.assertEqual(qualification.quit_text_point(tsv=MENU_OCR, origin_x=1051, origin_y=546), (1102, 746))

    def test_quit_text_rejects_other_labels_and_words_on_separate_lines(self):
        for tsv in (MENU_OCR.replace("\tQuit\n", "\tQuitter\n"),
                    MENU_OCR.replace("5\t1\t1\t4\t3\t2", "5\t1\t1\t4\t4\t2")):
            with self.subTest(tsv=tsv):
                self.assertIsNone(qualification.quit_text_point(tsv=tsv, origin_x=1051, origin_y=546))

    def test_native_quit_reads_only_the_visible_host_owned_popup(self):
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "menu.png"
            env = {"DISPLAY": ":95"}
            with mock.patch.object(qualification, "run", side_effect=[
                    "11\n22\n", "_NET_WM_WINDOW_TYPE_NORMAL", "_NET_WM_WINDOW_TYPE_POPUP_MENU",
                    "WINDOW=22\nX=1051\nY=546\nWIDTH=206\nHEIGHT=218\nSCREEN=0\n", "", MENU_OCR]) as run:
                self.assertEqual(qualification.native_quit_point(pid=17, capture=capture, env=env), (1102, 746))
            self.assertEqual([call.kwargs["arguments"] for call in run.call_args_list], [
                ["xdotool", "search", "--onlyvisible", "--pid", "17"],
                ["xprop", "-id", "11", "_NET_WM_WINDOW_TYPE"],
                ["xprop", "-id", "22", "_NET_WM_WINDOW_TYPE"],
                ["xdotool", "getwindowgeometry", "--shell", "22"],
                ["import", "-window", "22", str(capture)],
                ["tesseract", str(capture), "stdout", "-l", "eng", "--psm", "6", "tsv"]])
            self.assertTrue(all(call.kwargs["env"] == env for call in run.call_args_list))
            self.assertEqual(capture.with_suffix(".tsv").read_text(), MENU_OCR)

    def test_absent_popup_does_not_capture_unrelated_host_windows(self):
        with mock.patch.object(qualification, "run", side_effect=[
                "11\n", "_NET_WM_WINDOW_TYPE_NORMAL"]) as run:
            self.assertIsNone(qualification.native_quit_point(pid=17, capture=Path("unused"), env={}))
        self.assertEqual(run.call_count, 2)

    def test_stop_process_reaps_a_group_that_exits_during_term_or_kill(self):
        for vanished in (qualification.signal.SIGTERM, qualification.signal.SIGKILL):
            with self.subTest(vanished=vanished):
                process = mock.Mock(pid=41)
                process.poll.return_value = None
                process.wait.side_effect = ([0] if vanished == qualification.signal.SIGTERM else
                                            [qualification.subprocess.TimeoutExpired(["fixture"], 10), 0])
                signals = ([ProcessLookupError()] if vanished == qualification.signal.SIGTERM else
                           [None, ProcessLookupError()])
                with mock.patch.object(qualification.os, "killpg", side_effect=signals) as kill:
                    qualification.stop_process(process=process)
                expected = [mock.call(41, qualification.signal.SIGTERM)]
                if vanished == qualification.signal.SIGKILL:
                    expected.append(mock.call(41, qualification.signal.SIGKILL))
                self.assertEqual(kill.call_args_list, expected)
                process.wait.assert_called_with(timeout=10)

    def test_stop_process_does_not_signal_an_already_reaped_child(self):
        process = mock.Mock()
        process.poll.return_value = 0
        with mock.patch.object(qualification.os, "killpg") as kill:
            qualification.stop_process(process=process)
        kill.assert_not_called()
        process.wait.assert_not_called()

    def test_readiness_is_bounded_and_command_failures_preserve_diagnostics(self):
        with mock.patch.object(qualification.time, "monotonic", side_effect=[0, 0, 2]), \
                mock.patch.object(qualification.time, "sleep"):
            with self.assertRaisesRegex(TimeoutError, "native window"):
                qualification.wait_for(description="native window", check=lambda: False, timeout=1)
        result = qualification.subprocess.CompletedProcess(["fixture"], 7, "useful output", "original error")
        with mock.patch.object(qualification.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "original error"):
                qualification.run(arguments=["fixture"])

    def test_workflow_keeps_both_native_cpus_credentials_and_shipping_separate(self):
        workflow = (Path(__file__).parents[1] / "workflows/desktop-linux-session.yml").read_text()
        self.assertIn("runner: ubuntu-24.04\n", workflow)
        self.assertIn("runner: ubuntu-24.04-arm\n", workflow)
        self.assertIn("desktop: gnome-wayland", workflow)
        self.assertIn("desktop: kde-x11", workflow)
        self.assertIn("max-parallel: 2", workflow)
        self.assertIn("actions: read", workflow)
        self.assertIn("pattern: desktop-linux-*", workflow)
        self.assertIn("  workflow_call:\n", workflow)
        self.assertNotIn("  pull_request:", workflow)
        self.assertNotIn("  workflow_dispatch:", workflow)
        self.assertNotIn("default:", workflow)
        self.assertEqual(workflow.count("required: true"), 2)
        self.assertIn("run-id: ${{ inputs.previous_run }}\n", workflow)
        self.assertIn("run-id: ${{ inputs.current_run }}\n", workflow)
        self.assertLess(workflow.index("Require explicit retained signed producer pair"),
                        workflow.index("uses: actions/download-artifact"))
        parent = (Path(__file__).parents[1] / "workflows/desktop-qualification.yml").read_text()
        job = parent.split("  linux-session:\n", 1)[1].split("\n  linux-interactive-debug:", 1)[0]
        self.assertIn("if: github.event_name == 'workflow_dispatch' && inputs.mode == 'linux-session'", job)
        self.assertIn("uses: ./.github/workflows/desktop-linux-session.yml", job)
        self.assertIn("previous_run: ${{ inputs.previous_packaging_run }}", job)
        self.assertIn("current_run: ${{ inputs.packaging_run }}", job)
        self.assertNotIn("secrets:", job)
        self.assertIn("inputs.mode == 'linux-session' && 'linux-session'", parent)
        self.assertIn("python3-pyatspi", workflow)
        self.assertIn("x11-utils", workflow)
        self.assertIn("tesseract-ocr tesseract-ocr-eng", workflow)
        self.assertNotIn("previous_tag", workflow)
        self.assertIn("/usr/bin/python3", workflow)
        self.assertIn("dbus-run-session", workflow)
        self.assertNotIn("secrets.", workflow)
        self.assertNotIn("id-token: write", workflow)
        self.assertNotIn("store-production", workflow)
        self.assertNotIn("linux-signing", workflow)
        self.assertIn(".qa-$candidate/client/desktop/build/linux/", workflow)


if __name__ == "__main__":
    unittest.main()
