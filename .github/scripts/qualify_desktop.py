"""Unsigned native build qualification only; never signs, publishes, or starts the GUI."""

import argparse
import hashlib
import json
import os
import platform
import shutil
import struct
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "build/desktop-qualification"
OS_NAMES = {"darwin": "macos", "win32": "windows", "linux": "linux"}
CPU_NAMES = {"AMD64": "x64", "x86_64": "x64", "arm64": "arm64", "ARM64": "arm64", "aarch64": "arm64"}
MACH_CPUS = {0x01000007: "x64", 0x0100000C: "arm64"}


def run(*, command: list[str], cwd: Path = ROOT) -> str:
    try:
        return subprocess.check_output(command, cwd=cwd, text=True, encoding="utf-8", stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as error:
        # The exception traceback alone omits the captured compiler/bootstrap diagnostics.
        print(error.output, file=sys.stderr)
        raise


def native_arch(*, path: Path) -> tuple[str, list[str]] | None:
    """Read shipped executable/library headers, not filename-based CPU guesses."""
    with path.open("rb") as stream:
        header = stream.read(64)
        if header[:4] == b"\x7fELF":
            endian = "<" if header[5] == 1 else ">"
            machine = struct.unpack_from(endian + "H", header, 18)[0]
            return "ELF", [{62: "x64", 183: "arm64"}.get(machine, f"unknown-{machine}")]
        if header[:2] == b"MZ":
            stream.seek(struct.unpack_from("<I", header, 60)[0])
            pe = stream.read(6)
            if pe[:4] != b"PE\0\0":
                raise ValueError(f"Invalid PE header: {path}")
            machine = struct.unpack_from("<H", pe, 4)[0]
            return "PE", [{0x8664: "x64", 0xAA64: "arm64"}.get(machine, f"unknown-{machine}")]
        if header[:4] == b"\xcf\xfa\xed\xfe":
            machine = struct.unpack_from("<I", header, 4)[0]
            return "Mach-O", [MACH_CPUS.get(machine, f"unknown-{machine}")]
        if header[:4] in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
            count = struct.unpack_from(">I", header, 4)[0]
            stream.seek(8)
            size = 20 if header[:4] == b"\xca\xfe\xba\xbe" else 32
            arches = []
            for _ in range(count):
                machine = struct.unpack_from(">I", stream.read(size))[0]
                arches.append(MACH_CPUS.get(machine, f"unknown-{machine}"))
            return "Mach-O", sorted(arches)
    return None


def inventory(*, root: Path, target_os: str, arch: str) -> list[dict]:
    platform_format = {"macos": "Mach-O", "windows": "PE", "linux": "ELF"}[target_os]
    entries = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        native = native_arch(path=path)
        if native is None:
            if path.suffix in (".exe", ".dll", ".dylib", ".so"):
                raise ValueError(f"Unrecognized native library/executable: {path}")
            continue
        binary_format, arches = native
        relative_path = path.relative_to(root).as_posix()
        # Flutter loads this Dart AOT snapshot as ELF even on Windows; DLLs/EXEs remain PE.
        expected_format = "ELF" if target_os == "windows" and relative_path == "data/app.so" else platform_format
        if binary_format != expected_format or arch not in arches:
            raise ValueError(f"Wrong native target: {path}: {binary_format} {arches}; expected {target_os}/{arch}")
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        entries.append({"path": relative_path, "format": binary_format,
                        "architectures": arches, "sha256": digest, "bytes": path.stat().st_size})
    if not entries:
        raise ValueError(f"No native binaries found in {root}")
    return entries


def resolve_flutter(*, target_os: str) -> dict:
    spec = next(line.split()[1] for line in (ROOT / ".tool-versions").read_text().splitlines()
                if line.startswith("flutter "))
    version, channel = spec.rsplit("-", 1)
    url = f"https://storage.googleapis.com/flutter_infra_release/releases/releases_{target_os}.json"
    with urllib.request.urlopen(url, timeout=60) as response:
        releases = json.load(response)["releases"]
    matches = [item for item in releases if item["version"] == version and item["channel"] == channel]
    revisions = {item["hash"] for item in matches}
    if len(revisions) != 1:
        raise ValueError(f"No unambiguous official Flutter revision for {spec} on {target_os}")
    return {"version": version, "channel": channel, "revision": revisions.pop(), "manifest": url}


def bootstrap(*, sdk: Path, target_os: str, arch: str) -> None:
    """CI-only official source bootstrap, including hosts without an SDK archive."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Bootstrap is CI-only; use the repository-pinned local SDK for local inspection")
    release = resolve_flutter(target_os=target_os)
    print(run(command=["git", "-c", "core.longpaths=true", "clone", "--depth=1", "--branch",
                       release["version"], "https://github.com/flutter/flutter.git", str(sdk)]))
    revision = run(command=["git", "rev-parse", "HEAD"], cwd=sdk).strip()
    if revision != release["revision"]:
        raise ValueError(f"Flutter tag differs from official release manifest: {revision}")
    flutter = sdk / "bin" / ("flutter.bat" if target_os == "windows" else "flutter")
    # First invocation includes bootstrap chatter; request machine JSON only after it completes.
    # The official scripts select the native Dart SDK. Do not inject an x64 fallback.
    (OUTPUT / "flutter-bootstrap.log").write_text(run(command=[str(flutter), "--version"]), encoding="utf-8")
    version = json.loads(run(command=[str(flutter), "--version", "--machine"]))
    dart = sdk / "bin/cache/dart-sdk/bin" / ("dart.exe" if target_os == "windows" else "dart")
    if version["frameworkRevision"] != revision or native_arch(path=dart)[1] != [arch]:
        raise ValueError("Flutter revision or bootstrapped Dart architecture does not match the native job")
    (OUTPUT / "sdk.json").write_text(
        json.dumps({"release": release, "installed": version}, indent=2) + "\n", encoding="utf-8"
    )
    with Path(os.environ["GITHUB_PATH"]).open("a", encoding="utf-8") as stream:
        stream.write(str(sdk / "bin") + "\n")
    print(f"Bootstrapped official Flutter {release['version']} at {revision}, native Dart {arch}")


def inspect(*, target_os: str, arch: str) -> None:
    products = ROOT / "client/desktop/build"
    gui = {"macos": products / "macos/Build/Products/Release/Sesori.app",
           "windows": products / f"windows/{arch}/runner/Release",
           "linux": products / f"linux/{arch}/release/bundle"}[target_os]
    helper = ROOT / "bridge/app/build/cli/bundle"
    entry = {"macos": "Contents/MacOS/Sesori", "windows": "sesori_desktop.exe",
             "linux": "sesori_desktop"}[target_os]
    bridge_name = "bridge.exe" if target_os == "windows" else "bridge"
    for required in (gui / entry, helper / "bin" / bridge_name, helper / "lib"):
        if not required.exists():
            raise ValueError(f"Required bundle entry missing: {required}")
    binaries = {"gui": inventory(root=gui, target_os=target_os, arch=arch),
                "helper": inventory(root=helper, target_os=target_os, arch=arch)}
    # Relocate the complete bundle, including native assets; the space is intentional.
    layout = {"macos": "Sesori.app/Contents/Helpers/bridge", "windows": "Sesori Desktop/bridge",
              "linux": "opt/sesori-desktop/bridge"}[target_os]
    staged = OUTPUT / "layout probe" / layout
    if staged.exists():
        raise ValueError(f"Previous layout probe exists; remove only this probe before rerunning: {staged}")
    shutil.copytree(helper, staged, symlinks=True)
    relocated_version = run(command=[str(staged / "bin" / bridge_name), "--version"], cwd=OUTPUT).strip()
    if not relocated_version:
        raise ValueError("Relocated helper did not report a version")
    if "GITHUB_ENV" in os.environ:
        with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as stream:
            stream.write(f"SESORI_DESKTOP_BRIDGE_PATH={staged / 'bin' / bridge_name}\n")
    sdk = shutil.which("flutter")
    if sdk is None:
        raise ValueError("Pinned Flutter must be on PATH")
    version = json.loads(run(command=[sdk, "--version", "--machine"]))
    pin = next(line.split()[1] for line in (ROOT / ".tool-versions").read_text().splitlines()
               if line.startswith("flutter ")).rsplit("-", 1)[0]
    if version["frameworkVersion"] != pin:
        raise ValueError(f"Expected pinned Flutter {pin}, found {version['frameworkVersion']}")
    report = {"sourceSha": run(command=["git", "rev-parse", "HEAD"]).strip(),
              "trackedSourceDirty": bool(run(command=["git", "status", "--porcelain", "--untracked-files=no"]).strip()),
              "targetOs": target_os, "nativeHostCpu": arch, "hostOs": platform.platform(),
              "runnerImage": {key: os.environ.get(key) for key in ("ImageOS", "ImageVersion", "RUNNER_ARCH")},
              "flutter": version, "binaries": binaries, "relocatedHelperVersion": relocated_version,
              "proofBoundary": "Unsigned build + native headers + relocated helper --version, not GUI or release QA"}
    (OUTPUT / "inventory.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    # Keep raw diagnostics separate from the small inventory; upload no user data or installed-app state.
    (OUTPUT / "flutter-doctor.log").write_text(run(command=[sdk, "doctor", "-v"]), encoding="utf-8")
    if target_os == "macos":
        commands = [["xcodebuild", "-version"], ["xcrun", "--show-sdk-version"],
                    ["xcrun", "vtool", "-show-build", str(gui / entry)]]
    elif target_os == "linux":
        commands = [["cmake", "--version"], ["clang", "--version"]]
        commands += [["ldd", str(gui / item["path"])] for item in binaries["gui"]]
        commands += [["ldd", str(helper / item["path"])] for item in binaries["helper"]]
    else:
        commands = []  # flutter doctor records the detected Visual Studio version and SDK.
    with (OUTPUT / "native-toolchain.log").open("w", encoding="utf-8") as log:
        for command in commands:
            result = run(command=command)
            log.write("$ " + " ".join(command) + "\n" + result + "\n")
            if command[0] == "ldd" and "not found" in result:
                raise ValueError(f"Unresolved shared library: {command[-1]}; see native-toolchain.log")
    print(f"{target_os}/{arch}: {len(binaries['gui'])} GUI binaries, {len(binaries['helper'])} helper binaries; "
          f"relocated --version={relocated_version}. Build evidence only.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("bootstrap", "inspect"))
    parser.add_argument("--arch", choices=("x64", "arm64"), required=True)
    parser.add_argument("--sdk-dir", type=Path)
    args = parser.parse_args()
    target_os = OS_NAMES[sys.platform]
    host_cpu = CPU_NAMES.get(os.environ.get("PROCESSOR_ARCHITEW6432", platform.machine()))
    if host_cpu != args.arch:
        raise ValueError(f"Native host required: expected {args.arch}, found {host_cpu}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.operation == "bootstrap":
        if args.sdk_dir is None:
            parser.error("bootstrap requires --sdk-dir")
        bootstrap(sdk=args.sdk_dir, target_os=target_os, arch=args.arch)
    else:
        inspect(target_os=target_os, arch=args.arch)


if __name__ == "__main__":
    main()
