"""Seed package:sqlite3's build-hook download so CI never fetches it mid-test.

The sqlite3 build hook downloads a prebuilt library from a GitHub release into
<workspace>/.dart_tool/hooks_runner/shared/sqlite3/build/download-<sha[:8]>/,
and reuses a file already there when its SHA-256 matches the hash the package
pins. Those release downloads intermittently return a 504 page, which fails
the hook. This script puts the same pinned, hash-verified file in place first,
from the CI cache or a retried download, so the hook takes its reuse path.
Run by .github/actions/prefetch-sqlite3-native; CI only.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname

REPO = "simolus3/sqlite3.dart"
URL = f"https://github.com/{REPO}/releases/download/{{tag}}/{{name}}"
SHARED_BUILD_DIR = Path(".dart_tool/hooks_runner/shared/sqlite3/build")
ARCHITECTURES = {"X64": "x64", "ARM64": "arm64"}
# Bounds each gh or curl run so a stalled download falls through to a retry.
COMMAND_TIMEOUT_SECONDS = 120


def fail(message: str) -> None:
    print(f"::error::{message}")
    sys.exit(1)


def sqlite3_root(*, workspace: Path) -> Path:
    config_file = (workspace / ".dart_tool/package_config.json").resolve()
    config = json.loads(config_file.read_text())
    for package in config["packages"]:
        if package["name"] == "sqlite3":
            # A rootUri may be relative to the config file.
            root = urljoin(config_file.as_uri(), package["rootUri"])
            return Path(url2pathname(urlparse(root).path))
    fail(f"package:sqlite3 is not in {workspace}'s package config; run dart pub get first")


def pinned_assets(*, workspace: Path) -> tuple[str, dict[str, str]]:
    hashes_file = sqlite3_root(workspace=workspace) / "lib/src/hook/asset_hashes.dart"
    text = hashes_file.read_text()
    tag = re.search(r"releaseTag = '([^']+)'", text)
    hashes = dict(re.findall(r"'([^']+)': '([0-9a-f]{64})'", text))
    if tag is None or not hashes:
        fail(f"{hashes_file} changed shape; update this script for the new sqlite3 hook")
    return tag.group(1), hashes


def runner_assets() -> list[tuple[str, str]]:
    """(release asset name, file name the hook stores) for this runner."""
    runner_os = os.environ["RUNNER_OS"]
    arch = ARCHITECTURES.get(os.environ["RUNNER_ARCH"])
    if arch is None:
        fail(f"Unsupported runner architecture {os.environ['RUNNER_ARCH']}")
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


def download_commands(*, tag: str, name: str, partial: Path) -> list[list[str]]:
    # The release API path (gh) keeps working while the public
    # releases/download URL the hook uses returns 504s, so try it first.
    gh = ["gh", "release", "download", tag, "--repo", REPO, "--pattern", name,
          "--output", str(partial), "--clobber"]
    curl = ["curl", "--fail", "--location", "--silent", "--show-error",
            "--retry", "3", "--retry-all-errors", "--retry-delay", "5",
            "--connect-timeout", "30", "--max-time", str(COMMAND_TIMEOUT_SECONDS),
            "--output", str(partial), URL.format(tag=tag, name=name)]
    return [gh, curl] if shutil.which("gh") else [curl]


def download(*, tag: str, name: str, destination: Path, expected: str) -> None:
    partial = destination.with_name(destination.name + ".prefetch")
    for attempt in range(1, 6):
        for command in download_commands(tag=tag, name=name, partial=partial):
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
                print(f"Downloaded and verified sqlite3 native library {destination} ({name}) with {command[0]}")
                return
            print(f"::warning::{command[0]} fetched {name} with SHA-256 {actual}, expected {expected}")
        if attempt < 5:
            time.sleep(10 * attempt)
    fail(f"Could not download a verified {name} from {REPO} release {tag}")


def targets(*, hashes: dict[str, str]) -> list[tuple[str, str, str]]:
    """(release asset name, stored file name, pinned SHA-256) for this runner."""
    pinned = []
    for name, stored_name in runner_assets():
        expected = hashes.get(name)
        if expected is None:
            fail(f"package:sqlite3 pins no hash for {name}")
        pinned.append((name, stored_name, expected))
    return pinned


def plan(*, workspace: Path) -> None:
    tag, hashes = pinned_assets(workspace=workspace)
    # The pinned hashes, not just the names, so a re-pinned asset gets a fresh cache.
    pins = "-".join(f"{name}@{expected[:12]}" for name, _, expected in targets(hashes=hashes))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"path={(workspace / SHARED_BUILD_DIR).as_posix()}\n")
        output.write(f"key=sqlite3-native-{tag}-{pins}\n")


def seed(*, workspace: Path) -> None:
    tag, hashes = pinned_assets(workspace=workspace)
    for name, stored_name, expected in targets(hashes=hashes):
        # The hook's PrebuiltSqliteLibrary.dirname.
        destination = workspace / SHARED_BUILD_DIR / f"download-{expected[:8]}" / stored_name
        if destination.is_file() and sha256(path=destination) == expected:
            print(f"Reusing cached sqlite3 native library {destination} ({name})")
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        download(tag=tag, name=name, destination=destination, expected=expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["plan", "seed"])
    parser.add_argument("--workspace", required=True, type=Path)
    args = parser.parse_args()
    {"plan": plan, "seed": seed}[args.command](workspace=args.workspace)


if __name__ == "__main__":
    main()
