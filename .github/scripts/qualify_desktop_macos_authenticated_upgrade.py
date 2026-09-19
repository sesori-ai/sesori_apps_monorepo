#!/usr/bin/env python3
"""Qualify private signed macOS N→N+1 replacement with an authenticated helper On."""

import argparse
import base64
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from functools import partial
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import urllib.error
import urllib.request

from package_desktop_macos import execute
from qualify_desktop_macos_upgrade import (
    APPLICATION,
    ATTACHMENTS_ROOT,
    REGISTRATION,
    SHARED_DATA_ROOT,
    SUPPORT_ROOT,
    compile_native_helpers,
    install_candidate,
    installed_helper_processes,
    load_candidate,
    owned_processes,
    read_json_array,
    require,
    require_fresh_native_runner,
    require_trusted_source,
    seed_login_registration,
    sha256,
    validate_upgrade,
    wait_for_visible_window,
)


AUTH_ENDPOINT = "https://api.sesori.com/auth/email"
AUTH_EMAIL_ENVIRONMENT_KEY = "SESORI_DESKTOP_QA_EMAIL"
AUTH_PASSWORD_ENVIRONMENT_KEY = "SESORI_DESKTOP_QA_PASSWORD"
KEYCHAIN_SERVICE = "com.sesori.desktop"
KEYCHAIN_ACCOUNTS = ("access_token", "refresh_token", "auth_user")
KEYCHAIN_WRITER_SOURCE = Path(__file__).with_name("write_desktop_macos_keychain.swift")
BRIDGE_LOG = SUPPORT_ROOT / "logs/bridge.log"
HELPER_WAIT_SECONDS = 60.0
HELPER_POLL_INTERVAL_SECONDS = 0.1
KEYCHAIN_COMMAND_TIMEOUT_SECONDS = 15
MIN_SESSION_VALIDITY_SECONDS = 600
# Covers 15s process admission + 60s helper + 45s window + 30s Quit + 5s absence, with margin.
MIN_LAUNCH_VALIDITY_SECONDS = 180
PRIVATE_APP_LOG_DIAGNOSTIC_LIMIT_BYTES = 1024 * 1024
PRIVATE_APP_LOG_DIAGNOSTIC_MARKERS = (
    ("desktopStartupRendered", ("Desktop startup: rendering the application",)),
    ("localSessionUnavailable", ("Desktop auth gate found no locally valid session",)),
    (
        "localUserRestoreIncomplete",
        (
            "Desktop auth gate could not restore the local session",
            "Failed to restore the local auth session",
        ),
    ),
    ("desiredStateRestoreFailure", ("Failed to restore the desktop bridge's desired On state",)),
    (
        "bridgeStartFailure",
        (
            "Bridge start after successful authentication",
            "Failed to start the desktop bridge after first sign-in",
            "BridgeExecutableResolutionException",
            "Bridge startup failed after its process exit was already claimed",
        ),
    ),
)


@dataclass(frozen=True)
class QaCredentials:
    email: str
    password: str


@dataclass(frozen=True)
class KeychainSession:
    access_token: str
    refresh_token: str
    auth_user: str

    @property
    def values(self) -> tuple[tuple[str, str], ...]:
        return (
            ("access_token", self.access_token),
            ("refresh_token", self.refresh_token),
            ("auth_user", self.auth_user),
        )


@dataclass(frozen=True)
class BridgeLogCursor:
    device: int
    inode: int
    offset: int


def capture_bridge_log_cursor(*, path: Path) -> BridgeLogCursor | None:
    try:
        status = path.stat()
    except FileNotFoundError:
        return None
    return BridgeLogCursor(device=status.st_dev, inode=status.st_ino, offset=status.st_size)


def load_qa_credentials() -> QaCredentials:
    # Consume once, then remove both values before any child process is launched.
    email = os.environ.pop(AUTH_EMAIL_ENVIRONMENT_KEY, "")
    password = os.environ.pop(AUTH_PASSWORD_ENVIRONMENT_KEY, "")
    require(bool(email.strip()), f"{AUTH_EMAIL_ENVIRONMENT_KEY} is required")
    require(bool(password), f"{AUTH_PASSWORD_ENVIRONMENT_KEY} is required")
    require("\n" not in email and "\n" not in password, "QA credentials must be single-line values")
    return QaCredentials(email=email, password=password)


def _jwt_expiration(token: str) -> int:
    parts = token.split(".")
    require(len(parts) == 3, "QA auth returned a non-JWT token")
    try:
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
    except (ValueError, json.JSONDecodeError) as error:
        raise ValueError("QA auth returned an unreadable JWT") from error
    require(isinstance(claims, dict), "QA auth JWT payload is not an object")
    expiration = claims.get("exp")
    require(isinstance(expiration, int), "QA auth JWT has no integer expiration")
    return expiration


def require_session_valid_for(
    *,
    session: KeychainSession,
    minimum_seconds: int,
    label: str,
    now: float | None = None,
) -> None:
    current_time = time.time() if now is None else now
    require(
        _jwt_expiration(session.access_token) > current_time + minimum_seconds,
        f"{label}: QA access token expires too soon",
    )
    require(
        _jwt_expiration(session.refresh_token) > current_time + minimum_seconds,
        f"{label}: QA refresh token expires too soon",
    )


def parse_keychain_session(*, payload: object, now: float | None = None) -> KeychainSession:
    require(isinstance(payload, dict), "QA auth response is not an object")
    access_token = payload.get("accessToken")
    refresh_token = payload.get("refreshToken")
    user = payload.get("user")
    require(isinstance(access_token, str) and bool(access_token), "QA auth response has no access token")
    require(isinstance(refresh_token, str) and bool(refresh_token), "QA auth response has no refresh token")
    require(isinstance(user, dict), "QA auth response has no user object")
    require(isinstance(user.get("id"), str) and bool(user["id"]), "QA auth user has no ID")
    require(user.get("provider") == "email", "QA auth user is not the expected email provider")
    require(
        isinstance(user.get("providerUserId"), str) and bool(user["providerUserId"]),
        "QA auth user has no provider ID",
    )
    require(
        user.get("providerUsername") is None or isinstance(user.get("providerUsername"), str),
        "QA auth user has an invalid provider username",
    )
    session = KeychainSession(
        access_token=access_token,
        refresh_token=refresh_token,
        auth_user=json.dumps(user, separators=(",", ":"), sort_keys=True),
    )
    require_session_valid_for(
        session=session,
        minimum_seconds=MIN_SESSION_VALIDITY_SECONDS,
        label="QA auth response",
        now=now,
    )
    return session


def request_qa_session(*, credentials: QaCredentials) -> KeychainSession:
    body = json.dumps({"email": credentials.email, "password": credentials.password}).encode("utf-8")
    request = urllib.request.Request(
        AUTH_ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = response.status
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"QA email login returned HTTP {error.code}") from error
    except urllib.error.URLError as error:
        raise RuntimeError("QA email login could not reach the auth service") from error
    require(200 <= status < 300, f"QA email login returned HTTP {status}")
    return parse_keychain_session(payload=payload)


def compile_keychain_writer(*, output: Path, log: Path) -> Path:
    writer = output / "keychain-writer"
    execute(
        command=[
            "xcrun",
            "swiftc",
            str(KEYCHAIN_WRITER_SOURCE),
            "-framework",
            "Security",
            "-o",
            str(writer),
        ],
        log=log,
    )
    return writer


def _security(*, arguments: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["security", *arguments],
            text=True,
            capture_output=True,
            check=False,
            timeout=KEYCHAIN_COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"security timed out during {arguments[0]}") from None


def _keychain_writer(
    *,
    writer: Path,
    operation: str,
    account: str,
    secret_input: str,
) -> subprocess.CompletedProcess[str]:
    executable = APPLICATION / "Contents/MacOS/Sesori"
    try:
        result = subprocess.run(
            [str(writer), operation, account, KEYCHAIN_SERVICE, str(executable), "/usr/bin/security"],
            input=f"{secret_input}\n",
            text=True,
            capture_output=True,
            check=False,
            timeout=KEYCHAIN_COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Keychain writer timed out during {operation} for {account}") from None
    return subprocess.CompletedProcess(
        args=result.args,
        returncode=result.returncode,
        stdout=result.stdout,
        stderr=result.stderr.replace(secret_input, "<redacted>"),
    )


def _security_failure(*, result: subprocess.CompletedProcess[str]) -> str:
    stderr = result.stderr.strip()
    suffix = f": {stderr[:2000]}" if stderr else " (no stderr)"
    return f"security exited {result.returncode}{suffix}"


def require_auth_keychain_absent() -> None:
    for account in KEYCHAIN_ACCOUNTS:
        result = _security(arguments=["find-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE])
        if result.returncode == 0:
            raise RuntimeError(f"Fresh runner already contains the {account} desktop Keychain item")
        if result.returncode != 44:
            raise RuntimeError(
                f"Could not inspect the {account} desktop Keychain item: {_security_failure(result=result)}",
            )


def _set_auth_keychain(
    *,
    writer: Path,
    session: KeychainSession,
    update: bool,
    created_accounts: list[str] | None = None,
) -> list[str]:
    executable = APPLICATION / "Contents/MacOS/Sesori"
    require(executable.is_file(), "Installed desktop executable is missing before Keychain setup")
    written_accounts: list[str] = []
    operation = "update" if update else "create"
    for account, value in session.values:
        if not update:
            require(created_accounts is not None, "Created Keychain account tracking is required")
            created_accounts.append(account)
        result = _keychain_writer(
            writer=writer,
            operation=operation,
            account=account,
            secret_input=value,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Could not {operation} the {account} desktop Keychain item: {_security_failure(result=result)}",
            )
        written_accounts.append(account)
    return written_accounts


def write_auth_keychain(*, writer: Path, session: KeychainSession, created_accounts: list[str]) -> None:
    written_accounts = _set_auth_keychain(
        writer=writer,
        session=session,
        update=False,
        created_accounts=created_accounts,
    )
    require(tuple(written_accounts) == KEYCHAIN_ACCOUNTS, "Did not create every desktop Keychain item")


def update_auth_keychain(*, writer: Path, session: KeychainSession) -> None:
    written_accounts = _set_auth_keychain(writer=writer, session=session, update=True)
    require(tuple(written_accounts) == KEYCHAIN_ACCOUNTS, "Did not refresh every desktop Keychain item")


def read_auth_keychain(*, account: str) -> str:
    result = _security(arguments=["find-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE, "-w"])
    if result.returncode != 0:
        raise RuntimeError(
            f"Could not read the {account} desktop Keychain item: {_security_failure(result=result)}",
        )
    return result.stdout.rstrip("\n")


def require_auth_keychain_session(*, expected: KeychainSession, label: str, output: Path) -> None:
    observed = {account: read_auth_keychain(account=account) for account in KEYCHAIN_ACCOUNTS}
    require(observed["access_token"] == expected.access_token, f"{label}: access token changed")
    require(observed["refresh_token"] == expected.refresh_token, f"{label}: refresh token changed")
    try:
        observed_user = json.loads(observed["auth_user"])
        expected_user = json.loads(expected.auth_user)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"{label}: desktop Keychain user is not valid JSON") from error
    require(observed_user == expected_user, f"{label}: desktop Keychain user changed")
    (output / f"{label}-keychain.log").write_text(
        "ACCESS_TOKEN_PRESENT\nREFRESH_TOKEN_PRESENT\nAUTH_USER_PRESENT\n",
        encoding="utf-8",
    )


def delete_auth_keychain(*, created_accounts: list[str]) -> None:
    failures: list[str] = []
    for account in reversed(created_accounts):
        try:
            result = _security(arguments=["delete-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE])
        except RuntimeError as error:
            failures.append(f"{account}: {error}")
            continue
        if result.returncode not in (0, 44):
            failures.append(f"{account}: {_security_failure(result=result)}")
    if failures:
        raise RuntimeError("Could not remove probe-owned desktop Keychain items:\n" + "\n".join(failures))


def _write_authenticated_helper_observation(
    *,
    label: str,
    output: Path,
    helper_process_count: int,
    helper_pid: int | None,
    authenticated_profile: bool,
    relay_serving: bool,
    helper_observed_during_wait: bool,
    bridge_log_activity_observed: bool,
) -> None:
    observation = {
        "helperProcessCount": helper_process_count,
        "helperPid": helper_pid,
        "helperObservedDuringWait": helper_observed_during_wait,
        "bridgeLogActivityObserved": bridge_log_activity_observed,
        "authenticatedProfileConfirmed": authenticated_profile,
        "relayServing": relay_serving,
    }
    (output / f"{label}-authenticated-helper.json").write_text(
        json.dumps(observation, indent=2) + "\n",
        encoding="utf-8",
    )


def _bridge_log_has_fresh_activity(*, path: Path, baseline: BridgeLogCursor | None) -> bool:
    try:
        status = path.stat()
    except FileNotFoundError:
        return False
    if baseline is None:
        return True
    return (
        (status.st_dev, status.st_ino) != (baseline.device, baseline.inode)
        or status.st_size != baseline.offset
    )


def write_private_app_startup_diagnostics(*, label: str, private_app_log: Path, output: Path) -> None:
    app_log_present = False
    app_log_truncated = False
    app_output = ""
    try:
        with private_app_log.open("rb") as stream:
            app_log_present = True
            data = stream.read(PRIVATE_APP_LOG_DIAGNOSTIC_LIMIT_BYTES + 1)
    except FileNotFoundError:
        pass
    else:
        app_log_truncated = len(data) > PRIVATE_APP_LOG_DIAGNOSTIC_LIMIT_BYTES
        app_output = data[:PRIVATE_APP_LOG_DIAGNOSTIC_LIMIT_BYTES].decode("utf-8", errors="replace")
    diagnostics = {
        "appLogPresent": app_log_present,
        "appLogTruncated": app_log_truncated,
        **{
            diagnostic: any(marker in app_output for marker in markers)
            for diagnostic, markers in PRIVATE_APP_LOG_DIAGNOSTIC_MARKERS
        },
    }
    (output / f"{label}-startup-diagnostics.json").write_text(
        json.dumps(diagnostics, indent=2) + "\n",
        encoding="utf-8",
    )


def _helper_pid(*, processes: str) -> tuple[int | None, int]:
    lines = processes.splitlines()
    if len(lines) != 1:
        return None, len(lines)
    try:
        return int(lines[0].split(maxsplit=1)[0]), 1
    except (IndexError, ValueError) as error:
        raise RuntimeError("Installed helper process listing has no numeric PID") from error


def wait_for_authenticated_helper(
    *,
    label: str,
    launcher: subprocess.Popen[str],
    output: Path,
    bridge_log: Path = BRIDGE_LOG,
    bridge_log_cursor: BridgeLogCursor | None = None,
) -> int:
    deadline = time.monotonic() + HELPER_WAIT_SECONDS
    active_helper_pid: int | None = None
    observed_helper_generation = False
    bridge_log_activity_observed = False
    generation_log_cursor = bridge_log_cursor
    generation_log_offset = bridge_log_cursor.offset if bridge_log_cursor is not None else 0
    while True:
        launcher_returncode = launcher.poll()
        bridge_log_activity_observed = bridge_log_activity_observed or _bridge_log_has_fresh_activity(
            path=bridge_log,
            baseline=bridge_log_cursor,
        )
        helper_pid, helper_process_count = _helper_pid(processes=installed_helper_processes())
        if helper_process_count > 1:
            _write_authenticated_helper_observation(
                label=label,
                output=output,
                helper_process_count=helper_process_count,
                helper_pid=None,
                authenticated_profile=False,
                relay_serving=False,
                helper_observed_during_wait=observed_helper_generation or helper_process_count > 0,
                bridge_log_activity_observed=bridge_log_activity_observed,
            )
            raise RuntimeError(f"{label}: expected at most one installed helper process")
        if helper_pid != active_helper_pid:
            if observed_helper_generation:
                generation_log_cursor = capture_bridge_log_cursor(path=bridge_log)
                generation_log_offset = generation_log_cursor.offset if generation_log_cursor is not None else 0
            active_helper_pid = helper_pid
            if helper_pid is not None:
                observed_helper_generation = True
        bridge_output = ""
        if active_helper_pid is not None:
            try:
                stream = bridge_log.open("rb")
            except FileNotFoundError:
                stream = None
            if stream is not None:
                with stream:
                    status = os.fstat(stream.fileno())
                    active_cursor = BridgeLogCursor(device=status.st_dev, inode=status.st_ino, offset=status.st_size)
                    if (
                        generation_log_cursor is None
                        or (active_cursor.device, active_cursor.inode)
                        != (generation_log_cursor.device, generation_log_cursor.inode)
                        or active_cursor.offset < generation_log_offset
                    ):
                        generation_log_cursor = active_cursor
                        generation_log_offset = 0
                    stream.seek(generation_log_offset)
                    bridge_output = stream.read().decode("utf-8", errors="replace")
                    bridge_log_activity_observed = bridge_log_activity_observed or bool(bridge_output)
        authenticated_profile = "Authenticated as " in bridge_output
        relay_serving = "Waiting for relay events..." in bridge_output
        if launcher_returncode is not None:
            _write_authenticated_helper_observation(
                label=label,
                output=output,
                helper_process_count=helper_process_count,
                helper_pid=active_helper_pid,
                authenticated_profile=authenticated_profile,
                relay_serving=relay_serving,
                helper_observed_during_wait=observed_helper_generation,
                bridge_log_activity_observed=bridge_log_activity_observed,
            )
            raise RuntimeError(f"{label}: desktop exited before its authenticated helper became ready")
        if active_helper_pid is not None and authenticated_profile and relay_serving:
            _write_authenticated_helper_observation(
                label=label,
                output=output,
                helper_process_count=helper_process_count,
                helper_pid=active_helper_pid,
                authenticated_profile=authenticated_profile,
                relay_serving=relay_serving,
                helper_observed_during_wait=observed_helper_generation,
                bridge_log_activity_observed=bridge_log_activity_observed,
            )
            return active_helper_pid
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            _write_authenticated_helper_observation(
                label=label,
                output=output,
                helper_process_count=helper_process_count,
                helper_pid=active_helper_pid,
                authenticated_profile=authenticated_profile,
                relay_serving=relay_serving,
                helper_observed_during_wait=observed_helper_generation,
                bridge_log_activity_observed=bridge_log_activity_observed,
            )
            raise RuntimeError(f"{label}: authenticated helper did not become ready")
        time.sleep(min(HELPER_POLL_INTERVAL_SECONDS, remaining))


def write_missing_authenticated_helper_observation(
    *,
    label: str,
    output: Path,
    bridge_log: Path,
    bridge_log_cursor: BridgeLogCursor | None,
) -> None:
    if (output / f"{label}-authenticated-helper.json").exists():
        return
    helper_pid, helper_process_count = _helper_pid(processes=installed_helper_processes())
    _write_authenticated_helper_observation(
        label=label,
        output=output,
        helper_process_count=helper_process_count,
        helper_pid=helper_pid,
        authenticated_profile=False,
        relay_serving=False,
        helper_observed_during_wait=helper_process_count > 0,
        bridge_log_activity_observed=_bridge_log_has_fresh_activity(
            path=bridge_log,
            baseline=bridge_log_cursor,
        ),
    )


def capture_authenticated_launch_diagnostics(
    *,
    label: str,
    private_app_log: Path,
    output: Path,
    bridge_log: Path,
    bridge_log_cursor: BridgeLogCursor | None,
) -> None:
    failures: list[BaseException] = []
    try:
        write_missing_authenticated_helper_observation(
            label=label,
            output=output,
            bridge_log=bridge_log,
            bridge_log_cursor=bridge_log_cursor,
        )
    except BaseException as error:
        failures.append(error)
    try:
        write_private_app_startup_diagnostics(
            label=label,
            private_app_log=private_app_log,
            output=output,
        )
    except BaseException as error:
        failures.append(error)
    if len(failures) == 1:
        raise failures[0]
    if failures:
        raise BaseExceptionGroup(f"{label}: bounded diagnostic captures failed", failures)


def wait_for_installed_app_pid(*, label: str, launcher: subprocess.Popen[str]) -> int:
    deadline = time.monotonic() + 15
    while True:
        if launcher.poll() is not None:
            raise RuntimeError(f"{label}: installed desktop exited during startup: {launcher.returncode}")
        result = subprocess.run(
            ["pgrep", "-f", r"^/Applications/Sesori\.app/Contents/MacOS/Sesori($| )"],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise RuntimeError(f"{label}: could not inspect the installed desktop process")
        pids = result.stdout.split()
        if len(pids) == 1:
            return int(pids[0])
        require(not pids, f"{label}: expected at most one installed desktop process")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(f"{label}: installed desktop process did not appear")
        time.sleep(min(HELPER_POLL_INTERVAL_SECONDS, remaining))


def _terminate_probe_processes() -> None:
    patterns = (
        r"^/Applications/Sesori\.app/Contents/MacOS/Sesori($| )",
        r"^/Applications/Sesori\.app/Contents/Helpers/bridge/bin/bridge($| )",
    )
    for signal_name in ("TERM", "KILL"):
        for pattern in patterns:
            subprocess.run(
                ["pkill", f"-{signal_name}", "-f", pattern],
                text=True,
                capture_output=True,
                check=False,
            )
        if signal_name == "TERM":
            time.sleep(1)


def cleanup_qualification(*, created_keychain_accounts: list[str]) -> None:
    failures: list[str] = []
    _terminate_probe_processes()
    if APPLICATION.exists():
        try:
            shutil.rmtree(APPLICATION)
        except OSError as error:
            failures.append(f"installed app: {error}")
    if REGISTRATION.exists():
        try:
            REGISTRATION.unlink()
        except OSError as error:
            failures.append(f"login registration: {error}")
    for root in (SUPPORT_ROOT, SHARED_DATA_ROOT, ATTACHMENTS_ROOT):
        if root.exists():
            try:
                shutil.rmtree(root)
            except OSError as error:
                failures.append(f"probe-owned state {root}: {error}")
    try:
        delete_auth_keychain(created_accounts=created_keychain_accounts)
    except RuntimeError as error:
        failures.append(str(error))
    remaining = owned_processes()
    if remaining:
        failures.append(f"remaining owned processes:\n{remaining}")
    if failures:
        raise RuntimeError("Authenticated upgrade cleanup failed:\n" + "\n".join(failures))


@contextmanager
def qualification_cleanup(*, cleanup: Callable[[], None]) -> Iterator[None]:
    try:
        yield
    except BaseException as qualification_error:
        try:
            cleanup()
        except BaseException as cleanup_error:
            raise BaseExceptionGroup(
                "Authenticated qualification and cleanup both failed",
                [qualification_error, cleanup_error],
            ) from None
        raise
    else:
        cleanup()


def launch_authenticated_and_quit(
    *,
    label: str,
    inspector: Path,
    quitter: Path,
    output: Path,
) -> None:
    launcher_log = output / f"{label}-launcher.log"
    # Authenticated app output stays in the exact probe-owned support root and is never uploaded.
    private_app_log = SUPPORT_ROOT / "desktop-instance" / f"{label}-authenticated-app.log"
    bridge_log_cursor = capture_bridge_log_cursor(path=BRIDGE_LOG)
    launch_started_at = time.monotonic()
    with launcher_log.open("w", encoding="utf-8") as stream:
        launcher = subprocess.Popen(
            [
                "open",
                "-n",
                "-W",
                "--stdout",
                str(private_app_log),
                "--stderr",
                str(private_app_log),
                str(APPLICATION),
            ],
            stdout=stream,
            stderr=subprocess.STDOUT,
        )
    completed = False
    try:
        app_pid = wait_for_installed_app_pid(label=label, launcher=launcher)
        authenticated_helper_pid = wait_for_authenticated_helper(
            label=label,
            launcher=launcher,
            output=output,
            bridge_log_cursor=bridge_log_cursor,
        )
        startup_interval_remaining = 15 - (time.monotonic() - launch_started_at)
        if startup_interval_remaining > 0:
            try:
                launcher.wait(timeout=startup_interval_remaining)
            except subprocess.TimeoutExpired:
                pass
            else:
                raise RuntimeError(f"{label}: installed desktop exited during startup: {launcher.returncode}")
        wait_for_visible_window(
            label=label,
            inspector=inspector,
            app_pid=app_pid,
            launcher=launcher,
            output=output,
        )
        current_helper_pid, helper_process_count = _helper_pid(processes=installed_helper_processes())
        require(
            helper_process_count == 1 and current_helper_pid == authenticated_helper_pid,
            f"{label}: authenticated helper exited or was replaced before tray Quit",
        )
        quit_result = subprocess.run([str(quitter), str(app_pid)], text=True, capture_output=True, check=False)
        (output / f"{label}-quit.log").write_text(quit_result.stdout + quit_result.stderr, encoding="utf-8")
        if quit_result.returncode == 2:
            raise RuntimeError(f"BLOCKED {label}: native runner lacks Accessibility trust")
        if quit_result.returncode != 0:
            details = (quit_result.stdout + quit_result.stderr).strip()
            raise RuntimeError(f"{label}: accessible tray Quit failed: {details}")
        launcher.wait(timeout=30)
        if launcher.returncode != 0:
            raise RuntimeError(f"{label}: tray Quit returned launcher exit {launcher.returncode}")
        time.sleep(5)
        remaining = owned_processes()
        require(not remaining, f"{label}: application/helper remained or relaunched after Quit:\n{remaining}")
        completed = True
    except BaseException as launch_error:
        try:
            capture_authenticated_launch_diagnostics(
                label=label,
                private_app_log=private_app_log,
                output=output,
                bridge_log=BRIDGE_LOG,
                bridge_log_cursor=bridge_log_cursor,
            )
        except BaseException as diagnostic_error:
            raise BaseExceptionGroup(
                f"{label}: authenticated launch and bounded diagnostic capture both failed",
                [launch_error, diagnostic_error],
            ) from None
        raise
    finally:
        if not completed:
            _terminate_probe_processes()
        if launcher.poll() is None:
            launcher.kill()
            launcher.wait()


def qualify(
    *,
    previous_run_json: Path,
    previous_packages: Path,
    previous_evidence: Path,
    previous_pulls_json: Path,
    current_run_json: Path,
    current_packages: Path,
    current_evidence: Path,
    current_pulls_json: Path,
    architecture: str,
    channel: str,
    output: Path,
) -> None:
    credentials = load_qa_credentials()
    require_fresh_native_runner()
    require_auth_keychain_absent()
    output.mkdir(parents=True)
    log = output / "commands.log"
    previous = load_candidate(
        label="previous",
        run_json=previous_run_json,
        packages=previous_packages,
        evidence=previous_evidence,
        architecture=architecture,
        expected_channel=channel,
        allow_missing_channel=True,
    )
    current = load_candidate(
        label="current",
        run_json=current_run_json,
        packages=current_packages,
        evidence=current_evidence,
        architecture=architecture,
        expected_channel=channel,
    )
    validate_upgrade(previous=previous, current=current)
    previous_source_acceptance = require_trusted_source(
        run_id=previous.run_id,
        source_sha=previous.source_sha,
        associated_pulls=read_json_array(previous_pulls_json),
    )
    current_source_acceptance = require_trusted_source(
        run_id=current.run_id,
        source_sha=current.source_sha,
        associated_pulls=read_json_array(current_pulls_json),
    )
    inspector, quitter = compile_native_helpers(output=output, log=log)
    keychain_writer = compile_keychain_writer(output=output, log=log)

    sentinel = SUPPORT_ROOT / "desktop-instance/upgrade-probe-sentinel"
    desired_state = SUPPORT_ROOT / "desktop-instance/bridge-desired-state"
    shared_sentinel = SHARED_DATA_ROOT / "upgrade-probe/preserved-state"
    attachment_sentinel = ATTACHMENTS_ROOT / "upgrade-probe-preserved-state"
    sentinel_value = "sesori-private-macos-authenticated-upgrade-probe\n"
    created_keychain_accounts: list[str] = []
    cleanup = partial(cleanup_qualification, created_keychain_accounts=created_keychain_accounts)
    with qualification_cleanup(cleanup=cleanup):
        install_candidate(candidate=previous, mount=output / "previous-volume", log=log)
        session = request_qa_session(credentials=credentials)
        write_auth_keychain(
            writer=keychain_writer,
            session=session,
            created_accounts=created_keychain_accounts,
        )
        require_session_valid_for(
            session=session,
            minimum_seconds=MIN_LAUNCH_VALIDITY_SECONDS,
            label="previous launch",
        )
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text(sentinel_value, encoding="utf-8")
        desired_state.write_text("on\n", encoding="utf-8")
        shared_sentinel.parent.mkdir(parents=True)
        shared_sentinel.write_text(sentinel_value, encoding="utf-8")
        attachment_sentinel.parent.mkdir(parents=True)
        attachment_sentinel.write_text(sentinel_value, encoding="utf-8")
        registration_hash = seed_login_registration()
        launch_authenticated_and_quit(
            label="previous",
            inspector=inspector,
            quitter=quitter,
            output=output,
        )
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Previous launch changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "on", "Previous Quit changed On intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Previous launch changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Previous launch changed shared attachment sentinel")
        require(
            REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
            "Previous launch changed login registration",
        )
        require_auth_keychain_session(expected=session, label="previous", output=output)

        replacement_session = request_qa_session(credentials=credentials)
        update_auth_keychain(writer=keychain_writer, session=replacement_session)
        require_auth_keychain_session(expected=replacement_session, label="replacement-seed", output=output)
        shutil.rmtree(APPLICATION)
        install_candidate(candidate=current, mount=output / "current-volume", log=log)
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Replacement changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "on", "Replacement changed On intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Replacement changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Replacement changed shared attachment sentinel")
        require(
            REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
            "Replacement changed login registration",
        )
        require_session_valid_for(
            session=replacement_session,
            minimum_seconds=MIN_LAUNCH_VALIDITY_SECONDS,
            label="current launch",
        )
        require_auth_keychain_session(expected=replacement_session, label="replacement", output=output)
        launch_authenticated_and_quit(
            label="current",
            inspector=inspector,
            quitter=quitter,
            output=output,
        )
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Current launch changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "on", "Current Quit changed On intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Current launch changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Current launch changed shared attachment sentinel")
        require(
            REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
            "Current launch changed login registration",
        )
        require_auth_keychain_session(expected=replacement_session, label="current", output=output)

        report = {
            "schemaVersion": 1,
            "architecture": architecture,
            "channel": channel,
            "helperMode": "authenticated-on",
            "previous": {
                "runId": previous.run_id,
                "sourceSha": previous.source_sha,
                "sourceAcceptance": previous_source_acceptance,
                "version": previous.version,
                "buildNumber": previous.build_number,
                "dmgSha256": previous.dmg_sha256,
            },
            "current": {
                "runId": current.run_id,
                "sourceSha": current.source_sha,
                "sourceAcceptance": current_source_acceptance,
                "version": current.version,
                "buildNumber": current.build_number,
                "dmgSha256": current.dmg_sha256,
            },
            "checks": {
                "nativeSignaturesAndGatekeeper": True,
                "applicationsLink": True,
                "visibleStartup": True,
                "classicKeychainSessionRestored": True,
                "phaseFreshKeychainSession": True,
                "authenticatedProfileConfirmed": True,
                "relayServing": True,
                "helperRunningBeforeQuit": True,
                "trayQuitStoppedHelper": True,
                "noRelaunchOrOrphan": True,
                "desktopStateSentinelPreserved": True,
                "onIntentPreserved": True,
                "sharedCliStateSentinelPreserved": True,
                "sharedAttachmentSentinelPreserved": True,
                "priorLoginRegistrationPreserved": True,
            },
            "proofBoundary": (
                "Private signed manual replacement with a QA account and helper On: classic Keychain session "
                "restoration, authenticated profile lookup, relay serving, visible startup, actual tray Quit "
                "stopping the helper, no relaunch/orphan, and bounded desktop/shared-state preservation. Not "
                "interactive browser login, failed-stop refusal, user-account/TCC, public-download, or minimum-OS QA."
            ),
        }
        (output / "authenticated-upgrade.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"PASS private authenticated macOS/{architecture} {previous.version}+{previous.build_number} "
              f"→ {current.version}+{current.build_number} manual replacement")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--previous-run-json", type=Path, required=True)
    parser.add_argument("--previous-packages", type=Path, required=True)
    parser.add_argument("--previous-evidence", type=Path, required=True)
    parser.add_argument("--previous-pulls-json", type=Path, required=True)
    parser.add_argument("--current-run-json", type=Path, required=True)
    parser.add_argument("--current-packages", type=Path, required=True)
    parser.add_argument("--current-evidence", type=Path, required=True)
    parser.add_argument("--current-pulls-json", type=Path, required=True)
    parser.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    parser.add_argument("--channel", choices=("stable", "internal"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    qualify(**vars(args))


if __name__ == "__main__":
    main()
