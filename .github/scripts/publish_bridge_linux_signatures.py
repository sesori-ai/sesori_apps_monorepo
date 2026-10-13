"""Verify core-owned signature delivery, or bootstrap missing signatures without replacement."""

import argparse
import json
import re
import shutil
from pathlib import Path
from urllib.request import urlopen

from github_release_assets import github, public_sha256
from linux_signing import PUBLIC_KEY, sha256
from sign_bridge_linux import ARCHIVES

SIGNING_ASSETS = (PUBLIC_KEY, *(archive + ".asc" for archive in ARCHIVES))


def public_release(*, repository: str, tag: str) -> dict:
    if re.fullmatch(r"v\d+\.\d+\.\d+(-internal\.\d+)?", tag) is None:
        raise ValueError("Expected an existing shared stable or internal release tag")
    release = json.loads(github(arguments=["api", f"repos/{repository}/releases/tags/{tag}"]))
    if release["draft"] or release["tag_name"] != tag:
        raise ValueError("Linux signatures require an existing public release")
    return release


def public_url(*, repository: str, tag: str, name: str) -> str:
    return f"https://github.com/{repository}/releases/download/{tag}/{name}"


def download(*, repository: str, tag: str, root: Path) -> None:
    release = public_release(repository=repository, tag=tag)
    assets = {asset["name"]: asset for asset in release["assets"]}
    root.mkdir(parents=True)
    # Anonymous retrieval, before signing secrets are exposed; never unpack or run an archive.
    for name in ("checksums.txt", *ARCHIVES):
        asset = assets[name]
        path = root / name
        url = public_url(repository=repository, tag=tag, name=name)
        with urlopen(url, timeout=60) as response, path.open("wb") as out:
            shutil.copyfileobj(response, out)
        if path.stat().st_size != asset["size"] or f"sha256:{sha256(path=path)}" != asset["digest"]:
            raise ValueError(f"Public archive/index digest mismatch: {name}")
    checksums = {}
    for line in (root / "checksums.txt").read_text(encoding="utf-8").splitlines():
        digest, name = line.split()
        checksums[name] = digest
    for name in ARCHIVES:
        if checksums[name] != sha256(path=root / name):
            raise ValueError(f"Archive differs from the published Bridge checksums: {name}")


def verify_archive_bytes(*, repository: str, tag: str, root: Path) -> None:
    report = json.loads((root / "signing.json").read_text(encoding="utf-8"))
    rows = report["artifacts"]
    if sorted(row["name"] for row in rows) != sorted(ARCHIVES) or report["publicKeyFile"] != PUBLIC_KEY:
        raise ValueError("Expected the two Linux Bridge archive signing records")
    # A release can change between download/sign and this job. Refuse stale signatures
    # before uploading anything; do not overwrite archive bytes or their checksum file.
    for row in rows:
        actual = public_sha256(url=public_url(repository=repository, tag=tag, name=row["name"]))
        if actual != row["sha256"]:
            raise ValueError(f"Public archive changed after signing: {row['name']}")


def verify_signing_asset(*, repository: str, tag: str, path: Path) -> None:
    actual = public_sha256(url=public_url(repository=repository, tag=tag, name=path.name))
    if actual != sha256(path=path):
        raise ValueError(f"Conflicting public signing asset; refusing replacement: {path.name}")
    print(f"Verified public signing asset: {path.name} sha256:{actual}")


def verify(*, repository: str, tag: str, root: Path) -> None:
    # Core release owners already uploaded their archive/signature set. No repair writes here.
    public_release(repository=repository, tag=tag)
    verify_archive_bytes(repository=repository, tag=tag, root=root)
    for name in SIGNING_ASSETS:
        verify_signing_asset(repository=repository, tag=tag, path=root / name)


def publish(*, repository: str, tag: str, root: Path) -> None:
    # The standalone bootstrap owns only missing signatures, never existing release assets.
    release = public_release(repository=repository, tag=tag)
    verify_archive_bytes(repository=repository, tag=tag, root=root)
    existing = {asset["name"] for asset in release["assets"]}
    for name in SIGNING_ASSETS:
        path = root / name
        if name not in existing:
            github(arguments=["release", "upload", tag, str(path), "--repo", repository])
        verify_signing_asset(repository=repository, tag=tag, path=path)


def main() -> None:
    operations = {"download": download, "publish": publish, "verify": verify}
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=operations)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    operations[args.operation](repository=args.repository, tag=args.tag, root=args.root)


if __name__ == "__main__":
    main()
