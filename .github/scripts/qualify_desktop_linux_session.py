"""Native, disposable Actions desktops. No account credentials, publishing or stable admission."""

import argparse
from enum import StrEnum
import json
import os
from pathlib import Path
import platform
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


def run(*, arguments: list[str], env: dict[str, str] | None = None, timeout: int = 120) -> str:
    result = subprocess.run(arguments, env=env, capture_output=True, text=True, timeout=timeout)
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
                                  f"{process.pid}).map(a => {{ const r=a.meta_window.get_frame_rect(); "
                                  "return [r.x,r.y,r.width,r.height]; })")
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
                # Drain accessibility cache updates after the host opens its menu.
                context = GLib.MainContext.default()
                while context.iteration(False):
                    pass
                for application in pyatspi.Registry.getDesktop(0):
                    if application.get_process_id() == plasma_pid:
                        return pyatspi.findDescendant(
                            application, lambda node: node.name == name
                            and node.getState().contains(pyatspi.STATE_SHOWING))
                return None

            def click(*, node):
                bounds = node.queryComponent().getExtents(pyatspi.DESKTOP_COORDS)
                require(bounds.width > 0 and bounds.height > 0, "Native tray target has no visible bounds")
                run(arguments=["xdotool", "mousemove", "--sync", str(bounds.x + bounds.width // 2),
                               str(bounds.y + bounds.height // 2), "click", "1"], env=env)

            for item in items:
                service, _, path = str(item).partition("/")
                if int(connection.GetConnectionUnixProcessID(service)) != process.pid:
                    continue
                properties = dbus.Interface(bus.get_object(service, "/" + path), "org.freedesktop.DBus.Properties")
                menu_path = str(properties.Get("org.kde.StatusNotifierItem", "Menu"))
                require(menu_path not in ("/", "/NO_DBUSMENU"), "Native tray does not advertise a usable menu")
                title = str(properties.Get("org.kde.StatusNotifierItem", "Title"))
                icon = wait_for(description=f"visible native tray icon {title!r}", check=lambda: accessible(name=title))
                click(node=icon)
                quit_item = wait_for(description="visible native Quit item",
                                     check=lambda: accessible(name="Quit Sesori"))
                time.sleep(0.3)  # Let the native popup transition render before capture and click.
                run(arguments=["import", "-window", "root", str(output / f"{label}-anonymous-menu.png")], env=env)
                click(node=quit_item)
                return
            raise ValueError("No StatusNotifier item belongs to the application")

        def probe(*, label: str, phase: str):
            report = output / f"{label}-storage.txt"
            result = run(arguments=[str(probes / label / "sesori_desktop")],
                         env={**env, "SESORI_PACKAGED_PROBE_PHASE": phase,
                              "SESORI_PACKAGED_PROBE_OUTPUT": str(report)})
            (output / f"{label}-probe.log").write_text(result)
            require(report.read_text().startswith("PASS shared SQLite/Secret Service"), "Native storage probe failed")

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
            keyring = start(arguments=["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets"],
                            label="keyring", stdin=subprocess.PIPE)
            keyring.stdin.write(b"disposable-ci-keyring\n")
            keyring.stdin.close()
            wait_for(description="Secret Service", check=lambda: bus.name_has_owner("org.freedesktop.secrets"))
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
                    success, _ = capture.ScreenshotArea(*bounds[0], False, str(screenshot))
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
                observations.append({"candidate": label, "identity": identity, "nativeWindowAndQuit": True,
                                     "closeToTray": desktop == Desktop.KDE, "screenshot": screenshot.name})
            probe(label="current", phase="read")
            run(arguments=["sudo", "apt-get", "remove", "--yes", "sesori-desktop"], timeout=120)
            (output / "result.json").write_text(json.dumps({
                "desktop": desktop, "architecture": architecture, "hostArchitecture": platform.machine(),
                "observations": observations, "nativeStorageSurvivesUpgrade": True,
                "productSourceChanged": (observations[0]["identity"]["sourceSha"]
                                         != observations[1]["identity"]["sourceSha"]),
                "loginRegistrationRoundTrip": True, "authenticatedAccountQualified": False,
                "loginSessionAutostartQualified": False, "stableAdmission": False,
            }, indent=2) + "\n")
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=10)
            for log in logs:
                log.close()


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
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(inputs=args.inputs.resolve(), output=args.output.resolve(), previous=args.previous,
                current=args.current, tooling_sha=args.tooling_sha)
    else:
        exercise(inputs=args.inputs.resolve(), probes=args.probes.resolve(), output=args.output.resolve(),
                 desktop=args.desktop, architecture=args.architecture)


if __name__ == "__main__":
    main()
