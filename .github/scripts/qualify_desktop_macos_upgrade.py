#!/usr/bin/env python3
"""Qualify a private signed macOS N→N+1 replacement on fresh native Actions hosts."""

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import time

from package_desktop_macos import execute
from qualify_desktop import ROOT


REPOSITORY = "sesori-ai/sesori_apps_monorepo"
RUN_WORKFLOW = ".github/workflows/desktop-qualification.yml"
APPLICATION = Path("/Applications/Sesori.app")
REGISTRATION = Path.home() / "Library/LaunchAgents/com.sesori.desktop.plist"
SUPPORT_ROOT = Path.home() / "Library/Application Support/com.sesori.desktop"
SHARED_DATA_ROOT = Path.home() / ".local/share/sesori"
ATTACHMENTS_ROOT = Path.home() / "Library/Application Support/Sesori Attachments"
WINDOW_WAIT_SECONDS = 45.0
WINDOW_POLL_INTERVAL_SECONDS = 1.0
PROCESS_PATTERN = (
    r"/Sesori\.app/Contents/MacOS/|/bridge/app/build/cli/bundle/bin/bridge|"
    r"/Contents/Helpers/bridge/bin/bridge|sesori-bridge"
)
PINNED_RETAINED_BASELINES = {
    35042335424: {
        "sourceSha": "efefcbcff7e7b75bdde271c1c670333987530212",
        "sourceTree": "d0f1d0e3cfb31090d0ddb6d5b8321604e7e65730",
        "pullRequest": 1503,
        "mergeCommitSha": "d1813409e3c0a8e053c3a28068d574e24fb70730",
    },
}


@dataclass(frozen=True)
class Candidate:
    label: str
    run_id: int
    source_sha: str
    version: str
    build_number: int
    architecture: str
    dmg: Path
    dmg_sha256: str
    identity: dict

    @property
    def release_order(self) -> tuple[tuple[int, int, int], int]:
        return tuple(int(part) for part in self.version.split(".")), self.build_number


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"Expected JSON object: {path}")
    return value


def read_json_array(path: Path) -> list[dict]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, list) and all(isinstance(item, dict) for item in value),
            f"Expected JSON object array: {path}")
    return value


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def parse_defines(path: Path) -> dict[str, str]:
    return dict(line.split("=", 1) for line in path.read_text(encoding="utf-8").splitlines())


def normalized_lipo_architectures(output: str) -> set[str]:
    mapping = {"x86_64": "x64", "arm64": "arm64"}
    architectures = output.split()
    require(architectures and all(architecture in mapping for architecture in architectures),
            "Native executable reported an unsupported architecture")
    return {mapping[architecture] for architecture in architectures}


def validate_installed_architectures(
    *,
    label: str,
    expected: str,
    gui_output: str,
    helper_output: str,
) -> None:
    require(expected in normalized_lipo_architectures(gui_output),
            f"{label}: installed GUI does not support the package architecture")
    require(normalized_lipo_architectures(helper_output) == {expected},
            f"{label}: installed helper architecture differs")


def load_candidate(
    *,
    label: str,
    run_json: Path,
    packages: Path,
    evidence: Path,
    architecture: str,
    expected_channel: str | None,
    allow_missing_channel: bool = False,
) -> Candidate:
    selected_run = read_json(run_json)
    run_id = selected_run.get("id")
    require(type(run_id) is int and run_id > 0, f"{label}: invalid run ID")
    require(selected_run.get("repository", {}).get("full_name") == REPOSITORY, f"{label}: wrong repository")
    require(selected_run.get("path") == RUN_WORKFLOW, f"{label}: wrong producer workflow")
    require(selected_run.get("event") == "workflow_dispatch", f"{label}: producer was not manually dispatched")
    require(selected_run.get("conclusion") == "success", f"{label}: producer did not succeed")
    source_sha = selected_run.get("head_sha")
    require(isinstance(source_sha, str) and bool(re.fullmatch(r"[0-9a-f]{40}", source_sha)),
            f"{label}: invalid source SHA")

    packaging = evidence / "desktop-macos-packaging"
    identity = read_json(packaging / "desktop-bundle.json")
    require(identity.get("os") == "macos", f"{label}: wrong operating system")
    require(identity.get("architecture") == architecture, f"{label}: wrong architecture")
    require(identity.get("sourceSha") == source_sha, f"{label}: identity source differs from run")
    version = identity.get("version")
    build_number = identity.get("buildNumber")
    require(isinstance(version, str) and bool(re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version)),
            f"{label}: invalid semantic version")
    require(type(build_number) is int and build_number > 0, f"{label}: invalid build number")

    report = read_json(packaging / "packaging.json")
    require(report.get("packagerSourceSha") == source_sha, f"{label}: packager source differs from run")
    require(report.get("architecture") == architecture, f"{label}: packaging architecture differs")
    artifact_name = f"Sesori-macos-{architecture}.dmg"
    require(set(report.get("artifacts", {})) == {
        artifact_name,
        f"Sesori-macos-{architecture}.zip",
    }, f"{label}: unexpected package inventory")
    dmg = packages / artifact_name
    digest = sha256(dmg)
    require(report["artifacts"].get(artifact_name) == digest, f"{label}: DMG digest differs from producer evidence")
    require(read_json(packaging / "app-notarization.json").get("status") == "Accepted",
            f"{label}: app notarization was not accepted")
    require(read_json(packaging / "dmg-notarization.json").get("status") == "Accepted",
            f"{label}: DMG notarization was not accepted")
    require((evidence / "desktop-bundle/build-source-changes.patch").read_bytes() == b"",
            f"{label}: producer source was not clean")

    if expected_channel is not None:
        defines_path = evidence / "desktop-bundle/dart-defines.env"
        pinned_without_channel = (
            allow_missing_channel
            and PINNED_RETAINED_BASELINES.get(run_id, {}).get("sourceSha") == source_sha
        )
        require(defines_path.exists() or pinned_without_channel,
                f"{label}: compiled channel evidence is missing")
        if defines_path.exists():
            defines = parse_defines(defines_path)
            require(defines.get("SESORI_DESKTOP_RELEASE_CHANNEL") == expected_channel,
                    f"{label}: compiled channel differs")
            require(json.loads(defines["SESORI_DESKTOP_BUNDLE_IDENTITY"]) == identity,
                    f"{label}: compiled identity differs from sealed identity")

    return Candidate(
        label=label,
        run_id=run_id,
        source_sha=source_sha,
        version=version,
        build_number=build_number,
        architecture=architecture,
        dmg=dmg,
        dmg_sha256=digest,
        identity=identity,
    )


def validate_upgrade(*, previous: Candidate, current: Candidate) -> None:
    require(previous.architecture == current.architecture, "Upgrade architectures differ")
    require(previous.release_order < current.release_order,
            "Current package must have a strictly newer semantic version/build identity")


def git_is_main_ancestor(*, source_sha: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", source_sha, "origin/main"],
        cwd=ROOT,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def require_trusted_source(*, run_id: int, source_sha: str, associated_pulls: list[dict]) -> dict:
    if git_is_main_ancestor(source_sha=source_sha):
        return {"kind": "mainAncestor"}
    baseline = PINNED_RETAINED_BASELINES.get(run_id)
    require(baseline is not None and baseline["sourceSha"] == source_sha,
            f"Selected source is neither in main history nor an exact pinned retained baseline: {source_sha}")
    accepted = next((
        pull for pull in associated_pulls
        if pull.get("number") == baseline["pullRequest"]
        and pull.get("state") == "closed"
        and isinstance(pull.get("merged_at"), str)
        and pull.get("merge_commit_sha") == baseline["mergeCommitSha"]
        and pull.get("base", {}).get("ref") == "main"
        and pull.get("base", {}).get("repo", {}).get("full_name") == REPOSITORY
        and git_is_main_ancestor(source_sha=baseline["mergeCommitSha"])
    ), None)
    require(accepted is not None, f"Pinned retained baseline has no accepted merged-main provenance: {source_sha}")
    return {
        "kind": "pinnedRetainedBaseline",
        "sourceTree": baseline["sourceTree"],
        "pullRequest": baseline["pullRequest"],
        "mergeCommitSha": baseline["mergeCommitSha"],
    }


def require_fresh_native_runner() -> None:
    if sys.platform != "darwin" or os.environ.get("GITHUB_ACTIONS") != "true":
        raise PermissionError("macOS upgrade probes require a fresh native Actions runner")
    processes = subprocess.check_output(["ps", "ax", "-o", "pid=,command="], text=True)
    if re.search(PROCESS_PATTERN, processes):
        raise RuntimeError("An existing desktop/bridge is active; refusing takeover or cleanup")
    for path, description in (
        (APPLICATION, "installed Sesori application"),
        (REGISTRATION, "login registration"),
        (SUPPORT_ROOT, "desktop application support"),
        (SHARED_DATA_ROOT, "shared Sesori data"),
        (ATTACHMENTS_ROOT, "shared Sesori attachments"),
    ):
        if path.exists() or path.is_symlink():
            raise RuntimeError(f"Existing {description}; refusing to alter user state: {path}")


def compile_native_helpers(*, output: Path, log: Path) -> tuple[Path, Path]:
    inspector = output / "desktop-window-inspector"
    quitter = output / "desktop-tray-quitter"
    execute(
        command=[
            "xcrun",
            "swiftc",
            str(ROOT / ".github/scripts/inspect_desktop_macos_window.swift"),
            "-o",
            str(inspector),
        ],
        log=log,
    )
    execute(
        command=[
            "xcrun",
            "swiftc",
            str(ROOT / ".github/scripts/quit_desktop_macos.swift"),
            "-o",
            str(quitter),
        ],
        log=log,
    )
    host = subprocess.run([str(inspector)], text=True, capture_output=True, check=False)
    (output / "host.log").write_text(host.stdout + host.stderr, encoding="utf-8")
    if host.returncode == 2:
        raise RuntimeError("BLOCKED upgrade probe: native runner has no active screen")
    host.check_returncode()
    if "ACCESSIBILITY_TRUSTED true" not in host.stdout:
        raise RuntimeError("BLOCKED upgrade probe: native runner lacks Accessibility trust")
    return inspector, quitter


def verify_installed_app(*, candidate: Candidate, app: Path, log: Path) -> None:
    execute(command=["codesign", "--verify", "--deep", "--strict", str(app)], log=log)
    requirement = '=anchor apple generic and certificate leaf[subject.OU] = "AQNCF7663C"'
    execute(command=["codesign", "--verify", "-R", requirement, str(app)], log=log)
    execute(command=["xcrun", "stapler", "validate", str(app)], log=log)
    execute(command=["spctl", "--assess", "--type", "execute", "--verbose=2", str(app)], log=log)
    installed_identity = read_json(app / "Contents/Resources/desktop-bundle.json")
    require(installed_identity == candidate.identity, f"{candidate.label}: installed identity differs")
    with (app / "Contents/Info.plist").open("rb") as stream:
        metadata = plistlib.load(stream)
    require(metadata.get("CFBundleIdentifier") == "com.sesori.desktop",
            f"{candidate.label}: installed bundle identifier differs")
    require(metadata.get("CFBundleShortVersionString") == candidate.version,
            f"{candidate.label}: installed version differs")
    require(metadata.get("CFBundleVersion") == str(candidate.build_number),
            f"{candidate.label}: installed build number differs")
    validate_installed_architectures(
        label=candidate.label,
        expected=candidate.architecture,
        gui_output=execute(command=["lipo", "-archs", str(app / "Contents/MacOS/Sesori")], log=log),
        helper_output=execute(
            command=["lipo", "-archs", str(app / "Contents/Helpers/bridge/bin/bridge")],
            log=log,
        ),
    )


def install_candidate(*, candidate: Candidate, mount: Path, log: Path) -> None:
    requirement = '=anchor apple generic and certificate leaf[subject.OU] = "AQNCF7663C"'
    execute(command=["hdiutil", "verify", str(candidate.dmg)], log=log)
    execute(command=["codesign", "--verify", "--strict", str(candidate.dmg)], log=log)
    execute(command=["codesign", "--verify", "-R", requirement, str(candidate.dmg)], log=log)
    execute(command=["xcrun", "stapler", "validate", str(candidate.dmg)], log=log)
    execute(
        command=[
            "spctl", "--assess", "--type", "open", "--context", "context:primary-signature",
            "--verbose=2", str(candidate.dmg),
        ],
        log=log,
    )
    mount.mkdir()
    execute(
        command=["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(candidate.dmg)],
        log=log,
    )
    try:
        source = mount / "Sesori.app"
        require(source.is_dir(), f"{candidate.label}: DMG has no Sesori.app")
        applications = mount / "Applications"
        require(applications.is_symlink() and os.readlink(applications) == "/Applications",
                f"{candidate.label}: DMG has no exact Applications link")
        verify_installed_app(candidate=candidate, app=source, log=log)
        execute(command=["ditto", str(source), str(APPLICATION)], log=log)
    finally:
        execute(command=["hdiutil", "detach", str(mount)], log=log)
    verify_installed_app(candidate=candidate, app=APPLICATION, log=log)


def owned_processes() -> str:
    processes = subprocess.check_output(["ps", "ax", "-o", "pid=,command="], text=True)
    return "\n".join(line for line in processes.splitlines() if re.search(PROCESS_PATTERN, line))


def seed_login_registration() -> str:
    registration = "\n".join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0">',
        '<dict>',
        '  <key>Label</key>',
        '  <string>com.sesori.desktop</string>',
        '  <key>ProgramArguments</key>',
        '  <array>',
        '    <string>/Applications/Sesori.app/Contents/MacOS/Sesori</string>',
        '    <string>--hidden</string>',
        '  </array>',
        '  <key>RunAtLoad</key>',
        '  <true/>',
        '  <key>ProcessType</key>',
        '  <string>Interactive</string>',
        '  <key>LimitLoadToSessionType</key>',
        '  <string>Aqua</string>',
        '</dict>',
        '</plist>',
        '',
    ])
    REGISTRATION.parent.mkdir(parents=True, exist_ok=True)
    REGISTRATION.write_text(registration, encoding="utf-8")
    return sha256(REGISTRATION)


def wait_for_visible_window(
    *,
    label: str,
    inspector: Path,
    app_pid: int,
    launcher: subprocess.Popen[str],
    output: Path,
) -> str:
    deadline = time.monotonic() + WINDOW_WAIT_SECONDS
    attempts: list[str] = []
    window_log = output / f"{label}-window.log"
    timeout_message = f"{label}: installed desktop has no visible main window after {WINDOW_WAIT_SECONDS:.0f} seconds"
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(timeout_message)
        try:
            window = subprocess.run(
                [str(inspector), str(app_pid)],
                text=True,
                capture_output=True,
                check=False,
                timeout=remaining,
            )
        except subprocess.TimeoutExpired as error:
            partial_output = ""
            for stream in (error.stdout, error.stderr):
                if isinstance(stream, bytes):
                    stream = stream.decode("utf-8", errors="replace")
                partial_output += stream or ""
            attempts.append(f"ATTEMPT {len(attempts) + 1}\nINSPECTOR_TIMEOUT\n{partial_output}")
            window_log.write_text("\n".join(attempts), encoding="utf-8")
            raise RuntimeError(timeout_message) from error
        attempts.append(f"ATTEMPT {len(attempts) + 1}\n{window.stdout}{window.stderr}")
        window_log.write_text("\n".join(attempts), encoding="utf-8")
        if window.returncode == 2:
            raise RuntimeError(f"BLOCKED {label}: native runner has no active screen")
        if window.returncode == 0:
            window_id = re.search(r"WINDOW_ID (\d+)", window.stdout)
            require(window_id is not None, f"{label}: window inspector did not report a window ID")
            return window_id[1]
        if launcher.poll() is not None:
            raise RuntimeError(f"{label}: installed desktop exited before showing a visible main window")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(timeout_message)
        time.sleep(min(WINDOW_POLL_INTERVAL_SECONDS, remaining))


def launch_and_quit(*, label: str, inspector: Path, quitter: Path, output: Path, log: Path) -> None:
    launcher_log = output / f"{label}-launcher.log"
    app_log = output / f"{label}-installed-gui.log"
    with launcher_log.open("w", encoding="utf-8") as stream:
        launcher = subprocess.Popen(
            ["open", "-n", "-W", "--stdout", str(app_log), "--stderr", str(app_log), str(APPLICATION)],
            stdout=stream,
            stderr=subprocess.STDOUT,
        )
    app_pid: int | None = None
    try:
        try:
            launcher.wait(timeout=15)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise RuntimeError(f"{label}: installed desktop exited during startup: {launcher.returncode}")
        pids = subprocess.check_output(
            ["pgrep", "-f", r"^/Applications/Sesori\.app/Contents/MacOS/Sesori($| )"], text=True
        ).split()
        require(len(pids) == 1, f"{label}: expected exactly one installed desktop process")
        app_pid = int(pids[0])
        window_id = wait_for_visible_window(
            label=label,
            inspector=inspector,
            app_pid=app_pid,
            launcher=launcher,
            output=output,
        )
        execute(
            command=["screencapture", "-x", "-l", window_id, str(output / f"{label}-installed-gui.png")],
            log=log,
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
        app_pid = None
    finally:
        if app_pid is not None:
            try:
                os.kill(app_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
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
    require_fresh_native_runner()
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

    sentinel = SUPPORT_ROOT / "desktop-instance/upgrade-probe-sentinel"
    desired_state = SUPPORT_ROOT / "desktop-instance/bridge-desired-state"
    shared_sentinel = SHARED_DATA_ROOT / "upgrade-probe/preserved-state"
    attachment_sentinel = ATTACHMENTS_ROOT / "upgrade-probe-preserved-state"
    sentinel_value = "sesori-private-macos-upgrade-probe\n"
    try:
        install_candidate(candidate=previous, mount=output / "previous-volume", log=log)
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text(sentinel_value, encoding="utf-8")
        desired_state.write_text("off\n", encoding="utf-8")
        shared_sentinel.parent.mkdir(parents=True)
        shared_sentinel.write_text(sentinel_value, encoding="utf-8")
        attachment_sentinel.parent.mkdir(parents=True)
        attachment_sentinel.write_text(sentinel_value, encoding="utf-8")
        registration_hash = seed_login_registration()
        launch_and_quit(label="previous", inspector=inspector, quitter=quitter, output=output, log=log)
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Previous launch changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "off", "Previous launch changed Off intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Previous launch changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Previous launch changed shared attachment sentinel")
        require(REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
                "Previous launch changed login registration")

        shutil.rmtree(APPLICATION)
        install_candidate(candidate=current, mount=output / "current-volume", log=log)
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Replacement changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "off", "Replacement changed Off intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Replacement changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Replacement changed shared attachment sentinel")
        require(REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
                "Replacement changed login registration")
        launch_and_quit(label="current", inspector=inspector, quitter=quitter, output=output, log=log)
        require(sentinel.read_text(encoding="utf-8") == sentinel_value, "Current launch changed upgrade sentinel")
        require(desired_state.read_text(encoding="utf-8").strip() == "off", "Current launch changed Off intent")
        require(shared_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Current launch changed shared CLI state sentinel")
        require(attachment_sentinel.read_text(encoding="utf-8") == sentinel_value,
                "Current launch changed shared attachment sentinel")
        require(REGISTRATION.exists() and sha256(REGISTRATION) == registration_hash,
                "Current launch changed login registration")

        report = {
            "schemaVersion": 1,
            "architecture": architecture,
            "channel": channel,
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
                "trayQuit": True,
                "noRelaunchOrOrphan": True,
                "desktopStateSentinelPreserved": True,
                "offIntentPreserved": True,
                "sharedCliStateSentinelPreserved": True,
                "sharedAttachmentSentinelPreserved": True,
                "priorLoginRegistrationPreserved": True,
            },
            "proofBoundary": (
                "Private signed manual replacement with the helper Off: native package trust, visible startup, "
                "actual tray Quit, no relaunch/orphan, and bounded desktop/shared-state preservation. Not "
                "authenticated "
                "helper-On, failed-stop refusal, real-account/Keychain/TCC, public-download, or minimum-OS QA."
            ),
        }
        (output / "upgrade.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"PASS private macOS/{architecture} {previous.version}+{previous.build_number} "
              f"→ {current.version}+{current.build_number} manual replacement")
    finally:
        # The fresh-run guard proved this path absent, so any copy is probe-owned even
        # when installation or post-copy verification fails before returning.
        if APPLICATION.exists():
            shutil.rmtree(APPLICATION)
        if REGISTRATION.exists():
            REGISTRATION.unlink()
        for root in (SUPPORT_ROOT, SHARED_DATA_ROOT, ATTACHMENTS_ROOT):
            if root.exists():
                shutil.rmtree(root)
        remaining = owned_processes()
        if remaining:
            raise RuntimeError(f"Upgrade cleanup found remaining owned processes:\n{remaining}")


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
