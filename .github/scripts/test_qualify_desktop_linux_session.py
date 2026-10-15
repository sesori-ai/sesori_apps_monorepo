"""Driver contracts, not substitutes for native desktop session evidence."""

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import qualify_desktop_linux_session as qualification


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
        self.assertIn("actions: read", workflow)
        self.assertIn("pattern: desktop-linux-*", workflow)
        self.assertIn("'.github/scripts/publish_desktop_linux.py'", workflow)
        self.assertIn("'.github/scripts/publish_linux_repository.py'", workflow)
        self.assertIn("python3-pyatspi", workflow)
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
