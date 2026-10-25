"""Native, disposable Actions desktops. No account credentials, publishing or stable admission."""

import argparse
from contextlib import suppress
import csv
from enum import StrEnum
import io
import json
import os
from pathlib import Path
import platform
import pwd
import signal
import subprocess
import tempfile
import time

from build_linux_repository import Channel, verify_release
from github_release_assets import github
from prepare_desktop_release import read_json, require
from publish_desktop_linux import MANIFEST, TRUSTED_PRIMARY_FINGERPRINT, prepare as prepare_signed
from publish_linux_repository import REPOSITORY, version_order


class Desktop(StrEnum):
    GNOME = "gnome-wayland"
    KDE = "kde-x11"


# Exactly what IoLaunchAtLogin writes for the packaged executable. The authenticated driver proves
# the signed app's first run writes these bytes; the login job boots a genuine session from them.
LOGIN_REGISTRATION = ("[Desktop Entry]\nType=Application\nVersion=1.0\nName=Sesori\n"
                      'Exec="/opt/sesori-desktop/sesori_desktop" "--hidden"\n'
                      "Terminal=false\nStartupNotify=false\nX-GNOME-Autostart-enabled=true\n")
HIDDEN_LAUNCH = ["/opt/sesori-desktop/sesori_desktop", "--hidden"]


class MouseButton(StrEnum):
    PRIMARY = "1"
    SECONDARY = "3"


def run(*, arguments: list[str], env: dict[str, str] | None = None, timeout: int = 120,
        input_text: str | None = None) -> str:
    result = subprocess.run(arguments, env=env, input=input_text, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {arguments}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def wait_for(*, description: str, check, timeout: int = 60):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.25)
    raise TimeoutError(f"Timed out waiting for {description}")


def stop_process(*, process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    # Normal Quit can complete between poll and signal. Still reap the tracked child.
    with suppress(ProcessLookupError):
        os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        with suppress(ProcessLookupError):
            os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=10)


def prepare(*, inputs: Path, output: Path, previous: int, current: int, tooling_sha: str) -> None:
    output.mkdir(parents=True)
    releases = {}
    for label, run_id in (("previous", previous), ("current", current)):
        root = inputs / label
        producer = github(arguments=["api", f"repos/{REPOSITORY}/actions/runs/{run_id}"])
        (root / "run.json").write_text(producer)
        identity = read_json(root / "desktop-linux-evidence-x64/desktop-bundle/bundle/bridge/desktop-bundle.json")
        # Reuse the publisher's non-publishing preparation: original signed bytes,
        # trusted main producer, compiled identity and native package evidence.
        releases[label] = prepare_signed(
            root=root, output=output / label, source_sha=identity["sourceSha"], tooling_sha=tooling_sha,
            repository=REPOSITORY, run_id=run_id, current_run_id=None,
            version=identity["version"], build_number=identity["buildNumber"])
        verify_release(root=output / label, channel=Channel.INTERNAL, fingerprint=TRUSTED_PRIMARY_FINGERPRINT)
    versions = [version_order(version=f"{releases[label]['version']}-{releases[label]['buildNumber']}")
                for label in ("previous", "current")]
    require(versions[0] < versions[1], "Select a genuine increasing package upgrade")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as target:
        for label, release in releases.items():
            target.write(f"{label}_source={release['sourceSha']}\n")


def quit_text_point(*, tsv: str, origin_x: int, origin_y: int) -> tuple[int, int] | None:
    lines = {}
    for word in csv.DictReader(io.StringIO(tsv), delimiter="\t"):
        if word["text"].strip():
            line = tuple(word[key] for key in ("page_num", "block_num", "par_num", "line_num"))
            lines.setdefault(line, []).append(word)
    for words in lines.values():
        if " ".join(word["text"].strip() for word in words) != "Quit Sesori":
            continue
        left = min(int(word["left"]) for word in words)
        top = min(int(word["top"]) for word in words)
        right = max(int(word["left"]) + int(word["width"]) for word in words)
        bottom = max(int(word["top"]) + int(word["height"]) for word in words)
        return origin_x + (left + right) // 2, origin_y + (top + bottom) // 2
    return None


def native_quit_point(*, pid: int, capture: Path, env: dict[str, str]) -> tuple[int, int] | None:
    windows = run(arguments=["xdotool", "search", "--onlyvisible", "--pid", str(pid)], env=env)
    for window_id in windows.splitlines():
        kind = run(arguments=["xprop", "-id", window_id, "_NET_WM_WINDOW_TYPE"], env=env)
        if "_NET_WM_WINDOW_TYPE_POPUP_MENU" not in kind:
            continue
        geometry = dict(line.split("=", 1) for line in run(
            arguments=["xdotool", "getwindowgeometry", "--shell", window_id], env=env).splitlines())
        # Plasma's real QWidget popup is not exported in its AT-SPI tree. Read the
        # visible label within that host-owned window, not an assumed row/offset.
        run(arguments=["import", "-window", window_id, str(capture)], env=env)
        tsv = run(arguments=["tesseract", str(capture), "stdout", "-l", "eng", "--psm", "6", "tsv"], env=env)
        capture.with_suffix(".tsv").write_text(tsv)
        point = quit_text_point(tsv=tsv, origin_x=int(geometry["X"]), origin_y=int(geometry["Y"]))
        if point:
            return point
    return None


def exercise(*, inputs: Path, probes: Path, output: Path, desktop: Desktop, architecture: str) -> None:
    # Never run the root installer or session controls on a developer's own machine.
    require(platform.system() == "Linux" and os.environ.get("GITHUB_ACTIONS") == "true",
            "Native session qualification requires a disposable Linux Actions runner")
    require(platform.machine() == {"x64": "x86_64", "arm64": "aarch64"}[architecture],
            "CPU emulation is not qualification")
    require(os.geteuid() != 0, "The desktop must run as the ordinary runner user, never root")
    require(not Path("/opt/sesori-desktop").exists(), "Runner already has a Sesori installation")
    require("DBUS_SESSION_BUS_ADDRESS" in os.environ, "Run this driver inside its own dbus-run-session")
    # The distro Python supplies its real D-Bus binding; no mock notification host.
    import dbus

    output.mkdir(parents=True)
    processes = []
    logs = []
    observations = []
    with tempfile.TemporaryDirectory(prefix="sesori-linux-session-", dir=os.environ["RUNNER_TEMP"]) as directory:
        home = Path(directory)
        env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
               "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
               "XDG_RUNTIME_DIR": str(home / "runtime"), "LIBGL_ALWAYS_SOFTWARE": "1",
               "QT_QUICK_BACKEND": "software", "QT_LINUX_ACCESSIBILITY_ALWAYS_ON": "1",
               "NO_AT_BRIDGE": "0", "LC_ALL": "C.UTF-8"}
        Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)
        bus = dbus.SessionBus()

        def start(*, arguments: list[str], label: str, stdin=None):
            log = (output / f"{label}.log").open("w")
            logs.append(log)
            process = subprocess.Popen(arguments, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       stdin=stdin, start_new_session=True)
            processes.append(process)
            return process

        def shell_eval(*, script: str):
            shell = dbus.Interface(bus.get_object("org.gnome.Shell", "/org/gnome/Shell"), "org.gnome.Shell")
            success, value = shell.Eval(script)
            require(bool(success), f"Owned GNOME inspection failed: {value}")
            return json.loads(str(value))

        def window(*, process):
            require(process.poll() is None, f"Application exited early: {process.returncode}")
            if desktop == Desktop.GNOME:
                return shell_eval(script=f"global.get_window_actors().filter(a => a.meta_window.get_pid() === "
                                  f"{process.pid}).map(a => a.meta_window.get_stable_sequence())")
            rows = run(arguments=["wmctrl", "-lp"], env=env).splitlines()
            return [row.split()[0] for row in rows if len(row.split()) > 3 and row.split()[2] == str(process.pid)]

        def tray_quit(*, process, label: str):
            import pyatspi
            from gi.repository import GLib

            watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
            items = dbus.Interface(watcher, "org.freedesktop.DBus.Properties").Get(
                "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
            connection = dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                                        "org.freedesktop.DBus")
            plasma_pid = int(connection.GetConnectionUnixProcessID("org.kde.plasmashell"))

            def accessible(*, name: str):
                # Drain accessibility updates before locating the visible tray icon.
                context = GLib.MainContext.default()
                while context.iteration(False):
                    pass
                for application in pyatspi.Registry.getDesktop(0):
                    if application.get_process_id() == plasma_pid:
                        return pyatspi.findDescendant(
                            application, lambda node: node.name == name
                            and node.getState().contains(pyatspi.STATE_SHOWING))
                return None

            def click(*, x: int, y: int, button: MouseButton):
                run(arguments=["xdotool", "mousemove", "--sync", str(x), str(y), "click", button], env=env)

            for item in items:
                service, _, path = str(item).partition("/")
                if int(connection.GetConnectionUnixProcessID(service)) != process.pid:
                    continue
                properties = dbus.Interface(bus.get_object(service, "/" + path), "org.freedesktop.DBus.Properties")
                menu_path = str(properties.Get("org.kde.StatusNotifierItem", "Menu"))
                require(menu_path not in ("/", "/NO_DBUSMENU"), "Native tray does not advertise a usable menu")
                title = str(properties.Get("org.kde.StatusNotifierItem", "Title"))
                icon = wait_for(description=f"visible native tray icon {title!r}", check=lambda: accessible(name=title))
                bounds = icon.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
                require(bounds.width > 0 and bounds.height > 0, "Native tray target has no visible bounds")
                # Plasma 5.27 forwards primary clicks as Activate; its context-menu gesture is right-click.
                click(x=bounds.x + bounds.width // 2, y=bounds.y + bounds.height // 2, button=MouseButton.SECONDARY)
                try:
                    quit_x, quit_y = wait_for(
                        description="visible native Quit item",
                        check=lambda: native_quit_point(pid=plasma_pid,
                                                       capture=output / f"{label}-anonymous-menu-window.png", env=env))
                finally:
                    # Retain the host's visible state even when visual label lookup fails.
                    run(arguments=["import", "-window", "root", str(output / f"{label}-anonymous-menu.png")], env=env)
                click(x=quit_x, y=quit_y, button=MouseButton.PRIMARY)
                return
            raise ValueError("No StatusNotifier item belongs to the application")

        def probe(*, label: str, phase: str):
            report = output / f"{label}-{phase}-storage.txt"
            result = run(arguments=[str(probes / label / "sesori_desktop")],
                         env={**env, "SESORI_PACKAGED_PROBE_PHASE": phase,
                              "SESORI_PACKAGED_PROBE_OUTPUT": str(report)})
            (output / f"{label}-{phase}-probe.log").write_text(result)
            require(report.read_text().startswith("PASS shared SQLite/Secret Service"), "Native storage probe failed")

        def start_keyring():
            keyring = start(arguments=["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets"],
                            label="keyring", stdin=subprocess.PIPE)
            keyring.stdin.write(b"disposable-ci-keyring\n")
            keyring.stdin.close()
            wait_for(description="Secret Service", check=lambda: bus.name_has_owner("org.freedesktop.secrets"))
            return keyring

        def launch_and_quit(*, label: str) -> None:
            process = start(arguments=["/usr/bin/sesori-desktop"], label=f"{label}-application")
            bounds = wait_for(description=f"{label} application window", check=lambda: window(process=process))
            application_log = output / f"{label}-application.log"
            wait_for(description=f"{label} Flutter rendering", check=lambda:
                     "Desktop startup: rendering the application" in application_log.read_text())
            # Allow compositor frames after the logged runApp call; inspect saved images before accepting evidence.
            time.sleep(2)
            screenshot = output / f"{label}-anonymous.png"
            if desktop == Desktop.GNOME:
                capture = dbus.Interface(
                    bus.get_object("org.gnome.Shell.Screenshot", "/org/gnome/Shell/Screenshot"),
                    "org.gnome.Shell.Screenshot")
                shell_eval(script=f"global.get_window_actors().filter(a => a.meta_window.get_pid() === "
                           f"{process.pid}).forEach(a => a.meta_window.activate(global.get_current_time())); true")
                # Capture the focused native window, not an early or off-screen frame rectangle.
                success, _ = capture.ScreenshotWindow(True, False, False, str(screenshot))
                require(bool(success), "GNOME application capture failed")
                shell_eval(script=f"global.get_window_actors().filter(a => a.meta_window.get_pid() === "
                           f"{process.pid}).forEach(a => a.meta_window.delete(global.get_current_time())); true")
            else:
                run(arguments=["import", "-window", bounds[0], str(screenshot)], env=env)
                run(arguments=["wmctrl", "-ic", bounds[0]], env=env)
                wait_for(description="close-to-tray", check=lambda: not window(process=process))
                run(arguments=["import", "-window", "root", str(output / f"{label}-anonymous-tray.png")], env=env)
                tray_quit(process=process, label=label)
            process.wait(timeout=30)
            require(process.returncode == 0, f"Normal Quit failed: {process.returncode}")
            helper = subprocess.run(["pgrep", "-f", r"^/opt/sesori-desktop/bridge/bin/bridge( |$)"],
                                    capture_output=True, text=True, timeout=10)
            require(helper.returncode == 1, f"Packaged helper remains after Quit: {helper.stdout}{helper.stderr}")
            require(screenshot.is_file() and screenshot.stat().st_size > 1000, "Missing native window capture")
            identity = json.loads(Path("/opt/sesori-desktop/bridge/desktop-bundle.json").read_text())
            observations.append({"candidate": label, "identity": identity, "nativeWindowAndQuit": True,
                                 "closeToTray": desktop == Desktop.KDE, "screenshot": screenshot.name})

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
            # Both sessions deliberately use GNOME Keyring's real Secret Service, not a fake store.
            keyring = start_keyring()
            if desktop == Desktop.GNOME:
                # Unsafe mode permits inspection only inside this disposable, credential-free QA session.
                start(arguments=["gnome-shell", "--wayland", "--headless", "--virtual-monitor=1280x800",
                                 "--wayland-display=sesori-wayland", "--unsafe-mode"], label="desktop")
                wait_for(description="GNOME compositor", check=lambda: bus.name_has_owner("org.gnome.Shell"))
                require(not bus.name_has_owner("org.kde.StatusNotifierWatcher"), "Expected GNOME without a tray host")
            else:
                run(arguments=["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", "true"], env=env)
                start(arguments=["Xvfb", ":95", "-screen", "0", "1280x800x24", "-nolisten", "tcp"], label="x11")
                wait_for(description="X11 socket", check=lambda: Path("/tmp/.X11-unix/X95").exists())
                start(arguments=["startplasma-x11"], label="desktop")
                wait_for(description="KDE StatusNotifier host",
                         check=lambda: bus.name_has_owner("org.kde.StatusNotifierWatcher"))
            probe(label="previous", phase="write")
            for label in ("previous", "current"):
                release = json.loads((inputs / label / MANIFEST).read_text())
                filename = f"Sesori-linux-{architecture}-{release['version']}-{release['buildNumber']}.deb"
                package = inputs / label / filename
                run(arguments=["sudo", "apt-get", "install", "--yes", str(package)], timeout=240)
                identity = json.loads(Path("/opt/sesori-desktop/bridge/desktop-bundle.json").read_text())
                require(all(identity[key] == release[key] for key in ("version", "buildNumber", "sourceSha")),
                        "Installed application identity differs from qualified release")
                launch_and_quit(label=label)
            # Remove the real Secret Service. The workflow blocks D-Bus re-activation, so the
            # signed app and probe meet an absent store rather than a silently restarted one.
            stop_process(process=keyring)
            wait_for(description="Secret Service absence", check=lambda: not bus.name_has_owner("org.freedesktop.secrets"))
            probe(label="current", phase="unavailable")
            launch_and_quit(label="current-unavailable")
            require(not bus.name_has_owner("org.freedesktop.secrets"), "Secret Service was re-activated")
            # The same keyring file and password return; the original encrypted value must still read back.
            keyring = start_keyring()
            probe(label="current", phase="read")
            run(arguments=["sudo", "apt-get", "remove", "--yes", "sesori-desktop"], timeout=120)
            (output / "result.json").write_text(json.dumps({
                "desktop": desktop, "architecture": architecture, "hostArchitecture": platform.machine(),
                "observations": observations, "nativeStorageSurvivesUpgrade": True,
                "unavailableSecretServicePreservesData": True,
                "productSourceChanged": (observations[0]["identity"]["sourceSha"]
                                         != observations[1]["identity"]["sourceSha"]),
                "loginRegistrationRoundTrip": True, "authenticatedAccountQualified": False,
                "loginSessionAutostartQualified": False, "stableAdmission": False,
            }, indent=2) + "\n")
        finally:
            for process in reversed(processes):
                stop_process(process=process)
            for log in logs:
                log.close()


def login(*, inputs: Path, output: Path, desktop: Desktop, architecture: str) -> None:
    """Boot the installed signed app through a real display-manager login of the runner user."""
    require(platform.system() == "Linux" and os.environ.get("GITHUB_ACTIONS") == "true",
            "Login qualification requires a disposable Linux Actions runner")
    require(platform.machine() == {"x64": "x86_64", "arm64": "aarch64"}[architecture],
            "CPU emulation is not qualification")
    require(not Path("/opt/sesori-desktop").exists(), "Runner already has a Sesori installation")
    output.mkdir(parents=True)
    uid = os.getuid()
    user = pwd.getpwuid(uid).pw_name
    # The session bus is the user's own, shared by the job and the display-manager login.
    env = {**os.environ, "XDG_RUNTIME_DIR": f"/run/user/{uid}", "DBUS_SESSION_BUS_ADDRESS": f"unix:path=/run/user/{uid}/bus"}
    release = json.loads((inputs / "current" / MANIFEST).read_text())
    package = inputs / "current" / f"Sesori-linux-{architecture}-{release['version']}-{release['buildNumber']}.deb"
    run(arguments=["sudo", "apt-get", "install", "--yes", str(package)], timeout=240)
    identity = json.loads(Path("/opt/sesori-desktop/bridge/desktop-bundle.json").read_text())
    require(all(identity[key] == release[key] for key in ("version", "buildNumber", "sourceSha")),
            "Installed application identity differs from qualified release")

    run(arguments=["sudo", "loginctl", "enable-linger", user])
    wait_for(description="user session bus", check=lambda: Path(f"/run/user/{uid}/bus").exists())
    # Autologin cannot unlock a keyring with a password, so the lingering user bus keeps one unlocked.
    # The daemon forks; discard its inherited output instead of waiting for the pipe to close.
    subprocess.run(["gnome-keyring-daemon", "--unlock", "--components=secrets"], env=env, check=True,
                   input="disposable-ci-keyring\n", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   text=True, timeout=30)
    run(arguments=["busctl", "--user", "status", "org.freedesktop.secrets"], env=env)
    registration = Path.home() / ".config/autostart/com.sesori.desktop.desktop"
    registration.parent.mkdir(parents=True, exist_ok=True)
    registration.write_text(LOGIN_REGISTRATION)

    if desktop == Desktop.GNOME:
        manager, session_type, autostart_cgroup = "gdm3", "wayland", "/app-gnome-com.sesori.desktop-"
        run(arguments=["sudo", "tee", "/etc/gdm3/custom.conf"], timeout=10, input_text=(
            f"[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin={user}\nWaylandEnable=true\n"))
    else:
        manager, session_type, autostart_cgroup = "sddm", "x11", "/app-com.sesori.desktop@autostart.service"
        run(arguments=["sudo", "mkdir", "-p", "/etc/sddm.conf.d"])
        run(arguments=["sudo", "tee", "/etc/sddm.conf.d/autologin.conf"], timeout=10,
            input_text=f"[Autologin]\nUser={user}\nSession=plasma\n")
    run(arguments=["sudo", "systemctl", "start", manager])

    def hidden_pid():
        for entry in Path("/proc").iterdir():
            with suppress(OSError):
                if entry.name.isdigit() and (entry / "cmdline").read_bytes().split(b"\0")[:-1] == [
                        part.encode() for part in HIDDEN_LAUNCH]:
                    return int(entry.name)
        return None

    pid = wait_for(description="login-launched hidden application", check=hidden_pid, timeout=180)
    cgroup = Path(f"/proc/{pid}/cgroup").read_text()
    require(autostart_cgroup in cgroup, f"Application was not launched by session autostart: {cgroup}")
    environ = dict(line.split("=", 1) for line in Path(f"/proc/{pid}/environ").read_text().split("\0") if "=" in line)
    require(environ.get("XDG_SESSION_TYPE") == session_type, "Application is not in the expected session type")
    sessions = []
    for session in run(arguments=["loginctl", "list-sessions", "--no-legend"]).splitlines():
        fields = dict(line.split("=", 1) for line in run(arguments=[
            "loginctl", "show-session", session.split()[0], "-p", "Name", "-p", "Type", "-p", "Class",
            "-p", "Active", "-p", "Service"]).splitlines())
        sessions.append(fields)
    require({"Name": user, "Type": session_type, "Class": "user", "Active": "yes",
             "Service": f"{manager.removesuffix('3')}-autologin"} in sessions, f"No genuine login session: {sessions}")

    def journal() -> str:
        # gnome-session owns the stream it hands its children, so filter by text, not _PID.
        return run(arguments=["journalctl", "--user", "-b", "--no-pager", "-o", "cat"], env=env)

    wait_for(description="hidden Flutter rendering", check=lambda: "Desktop startup: rendering the application" in journal())
    if desktop == Desktop.GNOME:
        # GNOME has no tray host: a hidden launch must surface the window instead of disappearing.
        wait_for(description="hidden-launch window fallback",
                 check=lambda: "keeping the desktop window visible" in journal())
    else:
        def owned_tray_item():
            items = run(arguments=["busctl", "--user", "get-property", "org.kde.StatusNotifierWatcher",
                                   "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
                                   "RegisteredStatusNotifierItems"], env=env)
            return f"org.kde.StatusNotifierItem-{pid}-" in items

        wait_for(description="tray item of the hidden application", check=owned_tray_item)
        display = {key: environ[key] for key in ("DISPLAY", "XAUTHORITY")}
        windows = run(arguments=["wmctrl", "-lp"], env={**env, **display}).splitlines()
        require(not [row for row in windows if len(row.split()) > 3 and row.split()[2] == str(pid)],
                "Hidden launch opened a window despite an available tray")
    if desktop == Desktop.GNOME:
        run(arguments=["busctl", "--user", "call", "org.gnome.SessionManager", "/org/gnome/SessionManager",
                       "org.gnome.SessionManager", "Logout", "u", "1"], env=env)
    else:
        run(arguments=["busctl", "--user", "call", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout"],
            env=env)
    wait_for(description="application exit at logout", check=lambda: not Path(f"/proc/{pid}").exists())
    leftovers = subprocess.run(["pgrep", "-f", "^/opt/sesori-desktop/"], capture_output=True, text=True, timeout=10)
    require(leftovers.returncode == 1, f"Sesori processes remain after logout: {leftovers.stdout}")
    run(arguments=["sudo", "apt-get", "remove", "--yes", "sesori-desktop"], timeout=120)
    (output / "result.json").write_text(json.dumps({
        "desktop": desktop, "architecture": architecture, "hostArchitecture": platform.machine(),
        "identity": identity, "displayManager": manager, "genuineLoginSession": True,
        "hiddenAutostartFromRegistration": True,
        "hiddenLaunchPresentation": "windowWithoutTray" if desktop == Desktop.GNOME else "trayWithoutWindow",
        "logoutEndsApplication": True, "authenticatedAccountQualified": False, "stableAdmission": False,
    }, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preparation = commands.add_parser("prepare")
    preparation.add_argument("--previous", type=int, required=True)
    preparation.add_argument("--current", type=int, required=True)
    preparation.add_argument("--inputs", type=Path, required=True)
    preparation.add_argument("--output", type=Path, required=True)
    preparation.add_argument("--tooling-sha", required=True)
    execution = commands.add_parser("exercise")
    execution.add_argument("--inputs", type=Path, required=True)
    execution.add_argument("--probes", type=Path, required=True)
    execution.add_argument("--output", type=Path, required=True)
    execution.add_argument("--desktop", type=Desktop, choices=list(Desktop), required=True)
    execution.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    session_login = commands.add_parser("login")
    session_login.add_argument("--inputs", type=Path, required=True)
    session_login.add_argument("--output", type=Path, required=True)
    session_login.add_argument("--desktop", type=Desktop, choices=list(Desktop), required=True)
    session_login.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(inputs=args.inputs.resolve(), output=args.output.resolve(), previous=args.previous,
                current=args.current, tooling_sha=args.tooling_sha)
    elif args.command == "login":
        login(inputs=args.inputs.resolve(), output=args.output.resolve(), desktop=args.desktop,
              architecture=args.architecture)
    else:
        exercise(inputs=args.inputs.resolve(), probes=args.probes.resolve(), output=args.output.resolve(),
                 desktop=args.desktop, architecture=args.architecture)


if __name__ == "__main__":
    main()
