#!/usr/bin/env python3
"""Attach verified desktop assets to the shared release; never create/promote a release.

The caller owns platform admission and production approval. Existing assets are
immutable, including on partial-upload retries. No private evidence is published.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from urllib.request import urlopen

from prepare_desktop_release import prepare, require, sha256


def github(*, arguments: list[str]) -> str:
    return subprocess.run(["gh", *arguments], check=True, stdout=subprocess.PIPE,
                          text=True, timeout=300).stdout


def public_sha256(*, url: str) -> str:
    # Deliberately no GH_TOKEN/Authorization: prove ordinary public retrieval.
    digest = hashlib.sha256()
    with urlopen(url, timeout=60) as response:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def publish(*, root: Path, output: Path, source_sha: str, tooling_sha: str, channel: str,
            repository: str, run_id: int, current_run_id: int | None, version: str, build_number: int) -> None:
    metadata = prepare(root=root, output=output, source_sha=source_sha, tooling_sha=tooling_sha,
                       channel=channel, repository=repository, run_id=run_id, current_run_id=current_run_id)
    require(metadata["version"] == version and metadata["buildNumber"] == build_number,
            "Desktop identity differs from the shared release")
    tag = metadata["tag"]
    release = json.loads(github(arguments=["api", f"repos/{repository}/releases/tags/{tag}"]))
    require(not release["draft"], "Shared release must already be public")
    if channel == "internal":
        require(release["prerelease"], "Internal desktop packages require an internal pre-release")
    existing = {asset["name"] for asset in release["assets"]}
    assets = [(root / f"desktop-macos-packages-{row['architecture']}" / row["name"], row["sha256"])
              for row in metadata["artifacts"]]
    # The bridge owns checksums.txt. Desktop has a separate, complete checksum set.
    checksums = output / "desktop-checksums.txt"
    (output / "checksums.txt").rename(checksums)
    manifest = output / "desktop-release.json"
    # Publish the manifest last, only after all four installers are publicly retrievable.
    assets.extend([(checksums, sha256(checksums)), (manifest, sha256(manifest))])
    for path, expected in assets:
        if path.name not in existing:
            github(arguments=["release", "upload", tag, str(path), "--repo", repository])
        # No --clobber, even when recovering a partial upload. A conflicting public
        # asset requires a new build/version, not silently replacing delivered bytes.
        actual = public_sha256(url=f"https://github.com/{repository}/releases/download/{tag}/{path.name}")
        require(actual == expected, f"Public asset digest mismatch; refusing replacement: {path.name}")
        print(f"Verified public desktop asset: {path.name} sha256:{actual}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tooling-sha", required=True)
    parser.add_argument("--channel", choices=("stable", "internal"), required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", type=int, required=True)
    publish(**vars(parser.parse_args()), current_run_id=int(os.environ.get("GITHUB_RUN_ID", "0")) or None)


if __name__ == "__main__":
    main()
