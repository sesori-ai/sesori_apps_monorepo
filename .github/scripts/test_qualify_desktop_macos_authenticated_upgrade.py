import ast
import base64
import inspect
import json
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest
import urllib.error
from unittest.mock import Mock, patch

from qualify_desktop_macos_authenticated_upgrade import (
    AUTH_EMAIL_ENVIRONMENT_KEY,
    AUTH_PASSWORD_ENVIRONMENT_KEY,
    KEYCHAIN_ACCOUNTS,
    KEYCHAIN_SERVICE,
    BridgeLogCursor,
    KeychainSession,
    QaCredentials,
    _keychain_writer,
    cleanup_qualification,
    delete_auth_keychain,
    launch_authenticated_and_quit,
    load_qa_credentials,
    parse_keychain_session,
    qualification_cleanup,
    qualify,
    request_qa_session,
    require_auth_keychain_absent,
    require_auth_keychain_session,
    update_auth_keychain,
    wait_for_authenticated_helper,
    write_auth_keychain,
)


WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"
KEYCHAIN_WRITER = Path(__file__).with_name("write_desktop_macos_keychain.swift")


def dotted_name(node: ast.expr) -> str:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        owner = dotted_name(node.value)
        return f"{owner}.{node.attr}" if owner else node.attr
    return ""


def call_events(function: object) -> list[dict[str, object]]:
    tree = ast.parse(textwrap.dedent(inspect.getsource(function)))
    events: list[dict[str, object]] = []
    for node in ast.walk(tree):
        call: ast.Call | None = None
        assigned_to: str | None = None
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call):
            call = node.value
            if len(node.targets) == 1:
                assigned_to = dotted_name(node.targets[0])
        elif isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
            call = node.value
        if call is None:
            continue
        events.append({
            "line": node.lineno,
            "column": node.col_offset,
            "name": dotted_name(call.func),
            "assignedTo": assigned_to,
            "keywords": {keyword.arg: ast.unparse(keyword.value) for keyword in call.keywords},
        })
    return sorted(events, key=lambda event: (event["line"], event["column"]))


def find_event(
    *,
    events: list[dict[str, object]],
    name: str,
    assigned_to: str | None = None,
    keyword: tuple[str, str] | None = None,
) -> dict[str, object]:
    for event in events:
        if event["name"] != name:
            continue
        if assigned_to is not None and event["assignedTo"] != assigned_to:
            continue
        keywords = event["keywords"]
        if keyword is not None and isinstance(keywords, dict) and keywords.get(keyword[0]) != keyword[1]:
            continue
        return event
    raise AssertionError(f"Missing call event for {name}")


def bridge_log_cursor(*, path: Path, offset: int) -> BridgeLogCursor:
    status = path.stat()
    return BridgeLogCursor(device=status.st_dev, inode=status.st_ino, offset=offset)


def jwt(*, expiration: int) -> str:
    def encoded(value: object) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode("utf-8")
        return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")

    return f"{encoded({'alg': 'none'})}.{encoded({'exp': expiration})}.signature"


class MacosAuthenticatedUpgradeTests(unittest.TestCase):
    def test_parses_fresh_email_session_for_exact_keychain_shape(self):
        session = parse_keychain_session(
            payload={
                "accessToken": jwt(expiration=2_000),
                "refreshToken": jwt(expiration=3_000),
                "accountStatus": "active",
                "user": {
                    "id": "user-id",
                    "provider": "email",
                    "providerUserId": "provider-id",
                    "providerUsername": "qa-user",
                },
            },
            now=1_000,
        )

        self.assertEqual(tuple(account for account, _ in session.values), KEYCHAIN_ACCOUNTS)
        self.assertEqual(json.loads(session.auth_user)["provider"], "email")

    def test_rejects_expiring_or_non_email_session(self):
        valid = {
            "accessToken": jwt(expiration=2_000),
            "refreshToken": jwt(expiration=3_000),
            "user": {
                "id": "user-id",
                "provider": "github",
                "providerUserId": "provider-id",
                "providerUsername": None,
            },
        }
        with self.assertRaisesRegex(ValueError, "expected email provider"):
            parse_keychain_session(payload=valid, now=1_000)

        valid["user"]["provider"] = "email"
        valid["accessToken"] = jwt(expiration=1_100)
        with self.assertRaisesRegex(ValueError, "expires too soon"):
            parse_keychain_session(payload=valid, now=1_000)

    def test_loads_credentials_only_from_the_scoped_environment(self):
        with patch.dict(
            os.environ,
            {
                AUTH_EMAIL_ENVIRONMENT_KEY: "qa@example.test",
                AUTH_PASSWORD_ENVIRONMENT_KEY: "private-password",
            },
            clear=True,
        ):
            credentials = load_qa_credentials()
            self.assertNotIn(AUTH_EMAIL_ENVIRONMENT_KEY, os.environ)
            self.assertNotIn(AUTH_PASSWORD_ENVIRONMENT_KEY, os.environ)

        self.assertEqual(credentials.email, "qa@example.test")
        self.assertEqual(credentials.password, "private-password")

    def test_http_auth_failure_retains_the_native_error_as_its_cause(self):
        native_error = urllib.error.HTTPError(
            url="https://api.sesori.com/auth/email",
            code=429,
            msg="Too Many Requests",
            hdrs=None,
            fp=None,
        )
        credentials = QaCredentials(email="qa@example.test", password="private-password")
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.urllib.request.urlopen",
            side_effect=native_error,
        ):
            with self.assertRaisesRegex(RuntimeError, "HTTP 429") as raised:
                request_qa_session(credentials=credentials)

        self.assertIs(raised.exception.__cause__, native_error)
        native_error.close()

    def test_requires_all_auth_keychain_items_to_be_absent(self):
        not_found = subprocess.CompletedProcess(args=[], returncode=44, stdout="", stderr="")
        with patch("qualify_desktop_macos_authenticated_upgrade._security", return_value=not_found) as security:
            require_auth_keychain_absent()

        self.assertEqual(security.call_count, len(KEYCHAIN_ACCOUNTS))
        for call, account in zip(security.call_args_list, KEYCHAIN_ACCOUNTS, strict=True):
            self.assertEqual(
                call.kwargs["arguments"],
                ["find-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE],
            )

    def test_native_keychain_writer_reads_secret_only_from_stdin(self):
        source = KEYCHAIN_WRITER.read_text(encoding="utf-8")
        self.assertIn("FileHandle.standardInput.readDataToEndOfFile()", source)
        self.assertIn("FileManager.default.currentDirectoryPath", source)
        self.assertNotIn("let password = CommandLine.arguments", source)
        self.assertNotIn("add-generic-password", source)

    def test_keychain_values_use_stdin_and_never_process_arguments(self):
        session = KeychainSession(
            access_token="private-access-token",
            refresh_token="private-refresh-token",
            auth_user='{"private":"user"}',
        )
        created: list[str] = []
        writer = Path(tempfile.gettempdir()) / "keychain-writer"
        success = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.APPLICATION",
            Path(tempfile.gettempdir()) / "Sesori.app",
        ), patch.object(Path, "is_file", return_value=True), patch(
            "qualify_desktop_macos_authenticated_upgrade._keychain_writer",
            return_value=success,
        ) as keychain_writer:
            write_auth_keychain(writer=writer, session=session, created_accounts=created)

        self.assertEqual(created, list(KEYCHAIN_ACCOUNTS))
        for call, (account, secret) in zip(keychain_writer.call_args_list, session.values, strict=True):
            self.assertEqual(call.kwargs["writer"], writer)
            self.assertEqual(call.kwargs["operation"], "create")
            self.assertEqual(call.kwargs["account"], account)
            self.assertEqual(call.kwargs["secret_input"], secret)

    def test_phase_refresh_updates_every_keychain_item_without_exposing_values(self):
        session = KeychainSession(
            access_token="new-private-access",
            refresh_token="new-private-refresh",
            auth_user='{"private":"new-user"}',
        )
        writer = Path(tempfile.gettempdir()) / "keychain-writer"
        success = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.APPLICATION",
            Path(tempfile.gettempdir()) / "Sesori.app",
        ), patch.object(Path, "is_file", return_value=True), patch(
            "qualify_desktop_macos_authenticated_upgrade._keychain_writer",
            return_value=success,
        ) as keychain_writer:
            update_auth_keychain(writer=writer, session=session)

        self.assertEqual(keychain_writer.call_count, len(KEYCHAIN_ACCOUNTS))
        for call, (account, secret) in zip(keychain_writer.call_args_list, session.values, strict=True):
            self.assertEqual(call.kwargs["operation"], "update")
            self.assertEqual(call.kwargs["account"], account)
            self.assertEqual(call.kwargs["secret_input"], secret)

    def test_keychain_writer_uses_stdin_and_redacts_native_stderr(self):
        native = subprocess.CompletedProcess(
            args=["keychain-writer"],
            returncode=36,
            stdout="",
            stderr="Keychain locked while storing private-token",
        )
        writer = Path(tempfile.gettempdir()) / "keychain-writer"
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.subprocess.run",
            return_value=native,
        ) as run:
            result = _keychain_writer(
                writer=writer,
                operation="create",
                account="access_token",
                secret_input="private-token",
            )

        arguments = run.call_args.args[0]
        self.assertNotIn("private-token", arguments)
        self.assertEqual(run.call_args.kwargs["input"], "private-token\n")
        self.assertEqual(result.returncode, 36)
        self.assertIn("Keychain locked", result.stderr)
        self.assertNotIn("private-token", result.stderr)

    def test_keychain_write_failure_surfaces_safe_native_diagnostics(self):
        session = KeychainSession(access_token="secret", refresh_token="refresh", auth_user="user")
        failed = subprocess.CompletedProcess(
            args=[],
            returncode=36,
            stdout="secret must stay hidden",
            stderr="security: User interaction is not allowed.",
        )
        created_accounts: list[str] = []
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.APPLICATION",
            Path(tempfile.gettempdir()) / "Sesori.app",
        ), patch.object(Path, "is_file", return_value=True), patch(
            "qualify_desktop_macos_authenticated_upgrade._keychain_writer",
            return_value=failed,
        ):
            with self.assertRaisesRegex(RuntimeError, "security exited 36.*User interaction") as raised:
                write_auth_keychain(
                    writer=Path(tempfile.gettempdir()) / "keychain-writer",
                    session=session,
                    created_accounts=created_accounts,
                )

        self.assertEqual(created_accounts, ["access_token"])
        self.assertNotIn("secret must stay hidden", str(raised.exception))
        self.assertNotIn("secret", str(raised.exception).split("security exited", 1)[-1])

    def test_keychain_session_accepts_equivalent_reserialized_user_json(self):
        session = KeychainSession(
            access_token="access",
            refresh_token="refresh",
            auth_user='{"id":"user","provider":"email"}',
        )
        observed = {
            "access_token": "access",
            "refresh_token": "refresh",
            "auth_user": '{"provider": "email", "id": "user"}',
        }
        with tempfile.TemporaryDirectory() as directory, patch(
            "qualify_desktop_macos_authenticated_upgrade.read_auth_keychain",
            side_effect=lambda *, account: observed[account],
        ):
            require_auth_keychain_session(
                expected=session,
                label="current",
                output=Path(directory),
            )
            self.assertIn(
                "AUTH_USER_PRESENT",
                (Path(directory) / "current-keychain.log").read_text(encoding="utf-8"),
            )

    def test_keychain_cleanup_is_limited_to_probe_created_accounts(self):
        success = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch(
            "qualify_desktop_macos_authenticated_upgrade._security",
            return_value=success,
        ) as security:
            delete_auth_keychain(created_accounts=["access_token", "auth_user"])

        self.assertEqual(
            [call.kwargs["arguments"] for call in security.call_args_list],
            [
                ["delete-generic-password", "-a", "auth_user", "-s", KEYCHAIN_SERVICE],
                ["delete-generic-password", "-a", "access_token", "-s", KEYCHAIN_SERVICE],
            ],
        )

    def test_cleanup_still_removes_keychain_when_app_removal_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            application = root / "Sesori.app"
            application.mkdir()
            with patch(
                "qualify_desktop_macos_authenticated_upgrade.APPLICATION",
                application,
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.REGISTRATION",
                root / "missing-registration",
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.SUPPORT_ROOT",
                root / "missing-support",
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.SHARED_DATA_ROOT",
                root / "missing-shared",
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.ATTACHMENTS_ROOT",
                root / "missing-attachments",
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade._terminate_probe_processes",
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.shutil.rmtree",
                side_effect=OSError("refused"),
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.delete_auth_keychain",
            ) as delete_keychain, patch(
                "qualify_desktop_macos_authenticated_upgrade.owned_processes",
                return_value="",
            ):
                with self.assertRaisesRegex(RuntimeError, "installed app"):
                    cleanup_qualification(created_keychain_accounts=["access_token"])

            delete_keychain.assert_called_once_with(created_accounts=["access_token"])

    def test_cleanup_failure_is_grouped_with_the_primary_qualification_failure(self):
        cleanup = Mock(side_effect=RuntimeError("cleanup failed"))
        with self.assertRaises(ExceptionGroup) as raised:
            with qualification_cleanup(cleanup=cleanup):
                raise ValueError("qualification failed")

        self.assertEqual(len(raised.exception.exceptions), 2)
        self.assertIsInstance(raised.exception.exceptions[0], ValueError)
        self.assertEqual(str(raised.exception.exceptions[0]), "qualification failed")
        self.assertIsInstance(raised.exception.exceptions[1], RuntimeError)
        self.assertEqual(str(raised.exception.exceptions[1]), "cleanup failed")

    def test_cleanup_runs_and_groups_failure_for_base_exceptions(self):
        cleanup = Mock(side_effect=RuntimeError("cleanup failed"))
        with self.assertRaises(BaseExceptionGroup) as raised:
            with qualification_cleanup(cleanup=cleanup):
                raise KeyboardInterrupt("interrupted")

        self.assertIsInstance(raised.exception.exceptions[0], KeyboardInterrupt)
        self.assertIsInstance(raised.exception.exceptions[1], RuntimeError)

    def test_helper_observation_records_only_bounded_boolean_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            stale = "Authenticated as stale-user\nWaiting for relay events...\n"
            bridge_log.write_text(
                stale + "Authenticated as private-user-value\nWaiting for relay events...\nprivate-token-value\n",
                encoding="utf-8",
            )
            launcher = Mock()
            launcher.poll.return_value = None
            with patch(
                "qualify_desktop_macos_authenticated_upgrade.installed_helper_processes",
                return_value="501 /Applications/Sesori.app/Contents/Helpers/bridge/bin/bridge",
            ):
                wait_for_authenticated_helper(
                    label="current",
                    launcher=launcher,
                    output=root,
                    bridge_log=bridge_log,
                    bridge_log_cursor=bridge_log_cursor(
                        path=bridge_log,
                        offset=len(stale.encode("utf-8")),
                    ),
                )

            recorded = (root / "current-authenticated-helper.json").read_text(encoding="utf-8")
            self.assertNotIn("private-user-value", recorded)
            self.assertNotIn("private-token-value", recorded)
            self.assertEqual(
                json.loads(recorded),
                {
                    "helperProcessCount": 1,
                    "helperPid": 501,
                    "authenticatedProfileConfirmed": True,
                    "relayServing": True,
                },
            )

    def test_helper_observation_reanchors_when_active_log_rotates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            bridge_log.write_text("old\n", encoding="utf-8")
            pre_rotation_cursor = bridge_log_cursor(path=bridge_log, offset=bridge_log.stat().st_size)
            replacement = root / "bridge.log.replacement"
            replacement.write_text(
                "Authenticated as current-user\nWaiting for relay events...\nnew file exceeds old offset\n",
                encoding="utf-8",
            )
            replacement.replace(bridge_log)
            self.assertGreater(bridge_log.stat().st_size, pre_rotation_cursor.offset)
            self.assertNotEqual(bridge_log.stat().st_ino, pre_rotation_cursor.inode)
            launcher = Mock()
            launcher.poll.return_value = None
            with patch(
                "qualify_desktop_macos_authenticated_upgrade.installed_helper_processes",
                return_value="501 exact-helper",
            ):
                helper_pid = wait_for_authenticated_helper(
                    label="current",
                    launcher=launcher,
                    output=root,
                    bridge_log=bridge_log,
                    bridge_log_cursor=pre_rotation_cursor,
                )

            self.assertEqual(helper_pid, 501)

    def test_helper_timeout_does_not_copy_raw_bridge_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            bridge_log.write_text("private-token-value\n", encoding="utf-8")
            launcher = Mock()
            launcher.poll.return_value = None
            with patch(
                "qualify_desktop_macos_authenticated_upgrade.installed_helper_processes",
                return_value="",
            ), patch("qualify_desktop_macos_authenticated_upgrade.HELPER_WAIT_SECONDS", 0):
                with self.assertRaisesRegex(RuntimeError, "did not become ready"):
                    wait_for_authenticated_helper(
                        label="current",
                        launcher=launcher,
                        output=root,
                        bridge_log=bridge_log,
                    )

            recorded = (root / "current-authenticated-helper.json").read_text(encoding="utf-8")
            self.assertNotIn("private-token-value", recorded)

    def test_current_launch_ignores_authenticated_markers_from_previous_log_segment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            stale = "Authenticated as previous-user\nWaiting for relay events...\n"
            bridge_log.write_text(stale + "current launch has not authenticated\n", encoding="utf-8")
            launcher = Mock()
            launcher.poll.return_value = None
            with patch(
                "qualify_desktop_macos_authenticated_upgrade.installed_helper_processes",
                return_value="501 exact-helper",
            ), patch("qualify_desktop_macos_authenticated_upgrade.HELPER_WAIT_SECONDS", 0):
                with self.assertRaisesRegex(RuntimeError, "did not become ready"):
                    wait_for_authenticated_helper(
                        label="current",
                        launcher=launcher,
                        output=root,
                        bridge_log=bridge_log,
                        bridge_log_cursor=bridge_log_cursor(
                            path=bridge_log,
                            offset=len(stale.encode("utf-8")),
                        ),
                    )

            recorded = json.loads((root / "current-authenticated-helper.json").read_text(encoding="utf-8"))
            self.assertFalse(recorded["authenticatedProfileConfirmed"])
            self.assertFalse(recorded["relayServing"])

    def test_helper_restart_requires_fresh_markers_from_the_new_pid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            bridge_log.write_text("", encoding="utf-8")
            launcher = Mock()
            launcher.poll.return_value = None
            sleep_count = 0

            def advance_log(_seconds: float) -> None:
                nonlocal sleep_count
                sleep_count += 1
                with bridge_log.open("a", encoding="utf-8") as stream:
                    if sleep_count == 1:
                        stream.write("Authenticated as first-helper\nWaiting for relay events...\n")
                    elif sleep_count == 2:
                        stream.write("Authenticated as second-helper\nWaiting for relay events...\n")

            with patch(
                "qualify_desktop_macos_authenticated_upgrade.installed_helper_processes",
                side_effect=["501 first-helper", "502 second-helper", "502 second-helper"],
            ), patch(
                "qualify_desktop_macos_authenticated_upgrade.time.sleep",
                side_effect=advance_log,
            ):
                helper_pid = wait_for_authenticated_helper(
                    label="current",
                    launcher=launcher,
                    output=root,
                    bridge_log=bridge_log,
                )

            self.assertEqual(helper_pid, 502)
            self.assertEqual(sleep_count, 2)
            recorded = json.loads((root / "current-authenticated-helper.json").read_text(encoding="utf-8"))
            self.assertEqual(recorded["helperPid"], 502)
            self.assertTrue(recorded["authenticatedProfileConfirmed"])
            self.assertTrue(recorded["relayServing"])

    def test_authenticated_helper_is_observed_and_remains_same_process_before_real_tray_quit(self):
        events = call_events(launch_authenticated_and_quit)
        launch = find_event(events=events, name="subprocess.Popen", assigned_to="launcher")
        observation = find_event(events=events, name="wait_for_authenticated_helper")
        window = find_event(events=events, name="wait_for_visible_window")
        current_process = find_event(events=events, name="_helper_pid")
        tray_quit = find_event(events=events, name="subprocess.run", assigned_to="quit_result")
        self.assertEqual(observation["keywords"]["bridge_log_cursor"], "bridge_log_cursor")
        tree = ast.parse(textwrap.dedent(inspect.getsource(launch_authenticated_and_quit)))
        baseline = next(
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.Assign)
            and any(dotted_name(target) == "bridge_log_cursor" for target in node.targets)
        )
        self.assertLess(baseline.lineno, launch["line"])
        self.assertLess(launch["line"], observation["line"])
        self.assertLess(observation["line"], window["line"])
        self.assertLess(window["line"], current_process["line"])
        self.assertLess(current_process["line"], tray_quit["line"])
        tree = ast.parse(textwrap.dedent(inspect.getsource(launch_authenticated_and_quit)))
        guard = next(
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and dotted_name(node.func) == "require"
            and "authenticated helper exited or was replaced before tray Quit" in ast.unparse(node)
        )
        self.assertEqual(
            ast.unparse(guard.args[0]),
            "helper_process_count == 1 and current_helper_pid == authenticated_helper_pid",
        )
        self.assertFalse(any(event["name"] == "screencapture" for event in events))

    def test_qualification_seeds_on_and_phase_fresh_keychain_before_each_launch(self):
        events = call_events(qualify)
        credentials = find_event(events=events, name="load_qa_credentials", assigned_to="credentials")
        fresh_runner = find_event(events=events, name="require_fresh_native_runner")
        on_intent = find_event(events=events, name="desired_state.write_text")
        previous_launch = find_event(
            events=events,
            name="launch_authenticated_and_quit",
            keyword=("label", "'previous'"),
        )
        replacement_session = find_event(
            events=events,
            name="request_qa_session",
            assigned_to="replacement_session",
        )
        replacement_keychain = find_event(events=events, name="update_auth_keychain")
        remove_previous = find_event(events=events, name="shutil.rmtree")
        current_install = find_event(
            events=events,
            name="install_candidate",
            keyword=("candidate", "current"),
        )
        current_validity = find_event(
            events=events,
            name="require_session_valid_for",
            keyword=("label", "'current launch'"),
        )
        current_launch = find_event(
            events=events,
            name="launch_authenticated_and_quit",
            keyword=("label", "'current'"),
        )
        self.assertLess(credentials["line"], fresh_runner["line"])
        self.assertLess(on_intent["line"], previous_launch["line"])
        self.assertLess(previous_launch["line"], replacement_session["line"])
        self.assertLess(replacement_session["line"], replacement_keychain["line"])
        self.assertLess(replacement_keychain["line"], remove_previous["line"])
        self.assertLess(remove_previous["line"], current_install["line"])
        self.assertLess(current_install["line"], current_validity["line"])
        self.assertLess(current_validity["line"], current_launch["line"])
        self.assertTrue(
            any(
                isinstance(constant, str) and "failed-stop refusal" in constant
                for constant in qualify.__code__.co_consts
            ),
        )

    def test_workflow_scopes_credentials_to_serial_main_only_environment_job(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        job_start = workflow.index("  macos-authenticated-upgrade:")
        job_end = workflow.index("\n  windows-distribution:", job_start)
        job = workflow[job_start:job_end]

        self.assertIn("inputs.mode == 'macos-authenticated-upgrade-probe'", job)
        self.assertIn("environment: desktop-qa", job)
        self.assertIn("max-parallel: 1", job)
        guard = job.index('if [[ "$GITHUB_REF" != "refs/heads/main" ]]')
        exercise = job.index("qualify_desktop_macos_authenticated_upgrade.py")
        self.assertLess(guard, exercise)
        self.assertIn("CHANNEL: ${{ inputs.channel }}", job)
        self.assertIn(' --channel "$CHANNEL"', job)
        self.assertNotIn("--channel '${{ inputs.channel }}'", job)
        self.assertIn("SESORI_DESKTOP_QA_EMAIL: ${{ secrets.DESKTOP_QA_EMAIL }}", job)
        self.assertIn("SESORI_DESKTOP_QA_PASSWORD: ${{ secrets.DESKTOP_QA_PASSWORD }}", job)
        self.assertNotIn("--email", job)
        self.assertNotIn("--password", job)
        self.assertNotIn("MACOS_CERT", job)
        self.assertNotIn("contents: write", job)
        self.assertEqual(job.count("secrets."), 2)
        self.assertIn("desktop-macos-authenticated-upgrade-evidence-${{ matrix.architecture }}", job)


if __name__ == "__main__":
    unittest.main()
