#!/usr/bin/env python3
"""Owned-process probes on fresh native Actions hosts; never a local QA launcher."""

import argparse
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys

from package_desktop_macos import execute
from qualify_desktop import ROOT


def probe_platform_fixture(*, fixture: Path, output: Path) -> None:
    # No account, bridge or session services run in this separate test entrypoint.
    for phase in ("write", "read"):
        report = output / f"platform-{phase}.log"
        environment = {**os.environ, "SESORI_PACKAGED_PROBE_PHASE": phase,
                       "SESORI_PACKAGED_PROBE_OUTPUT": str(report)}
        with (output / f"platform-{phase}-process.log").open("w") as stream:
            subprocess.run([str(fixture / "Contents/MacOS/Sesori")], env=environment,
                           stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=60)
        print(report.read_text().strip())


def probe(*, app: Path, fixture: Path | None, output: Path) -> None:
    if sys.platform != "darwin" or os.environ.get("GITHUB_ACTIONS") != "true":
        raise PermissionError("Installed-app probes require a fresh macOS Actions runner")
    processes = subprocess.check_output(["ps", "ax", "-o", "pid=,command="], text=True)
    if re.search(r"/Sesori\.app/Contents/MacOS/|/bridge/app/build/cli/bundle/bin/bridge|"
                 r"/Contents/Helpers/bridge/bin/bridge|sesori-bridge", processes):
        raise RuntimeError("An existing desktop/bridge is active; refusing any takeover or cleanup")
    registration = Path.home() / "Library/LaunchAgents/com.sesori.desktop.plist"
    if registration.exists():
        raise RuntimeError("Existing login registration; refusing to alter user state")
    output.mkdir(parents=True)
    log = output / "commands.log"
    inspector = Path(os.environ["RUNNER_TEMP"]) / "desktop-window-inspector"
    execute(command=["xcrun", "swiftc", str(ROOT / ".github/scripts/inspect_desktop_macos_window.swift"),
                     "-o", str(inspector)], log=log)
    host = subprocess.run([str(inspector)], text=True, capture_output=True)
    (output / "host.log").write_text(host.stdout + host.stderr)
    if host.returncode == 2:
        print("BLOCKED GUI/platform probes: this runner has no active screen")
        return
    host.check_returncode()
    installed: list[Path] = []
    sources = [(app, Path("/Applications/Sesori.app"))]
    if fixture is not None:
        sources.append((fixture, Path("/Applications/SesoriPlatformProbe.app")))
    try:
        for source, destination in sources:
            if destination.exists():
                raise FileExistsError(f"Refusing to replace {destination}")
            execute(command=["ditto", str(source), str(destination)], log=log)
            installed.append(destination)
            execute(command=["codesign", "--verify", "--deep", "--strict", str(destination)], log=log)
            requirement = '=anchor apple generic and certificate leaf[subject.OU] = "AQNCF7663C"'
            execute(command=["codesign", "--verify", "-R", requirement, str(destination)], log=log)
        product = installed[0]
        shutil.copyfile(product / "Contents/Resources/desktop-bundle.json", output / "source-desktop-bundle.json")
        if fixture is not None:
            probe_platform_fixture(fixture=installed[1], output=output)
            if registration.exists():
                raise RuntimeError("The probe left its login registration behind")
        execute(command=["spctl", "--assess", "--type", "execute", "--verbose=2", str(product)], log=log)
        with (output / "launcher.log").open("w") as stream:
            process = subprocess.Popen(["open", "-n", "-W", "--stdout", str(output / "installed-gui.log"),
                                        "--stderr", str(output / "installed-gui.log"), str(product)],
                                       stdout=stream, stderr=subprocess.STDOUT)
            app_pid: int | None = None
            try:
                try:
                    process.wait(timeout=15)  # Bounded startup observation, not a production Quit test.
                except subprocess.TimeoutExpired:
                    pass
                else:
                    raise RuntimeError(f"Installed desktop exited during startup: {process.returncode}")
                # The fresh-host guard and exact installed path exclude unrelated applications.
                app_pid = int(subprocess.check_output(
                    ["pgrep", "-f", r"^/Applications/Sesori\.app/Contents/MacOS/Sesori($| )"], text=True).strip())
                window = subprocess.run([str(inspector), str(app_pid)], text=True, capture_output=True)
                (output / "window.log").write_text(window.stdout + window.stderr)
                if window.returncode == 2:
                    print("BLOCKED installed GUI: this runner has no active screen")
                elif window.returncode:
                    raise RuntimeError("Installed desktop has no visible main window; see window.log")
                else:
                    print("PASS installed desktop survived startup with a visible native main window")
                    window_id = re.search(r"WINDOW_ID (\d+)", window.stdout)[1]
                    try:
                        execute(command=["screencapture", "-x", "-l", window_id,
                                         str(output / "installed-gui.png")], log=log)
                        execute(command=["screencapture", "-x", str(output / "desktop.png")], log=log)
                        execute(command=["sample", str(app_pid), "2", "-file",
                                         str(output / "process-sample.txt")], log=log)
                    except subprocess.CalledProcessError as error:
                        print(f"BLOCKED diagnostic capture (exit {error.returncode}); see commands.log")
            finally:
                if process.poll() is None:
                    if app_pid is not None:
                        try:
                            os.kill(app_pid, signal.SIGTERM)  # Owned CI app only; not a production Quit assertion.
                        except ProcessLookupError:
                            print("The owned GUI already exited before teardown")
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()  # Only the waiting open(1) launcher.
                        process.wait()
    finally:
        for destination in installed:
            shutil.rmtree(destination)
    print("PASS owned installed-app copies removed; no local user bridge or desktop was touched")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, help="Separately signed platform fixture; omit for GUI-only replay")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    probe(app=args.app.resolve(), fixture=args.fixture.resolve() if args.fixture else None, output=args.output.resolve())
