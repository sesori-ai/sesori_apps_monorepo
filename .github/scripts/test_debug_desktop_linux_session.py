"""Diagnostic access boundaries; not substitutes for native desktop qualification."""

import contextlib
import io
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest import mock

import debug_desktop_linux_session as diagnostics


class LinuxInteractiveDiagnosticsTest(unittest.TestCase):
    def test_preparation_reuses_original_producer_validation_and_independent_trust(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "desktop-linux-evidence-x64/desktop-bundle/bundle/bridge/desktop-bundle.json"
            identity.parent.mkdir(parents=True)
            identity.write_text(json.dumps({"sourceSha": "a" * 40, "version": "1.9.2", "buildNumber": 168}))
            with mock.patch.object(diagnostics, "github", return_value='{"id": 42}') as github, \
                    mock.patch.object(diagnostics, "prepare_signed") as prepare, \
                    mock.patch.object(diagnostics, "verify_release") as verify:
                diagnostics.prepare(inputs=root, output=root / "prepared", run_id=42, tooling_sha="b" * 40)
            github.assert_called_once_with(arguments=[
                "api", f"repos/{diagnostics.REPOSITORY}/actions/runs/42"])
            self.assertEqual(json.loads((root / "run.json").read_text()), {"id": 42})
            prepare.assert_called_once_with(root=root, output=root / "prepared", source_sha="a" * 40,
                                            tooling_sha="b" * 40, channel=diagnostics.Channel.INTERNAL,
                                            repository=diagnostics.REPOSITORY,
                                            run_id=42, current_run_id=None, version="1.9.2", build_number=168)
            verify.assert_called_once_with(root=root / "prepared", channel=diagnostics.Channel.INTERNAL,
                                           fingerprint=diagnostics.TRUSTED_PRIMARY_FINGERPRINT)

    def test_untrusted_producer_stops_before_further_processing(self):
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(diagnostics, "github", side_effect=RuntimeError("original producer error")), \
                mock.patch.object(diagnostics, "prepare_signed") as prepare:
            with self.assertRaisesRegex(RuntimeError, "original producer error"):
                diagnostics.prepare(inputs=Path(directory), output=Path(directory) / "output",
                                    run_id=42, tooling_sha="b" * 40)
            prepare.assert_not_called()

    def test_workstation_root_and_wrong_cpu_refused_before_installer_or_desktop(self):
        cases = (("Darwin", "true", 501, "arm64", "disposable Linux"),
                 ("Linux", "false", 1001, "aarch64", "disposable Linux"),
                 ("Linux", "true", 0, "aarch64", "never root"),
                 ("Linux", "true", 1001, "x86_64", "selected native CPU"))
        for system, actions, uid, machine, message in cases:
            with self.subTest(system=system, uid=uid, machine=machine), \
                    mock.patch.object(diagnostics.platform, "system", return_value=system), \
                    mock.patch.object(diagnostics.platform, "machine", return_value=machine), \
                    mock.patch.object(diagnostics.os, "geteuid", return_value=uid), \
                    mock.patch.dict(os.environ, {"GITHUB_ACTIONS": actions}), \
                    mock.patch.object(diagnostics, "run") as run:
                with self.assertRaisesRegex(ValueError, message):
                    diagnostics.serve(inputs=Path("unused"), output=Path("unused"), architecture="arm64")
                run.assert_not_called()

    def test_vnc_readiness_requires_a_live_process_and_loopback_listener(self):
        process = mock.Mock()
        process.poll.return_value = None
        with mock.patch.object(diagnostics.socket, "create_connection", side_effect=[
                ConnectionRefusedError(), mock.MagicMock()]) as connect:
            self.assertFalse(diagnostics.vnc_ready(process=process))
            self.assertTrue(diagnostics.vnc_ready(process=process))
        self.assertEqual(connect.call_args_list, [mock.call(("127.0.0.1", 5900), timeout=1)] * 2)
        process.poll.return_value = 1
        with mock.patch.object(diagnostics.socket, "create_connection") as connect:
            with self.assertRaisesRegex(ValueError, "VNC server exited.*1"):
                diagnostics.vnc_ready(process=process)
        connect.assert_not_called()

    def test_unattended_stop_pipe_open_is_nonblocking_bounded_and_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            control = Path(directory) / "stop.pipe"

            def expired(readable, writable, exceptional, seconds):
                self.assertEqual(seconds, 1200)
                self.assertEqual(control.stat().st_mode & 0o777, 0o600)
                # A real FIFO with no writer must not hang before reaching this select.
                return [], [], []

            with mock.patch.object(diagnostics.select, "select", side_effect=expired), \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                diagnostics.wait_for_operator(control=control)
            self.assertIn("expired", output.getvalue())
            self.assertFalse(control.exists())

    def test_operator_can_stop_and_exception_also_removes_control_pipe(self):
        for failure in (False, True):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                control = Path(directory) / "stop.pipe"
                real_select = diagnostics.select.select

                def stop(readable, writable, exceptional, seconds):
                    if failure:
                        raise RuntimeError("diagnostic interrupted")
                    with control.open("w") as target:
                        target.write("stop\n")
                    return real_select(readable, writable, exceptional, 0)

                with mock.patch.object(diagnostics.select, "select", side_effect=stop), \
                        contextlib.redirect_stdout(io.StringIO()) as output:
                    if failure:
                        with self.assertRaisesRegex(RuntimeError, "diagnostic interrupted"):
                            diagnostics.wait_for_operator(control=control)
                    else:
                        diagnostics.wait_for_operator(control=control)
                        self.assertIn("Operator ended", output.getvalue())
                self.assertFalse(control.exists())

    def test_reusable_callers_admit_oidc_but_ordinary_callee_jobs_remain_read_only(self):
        workflows = Path(__file__).parents[1] / "workflows"
        callee = (workflows / "desktop-qualification.yml").read_text()
        default_permissions = callee.split("\npermissions:\n", 1)[1].split("\nconcurrency:", 1)[0]
        self.assertEqual(default_permissions.strip(), "contents: read")
        self.assertEqual(callee.count("id-token: write"), 1)
        for filename, job_name in (("release-all-platforms.yml", "desktop-linux"),
                                   ("release-all-platforms.yml", "desktop-macos"),
                                   ("submit-release.yml", "build-desktop-macos")):
            with self.subTest(filename=filename, job=job_name):
                text = (workflows / filename).read_text()
                job = re.search(rf"(?ms)^  {job_name}:\n(.*?)(?=^  [\w-]+:|\Z)", text).group(1)
                self.assertIn("uses: ./.github/workflows/desktop-qualification.yml", job)
                self.assertIn("contents: read", job)
                self.assertIn("actions: read", job)
                self.assertIn("id-token: write", job)
                self.assertIn("secrets: inherit", job)
                self.assertNotIn("contents: write", job)

    def test_workflow_requires_manual_scoped_oidc_without_signing_or_public_desktop(self):
        workflow = (Path(__file__).parents[1] / "workflows/desktop-qualification.yml").read_text()
        job = workflow.split("  linux-interactive-debug:\n", 1)[1].split("\n  macos-gui:", 1)[0]
        self.assertTrue(workflow.startswith("name: Desktop Native Qualification\n"))
        self.assertIn("if: github.event_name == 'workflow_dispatch' && inputs.mode == 'linux-interactive-debug'", job)
        self.assertIn("environment: desktop-linux-debug", job)
        self.assertIn("'ubuntu-24.04' || 'ubuntu-24.04-arm'", job)
        self.assertIn("timeout-minutes: 40", job)
        self.assertIn("timeout-minutes: 25", job)
        self.assertIn("contents: read\n      actions: read\n      id-token: write", job)
        self.assertIn("persist-credentials: false", job)
        self.assertIn('--architecture "$DEBUG_ARCH"', job)
        self.assertIn("audience: ${{ vars.TAILSCALE_AUDIENCE }}", job)
        self.assertIn("oauth-client-id: ${{ vars.TAILSCALE_CLIENT_ID }}", job)
        self.assertIn("tags: tag:sesori-ci-debug", job)
        self.assertIn("args: --ssh --accept-dns=false", job)
        self.assertNotIn("args: --ssh --accept-routes", job)
        self.assertLess(job.index("sudo tailscale set --accept-routes=false"), job.index("dbus-run-session"))
        self.assertNotIn("secrets.", job)
        self.assertNotIn("authkey:", job)
        self.assertNotIn("oauth-secret:", job)
        self.assertNotIn("upload-artifact", job)
        self.assertNotIn("contents: write", job)
        self.assertLess(job.index("Independently verify"), job.index("uses: tailscale/github-action@"))
        self.assertIn("inputs.mode == 'linux-interactive-debug' && 'linux-debug'", workflow)
        self.assertIn("if: github.event_name != 'workflow_dispatch' || "
                      "inputs.mode != 'linux-interactive-debug'", workflow)
        source = Path(diagnostics.__file__).read_text()
        self.assertIn('"-localhost", "-rfbport", "5900"', source)
        self.assertIn('"-nolisten", "tcp"', source)
        self.assertLess(source.index('"kwriteconfig5"'), source.index('"startplasma-x11"'))
        self.assertIn('"--key", "Autolock", "false"', source)
        self.assertLess(source.index('wait_for(description="loopback VNC listener"'),
                        source.index('environment = output / "session.env"'))
        self.assertIn("stop_process(process=process)", source)
        self.assertIn('TemporaryDirectory(prefix="sesori-linux-debug-"', source)


if __name__ == "__main__":
    unittest.main()
