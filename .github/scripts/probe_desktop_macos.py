#!/usr/bin/env python3
"""Owned-process probes on fresh native Actions hosts; never a local QA launcher."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from package_desktop_macos import execute
from qualify_desktop import ROOT


def probe(*, app: Path, fixture: Path, output: Path) -> None:
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
    try:
        for source, destination in [(app, Path("/Applications/Sesori.app")),
                                    (fixture, Path("/Applications/SesoriPlatformProbe.app"))]:
            if destination.exists():
                raise FileExistsError(f"Refusing to replace {destination}")
            execute(command=["ditto", str(source), str(destination)], log=log)
            installed.append(destination)
            execute(command=["codesign", "--verify", "--deep", "--strict", str(destination)], log=log)
        product, platform_fixture = installed
        # Exercise independent plugin boundaries before the broader GUI startup observation.
        # No product services run in this separately signed test entrypoint.
        for phase in ("write", "read"):
            report = output / f"platform-{phase}.log"
            environment = {**os.environ, "SESORI_PACKAGED_PROBE_PHASE": phase,
                           "SESORI_PACKAGED_PROBE_OUTPUT": str(report)}
            with (output / f"platform-{phase}-process.log").open("w") as stream:
                subprocess.run([str(platform_fixture / "Contents/MacOS/Sesori")], env=environment,
                               stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=60)
            print(report.read_text().strip())
        if registration.exists():
            raise RuntimeError("The probe left its login registration behind")
        execute(command=["spctl", "--assess", "--type", "execute", "--verbose=2", str(product)], log=log)
        with (output / "installed-gui.log").open("w") as stream:
            process = subprocess.Popen([str(product / "Contents/MacOS/Sesori")], stdout=stream,
                                       stderr=subprocess.STDOUT)
            try:
                try:
                    process.wait(timeout=15)  # Bounded startup observation, not a production Quit test.
                except subprocess.TimeoutExpired:
                    pass
                else:
                    raise RuntimeError(f"Installed desktop exited during startup: {process.returncode}")
                window = subprocess.run([str(inspector), str(process.pid)], text=True, capture_output=True)
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
                    except subprocess.CalledProcessError as error:
                        print(f"BLOCKED screenshot (exit {error.returncode}); see commands.log")
            finally:
                if process.poll() is None:
                    process.terminate()  # Only the process created above, on the isolated CI host.
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    finally:
        for destination in installed:
            shutil.rmtree(destination)
    print("PASS owned installed-app copies removed; no local user bridge or desktop was touched")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    probe(app=args.app.resolve(), fixture=args.fixture.resolve(), output=args.output.resolve())
