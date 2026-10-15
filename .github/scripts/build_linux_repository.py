"""Build signed APT/RPM metadata from one prepared desktop release, without publication."""

import argparse
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from datetime import UTC, datetime, timedelta
from email.utils import format_datetime
from enum import StrEnum

from linux_signing import signing_key, sha256
from prepare_desktop_release import require
from publish_desktop_linux import MANIFEST, PUBLIC_DESKTOP_KEY, TRUSTED_PRIMARY_FINGERPRINT, verify_checksums
from sign_desktop_linux import CHECKSUMS, PUBLIC_KEY, verify_rpm

ARCHITECTURES = {"x64": ("amd64", "x86_64"), "arm64": ("arm64", "aarch64")}
REPORT = "repository.json"
APT_METADATA_LIFETIME = timedelta(days=30)


class Channel(StrEnum):
    STABLE = "stable"
    INTERNAL = "internal"


def command(*, arguments: list[str], cwd: Path, env: dict[str, str]) -> str:
    return subprocess.run(arguments, cwd=cwd, env=env, check=True, capture_output=True,
                          text=True, timeout=120).stdout


def verify_release(*, root: Path, channel: Channel, fingerprint: str) -> dict:
    metadata = json.loads((root / MANIFEST).read_text())
    require(metadata["schemaVersion"] == 1 and metadata["platform"] == "linux", "Expected Linux release metadata")
    require(metadata["channel"] == channel.value, "Repository channel differs from prepared release")
    require(metadata["signerFingerprint"] == fingerprint, "Release signer differs from repository trust anchor")
    version, number = metadata["version"], metadata["buildNumber"]
    require(isinstance(version, str) and re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version),
            "Expected clean release version")
    require(type(number) is int and number > 0, "Expected positive shared build number")
    expected = {f"Sesori-linux-{arch}-{version}-{number}.{kind}" for arch in ARCHITECTURES for kind in ("deb", "rpm")}
    rows = metadata["artifacts"]
    require(len(rows) == 4 and {row["name"] for row in rows} == expected, "Expected both CPUs and package formats")
    for row in rows:
        path = root / row["name"]
        require(path.stat().st_size == row["bytes"] and sha256(path=path) == row["sha256"],
                f"Prepared package digest mismatch: {path.name}")
    # Adapt public asset names to the existing public-only signature verifier.
    # Do not change either signed checksum file or rely on the signing keyring.
    with tempfile.TemporaryDirectory(prefix="sesori-repository-input-") as directory:
        packages = Path(directory)
        shutil.copyfile(root / PUBLIC_DESKTOP_KEY, packages / PUBLIC_KEY)
        for arch in ARCHITECTURES:
            for suffix in ("", ".asc"):
                shutil.copyfile(root / f"desktop-linux-{arch}-checksums.txt{suffix}", packages / (CHECKSUMS + suffix))
            verify_checksums(packages=packages, fingerprint=fingerprint)
            checksums = dict((name, digest) for digest, name in
                             (line.split() for line in (packages / CHECKSUMS).read_text().splitlines()))
            wanted = {row["name"]: row["sha256"] for row in rows if row["name"].startswith(f"Sesori-linux-{arch}-")}
            require(checksums == wanted, f"Signed checksums differ from prepared packages: {arch}")
    return metadata


def build_apt(*, root: Path, output: Path, metadata: dict, channel: Channel, env: dict[str, str]) -> Path:
    apt = output / "apt"
    distribution = apt / "dists" / channel.value
    for arch, (debian_arch, _) in ARCHITECTURES.items():
        name = f"Sesori-linux-{arch}-{metadata['version']}-{metadata['buildNumber']}.deb"
        package = root / name
        fields = command(arguments=["dpkg-deb", "--show", "--showformat=${Package}\n${Version}\n${Architecture}\n",
                                    str(package)], cwd=root, env=env).splitlines()
        require(fields == ["sesori-desktop", f"{metadata['version']}-{metadata['buildNumber']}", debian_arch],
                f"DEB metadata differs from release: {name}")
        pool = apt / "pool" / channel.value / debian_arch
        pool.mkdir(parents=True)
        shutil.copyfile(package, pool / name)
        index = distribution / "main" / f"binary-{debian_arch}" / "Packages"
        index.parent.mkdir(parents=True)
        index.write_text(command(arguments=["apt-ftparchive", "--md5=no", "--sha1=no", "--sha512=no",
                                            "packages", pool.relative_to(apt).as_posix()], cwd=apt, env=env))
        compressed = index.with_name("Packages.gz")
        compressed.write_bytes(gzip.compress(index.read_bytes(), mtime=0))
        # Publish content-addressed indexes before InRelease and retain previous hashes.
        # SHA256 is the only advertised hash, so every advertised by-hash URL exists.
        hashes = index.parent / "by-hash/SHA256"
        hashes.mkdir(parents=True)
        for path in (index, compressed):
            shutil.copyfile(path, hashes / sha256(path=path))
    issued_at = datetime.now(UTC)
    fields = {
        # apt-ftparchive enables the Valid-Until field only when ValidTime is nonzero.
        "ValidTime": str(int(APT_METADATA_LIFETIME.total_seconds())),
        "Date": format_datetime(issued_at, usegmt=True),
        "Valid-Until": format_datetime(issued_at + APT_METADATA_LIFETIME, usegmt=True),
        "Origin": "Sesori", "Label": f"Sesori {channel.value}", "Suite": channel.value,
        "Codename": channel.value, "Architectures": "amd64 arm64", "Components": "main", "Acquire-By-Hash": "yes",
        "Description": f"Sesori desktop {channel.value} packages",
    }
    options = [item for name, value in fields.items() for item in ("-o", f"APT::FTPArchive::Release::{name}={value}")]
    release = distribution / "Release"
    release.write_text(command(arguments=["apt-ftparchive", "--md5=no", "--sha1=no", "--sha512=no", *options,
                                         "release", distribution.relative_to(apt).as_posix()], cwd=apt, env=env))
    return release


def build_rpm(*, root: Path, output: Path, metadata: dict, channel: Channel,
              public_key: Path, env: dict[str, str]) -> list[Path]:
    indexes = []
    with tempfile.TemporaryDirectory(prefix="sesori-repository-rpm-") as directory:
        for arch, (_, rpm_arch) in ARCHITECTURES.items():
            database = Path(directory) / rpm_arch
            name = f"Sesori-linux-{arch}-{metadata['version']}-{metadata['buildNumber']}.rpm"
            package = root / name
            verify_rpm(package=package, public_key=public_key, database=database, env=env)
            fields = command(arguments=["rpm", "-qp", "--queryformat", "%{NAME}\n%{VERSION}\n%{RELEASE}\n%{ARCH}\n",
                                        str(package)], cwd=root, env=env).splitlines()
            require(len(fields) == 4 and fields[:2] == ["sesori-desktop", metadata["version"]]
                    and re.fullmatch(rf"{metadata['buildNumber']}(?:\.fc\d+)?", fields[2])
                    and fields[3] == rpm_arch, f"RPM metadata differs from release: {name}")
            repository = output / "rpm" / channel.value / rpm_arch
            packages = repository / "Packages"
            packages.mkdir(parents=True)
            shutil.copyfile(package, packages / name)
            command(arguments=["createrepo_c", "--checksum", "sha256", "--unique-md-filenames",
                               "--revision", f"{metadata['version']}-{metadata['buildNumber']}",
                               "--general-compress-type", "gz", str(repository)], cwd=output, env=env)
            indexes.append(repository / "repodata/repomd.xml")
    return indexes


def build(*, root: Path, output: Path, channel: Channel, fingerprint: str) -> dict:
    root, output = root.resolve(), output.resolve()
    # Enter the existing key owner before invoking tools: it removes secret variables
    # from the process environment, owns all private files and cleans its agent.
    with signing_key(output=output, fingerprint=fingerprint) as key:
        metadata = verify_release(root=root, channel=channel, fingerprint=fingerprint)
        release = build_apt(root=root, output=output, metadata=metadata, channel=channel, env=key.public_env)
        indexes = build_rpm(root=root, output=output, metadata=metadata, channel=channel,
                            public_key=root / PUBLIC_DESKTOP_KEY, env=key.public_env)
        key.sign_detached(source=release, signature=release.with_name("Release.gpg"))
        key.sign_cleartext(source=release, signature=release.with_name("InRelease"))
        for index in indexes:
            key.sign_detached(source=index, signature=index.with_name("repomd.xml.asc"))
    report = {
        "schemaVersion": 1, "channel": channel.value, "version": metadata["version"],
        "buildNumber": metadata["buildNumber"], "sourceSha": metadata["sourceSha"],
        "signerFingerprint": fingerprint,
        "files": [{"name": path.relative_to(output).as_posix(), "sha256": sha256(path=path),
                   "bytes": path.stat().st_size} for path in sorted(output.rglob("*")) if path.is_file()],
    }
    (output / REPORT).write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Prepared desktop-linux-release.json and public files")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--channel", type=Channel, choices=list(Channel), required=True)
    arguments = parser.parse_args()
    require(os.environ.get("LINUX_GPG_FINGERPRINT") == TRUSTED_PRIMARY_FINGERPRINT,
            "Configured signer differs from repository trust anchor")
    build(**vars(arguments), fingerprint=TRUSTED_PRIMARY_FINGERPRINT)


if __name__ == "__main__":
    main()
