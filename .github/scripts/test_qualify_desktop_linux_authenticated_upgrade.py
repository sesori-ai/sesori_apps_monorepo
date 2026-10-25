"""Trust/privacy/sequence contracts; these fixtures do not qualify native account behavior."""

import inspect
import json
import os
from pathlib import Path
import re
import subprocess
import unittest
from unittest import mock

import desktop_qa_credentials as credentials
import qualify_desktop_linux_authenticated_upgrade as qualification


class AuthenticatedLinuxQualificationTest(unittest.TestCase):
    def test_credentials_are_consumed_before_even_the_session_bus_is_started(self):
        email, password = "fixture@example.invalid", "private-fixture-password"

        def child(command, **arguments):
            self.assertNotIn(credentials.AUTH_EMAIL_ENVIRONMENT_KEY, os.environ)
            self.assertNotIn(credentials.AUTH_PASSWORD_ENVIRONMENT_KEY, os.environ)
            self.assertNotIn(email, command)
            self.assertNotIn(password, command)
            self.assertEqual(arguments["input"], f"{email}\n{password}\n")
            self.assertEqual(command[:4], ["dbus-run-session", "--", "/usr/bin/python3",
                                           str(Path(qualification.__file__).resolve())])
            return subprocess.CompletedProcess(command, 0)

        with mock.patch.dict(os.environ, {credentials.AUTH_EMAIL_ENVIRONMENT_KEY: email,
                                         credentials.AUTH_PASSWORD_ENVIRONMENT_KEY: password}), \
                mock.patch.object(qualification, "require_native_main"), \
                mock.patch.object(qualification.os, "umask"), \
                mock.patch.object(qualification.subprocess, "run", side_effect=child) as run:
            qualification.exercise(inputs=Path("inputs"), probes=Path("probes"), output=Path("output"),
                                   desktop=qualification.Desktop.KDE, architecture="arm64")
        self.assertEqual(run.call_count, 1)

    def test_failed_credentials_are_also_removed_and_never_echoed(self):
        for email, password in (("", "sensitive"), ("fixture@example.invalid", ""),
                                ("fixture\n@example.invalid", "sensitive"),
                                ("fixture@example.invalid", "sensitive\rvalue")):
            with self.subTest(email_kind=bool(email), password_kind=bool(password)), \
                    mock.patch.dict(os.environ, {credentials.AUTH_EMAIL_ENVIRONMENT_KEY: email,
                                                 credentials.AUTH_PASSWORD_ENVIRONMENT_KEY: password}):
                with self.assertRaises(ValueError) as error:
                    credentials.load_qa_credentials()
                self.assertNotIn(credentials.AUTH_EMAIL_ENVIRONMENT_KEY, os.environ)
                self.assertNotIn(credentials.AUTH_PASSWORD_ENVIRONMENT_KEY, os.environ)
                self.assertNotIn("sensitive", str(error.exception))
        self.assertNotIn("sensitive", repr(credentials.QaCredentials(email="fixture", password="sensitive")))

    def test_workstation_untrusted_ref_root_and_wrong_cpu_fail_before_credentials_or_native_operations(self):
        defaults = {"GITHUB_ACTIONS": "true", "GITHUB_REF": "refs/heads/main",
                    "GITHUB_EVENT_NAME": "workflow_dispatch"}
        cases = (("Darwin", "true", "refs/heads/main", "workflow_dispatch", 1001, "x86_64", "disposable Linux"),
                 ("Linux", "false", "refs/heads/main", "workflow_dispatch", 1001, "x86_64", "disposable Linux"),
                 ("Linux", "true", "refs/heads/topic", "workflow_dispatch", 1001, "x86_64", "manual main"),
                 ("Linux", "true", "refs/heads/main", "pull_request", 1001, "x86_64", "manual main"),
                 ("Linux", "true", "refs/heads/main", "workflow_dispatch", 0, "x86_64", "never root"),
                 ("Linux", "true", "refs/heads/main", "workflow_dispatch", 1001, "aarch64", "CPU emulation"))
        for system, actions, ref, event, uid, machine, message in cases:
            with self.subTest(system=system, ref=ref, event=event, uid=uid, machine=machine), \
                    mock.patch.dict(os.environ, {**defaults, "GITHUB_ACTIONS": actions,
                                                 "GITHUB_REF": ref, "GITHUB_EVENT_NAME": event}), \
                    mock.patch.object(qualification.platform, "system", return_value=system), \
                    mock.patch.object(qualification.platform, "machine", return_value=machine), \
                    mock.patch.object(qualification.os, "geteuid", return_value=uid), \
                    mock.patch.object(qualification, "load_qa_credentials") as load, \
                    mock.patch.object(qualification.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, message):
                    qualification.exercise(inputs=Path("unused"), probes=Path("unused"), output=Path("unused"),
                                           desktop=qualification.Desktop.GNOME, architecture="x64")
                load.assert_not_called()
                run.assert_not_called()

    def test_menu_keyboard_target_requires_the_real_last_enabled_visible_action(self):
        quit_node = (3, {"label": "Quit Sesori", "enabled": True}, [])
        root = (0, {}, [(1, {"label": "private@example.invalid", "enabled": False}, []), quit_node,
                        (4, {"label": "hidden", "visible": False}, [])])
        qualification.require_quit_at_menu_end(layout=root)
        # DBusMenu omits enabled/visible when their specified default (true) applies.
        qualification.require_quit_at_menu_end(layout=(0, {}, [(3, {"label": "Quit Sesori"}, [])]))
        for last in ((3, {"label": "Quitter"}, []), (3, {"label": "Quit Sesori", "enabled": False}, []),
                     (3, {"label": "Quit Sesori"}, [quit_node])):
            with self.subTest(last_kind=last[1].get("enabled")):
                with self.assertRaisesRegex(ValueError, "enabled Quit Sesori"):
                    qualification.require_quit_at_menu_end(layout=(0, {}, [last]))

    def test_popup_discovery_reads_only_visible_host_owned_window_metadata(self):
        with mock.patch.object(qualification, "run", side_effect=["11\n22\n", "_NET_WM_WINDOW_TYPE_NORMAL",
                                                                "_NET_WM_WINDOW_TYPE_POPUP_MENU"]) as run:
            self.assertTrue(qualification.visible_popup(pid=17, env={"DISPLAY": ":95"}))
        self.assertEqual([call.kwargs["arguments"] for call in run.call_args_list], [
            ["xdotool", "search", "--onlyvisible", "--pid", "17"],
            ["xprop", "-id", "11", "_NET_WM_WINDOW_TYPE"], ["xprop", "-id", "22", "_NET_WM_WINDOW_TYPE"]])
        for call in run.call_args_list:
            self.assertEqual(call.kwargs["env"], {"DISPLAY": ":95"})

    def test_pending_popup_retries_while_the_visible_host_window_remains(self):
        with mock.patch.object(qualification, "run", side_effect=["11\n", "_NET_WM_WINDOW_TYPE_DOCK"]) as run:
            self.assertFalse(qualification.visible_popup(pid=17, env={"DISPLAY": ":95"}))
        self.assertEqual(run.call_count, 2)
        for call in run.call_args_list:
            self.assertEqual(call.kwargs["env"], {"DISPLAY": ":95"})

    def test_packaged_helper_listing_refuses_multiple_helpers_or_inspection_failure(self):
        for status, text, expected in ((1, "", None), (0, "71\n", 71)):
            with mock.patch.object(qualification.subprocess, "run", return_value=
                                   subprocess.CompletedProcess([], status, text, "")):
                self.assertEqual(qualification.installed_helper_pid(), expected)
        for status, text in ((0, "71\n72\n"), (2, "")):
            with mock.patch.object(qualification.subprocess, "run", return_value=
                                   subprocess.CompletedProcess([], status, text, "")):
                with self.assertRaises(ValueError):
                    qualification.installed_helper_pid()

    def test_safe_failure_retains_original_cause_without_presenting_sensitive_payload(self):
        original = ValueError("private-token-material")
        failure = qualification.AuthenticatedQualificationFailure(phase="current-on", cause=original)
        self.assertIs(failure.cause, original)
        self.assertNotIn("private-token-material", str(failure))

    def test_native_receipts_require_success_exit_and_only_allow_closed_phase_bound_reasons(self):
        for phase in qualification.ProbePhase:
            qualification.require_probe_success(exit_code=0, receipt=f"PASS {phase}\n", operation=phase)
            for reason in qualification.ProbeFailureReason:
                with self.subTest(phase=phase, reason=reason), \
                        self.assertRaises(qualification.NativeProbeFailure) as error:
                    qualification.require_probe_success(exit_code=1, receipt=f"FAIL {phase} {reason}\n",
                                                        operation=phase)
                self.assertEqual(error.exception.reason, reason)
        for receipt in ("", "PASS onToLogout\n", "FAIL cleanup registrationMissing\n",
                        "FAIL onToLogout private-token\n",
                        "FAIL onToLogout registrationMissing\nprivate-token"):
            with self.subTest(receipt_kind=receipt.split(" ", 1)[0]), \
                    self.assertRaises(qualification.NativeProbeFailure) as error:
                qualification.require_probe_success(exit_code=1, receipt=receipt,
                                                    operation=qualification.ProbePhase.ON_TO_LOGOUT)
            self.assertEqual(error.exception.reason, qualification.ProbeFailureReason.UNEXPECTED)
            self.assertNotIn("private-token", str(error.exception))
        with self.assertRaises(qualification.NativeProbeFailure) as error:
            qualification.require_probe_success(exit_code=0, receipt="FAIL onToLogout registrationMissing\n",
                                                operation=qualification.ProbePhase.ON_TO_LOGOUT)
        self.assertEqual(error.exception.reason, qualification.ProbeFailureReason.REGISTRATION_MISSING)

    def test_public_failure_evidence_adds_only_the_closed_reason_not_error_text_or_receipt(self):
        original = ValueError("private-token private@example.invalid /fixture/private/home")
        native = qualification.NativeProbeFailure(reason=qualification.ProbeFailureReason.REGISTRATION_NOT_CLEARED)
        for cause in (original, native):
            evidence = qualification.public_failure_evidence(phase="current-onToLogout", cause=cause, observations=[])
            expected = {"phase": "current-onToLogout", "errorType": type(cause).__name__, "completedObservations": []}
            if cause is native:
                expected["probeFailureReason"] = "registrationNotCleared"
            self.assertEqual(evidence, expected)
            serialized = json.dumps(evidence)
            for secret in ("private-token", "private@example.invalid", "/fixture/private/home"):
                self.assertNotIn(secret, serialized)
            wrapped = qualification.AuthenticatedQualificationFailure(phase="current-onToLogout", cause=cause)
            self.assertIs(wrapped.cause, cause)

    def test_http_failure_receipts_expose_only_an_exact_phase_and_bounded_status(self):
        for status in (100, 403, 503, 599):
            for exit_code in (0, 1):
                with self.subTest(status=status, exit_code=exit_code), \
                        self.assertRaises(qualification.NativeProbeHttpFailure) as error:
                    qualification.require_probe_success(
                        exit_code=exit_code, receipt=f"FAIL onToLogout bridgeDeletionHttpFailed {status}\n",
                        operation=qualification.ProbePhase.ON_TO_LOGOUT)
                self.assertEqual(error.exception.status_code, status)
                self.assertEqual(error.exception.reason, qualification.ProbeFailureReason.BRIDGE_DELETION_HTTP_FAILED)
        for receipt in ("FAIL onToLogout bridgeDeletionHttpFailed 99\n",
                        "FAIL onToLogout bridgeDeletionHttpFailed 600\n",
                        "FAIL onToLogout bridgeDeletionHttpFailed ４０３\n",
                        "FAIL onToLogout bridgeDeletionHttpFailed 403\nprivate-token",
                        "FAIL onToLogout bridgeDeletionHttpFailed 403 private-token\n",
                        "FAIL cleanup bridgeDeletionHttpFailed 403\n",
                        "FAIL onToLogout registrationNotCleared 403\n"):
            with self.subTest(receipt=receipt), \
                    self.assertRaises(qualification.NativeProbeFailure) as error:
                qualification.require_probe_success(exit_code=1, receipt=receipt,
                                                    operation=qualification.ProbePhase.ON_TO_LOGOUT)
            self.assertEqual(error.exception.reason, qualification.ProbeFailureReason.UNEXPECTED)
            self.assertNotIn("private-token", str(error.exception))

    def test_http_failure_evidence_adds_only_the_bounded_status(self):
        error = qualification.NativeProbeHttpFailure(status_code=403)
        self.assertEqual(qualification.public_failure_evidence(
            phase="current-onToLogout", cause=error, observations=[]), {
                "phase": "current-onToLogout", "errorType": "NativeProbeHttpFailure", "completedObservations": [],
                "probeFailureReason": "bridgeDeletionHttpFailed", "probeHttpStatus": 403,
            })

    def test_native_failure_vocabulary_matches_the_current_dart_fixture(self):
        root = Path(__file__).parents[2]
        source = (root / "client/desktop/test/native/packaged_authenticated_probe.dart").read_text()
        body = re.search(r"enum AuthenticatedProbeFailureReason\(\) \{([^}]+)\}", source).group(1)
        values = set(re.findall(r"^  (\w+),$", body, re.MULTILINE))
        self.assertEqual(values, {reason.value for reason in qualification.ProbeFailureReason})

    def test_current_signed_gui_opens_preserved_data_before_a_new_source_probe(self):
        source = inspect.getsource(qualification.session)
        install = source.index("current = install(candidate=Candidate.CURRENT)")
        gui = source.index("launch(candidate=Candidate.CURRENT, intent=HelperIntent.OFF", install)
        probe = source.index("probe(candidate=Candidate.CURRENT, operation=ProbePhase.OFF_TO_ON,", install)
        self.assertLess(install, gui)
        self.assertLess(gui, probe)
        self.assertEqual(source.count("operation=ProbePhase.LOGIN_ON"), 1)
        self.assertEqual(source.count("credentials.email"), 1)
        self.assertEqual(source.count("credentials.password"), 1)
        self.assertEqual(source.count("private_input=[account_id]"), 3)
        self.assertLess(source.index("with authenticated_cleanup("), source.index("launch(candidate=Candidate.PREVIOUS"))
        self.assertLess(source.index('"apt-get", "remove"'), source.index('output / "result.json"'))
        self.assertIn('"stableAdmission": False', source)
        self.assertIn('"loginSessionAutostartQualified": False', source)
        self.assertIn('"unavailableSecretServiceQualified": False', source)
        self.assertNotIn("Screenshot", source)
        self.assertNotIn('arguments=["import"', source)
        self.assertNotIn('arguments=["tesseract"', source)
        self.assertNotIn("menu.Event(", source)

    def test_cleanup_runs_before_session_teardown_on_success_failure_and_system_exit(self):
        gui = mock.Mock(args=[qualification.APPLICATION])
        keyring = mock.Mock(args=["gnome-keyring-daemon"])
        for failure in (None, RuntimeError("fixture failure"), SystemExit(143)):
            events = []

            def finish(*, operation):
                events.append(operation)

            with self.subTest(failure=type(failure).__name__), \
                    mock.patch.object(qualification, "stop_process", side_effect=lambda **_: events.append("gui")), \
                    mock.patch.object(qualification, "installed_helper_pid", side_effect=[4242, None]) as helper, \
                    mock.patch.object(qualification.time, "sleep"):
                try:
                    with qualification.authenticated_cleanup(processes=[keyring, gui], finish=finish):
                        if failure is not None:
                            raise failure
                except BaseException as error:
                    self.assertIs(error, failure)
            expected = qualification.ProbePhase.ON_TO_LOGOUT if failure is None else qualification.ProbePhase.CLEANUP
            self.assertEqual(events, ["gui", expected])
            self.assertEqual(helper.call_count, 2)

    def test_main_only_native_workflow_credentials_are_exercise_only_and_artifacts_are_allowlisted(self):
        workflows = Path(__file__).parents[1] / "workflows"
        child = (workflows / "desktop-linux-authenticated-upgrade.yml").read_text()
        self.assertIn("if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'", child)
        self.assertIn("runner: ubuntu-24.04\n", child)
        self.assertIn("runner: ubuntu-24.04-arm\n", child)
        self.assertIn("max-parallel: 1", child)
        self.assertNotIn("default:", child)
        self.assertNotIn("id-token: write", child)
        self.assertNotIn("environment:", child)
        self.assertNotIn("linux-signing", child)
        validation = child.split("      - name: Require explicit retained signed producer pair\n", 1)[1].split(
            "      - uses: actions/checkout@", 1)[0]
        for candidate in ("previous", "current"):
            self.assertIn(candidate.upper() + "_RUN: ${{ inputs." + candidate + "_run }}", validation)
            self.assertIn("run-id: ${{ inputs." + candidate + "_run }}", child)
        self.assertIn('"$PREVIOUS_RUN" =~ ^[1-9][0-9]*$', validation)
        self.assertIn('"$CURRENT_RUN" =~ ^[1-9][0-9]*$', validation)
        self.assertIn('"$PREVIOUS_RUN" != "$CURRENT_RUN"', validation)
        self.assertIn("exit 1", validation)
        self.assertLess(child.index("      - name: Require explicit retained signed producer pair\n"),
                        child.index("      - uses: actions/download-artifact@"))
        exercise = child.split("      - name: Exercise real account", 1)[1].split("      - name: Retain", 1)[0]
        for key in (credentials.AUTH_EMAIL_ENVIRONMENT_KEY, credentials.AUTH_PASSWORD_ENVIRONMENT_KEY):
            self.assertEqual(child.count("${{ secrets." + key + " }}"), 1)
            self.assertIn("${{ secrets." + key + " }}", exercise)
        self.assertNotIn("dbus-run-session --", exercise)
        self.assertIn("python .github/scripts/qualify_desktop_linux_authenticated_upgrade.py exercise", exercise)
        upload = child.split("uses: actions/upload-artifact@v4", 1)[1]
        self.assertIn("build/linux-authenticated-evidence/result.json\n", upload)
        self.assertIn("build/linux-authenticated-evidence/failure.json\n", upload)
        self.assertNotIn("*", upload)
        self.assertNotIn("private", upload)
        parent = (workflows / "desktop-qualification.yml").read_text()
        job = parent.split("  linux-authenticated-upgrade:\n", 1)[1].split("  macos-authenticated-upgrade:\n", 1)[0]
        self.assertIn("github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'", job)
        self.assertIn("inputs.mode == 'linux-authenticated-upgrade-probe'", job)
        self.assertIn("previous_run: ${{ inputs.previous_packaging_run }}", job)
        self.assertIn("current_run: ${{ inputs.packaging_run }}", job)
        self.assertNotIn("secrets: inherit", job)
        self.assertEqual(job.count("${{ secrets."), 2)
        concurrency = parent.split("concurrency:\n", 1)[1].split("jobs:\n", 1)[0]
        modes = re.findall(r"contains\(fromJSON\('([^']+)'\), inputs.mode\)", concurrency)
        self.assertEqual(len(modes), 1)
        self.assertEqual(set(json.loads(modes[0])),
                         {"macos-authenticated-upgrade-probe", "linux-authenticated-upgrade-probe"})
        self.assertIn("github.run_id || inputs.mode == 'linux-interactive-debug'", concurrency)
        self.assertIn("inputs.mode == 'linux-session' && 'linux-session'", concurrency)
        self.assertIn("inputs.mode == 'linux-packaging' && 'linux' || 'other'", concurrency)
        self.assertIn("cancel-in-progress: true", concurrency)
        self.assertNotIn("queue:", concurrency)
        for name in ("linux-authenticated-upgrade", "macos-authenticated-upgrade"):
            authenticated_job = re.split(r"\n  [\w-]+:\n", parent.split("  " + name + ":\n", 1)[1], maxsplit=1)[0]
            self.assertIn("github.ref == 'refs/heads/main'", authenticated_job)
            self.assertIn("    concurrency:\n"
                          "      group: desktop-authenticated-qualification\n"
                          "      queue: max\n"
                          "      cancel-in-progress: false\n", authenticated_job)


if __name__ == "__main__":
    unittest.main()
