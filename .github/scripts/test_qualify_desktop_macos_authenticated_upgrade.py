import base64
import inspect
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from qualify_desktop_macos_authenticated_upgrade import (
    AUTH_EMAIL_ENVIRONMENT_KEY,
    AUTH_PASSWORD_ENVIRONMENT_KEY,
    KEYCHAIN_ACCOUNTS,
    KEYCHAIN_SERVICE,
    KeychainSession,
    cleanup_qualification,
    delete_auth_keychain,
    launch_authenticated_and_quit,
    load_qa_credentials,
    parse_keychain_session,
    qualify,
    require_auth_keychain_absent,
    require_auth_keychain_session,
    wait_for_authenticated_helper,
    write_auth_keychain,
)


WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/desktop-qualification.yml"


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

    def test_keychain_values_use_stdin_and_never_process_arguments(self):
        session = KeychainSession(
            access_token="private-access-token",
            refresh_token="private-refresh-token",
            auth_user='{"private":"user"}',
        )
        created: list[str] = []
        success = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with patch(
            "qualify_desktop_macos_authenticated_upgrade.APPLICATION",
            Path(tempfile.gettempdir()) / "Sesori.app",
        ), patch.object(Path, "is_file", return_value=True), patch(
            "qualify_desktop_macos_authenticated_upgrade._security",
            return_value=success,
        ) as security:
            write_auth_keychain(session=session, created_accounts=created)

        self.assertEqual(created, list(KEYCHAIN_ACCOUNTS))
        secrets = [value for _, value in session.values]
        for call, secret in zip(security.call_args_list, secrets, strict=True):
            arguments = call.kwargs["arguments"]
            self.assertEqual(arguments[-1], "-w")
            self.assertEqual(call.kwargs["secret_input"], secret)
            self.assertFalse(any(secret in argument for argument in arguments))

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

    def test_helper_observation_records_only_bounded_boolean_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bridge_log = root / "bridge.log"
            bridge_log.write_text(
                "Authenticated as private-user-value\nWaiting for relay events...\nprivate-token-value\n",
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
                )

            recorded = (root / "current-authenticated-helper.json").read_text(encoding="utf-8")
            self.assertNotIn("private-user-value", recorded)
            self.assertNotIn("private-token-value", recorded)
            self.assertEqual(
                json.loads(recorded),
                {
                    "helperProcessCount": 1,
                    "authenticatedProfileConfirmed": True,
                    "relayServing": True,
                },
            )

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
                        bridge_log_offset=len(stale.encode("utf-8")),
                    )

            recorded = json.loads((root / "current-authenticated-helper.json").read_text(encoding="utf-8"))
            self.assertFalse(recorded["authenticatedProfileConfirmed"])
            self.assertFalse(recorded["relayServing"])

    def test_authenticated_helper_is_observed_before_real_tray_quit(self):
        source = inspect.getsource(launch_authenticated_and_quit)
        observation = source.index("wait_for_authenticated_helper(")
        tray_quit = source.index("quit_result = subprocess.run")
        self.assertLess(observation, tray_quit)
        self.assertIn("application/helper remained or relaunched after Quit", source)
        self.assertIn("private_app_log = SUPPORT_ROOT", source)
        self.assertNotIn("screencapture", source)

    def test_qualification_seeds_on_before_previous_launch_and_reuses_keychain(self):
        source = inspect.getsource(qualify)
        credentials = source.index("credentials = load_qa_credentials()")
        fresh_runner = source.index("require_fresh_native_runner()")
        self.assertLess(credentials, fresh_runner)
        on_intent = source.index('desired_state.write_text("on\\n"')
        previous_launch = source.index("launch_authenticated_and_quit(", on_intent)
        replacement_keychain = source.index('label="replacement"', previous_launch)
        current_launch = source.index("launch_authenticated_and_quit(", replacement_keychain)
        self.assertLess(on_intent, previous_launch)
        self.assertLess(previous_launch, replacement_keychain)
        self.assertLess(replacement_keychain, current_launch)
        self.assertIn("failed-stop refusal", source)

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
