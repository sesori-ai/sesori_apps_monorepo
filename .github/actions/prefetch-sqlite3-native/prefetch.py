"""Seed package:sqlite3's build-hook download so CI never fetches it mid-test.

The sqlite3 build hook downloads a prebuilt library from a GitHub release into
<workspace>/.dart_tool/hooks_runner/shared/sqlite3/build/download-<sha[:8]>/,
and reuses a file already there when its SHA-256 matches the hash the package
pins. Those release downloads intermittently return a 504 page, which fails
the hook. This script puts the same pinned, hash-verified file in place first,
from the CI cache or a retried download, so the hook takes its reuse path.
Run by .github/actions/prefetch-sqlite3-native in CI and release workflows;
the hook accepts only the pinned hash, so the built bytes never change.

package:pdfium_dart (pdfrx's PDF engine) has the same kind of hook: it fetches
pdfium-<platform>-<arch>.tgz from bblanchon/pdfium-binaries on every platform
but iOS, with three quick retries, and reuses the library it extracted into
<workspace>/.dart_tool/hooks_runner/shared/pdfium_dart/build/<release>/. The
package pins no hashes, so this script pins the archives' SHA-256 itself and
seeds the extracted library the same way.

Locally, after `pub get`, it seeds a worktree whose hook download failed. The
default seeds this host's libraries; add `--platform ios` or `--platform
android` for those targets. On Windows, run `python` instead of `python3`:
    python3 .github/actions/prefetch-sqlite3-native/prefetch.py seed --workspace client
"""

# Runners may ship a python3 older than 3.10.
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path
from platform import machine, system
from urllib.parse import quote, urljoin, urlparse
from urllib.request import url2pathname

REPO = "simolus3/sqlite3.dart"
URL = "https://github.com/{repo}/releases/download/{tag}/{name}"
SHARED_BUILD_DIR = Path(".dart_tool/hooks_runner/shared/sqlite3/build")
PDFIUM_REPO = "bblanchon/pdfium-binaries"
PDFIUM_BUILD_DIR = Path(".dart_tool/hooks_runner/shared/pdfium_dart/build")
# SHA-256 of each archive the pdfium_dart hook can fetch, per release. When a
# pdfrx update moves to a new release, add its pins from the release API:
#   gh api repos/bblanchon/pdfium-binaries/releases/tags/<release> \
#     --jq '.assets[] | "\(.name) \(.digest | ltrimstr("sha256:"))"'
PDFIUM_PINS = {
    "chromium/8125": {
        "pdfium-android-arm.tgz": "ac4ac5319ded88ba5d885747a6b2641e7f712c9797de0770465104abe4dbf7da",
        "pdfium-android-arm64.tgz": "0495e57163429937caaee1bdd9b07924a7098dbd51d1b97645d124e349f097b4",
        "pdfium-android-x64.tgz": "bd68707f29f2316c20f9d5c793b8731796a4a65408ac4d3c30bc606390354e41",
        "pdfium-linux-arm64.tgz": "8b8818f2ec57d1b213d952ca6d7f0ffeca9d0110487d0e20ad83ba918bc92efa",
        "pdfium-linux-x64.tgz": "e1c3ce6e270cb5e0c20816b379ad9f2c1309972697c505f508de92bf5e7d6659",
        "pdfium-mac-arm64.tgz": "4939bd935ac83ddc09a3a4f038bc43a19cea1660316a3667f26cb07a070e139d",
        "pdfium-mac-x64.tgz": "8a5193535b80c7215d8932f6647ae5097465b6dba2811602c21e120c2af112b0",
        "pdfium-win-arm64.tgz": "d394ba61991fb53f4d87f70988035f337d9e73f2bd2c3c1b966df8c43fcabb05",
        "pdfium-win-x64.tgz": "9a964261760cff52570aabf038ab346d3a5034dd8b30d0d5fe8861235d356b8b",
    },
}
ARCHITECTURES = {"X64": "x64", "ARM64": "arm64"}
# platform.system() and platform.machine() values, as RUNNER_OS and RUNNER_ARCH names.
HOST_SYSTEMS = {"Darwin": "macOS", "Linux": "Linux", "Windows": "Windows"}
HOST_MACHINES = {"x86_64": "X64", "amd64": "X64", "arm64": "ARM64", "aarch64": "ARM64"}
# Bounds each gh or curl run so a stalled download falls through to a retry.
COMMAND_TIMEOUT_SECONDS = 120


def fail(message: str) -> None:
    print(f"::error::{message}")
    sys.exit(1)


def package_root(*, workspace: Path, name: str) -> Path | None:
    config_file = (workspace / ".dart_tool/package_config.json").resolve()
    config = json.loads(config_file.read_text())
    for package in config["packages"]:
        if package["name"] == name:
            # A rootUri may be relative to the config file.
            root = urljoin(config_file.as_uri(), package["rootUri"])
            return Path(url2pathname(urlparse(root).path))
    return None


def pinned_assets(*, workspace: Path) -> tuple[str, dict[str, str]] | None:
    """The pinned release tag and hashes, or None when nothing downloads them."""
    root = package_root(workspace=workspace, name="sqlite3")
    if root is None or not (root / "hook/build.dart").is_file():
        # Release workflows may rebuild an older source whose sqlite3 has no build hook.
        print(f"::notice::{workspace} resolves no sqlite3 build hook; nothing to prefetch")
        return None
    hashes_file = root / "lib/src/hook/asset_hashes.dart"
    if not hashes_file.is_file():
        fail(f"{hashes_file} is missing; update this script for the new sqlite3 hook")
    text = hashes_file.read_text()
    tag = re.search(r"releaseTag = '([^']+)'", text)
    hashes = dict(re.findall(r"'([^']+)': '([0-9a-f]{64})'", text))
    if tag is None or not hashes:
        fail(f"{hashes_file} changed shape; update this script for the new sqlite3 hook")
    return tag.group(1), hashes


def host() -> tuple[str, str]:
    """The runner OS name and this script's architecture name for the host."""
    # Outside Actions, detect this machine.
    runner_os = os.environ.get("RUNNER_OS") or HOST_SYSTEMS.get(system(), system())
    runner_arch = os.environ.get("RUNNER_ARCH") or HOST_MACHINES.get(machine().lower(), machine())
    arch = ARCHITECTURES.get(runner_arch)
    if arch is None:
        fail(f"Unsupported architecture {runner_arch}")
    return runner_os, arch


def platform_assets(*, platform: str) -> list[tuple[str, str]]:
    """(release asset name, file name the hook stores) for the build target."""
    if platform == "ios":
        return [("libsqlite3.arm64.ios.dylib", "libsqlite3.dylib")]
    if platform == "android":
        # The ABIs `flutter build appbundle --release` targets by default.
        return [(f"libsqlite3.{a}.android.so", "libsqlite3.so") for a in ("arm", "arm64", "x64")]
    runner_os, arch = host()
    if runner_os == "Linux":
        return [(f"libsqlite3.{arch}.linux.so", "libsqlite3.so")]
    if runner_os == "macOS":
        # `flutter build macos` is universal, so it runs the hook for both.
        return [(f"libsqlite3.{a}.macos.dylib", "libsqlite3.dylib") for a in ("arm64", "x64")]
    if runner_os == "Windows":
        return [(f"sqlite3.{arch}.windows.dll", "sqlite3.dll")]
    fail(f"Unsupported runner OS {runner_os}")


def sha256(*, path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download_commands(*, repo: str, tag: str, name: str, partial: Path) -> list[list[str]]:
    # The release API path (gh) keeps working while the public
    # releases/download URL the hook uses returns 504s, so try it first.
    gh = ["gh", "release", "download", tag, "--repo", repo, "--pattern", name,
          "--output", str(partial), "--clobber"]
    curl = ["curl", "--fail", "--location", "--silent", "--show-error",
            "--retry", "3", "--retry-all-errors", "--retry-delay", "5",
            "--connect-timeout", "30", "--max-time", str(COMMAND_TIMEOUT_SECONDS),
            "--output", str(partial), URL.format(repo=repo, tag=quote(tag, safe=""), name=name)]
    return [gh, curl] if shutil.which("gh") else [curl]


def download(*, tag: str, name: str, destination: Path, expected: str, repo: str = REPO) -> None:
    partial = destination.with_name(destination.name + ".prefetch")
    for attempt in range(1, 6):
        for command in download_commands(repo=repo, tag=tag, name=name, partial=partial):
            try:
                # curl retries inside its own run, so give it room for them.
                timeout = COMMAND_TIMEOUT_SECONDS * (4 if command[0] == "curl" else 1)
                if subprocess.run(command, timeout=timeout).returncode != 0:
                    continue
            except subprocess.TimeoutExpired:
                print(f"::warning::{command[0]} timed out fetching {name}")
                continue
            actual = sha256(path=partial)
            if actual == expected:
                os.replace(partial, destination)
                print(f"Downloaded and verified {destination} ({name}) with {command[0]}")
                return
            print(f"::warning::{command[0]} fetched {name} with SHA-256 {actual}, expected {expected}")
        if attempt < 5:
            time.sleep(10 * attempt)
    fail(f"Could not download a verified {name} from {repo} release {tag}")


def targets(*, hashes: dict[str, str], platform: str) -> list[tuple[str, str, str]]:
    """(release asset name, stored file name, pinned SHA-256) for the build target."""
    pinned = []
    for name, stored_name in platform_assets(platform=platform):
        expected = hashes.get(name)
        if expected is None:
            fail(f"package:sqlite3 pins no hash for {name}")
        pinned.append((name, stored_name, expected))
    return pinned


def pdfium_release(*, workspace: Path) -> str | None:
    """The PDFium release the resolved pdfium_dart hook fetches, or None."""
    root = package_root(workspace=workspace, name="pdfium_dart")
    if root is None:
        return None
    hook = root / "hook/build.dart"
    match = re.search(r"_pdfiumRelease = '([^']+)'", hook.read_text()) if hook.is_file() else None
    if match is None:
        fail(f"{hook} changed shape; update this script for the new pdfium_dart hook")
    release = match.group(1).replace("%2F", "/")
    if release not in PDFIUM_PINS:
        fail(f"pdfium_dart fetches PDFium release {release}; add its archive hashes to PDFIUM_PINS "
             f"in {Path(__file__).name}, listed by the gh api command above it")
    return release


def pdfium_targets(*, release: str, platform: str) -> list[tuple[str, str, str, Path]]:
    """(archive name, pinned SHA-256, library path in the archive, path the hook
    stores it at, relative to its shared build directory) for the build target."""
    if platform == "ios":
        # iOS links PDFium from pdfium_flutter's XCFramework instead.
        return []
    if platform == "android":
        # The ABIs `flutter build appbundle --release` targets by default.
        archs = [("android", a) for a in ("arm", "arm64", "x64")]
    else:
        runner_os, arch = host()
        if runner_os == "Linux":
            archs = [("linux", arch)]
        elif runner_os == "macOS":
            # `flutter build macos` is universal, so it runs the hook for both.
            archs = [("mac", a) for a in ("arm64", "x64")]
        elif runner_os == "Windows":
            archs = [("win", arch)]
        else:
            fail(f"Unsupported runner OS {runner_os}")
    library = {"android": "lib/libpdfium.so", "linux": "lib/libpdfium.so",
               "mac": "lib/libpdfium.dylib", "win": "bin/pdfium.dll"}
    targets = []
    for system_name, arch in archs:
        name = f"pdfium-{system_name}-{arch}.tgz"
        expected = PDFIUM_PINS[release].get(name)
        if expected is None:
            fail(f"PDFIUM_PINS pins no hash for {name} in release {release}")
        member = library[system_name]
        # The hook's '<release>/<platform>-<arch>/<library file>'.
        stored = Path(release.replace("/", "_")) / f"{system_name}-{arch}" / Path(member).name
        targets.append((name, expected, member, stored))
    return targets


def plan(*, workspace: Path, platform: str) -> None:
    pinned = pinned_assets(workspace=workspace)
    release = pdfium_release(workspace=workspace)
    paths, keys = [], []
    if pinned is not None:
        tag, hashes = pinned
        # The pinned hashes, not just the names, so a re-pinned asset gets a fresh cache.
        pins = "-".join(f"{name}@{expected[:12]}" for name, _, expected in targets(hashes=hashes, platform=platform))
        paths.append((workspace / SHARED_BUILD_DIR).as_posix())
        keys.append(f"sqlite3-native-{tag}-{pins}")
    pdfium = [] if release is None else pdfium_targets(release=release, platform=platform)
    if pdfium:
        paths.append((workspace / PDFIUM_BUILD_DIR / pdfium[0][3].parts[0]).as_posix())
        keys.append("pdfium-" + "-".join(f"{name[len('pdfium-'):-len('.tgz')]}@{expected[:12]}"
                                         for name, expected, _, _ in pdfium))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        # An empty key makes the action skip its cache and seed steps.
        output.write(f"key={'-'.join(keys)}\n")
        output.write("path<<PREFETCH_PATHS\n" + "".join(f"{path}\n" for path in paths) + "PREFETCH_PATHS\n")


def seed_pdfium(*, workspace: Path, platform: str) -> None:
    release = pdfium_release(workspace=workspace)
    if release is None:
        return
    for name, expected, member, stored in pdfium_targets(release=release, platform=platform):
        destination = workspace / PDFIUM_BUILD_DIR / stored
        # The hook reuses any file at this path, and the cache that restores
        # one is keyed by the archive pins.
        if destination.is_file():
            print(f"Reusing cached PDFium library {destination} ({name})")
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        archive = destination.with_name(name)
        download(tag=release, name=name, destination=archive, expected=expected, repo=PDFIUM_REPO)
        partial = destination.with_name(destination.name + ".prefetch")
        with tarfile.open(archive) as tar:
            try:
                source = tar.extractfile(member)
            except KeyError:
                source = None
            if source is None:
                fail(f"{name} from {PDFIUM_REPO} release {release} has no {member}")
            partial.write_bytes(source.read())
        os.replace(partial, destination)
        archive.unlink()
        print(f"Extracted PDFium library {destination}")


def seed(*, workspace: Path, platform: str) -> None:
    seed_pdfium(workspace=workspace, platform=platform)
    pinned = pinned_assets(workspace=workspace)
    if pinned is None:
        return
    tag, hashes = pinned
    for name, stored_name, expected in targets(hashes=hashes, platform=platform):
        # The hook's PrebuiltSqliteLibrary.dirname.
        destination = workspace / SHARED_BUILD_DIR / f"download-{expected[:8]}" / stored_name
        if destination.is_file():
            if sha256(path=destination) == expected:
                print(f"Reusing cached sqlite3 native library {destination} ({name})")
                continue
            # download() swaps in the verified file over it.
            print(f"::warning::Replacing {destination}, whose SHA-256 does not match {name}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        download(tag=tag, name=name, destination=destination, expected=expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["plan", "seed"])
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--platform", choices=["host", "ios", "android"], default="host")
    args = parser.parse_args()
    {"plan": plan, "seed": seed}[args.command](workspace=args.workspace, platform=args.platform)


if __name__ == "__main__":
    main()
