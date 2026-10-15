"""Publish/refresh existing qualified Linux previews; no release creation or stable admission."""

import argparse
import gzip
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from datetime import UTC, datetime
from email.parser import Parser
from email.utils import parsedate_to_datetime
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

from build_linux_repository import ARCHITECTURES, Channel, REPORT, verify_release
from github_release_assets import github
from linux_signing import PUBLIC_KEY, sha256
from prepare_desktop_release import require
from publish_desktop_linux import MANIFEST, PUBLIC_DESKTOP_KEY, TRUSTED_PRIMARY_FINGERPRINT

REPOSITORY = "sesori-ai/sesori_apps_monorepo"
BUCKET = "sesori-ai-linux-packages"
PUBLIC_ROOT = f"https://storage.googleapis.com/{BUCKET}"
DISTRIBUTION = "apt/dists/internal"


def version_order(*, version: str) -> tuple[int, ...]:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)-(\d+)", version)
    require(match is not None, f"Unexpected repository package version: {version}")
    return tuple(int(part) for part in match.groups())


def fetch(*, url: str, output: Path) -> None:
    with urlopen(Request(url, headers={"User-Agent": "sesori-linux-repository"}), timeout=90) as response:
        with output.open("wb") as target:
            shutil.copyfileobj(response, target)


def download(*, output: Path, tag: str | None = None) -> None:
    # Completed public assets survive Actions artifact retention and retain the
    # original signed package bytes. Never bootstrap from an unpublished build.
    pages = json.loads(github(arguments=["api", "--paginate", "--slurp",
                                        f"repos/{REPOSITORY}/releases?per_page=100"]))
    candidates = []
    for release in (release for page in pages for release in page):
        match = re.fullmatch(r"v(\d+\.\d+\.\d+)-internal\.([1-9]\d*)", release["tag_name"])
        if (match and not release["draft"] and release["prerelease"]
                and (tag is None or release["tag_name"] == tag)
                and any(asset["name"] == MANIFEST for asset in release["assets"])):
            version, number = match.groups()
            candidates.append((version_order(version=f"{version}-{number}"), release))
    require(bool(candidates), "No completed public Linux internal release")
    _, release = max(candidates, key=lambda candidate: candidate[0])
    tag = release["tag_name"]
    match = re.fullmatch(r"v(\d+\.\d+\.\d+)-internal\.(\d+)", tag)
    version, number = match.groups()
    names = {f"Sesori-linux-{arch}-{version}-{number}.{kind}"
             for arch in ARCHITECTURES for kind in ("deb", "rpm")}
    names.update(f"desktop-linux-{arch}-checksums.txt{suffix}"
                 for arch in ARCHITECTURES for suffix in ("", ".asc"))
    names.update((PUBLIC_DESKTOP_KEY, MANIFEST))
    assets = {asset["name"]: asset for asset in release["assets"]}
    require(names <= assets.keys(), "Completed release is missing Linux assets")
    output.mkdir(parents=True)
    for name in sorted(names):
        path = output / name
        fetch(url=f"https://github.com/{REPOSITORY}/releases/download/{tag}/{name}", output=path)
        require(assets[name]["size"] == path.stat().st_size
                and assets[name]["digest"] == f"sha256:{sha256(path=path)}", f"Public asset differs: {name}")
    metadata = verify_release(root=output, channel=Channel.INTERNAL, fingerprint=TRUSTED_PRIMARY_FINGERPRINT)
    commit = json.loads(github(arguments=["api", f"repos/{REPOSITORY}/commits/{tag}"]))
    require(metadata["repository"] == REPOSITORY and metadata["tag"] == tag
            and metadata["version"] == version and metadata["buildNumber"] == int(number)
            and metadata["sourceSha"] == commit["sha"], "Completed release identity differs from its tag")
    print(f"Prepared existing qualified preview {tag}; original signed packages unchanged")


def checked_file(*, root: Path, name: str, digest: str, size: int | None = None) -> Path:
    path = root / name
    require(not path.is_symlink() and path.resolve().is_relative_to(root.resolve()), "Unsafe repository path")
    require(sha256(path=path) == digest and (size is None or path.stat().st_size == size),
            f"Repository content differs: {name}")
    return path


def verify_signature(*, home: Path, signature: Path, source: Path | None, fingerprint: str) -> bytes | None:
    command = ["gpgv", "--homedir", str(home), "--keyring", str(home / "trusted.gpg"), "--status-fd", "1"]
    if source is None:
        command.extend(["--output", str(home / "plaintext")])
    command.append(str(signature))
    if source is not None:
        command.append(str(source))
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
    signatures = [line.split() for line in result.stdout.splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
    require(len(signatures) == 1 and signatures[0][-1] == fingerprint, "Unexpected repository signer")
    return (home / "plaintext").read_bytes() if source is None else None


def verify(*, root: Path, fingerprint: str = TRUSTED_PRIMARY_FINGERPRINT) -> dict:
    report = json.loads((root / REPORT).read_text())
    require(report["schemaVersion"] == 1 and report["channel"] == "internal", "Only internal hosting is admitted")
    require(report["signerFingerprint"] == fingerprint, "Repository signer differs from independent trust anchor")
    version = f"{report['version']}-{report['buildNumber']}"
    version_order(version=version)
    expected = {PUBLIC_KEY, f"{DISTRIBUTION}/Release", f"{DISTRIBUTION}/Release.gpg", f"{DISTRIBUTION}/InRelease"}
    require((root / PUBLIC_KEY).read_text().startswith("-----BEGIN PGP PUBLIC KEY BLOCK-----"),
            "Expected public-only repository key")
    with tempfile.TemporaryDirectory(prefix="gpg-") as directory:
        home = Path(directory)
        subprocess.run(["gpg", "--homedir", str(home), "--batch", "--dearmor", "--output", str(home / "trusted.gpg"),
                        str(root / PUBLIC_KEY)], check=True, capture_output=True, timeout=30)
        release = root / DISTRIBUTION / "Release"
        plaintext = verify_signature(home=home, signature=release.with_name("InRelease"),
                                     source=None, fingerprint=fingerprint)
        require(plaintext == release.read_bytes(), "InRelease and Release differ")
        verify_signature(home=home, signature=release.with_name("Release.gpg"), source=release, fingerprint=fingerprint)
        fields = Parser().parsestr(release.read_text())
        require(fields["Suite"] == "internal" and fields["Acquire-By-Hash"] == "yes", "Unexpected APT suite")
        require(parsedate_to_datetime(fields["Valid-Until"]) > datetime.now(UTC), "APT metadata has expired")
        advertised = {}
        for line in fields["SHA256"].splitlines():
            if not line.strip():
                continue
            digest, size, name = line.split()
            advertised[name] = (digest, int(size))
        wanted_indexes = {f"main/binary-{debian}/Packages{suffix}"
                          for debian, _ in ARCHITECTURES.values() for suffix in ("", ".gz")}
        require(advertised.keys() == wanted_indexes, "Unexpected authenticated APT indexes")
        for name, (digest, size) in advertised.items():
            path = checked_file(root=root, name=f"{DISTRIBUTION}/{name}", digest=digest, size=size)
            hashed = path.parent / "by-hash/SHA256" / digest
            require(hashed.read_bytes() == path.read_bytes(), "Missing/mismatched APT by-hash object")
            expected.update((path.relative_to(root).as_posix(), hashed.relative_to(root).as_posix()))
        for arch, (debian, rpm_arch) in ARCHITECTURES.items():
            index = root / DISTRIBUTION / f"main/binary-{debian}/Packages"
            require(gzip.decompress(index.with_name("Packages.gz").read_bytes()) == index.read_bytes(),
                    "APT compressed index differs")
            package = Parser().parsestr(index.read_text())
            name = f"pool/internal/{debian}/Sesori-linux-{arch}-{version}.deb"
            require(package["Package"] == "sesori-desktop" and package["Version"] == version
                    and package["Architecture"] == debian and package["Filename"] == name
                    and not package.get_payload().strip(), "APT package identity differs")
            checked_file(root=root, name=f"apt/{name}", digest=package["SHA256"], size=int(package["Size"]))
            expected.add(f"apt/{name}")
            rpm_root = root / f"rpm/internal/{rpm_arch}"
            repomd = rpm_root / "repodata/repomd.xml"
            verify_signature(home=home, signature=repomd.with_name("repomd.xml.asc"),
                             source=repomd, fingerprint=fingerprint)
            expected.update(path.relative_to(root).as_posix() for path in (repomd, repomd.with_name("repomd.xml.asc")))
            metadata = ET.parse(repomd).getroot()
            require(metadata.find("{*}revision").text == version, "RPM revision differs")
            primary = None
            for row in metadata.findall("{*}data"):
                digest = row.find("{*}checksum")
                location = row.find("{*}location").attrib["href"]
                require(digest.attrib["type"] == "sha256" and location.startswith(f"repodata/{digest.text}-"),
                        "RPM index is not SHA256-addressed")
                path = checked_file(root=rpm_root, name=location, digest=digest.text)
                expected.add(path.relative_to(root).as_posix())
                if row.attrib["type"] == "primary":
                    primary = ET.fromstring(gzip.decompress(path.read_bytes()))
            require(primary is not None and len(primary.findall("{*}package")) == 1, "Expected one RPM package")
            package = primary.find("{*}package")
            location = f"Packages/Sesori-linux-{arch}-{version}.rpm"
            require(package.find("{*}location").attrib["href"] == location
                    and package.find("{*}arch").text == rpm_arch, "RPM package identity differs")
            checksum = package.find("{*}checksum")
            require(checksum.attrib["type"] == "sha256", "Expected SHA256 RPM package checksum")
            path = checked_file(root=rpm_root, name=location, digest=checksum.text,
                                size=int(package.find("{*}size").attrib["package"]))
            expected.add(path.relative_to(root).as_posix())
    rows = report["files"]
    require(len(rows) == len(expected) and {row["name"] for row in rows} == expected,
            "Inventory includes missing or unauthenticated files")
    for row in rows:
        checked_file(root=root, name=row["name"], digest=row["sha256"], size=row["bytes"])
    return report


def public_bytes(*, name: str) -> bytes | None:
    try:
        with urlopen(f"{PUBLIC_ROOT}/{name}", timeout=30) as response:
            return response.read()
    except HTTPError as error:
        error.close()
        if error.code == 404:
            return None
        raise


def public_digest(*, name: str) -> str | None:
    try:
        with urlopen(f"{PUBLIC_ROOT}/{name}", timeout=90) as response:
            digest = hashlib.sha256()
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
            return digest.hexdigest()
    except HTTPError as error:
        error.close()
        if error.code == 404:
            return None
        raise


def publication_order(*, name: str) -> int:
    if name.endswith("/InRelease"):
        return 5
    if name.endswith("/Release.gpg") or name.endswith("/repomd.xml.asc"):
        return 4
    if name.endswith("/Release") or name.endswith("/repomd.xml"):
        return 3
    if name.endswith("/Packages") or name.endswith("/Packages.gz"):
        return 2
    return 1


def publish(*, root: Path) -> None:
    report = verify(root=root)
    # A newer run can fail between architecture entrypoints. Inspect both before
    # writing anything; their existing revisions own the version, not a new pointer.
    incoming = version_order(version=f"{report['version']}-{report['buildNumber']}")
    for _, rpm_arch in ARCHITECTURES.values():
        current = public_bytes(name=f"rpm/internal/{rpm_arch}/repodata/repomd.xml")
        if current is not None:
            previous = ET.fromstring(current).find("{*}revision").text
            require(incoming >= version_order(version=previous),
                    "Refusing to downgrade an already-published repository")
    for row in sorted(report["files"], key=lambda row: (publication_order(name=row["name"]), row["name"])):
        name, digest = row["name"], row["sha256"]
        immutable = publication_order(name=name) == 1
        existing = public_digest(name=name)
        if existing is not None:
            require(not immutable or existing == digest, f"Conflicting immutable repository object: {name}")
            if existing == digest:
                print(f"Verified unchanged public object: {name}")
                continue
        command = ["gcloud", "storage", "cp", str(root / name), f"gs://{BUCKET}/{name}",
                   "--cache-control=" + ("public,max-age=31536000,immutable" if immutable else "no-store")]
        if immutable:
            command.append("--if-generation-match=0")
        subprocess.run(command, check=True, timeout=180)
        require(public_digest(name=name) == digest, f"Anonymous delivery differs: {name}")
        print(f"Verified published public object: {name}")
    print(f"Published Linux internal {report['version']}+{report['buildNumber']}; InRelease completed last")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("download").add_argument("--output", type=Path, required=True)
    for operation in ("verify", "publish"):
        commands.add_parser(operation).add_argument("--root", type=Path, required=True)
    arguments = parser.parse_args()
    if arguments.command == "download":
        download(output=arguments.output)
    elif arguments.command == "verify":
        verify(root=arguments.root)
        print("Independent repository signatures, references and inventory verified")
    else:
        publish(root=arguments.root)


if __name__ == "__main__":
    main()
