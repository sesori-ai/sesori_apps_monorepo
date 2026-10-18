#!/usr/bin/env python3
"""Main-only real-account Linux replacement. Authenticated pixels and raw logs stay private."""

import argparse
from enum import StrEnum
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import tempfile
import time

from desktop_qa_credentials import QaCredentials, load_qa_credentials
from publish_desktop_linux import MANIFEST, require
from qualify_desktop_linux_session import Desktop, MouseButton, run, stop_process, wait_for


class Candidate(StrEnum):
    PREVIOUS = "previous"
    CURRENT = "current"


class HelperIntent(StrEnum):
    ON = "on"
    OFF = "off"


class ProbePhase(StrEnum):
    LOGIN_ON = "loginOn"
    ON_TO_OFF = "onToOff"
    OFF_TO_ON = "offToOn"
    ON_TO_LOGOUT = "onToLogout"


APPLICATION = "/usr/bin/sesori-desktop"
HELPER = "/opt/sesori-desktop/bridge/bin/bridge"


class AuthenticatedQualificationFailure(RuntimeError):
    def __init__(self, *, phase: str, cause: Exception):
        self.cause = cause
        super().__init__(f"Authenticated Linux qualification failed during {phase}")


def require_native_main(*, architecture: str) -> None:
    require(platform.system() == "Linux" and os.environ.get("GITHUB_ACTIONS") == "true",
            "Authenticated qualification requires a disposable Linux Actions runner")
    require(os.environ.get("GITHUB_REF") == "refs/heads/main"
            and os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch",
            "Authenticated qualification requires a manual main dispatch")
    require(platform.machine() == {"x64": "x86_64", "arm64": "aarch64"}[architecture],
            "CPU emulation is not qualification")
    require(os.geteuid() != 0, "The desktop must run as the ordinary runner user, never root")
    require(not Path("/opt/sesori-desktop").exists(), "Runner already has a Sesori installation")


def installed_helper_pid() -> int | None:
    result = subprocess.run(["pgrep", "-f", "^" + HELPER + r"( |$)"],
                            capture_output=True, text=True, timeout=10)
    require(result.returncode in (0, 1), "Could not inspect the installed helper")
    rows = result.stdout.splitlines()
    require(len(rows) <= 1, "More than one packaged helper is running")
    return int(rows[0]) if rows else None


def require_quit_at_menu_end(*, layout) -> None:
    # Read-only DBusMenu inspection. Actual activation uses the host's keyboard path.
    visible = [node for node in layout[2] if node[1].get("visible", True)
               and node[1].get("type") != "separator"]
    require(bool(visible) and visible[-1][1].get("label") == "Quit Sesori"
            and bool(visible[-1][1].get("enabled", True)) and not visible[-1][2],
            "The host menu does not end with an enabled Quit Sesori action")


def visible_popup(*, pid: int, env: dict[str, str]) -> bool:
    for window in run(arguments=["xdotool", "search", "--onlyvisible", "--pid", str(pid)], env=env).splitlines():
        kind = run(arguments=["xprop", "-id", window, "_NET_WM_WINDOW_TYPE"], env=env)
        if "_NET_WM_WINDOW_TYPE_POPUP_MENU" in kind:
            return True
    return False


def exercise(*, inputs: Path, probes: Path, output: Path, desktop: Desktop, architecture: str) -> None:
    require_native_main(architecture=architecture)
    credentials = load_qa_credentials()
    os.umask(0o077)
    # In particular, the new session-bus daemon must never inherit the repository secrets.
    command = ["dbus-run-session", "--", "/usr/bin/python3", str(Path(__file__).resolve()), "session",
               "--inputs", str(inputs), "--probes", str(probes), "--output", str(output),
               "--desktop", desktop, "--architecture", architecture]
    result = subprocess.run(command, input=f"{credentials.email}\n{credentials.password}\n", text=True,
                            check=False)
    require(result.returncode == 0, "Authenticated Linux session failed; inspect bounded phase evidence")


def session(*, inputs: Path, probes: Path, output: Path, desktop: Desktop, architecture: str,
            credentials: QaCredentials) -> None:
    require_native_main(architecture=architecture)
    require("DBUS_SESSION_BUS_ADDRESS" in os.environ, "An owned session bus is required")
    import dbus

    output.mkdir(parents=True)
    processes = []
    logs = []
    observations = []
    phase = "session-start"
    with tempfile.TemporaryDirectory(prefix="sesori-authenticated-linux-", dir=os.environ["RUNNER_TEMP"]) as directory:
        home = Path(directory)
        private = home / "private"
        private.mkdir(mode=0o700)
        env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
               "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
               "XDG_RUNTIME_DIR": str(home / "runtime"), "LIBGL_ALWAYS_SOFTWARE": "1",
               "QT_QUICK_BACKEND": "software", "QT_LINUX_ACCESSIBILITY_ALWAYS_ON": "1",
               "NO_AT_BRIDGE": "0", "LC_ALL": "C.UTF-8"}
        Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)
        bus = dbus.SessionBus()

        def start(*, arguments: list[str], label: str, stdin=None):
            log = (private / f"{label}.log").open("w")
            logs.append(log)
            process = subprocess.Popen(arguments, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       stdin=stdin, start_new_session=True)
            processes.append(process)
            return process

        def shell_eval(*, script: str):
            shell = dbus.Interface(bus.get_object("org.gnome.Shell", "/org/gnome/Shell"), "org.gnome.Shell")
            success, value = shell.Eval(script)
            require(bool(success), "Owned GNOME operation failed")
            return json.loads(str(value))

        def window(*, process):
            require(process.poll() is None, "Signed application exited before normal Quit")
            if desktop == Desktop.GNOME:
                return shell_eval(script=f"global.get_window_actors().filter(a => a.meta_window.get_pid() === "
                                  f"{process.pid}).map(a => a.meta_window.get_stable_sequence())")
            return [row.split()[0] for row in run(arguments=["wmctrl", "-lp"], env=env).splitlines()
                    if len(row.split()) > 3 and row.split()[2] == str(process.pid)]

        def tray_quit(*, process):
            import pyatspi
            from gi.repository import GLib

            connection = dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                                        "org.freedesktop.DBus")
            plasma_pid = int(connection.GetConnectionUnixProcessID("org.kde.plasmashell"))
            watcher = dbus.Interface(bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher"),
                                     "org.freedesktop.DBus.Properties")
            for item in watcher.Get("org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"):
                service, _, path = str(item).partition("/")
                if int(connection.GetConnectionUnixProcessID(service)) != process.pid:
                    continue
                properties = dbus.Interface(bus.get_object(service, "/" + path), "org.freedesktop.DBus.Properties")
                menu_path = str(properties.Get("org.kde.StatusNotifierItem", "Menu"))
                require(menu_path not in ("/", "/NO_DBUSMENU"), "No native tray menu is advertised")
                title = str(properties.Get("org.kde.StatusNotifierItem", "Title"))

                def icon():
                    context = GLib.MainContext.default()
                    while context.iteration(False):
                        pass
                    for application in pyatspi.Registry.getDesktop(0):
                        if application.get_process_id() == plasma_pid:
                            return pyatspi.findDescendant(application, lambda node: node.name == title
                                and node.getState().contains(pyatspi.STATE_SHOWING))
                    return None

                target = wait_for(description="owned visible tray icon", check=icon)
                bounds = target.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
                require(bounds.width > 0 and bounds.height > 0, "Native tray icon has no visible bounds")
                menu = dbus.Interface(bus.get_object(service, menu_path), "com.canonical.dbusmenu")
                _, layout = menu.GetLayout(dbus.Int32(0), dbus.Int32(-1),
                    dbus.Array(["label", "enabled", "visible", "type"], signature="s"))
                require_quit_at_menu_end(layout=layout)
                run(arguments=["xdotool", "mousemove", "--sync", str(bounds.x + bounds.width // 2),
                               str(bounds.y + bounds.height // 2), "click", MouseButton.SECONDARY], env=env)
                wait_for(description="host-owned visible popup", check=lambda: visible_popup(pid=plasma_pid, env=env))
                # QMenu's End selects its last visible action. Return is a normal native user activation.
                # No pixels/OCR, fixed row coordinates or DBusMenu Event injection in an authenticated session.
                run(arguments=["xdotool", "key", "--clearmodifiers", "End", "Return"], env=env)
                return
            raise ValueError("No native tray item belongs to the signed application")

        def probe(*, candidate: Candidate, operation: ProbePhase) -> Path:
            nonlocal phase
            phase = f"{candidate}-{operation}"
            require(installed_helper_pid() is None, "A helper is running before the nonshipping fixture")
            report = private / f"{phase}.txt"
            payload = credentials.email + "\n"
            if operation == ProbePhase.LOGIN_ON:
                payload += credentials.password + "\n"
            result = subprocess.run([str(probes / candidate / "sesori_desktop")], input=payload, text=True,
                env={**env, "SESORI_AUTHENTICATED_PROBE_PHASE": operation,
                     "SESORI_AUTHENTICATED_PROBE_OUTPUT": str(report)}, capture_output=True, timeout=90)
            (private / f"{phase}.log").write_text(result.stdout + result.stderr)
            require(result.returncode == 0 and report.read_text() == f"PASS {operation}\n",
                    f"{phase}: native auth/persistence fixture failed")
            support = Path(Path(str(report) + ".support-path").read_text()).resolve()
            require(support.is_relative_to(home), "Native application support escaped the disposable home")
            require(installed_helper_pid() is None, "Nonshipping fixture started a packaged helper")
            return support

        def launch(*, candidate: Candidate, intent: HelperIntent, support: Path):
            nonlocal phase
            phase = f"{candidate}-{intent}"
            bridge_log = support / "logs/bridge.log"
            # No app/helper is running. Remove only this fixture's prior private log so readiness is fresh.
            bridge_log.unlink(missing_ok=True)
            process = start(arguments=[APPLICATION], label=phase)
            bounds = wait_for(description="signed native window", check=lambda: window(process=process))
            application_log = private / f"{phase}.log"
            wait_for(description="signed Flutter rendering", check=lambda:
                "Desktop startup: rendering the application" in application_log.read_text())
            helper_pid = None

            def helper_ready():
                nonlocal helper_pid
                require(process.poll() is None, "Signed GUI exited before helper readiness")
                current = installed_helper_pid()
                if helper_pid is not None:
                    require(current == helper_pid, "Packaged helper exited or restarted during qualification")
                helper_pid = current
                if current is None:
                    return False
                require(Path(f"/proc/{current}/exe").resolve() == Path(HELPER), "Helper executable differs")
                status = Path(f"/proc/{current}/status").read_text().splitlines()
                parent = next(line.split()[1] for line in status if line.startswith("PPid:"))
                require(int(parent) == process.pid, "Packaged helper is not owned by the signed GUI")
                text = bridge_log.read_text() if bridge_log.exists() else ""
                return "Authenticated as " in text and "Waiting for relay events..." in text

            if intent == HelperIntent.ON:
                wait_for(description="authenticated packaged helper serving the relay", check=helper_ready, timeout=90)
            else:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    require(process.poll() is None and installed_helper_pid() is None,
                            "Persisted helper Off was not honored")
                    time.sleep(0.1)
            if desktop == Desktop.GNOME:
                shell_eval(script=f"global.get_window_actors().filter(a => a.meta_window.get_pid() === "
                           f"{process.pid}).forEach(a => a.meta_window.delete(global.get_current_time())); true")
            else:
                run(arguments=["wmctrl", "-ic", bounds[0]], env=env)
                wait_for(description="close-to-tray", check=lambda: not window(process=process))
                tray_quit(process=process)
            process.wait(timeout=30)
            require(process.returncode == 0, "Signed application's normal Quit failed")
            require(installed_helper_pid() is None, "Packaged helper remains after normal Quit")
            observation = {"candidate": candidate, "helperIntent": intent, "nativeWindowAndQuit": True,
                           "packagedHelperAbsentAfterQuit": True,
                           "trayDisposedDiagnosticObserved":
                               "Failed to update the system tray menu: Bad state: System tray is disposed"
                               in application_log.read_text()}
            if intent == HelperIntent.ON:
                observation.update({"authenticatedProfileConfirmed": True, "relayServing": True})
            else:
                observation["helperAbsentDuringOff"] = True
            observations.append(observation)

        def install(*, candidate: Candidate):
            release = json.loads((inputs / candidate / MANIFEST).read_text())
            filename = f"Sesori-linux-{architecture}-{release['version']}-{release['buildNumber']}.deb"
            package = inputs / candidate / filename
            run(arguments=["sudo", "apt-get", "install", "--yes", str(package)], timeout=240)
            identity = json.loads(Path("/opt/sesori-desktop/bridge/desktop-bundle.json").read_text())
            require(all(identity[key] == release[key] for key in ("version", "buildNumber", "sourceSha")),
                    "Installed signed identity differs from the authenticated producer")
            return {key: identity[key] for key in ("version", "buildNumber", "sourceSha")}

        try:
            if desktop == Desktop.GNOME:
                env.update({"XDG_CURRENT_DESKTOP": "GNOME", "XDG_SESSION_TYPE": "wayland",
                            "WAYLAND_DISPLAY": "sesori-wayland", "GDK_BACKEND": "wayland"})
            else:
                env.update({"DISPLAY": ":95", "XDG_CURRENT_DESKTOP": "KDE", "XDG_SESSION_TYPE": "x11",
                            "GDK_BACKEND": "x11", "QT_XCB_GL_INTEGRATION": "none"})
            activation = {key: value for key, value in env.items()
                          if key.startswith("XDG_") or key in ("HOME", "DISPLAY", "WAYLAND_DISPLAY", "GDK_BACKEND")}
            dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                           "org.freedesktop.DBus").UpdateActivationEnvironment(activation)
            keyring = start(arguments=["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets"],
                            label="keyring", stdin=subprocess.PIPE)
            keyring.stdin.write(b"disposable-ci-keyring\n")
            keyring.stdin.close()
            wait_for(description="Secret Service", check=lambda: bus.name_has_owner("org.freedesktop.secrets"))
            if desktop == Desktop.GNOME:
                # Private runner-local bus permits only window IDs/close, never captures or account text.
                start(arguments=["gnome-shell", "--wayland", "--headless", "--virtual-monitor=1280x800",
                                 "--wayland-display=sesori-wayland", "--unsafe-mode"], label="desktop")
                wait_for(description="GNOME compositor", check=lambda: bus.name_has_owner("org.gnome.Shell"))
                require(not bus.name_has_owner("org.kde.StatusNotifierWatcher"), "Expected GNOME without a tray host")
            else:
                run(arguments=["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", "true"],
                    env=env)
                run(arguments=["kwriteconfig5", "--file", "kscreenlockerrc", "--group", "Daemon",
                               "--key", "Autolock", "false"], env=env)
                start(arguments=["Xvfb", ":95", "-screen", "0", "1280x800x24", "-nolisten", "tcp"], label="x11")
                wait_for(description="X11 socket", check=lambda: Path("/tmp/.X11-unix/X95").exists())
                start(arguments=["startplasma-x11"], label="desktop")
                wait_for(description="KDE tray host", check=lambda: bus.name_has_owner("org.kde.StatusNotifierWatcher"))
            phase = "previous-install"
            previous = install(candidate=Candidate.PREVIOUS)
            support = probe(candidate=Candidate.PREVIOUS, operation=ProbePhase.LOGIN_ON)
            launch(candidate=Candidate.PREVIOUS, intent=HelperIntent.ON, support=support)
            probe(candidate=Candidate.PREVIOUS, operation=ProbePhase.ON_TO_OFF)
            launch(candidate=Candidate.PREVIOUS, intent=HelperIntent.OFF, support=support)
            phase = "current-install"
            current = install(candidate=Candidate.CURRENT)
            # The new signed GUI opens old data before any new-source probe can rewrite it.
            launch(candidate=Candidate.CURRENT, intent=HelperIntent.OFF, support=support)
            probe(candidate=Candidate.CURRENT, operation=ProbePhase.OFF_TO_ON)
            launch(candidate=Candidate.CURRENT, intent=HelperIntent.ON, support=support)
            probe(candidate=Candidate.CURRENT, operation=ProbePhase.ON_TO_LOGOUT)
            phase = "package-removal"
            run(arguments=["sudo", "apt-get", "remove", "--yes", "sesori-desktop"], timeout=120)
            (output / "result.json").write_text(json.dumps({
                "architecture": architecture, "hostArchitecture": platform.machine(), "desktop": desktop,
                "previous": previous, "current": current, "observations": observations,
                "authenticatedSessionSurvivesReplacement": True, "helperOnOffRestoration": True,
                "productSourceChanged": previous["sourceSha"] != current["sourceSha"],
                "loginSessionAutostartQualified": False, "unavailableSecretServiceQualified": False,
                "otherNominatedDistrosQualified": False, "stableAdmission": False,
            }, indent=2) + "\n")
        except Exception as error:
            # Never serialize exception text, process output, names or token-bearing data.
            (output / "failure.json").write_text(json.dumps({"phase": phase, "errorType": type(error).__name__,
                                                           "completedObservations": observations}, indent=2) + "\n")
            raise AuthenticatedQualificationFailure(phase=phase, cause=error) from None
        finally:
            for process in reversed(processes):
                stop_process(process=process)
            for log in logs:
                log.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("exercise", "session"))
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--probes", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--desktop", type=Desktop, choices=list(Desktop), required=True)
    parser.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    args = parser.parse_args()
    arguments = {"inputs": args.inputs.resolve(), "probes": args.probes.resolve(),
                 "output": args.output.resolve(), "desktop": args.desktop, "architecture": args.architecture}
    if args.stage == "exercise":
        exercise(**arguments)
    else:
        signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(128 + signum))
        signal.signal(signal.SIGINT, lambda signum, frame: sys.exit(128 + signum))
        email, password = sys.stdin.readline().removesuffix("\n"), sys.stdin.readline().removesuffix("\n")
        require(bool(email) and bool(password), "Missing private QA input")
        session(**arguments, credentials=QaCredentials(email=email, password=password))


if __name__ == "__main__":
    main()
