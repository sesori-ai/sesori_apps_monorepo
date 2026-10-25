"""Arch AppImage replacement row; runs as the ordinary user inside a disposable container's own D-Bus session."""

import argparse
from contextlib import suppress
import glob
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import time

IMAGE = Path.home() / "Applications/Sesori.AppImage"
REGISTRATION = Path.home() / ".config/autostart/com.sesori.desktop.desktop"
MOUNTS = "/tmp/.mount_Sesori*"
RENDERED = "Desktop startup: rendering the application"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def wait_for(*, description: str, check, timeout: int = 90):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.25)
    raise TimeoutError(f"Timed out waiting for {description}")


def menu_items(*, layout) -> dict[str, int]:
    items = {}
    pending = [layout]
    while pending:
        identifier, properties, children = pending.pop()
        # Disabled text rows carry the status the driver asserts, so every labelled row is kept.
        if properties.get("label"):
            items[str(properties["label"])] = int(identifier)
        pending.extend(children)
    return items


def exercise(*, inputs: Path, probes: Path, output: Path, architecture: str) -> None:
    import dbus

    require(platform.machine() == {"x64": "x86_64", "arm64": "aarch64"}[architecture],
            "CPU emulation is not qualification")
    require(os.geteuid() != 0, "The desktop must run as an ordinary user, never root")
    runtime = Path("/tmp/qa-runtime")
    runtime.mkdir(mode=0o700)
    env = {**os.environ, "XDG_RUNTIME_DIR": str(runtime), "LIBGL_ALWAYS_SOFTWARE": "1",
           "XDG_CURRENT_DESKTOP": "KDE", "XDG_SESSION_TYPE": "wayland", "KDE_FULL_SESSION": "true",
           "WAYLAND_DISPLAY": "sesori-wayland", "QT_QPA_PLATFORM": "wayland", "GDK_BACKEND": "wayland"}
    bus = dbus.SessionBus()
    dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                   "org.freedesktop.DBus").UpdateActivationEnvironment(
        {key: env[key] for key in ("HOME", "XDG_RUNTIME_DIR", "XDG_CURRENT_DESKTOP", "WAYLAND_DISPLAY",
                                   "QT_QPA_PLATFORM", "GDK_BACKEND")})
    connection = dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"), "org.freedesktop.DBus")
    processes, logs, observations = [], [], []

    def start(*, arguments: list[str], label: str, stdin=None) -> subprocess.Popen:
        log = (output / f"{label}.log").open("w")
        logs.append(log)
        process = subprocess.Popen(arguments, env=env, stdout=log, stderr=subprocess.STDOUT, stdin=stdin,
                                   start_new_session=True)
        processes.append(process)
        return process

    def probe(*, label: str, phase: str) -> None:
        report = output / f"{label}-{phase}-storage.txt"
        with (output / f"{label}-{phase}-probe.log").open("w") as log:
            subprocess.run([str(probes / label / "sesori_desktop")], check=True, timeout=120, stdout=log,
                           stderr=subprocess.STDOUT, env={**env, "SESORI_PACKAGED_PROBE_PHASE": phase,
                                                          "SESORI_PACKAGED_PROBE_OUTPUT": str(report)})
        require(report.read_text().startswith("PASS shared SQLite/Secret Service"), "Native storage probe failed")

    def tray_menu(*, process: subprocess.Popen):
        require(process.poll() is None, f"Application exited early: {process.returncode}")
        watcher = dbus.Interface(bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher"),
                                 "org.freedesktop.DBus.Properties")
        for item in watcher.Get("org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"):
            service, _, path = str(item).partition("/")
            if int(connection.GetConnectionUnixProcessID(service)) != process.pid:
                continue
            properties = dbus.Interface(bus.get_object(service, "/" + path), "org.freedesktop.DBus.Properties")
            menu = dbus.Interface(bus.get_object(service, str(properties.Get("org.kde.StatusNotifierItem", "Menu"))),
                                  "com.canonical.dbusmenu")
            return menu
        return None

    def items(*, menu) -> dict[str, int]:
        _, layout = menu.GetLayout(0, -1, ["label"])
        return menu_items(layout=layout)

    def choose(*, menu, label: str) -> None:
        # Exactly the event Plasma's tray sends when its context-menu row is clicked.
        menu.Event(items(menu=menu)[label], "clicked", dbus.String("", variant_level=1), dbus.UInt32(0))

    def launch(*, label: str, arguments: list[str]):
        process = start(arguments=arguments, label=f"{label}-application")
        log = output / f"{label}-application.log"
        wait_for(description=f"{label} Flutter rendering", check=lambda: RENDERED in log.read_text())
        mount = Path(wait_for(description="AppImage mount", check=lambda: glob.glob(MOUNTS))[0])
        # Velopack images keep the bundle in usr/bin. Drop the mount-root fallback once no retained
        # producer run predates Velopack packaging.
        manifest = mount / "usr/bin/bridge/desktop-bundle.json"
        identity = json.loads((manifest if manifest.exists() else mount / "bridge/desktop-bundle.json").read_text())
        release = json.loads((inputs / label / "desktop-linux-release.json").read_text())
        require(all(identity[key] == release[key] for key in ("version", "buildNumber", "sourceSha")),
                "Running AppImage identity differs from qualified release")
        menu = wait_for(description="StatusNotifier item on the Plasma host", check=lambda: tray_menu(process=process))
        return process, menu, identity

    def quit_normally(*, process: subprocess.Popen, menu) -> None:
        choose(menu=menu, label="Quit Sesori")
        process.wait(timeout=30)
        require(process.returncode == 0, f"Normal Quit failed: {process.returncode}")
        wait_for(description="AppImage unmount", check=lambda: not glob.glob(MOUNTS))
        helper = subprocess.run(["pgrep", "-f", r"/bridge/bin/bridge( |$)"], capture_output=True, text=True)
        require(helper.returncode == 1, f"Packaged helper remains after Quit: {helper.stdout}")

    def install(*, label: str) -> None:
        # Users replace the image file in place; the new version keeps the same path.
        IMAGE.parent.mkdir(exist_ok=True)
        staged = IMAGE.with_suffix(".download")
        shutil.copyfile(next((inputs / label).glob("*.AppImage")), staged)
        staged.chmod(0o755)
        staged.replace(IMAGE)

    try:
        keyring = start(arguments=["gnome-keyring-daemon", "--foreground", "--unlock", "--components=secrets"],
                        label="keyring", stdin=subprocess.PIPE)
        keyring.stdin.write(b"disposable-ci-keyring\n")
        keyring.stdin.close()
        wait_for(description="Secret Service", check=lambda: bus.name_has_owner("org.freedesktop.secrets"))
        start(arguments=["kwin_wayland", "--virtual", "--width", "1280", "--height", "800",
                         "--socket", "sesori-wayland", "--no-lockscreen"], label="kwin")
        wait_for(description="Wayland compositor", check=lambda: (runtime / "sesori-wayland").exists())
        start(arguments=["kded6"], label="kded")
        start(arguments=["plasmashell", "--no-respawn"], label="plasmashell")
        wait_for(description="Plasma StatusNotifier host", check=lambda: bus.name_has_owner(
            "org.kde.StatusNotifierWatcher") and dbus.Interface(
            bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher"),
            "org.freedesktop.DBus.Properties").Get("org.kde.StatusNotifierWatcher", "IsStatusNotifierHostRegistered"))

        probe(label="previous", phase="write")
        install(label="previous")
        process, menu, identity = launch(label="previous", arguments=[str(IMAGE)])
        choose(menu=menu, label="Enable Launch at Login")
        wait_for(description="login registration", check=REGISTRATION.exists)
        registration = REGISTRATION.read_text()
        require(f'Exec="{IMAGE}" "--hidden"\n' in registration,
                f"Login registration does not target the image file: {registration}")
        quit_normally(process=process, menu=menu)
        observations.append({"candidate": "previous", "identity": identity, "trayQuit": True,
                             "loginRegistrationTargetsImage": True})

        install(label="current")
        # Relaunch exactly as the registered login entry does.
        process, menu, identity = launch(label="current", arguments=[str(IMAGE), "--hidden"])
        labels = items(menu=menu)
        require("Launch at login: On" in labels, f"Replacement lost the login registration: {sorted(labels)}")
        quit_normally(process=process, menu=menu)
        observations.append({"candidate": "current", "identity": identity, "hiddenLoginLaunch": True,
                             "trayQuit": True, "loginRegistrationPreserved": True})
        probe(label="current", phase="read")

        release = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
        (output / "result.json").write_text(json.dumps({
            "distribution": release["ID"], "architecture": architecture, "hostArchitecture": platform.machine(),
            "packages": subprocess.run(["pacman", "-Q", "glibc", "gtk3", "plasma-workspace", "kwin", "fuse3"],
                                       capture_output=True, text=True, check=True).stdout.splitlines(),
            "observations": observations, "nativeStorageSurvivesReplacement": True,
            "productSourceChanged": observations[0]["identity"]["sourceSha"] != observations[1]["identity"]["sourceSha"],
            "authenticatedAccountQualified": False, "stableAdmission": False,
        }, indent=2) + "\n")
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                with suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGTERM)
                with suppress(subprocess.TimeoutExpired):
                    process.wait(timeout=10)
        for log in logs:
            log.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--probes", type=Path, required=True)
    parser.add_argument("--architecture", choices=("x64", "arm64"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    exercise(inputs=args.inputs, probes=args.probes, output=args.output, architecture=args.architecture)


if __name__ == "__main__":
    main()
