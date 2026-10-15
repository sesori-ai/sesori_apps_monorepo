"""Driver contracts, not substitutes for native desktop session evidence."""

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import qualify_desktop_linux_session as qualification


class LinuxSessionQualificationTest(unittest.TestCase):
    def test_preparation_preserves_selected_sources_and_requires_genuine_upgrade(self):
        for old_build, new_build, same_source, accepted in ((1, 2, False, True), (2, 1, False, False),
                                                            (1, 1, False, False), (1, 2, True, False)):
            with self.subTest(old=old_build, new=new_build, same_source=same_source):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    output_file = root / "github-output"

                    def download(*, output, tag):
                        output.mkdir()
                        previous = tag == "old"
                        metadata = {"version": "9.8.7", "buildNumber": old_build if previous else new_build,
                                    "sourceSha": "a" * 40 if previous or same_source else "b" * 40}
                        (output / qualification.MANIFEST).write_text(json.dumps(metadata))

                    with mock.patch.object(qualification, "download", side_effect=download) as fetch, \
                            mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(output_file)}):
                        if accepted:
                            qualification.prepare(output=root / "inputs", previous="old", current="new")
                            self.assertIn("previous_source=" + "a" * 40, output_file.read_text())
                            self.assertIn("current_source=" + "b" * 40, output_file.read_text())
                        else:
                            with self.assertRaises(ValueError):
                                qualification.prepare(output=root / "inputs", previous="old", current="new")
                            self.assertFalse(output_file.exists())
                    self.assertEqual([call.kwargs["tag"] for call in fetch.call_args_list], ["old", "new"])

    def test_ordinary_workstation_and_root_gui_refused_before_any_native_operation(self):
        for system, actions, uid, message in (("Darwin", "true", 501, "disposable Linux"),
                                              ("Linux", "false", 1001, "disposable Linux"),
                                              ("Linux", "true", 0, "never root")):
            with self.subTest(system=system, actions=actions, uid=uid), \
                    mock.patch.object(qualification.platform, "system", return_value=system), \
                    mock.patch.object(qualification.platform, "machine", return_value="x86_64"), \
                    mock.patch.object(qualification.os, "geteuid", return_value=uid), \
                    mock.patch.dict(os.environ, {"GITHUB_ACTIONS": actions}), \
                    mock.patch.object(qualification.subprocess, "Popen") as process:
                with self.assertRaisesRegex(ValueError, message):
                    qualification.exercise(inputs=Path("unused"), probes=Path("unused"), output=Path("unused"),
                                           desktop=qualification.Desktop.GNOME, architecture="x64")
                process.assert_not_called()

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
        self.assertIn("/usr/bin/python3", workflow)
        self.assertIn("dbus-run-session", workflow)
        self.assertNotIn("secrets.", workflow)
        self.assertNotIn("id-token: write", workflow)
        self.assertNotIn("store-production", workflow)
        self.assertNotIn("linux-signing", workflow)
        self.assertIn(".qa-$candidate/client/desktop/build/linux/", workflow)


if __name__ == "__main__":
    unittest.main()
