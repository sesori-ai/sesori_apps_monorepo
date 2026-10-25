"""Manual, ephemeral Actions desktop diagnostics. Never release-qualification evidence."""

import argparse
import os
from pathlib import Path
import platform
import select
import shlex
import signal
import socket
import subprocess
import tempfile

from build_linux_repository import Channel, verify_release
from github_release_assets import github
from prepare_desktop_release import read_json, require
from publish_desktop_linux import MANIFEST, TRUSTED_PRIMARY_FINGERPRINT, prepare as prepare_signed
from publish_linux_repository import REPOSITORY
from qualify_desktop_linux_session import run, stop_process, wait_for


SESSION_SECONDS = 20 * 60


def prepare(*, inputs: Path, output: Path, run_id: int, tooling_sha: str) -> None:
    """Authenticate one retained internal producer without publishing or rebuilding it."""
    (inputs / "run.json").write_text(github(arguments=["api", f"repos/{REPOSITORY}/actions/runs/{run_id}"]))
    identity = read_json(inputs / "desktop-linux-evidence-x64/desktop-bundle/bundle/bridge/desktop-bundle.json")
    prepare_signed(root=inputs, output=output, source_sha=identity["sourceSha"], tooling_sha=tooling_sha,
                   channel=Channel.INTERNAL, repository=REPOSITORY, run_id=run_id, current_run_id=None,
                   version=identity["version"], build_number=identity["buildNumber"])
    verify_release(root=output, channel=Channel.INTERNAL, fingerprint=TRUSTED_PRIMARY_FINGERPRINT)


def wait_for_operator(*, control: Path) -> None:
    os.mkfifo(control, mode=0o600)
    # Both ends are open so the timeout also bounds sessions with no operator writer.
    descriptor = os.open(control, os.O_RDWR | os.O_NONBLOCK)
    try:
        if select.select([descriptor], [], [], SESSION_SECONDS)[0]:
            print("Operator ended the diagnostic session.", flush=True)
        else:
            print("20-minute diagnostic access expired.", flush=True)
    finally:
        os.close(descriptor)
        control.unlink()


def vnc_ready(*, process: subprocess.Popen) -> bool:
    code = process.poll()
    require(code is None, f"VNC server exited before listener readiness (status {code})")
    try:
        with socket.create_connection(("127.0.0.1", 5900), timeout=1):
            return True
    except ConnectionRefusedError:
        return False


def serve(*, inputs: Path, output: Path, architecture: str) -> None:
    require(platform.system() == "Linux" and os.environ.get("GITHUB_ACTIONS") == "true",
            "Interactive diagnostics require a disposable Linux Actions runner")
    require(platform.machine() == {"x64": "x86_64", "arm64": "aarch64"}[architecture],
            "Interactive diagnostics require the selected native CPU")
    require(os.geteuid() != 0, "The desktop must run as the ordinary runner user, never root")
    require(not Path("/opt/sesori-desktop").exists(), "Runner already has a Sesori installation")
    require("DBUS_SESSION_BUS_ADDRESS" in os.environ, "Run inside its own dbus-run-session")
    import dbus

    release = read_json(inputs / MANIFEST)
    package = inputs / f"Sesori-linux-{architecture}-{release['version']}-{release['buildNumber']}.deb"
    run(arguments=["sudo", "apt-get", "install", "--yes", str(package)], timeout=240)
    output.mkdir(parents=True)
    processes = []
    logs = []
    with tempfile.TemporaryDirectory(prefix="sesori-linux-debug-", dir=os.environ["RUNNER_TEMP"]) as directory:
        home = Path(directory)
        session = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                   "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
                   "XDG_RUNTIME_DIR": str(home / "runtime"), "DISPLAY": ":95", "XDG_CURRENT_DESKTOP": "KDE",
                   "XDG_SESSION_TYPE": "x11", "GDK_BACKEND": "x11", "QT_XCB_GL_INTEGRATION": "none",
                   "LIBGL_ALWAYS_SOFTWARE": "1", "QT_QUICK_BACKEND": "software",
                   "QT_LINUX_ACCESSIBILITY_ALWAYS_ON": "1", "NO_AT_BRIDGE": "0", "LC_ALL": "C.UTF-8",
                   "DBUS_SESSION_BUS_ADDRESS": os.environ["DBUS_SESSION_BUS_ADDRESS"]}
        env = {**os.environ, **session}
        Path(session["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)

        def start(*, arguments: list[str], label: str, stdin=None):
            log = (output / f"{label}.log").open("w")
            logs.append(log)
            process = subprocess.Popen(arguments, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       stdin=stdin, start_new_session=True)
            processes.append(process)
            return process

        def interrupted(signum, frame):
            raise SystemExit(128 + signum)

        previous_handler = signal.signal(signal.SIGTERM, interrupted)
        try:
            bus = dbus.SessionBus()
            dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                           "org.freedesktop.DBus").UpdateActivationEnvironment(session)
            run(arguments=["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", "true"], env=env)
            # An unattended operator connection can exceed Plasma's default five-minute idle lock.
            run(arguments=["kwriteconfig5", "--file", "kscreenlockerrc", "--group", "Daemon",
                           "--key", "Autolock", "false"], env=env)
            keyring = start(arguments=["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets"],
                            label="keyring", stdin=subprocess.PIPE)
            keyring.stdin.write(b"disposable-ci-debug-keyring\n")
            keyring.stdin.close()
            wait_for(description="Secret Service", check=lambda: bus.name_has_owner("org.freedesktop.secrets"))
            start(arguments=["Xvfb", ":95", "-screen", "0", "1280x800x24", "-nolisten", "tcp"], label="x11")
            wait_for(description="X11 socket", check=lambda: Path("/tmp/.X11-unix/X95").exists())
            start(arguments=["startplasma-x11"], label="desktop")
            wait_for(description="KDE StatusNotifier host",
                     check=lambda: bus.name_has_owner("org.kde.StatusNotifierWatcher"))
            start(arguments=["/usr/bin/sesori-desktop"], label="application")
            vnc = start(arguments=["x11vnc", "-display", ":95", "-localhost", "-rfbport", "5900", "-nopw",
                                   "-forever", "-shared"], label="vnc")
            wait_for(description="loopback VNC listener", check=lambda: vnc_ready(process=vnc))
            environment = output / "session.env"
            environment.write_text("".join(f"export {key}={shlex.quote(value)}\n" for key, value in session.items()))
            control = output / "stop.pipe"
            try:
                host = os.environ["DEBUG_HOST"]
                summary = ("## Private Linux diagnostic session\n\n"
                           "Manual diagnostics only; no account login, signing, publication or qualification. "
                           "Access ends after 20 minutes or the stop command. No automatic artifacts are uploaded.\n\n"
                           f"```sh\nssh runner@{host}\n"
                           f"ssh -N -L 15900:127.0.0.1:5900 runner@{host}\n```\n\n"
                           "With the tunnel running, use `vnc://127.0.0.1:15900`. In the runner shell:\n\n"
                           f"```sh\nsource {shlex.quote(str(environment))}\n"
                           f"printf 'stop\\n' > {shlex.quote(str(control))}\n```\n")
                with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as target:
                    target.write(summary)
                print(summary, flush=True)
                wait_for_operator(control=control)
            finally:
                environment.unlink()
        finally:
            signal.signal(signal.SIGTERM, previous_handler)
            for process in reversed(processes):
                stop_process(process=process)
            for log in logs:
                log.close()
            run(arguments=["sudo", "apt-get", "remove", "--yes", "sesori-desktop"], timeout=120)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preparation = commands.add_parser("prepare")
    preparation.add_argument("--run-id", type=int, required=True)
    preparation.add_argument("--tooling-sha", required=True)
    execution = commands.add_parser("serve")
    execution.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    for command in (preparation, execution):
        command.add_argument("--inputs", type=Path, required=True)
        command.add_argument("--output", type=Path, required=True)
    args = vars(parser.parse_args())
    command = args.pop("command")
    args.update({key: args[key].resolve() for key in ("inputs", "output")})
    (prepare if command == "prepare" else serve)(**args)


if __name__ == "__main__":
    main()
