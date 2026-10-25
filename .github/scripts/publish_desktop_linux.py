"""Attach qualified Linux desktop packages; never create/promote a release or change core assets."""

import argparse
from enum import StrEnum
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from github_release_assets import github, public_sha256
from prepare_desktop_release import ARCHITECTURES, read_json, require, require_producer, sha256
from qualify_desktop import CPU_NAMES
from sign_desktop_linux import CHECKSUMS, PACKAGE_EXTENSIONS, PUBLIC_KEY

MANIFEST = "desktop-linux-release.json"
PUBLIC_DESKTOP_KEY = "desktop-linux-public.asc"
# Public trust anchor, independent of producer artifacts/configuration. Rotate explicitly
# with the current verification instructions in docs/desktop/linux-signing.md.
TRUSTED_PRIMARY_FINGERPRINT = "E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7"
FIXTURES = ("ubuntu-24.04", "debian-13", "fedora-44")
FIXTURE_CHECKS = (
    "installedPayloadVerified", "signedChecksumsVerified", "boundedSystemOwnershipVerified",
    "sameVersionReinstallVerified", "removeOwnedPathsVerified", "sharedDataPreserved", "repositoryKeyMatchesSigner",
)


class Channel(StrEnum):
    STABLE = "stable"
    INTERNAL = "internal"


def verify_checksums(*, packages: Path, fingerprint: str) -> None:
    # The caller supplies the repository's public trust anchor, never an identity
    # accepted solely from the producer's signing report or downloaded key.
    with tempfile.TemporaryDirectory(prefix="gpg-") as directory:
        home = Path(directory)
        keyring = home / "public.gpg"
        try:
            subprocess.run(
                ["gpg", "--homedir", str(home), "--batch", "--dearmor", "--output", str(keyring),
                 str(packages / PUBLIC_KEY)], check=True, capture_output=True, text=True, timeout=30,
            )
            result = subprocess.run(
                ["gpgv", "--homedir", str(home), "--keyring", str(keyring), "--status-fd", "1",
                 str(packages / f"{CHECKSUMS}.asc"), str(packages / CHECKSUMS)],
                check=True, capture_output=True, text=True, timeout=30,
            )
        except subprocess.CalledProcessError as error:
            raise ValueError(f"Public checksum signature verification failed: {error.stderr}") from error
        signatures = [line.split() for line in result.stdout.splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
        require(len(signatures) == 1 and signatures[0][-1] == fingerprint, "Unexpected checksum signer")


def prepare(*, root: Path, output: Path, source_sha: str, tooling_sha: str, channel: Channel,
            repository: str, run_id: int, current_run_id: int | None,
            version: str, build_number: int) -> dict:
    run = require_producer(root=root, source_sha=source_sha, tooling_sha=tooling_sha,
                           repository=repository, run_id=run_id, current_run_id=current_run_id)
    require(bool(re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version)), "Expected clean release version")
    require(type(build_number) is int and build_number > 0, "Expected positive shared build number")
    output.mkdir(parents=True)
    artifacts, verification = [], []
    for arch in ARCHITECTURES:
        packages = root / f"desktop-linux-packages-{arch}"
        evidence = root / f"desktop-linux-evidence-{arch}"
        bundle = evidence / "desktop-bundle"
        packaging = evidence / "desktop-linux-packaging"
        signed = read_json(packaging / "signed/signing.json")
        identity = read_json(bundle / "bundle/bridge/desktop-bundle.json")
        require(identity["os"] == "linux" and identity["architecture"] == arch, "Wrong Linux target")
        require(identity["sourceSha"] == source_sha and identity["version"] == version
                and identity["buildNumber"] == build_number, "Package differs from shared release identity")
        require(signed["identity"] == identity, "Signing identity differs from sealed bundle")
        defines = dict(line.split("=", 1) for line in (bundle / "dart-defines.env").read_text().splitlines())
        require(json.loads(defines["SESORI_DESKTOP_BUNDLE_IDENTITY"]) == identity, "Compiled identity differs")
        require(defines["SESORI_DESKTOP_RELEASE_CHANNEL"] == channel.value, "Cannot relabel compiled channel")
        patch = bundle / "build-source-changes.patch"
        require(patch.exists() and patch.stat().st_size == 0, "Missing clean-source evidence or modified source")
        require(signed["signerFingerprint"] == TRUSTED_PRIMARY_FINGERPRINT,
                f"{arch}: signer {signed['signerFingerprint']} differs from trusted primary fingerprint "
                f"{TRUSTED_PRIMARY_FINGERPRINT}")
        require(signed["checksumFile"] == CHECKSUMS and signed["publicKeyFile"] == PUBLIC_KEY,
                "Unexpected signing companion files")
        formats = {f"Sesori-linux-{arch}-{version}-{build_number}.{extension}": kind
                   for kind, extension in PACKAGE_EXTENSIONS.items()}
        require(len(signed["artifacts"]) == len(formats) and {row["name"] for row in signed["artifacts"]} == set(formats),
                "Expected every qualified DEB/RPM/AppImage file")
        checksum_rows = (line.split() for line in (packages / CHECKSUMS).read_text().splitlines())
        checksums = {name: digest for digest, name in checksum_rows}
        require(set(checksums) == set(formats), "Unexpected signed checksum inventory")
        for row in signed["artifacts"]:
            name = row["name"]
            kind = formats[name]
            unsigned = read_json(packaging / kind / "packaging.json")
            require(unsigned["bundle"]["identity"] == identity and unsigned["package"]["name"] == name
                    and unsigned["packagerSourceSha"] == source_sha, "Unsigned qualification identity differs")
            require(unsigned["package"]["sha256"] == row["unsignedSha256"], "Unsigned package evidence differs")
            if kind != "rpm":
                require(row["unsignedSha256"] == row["sha256"], f"Signing changed {kind} bytes")
            path = packages / name
            require(path.stat().st_size == row["bytes"] and sha256(path) == row["sha256"] == checksums[name],
                    f"Signed package digest mismatch: {name}")
            shutil.copyfile(path, output / name)
            artifacts.append({"name": name, "architecture": arch, "format": kind,
                              "sha256": row["sha256"], "bytes": row["bytes"]})
        for fixture in FIXTURES:
            record = read_json(packaging / f"{fixture}-fixture.json")
            require(record["installedIdentity"] == identity and record["architecture"] == arch
                    and CPU_NAMES.get(record["containerMachine"]) == arch, f"Wrong native fixture identity: {fixture}")
            require(all(record.get(check) is True for check in FIXTURE_CHECKS), f"Incomplete fixture: {fixture}")
        verify_checksums(packages=packages, fingerprint=TRUSTED_PRIMARY_FINGERPRINT)
        # Keep each native checksum/signature pair intact; renaming does not change signed bytes.
        for suffix in ("", ".asc"):
            name = f"desktop-linux-{arch}-checksums.txt{suffix}"
            shutil.copyfile(packages / (CHECKSUMS + suffix), output / name)
            verification.append({"name": name, "sha256": sha256(output / name),
                                 "bytes": (output / name).stat().st_size})
        key = output / PUBLIC_DESKTOP_KEY
        if key.exists():
            require(sha256(key) == sha256(packages / PUBLIC_KEY), "Architecture public keys differ")
        else:
            # Separate immutable desktop asset from the core CLI owner's replaceable key asset.
            shutil.copyfile(packages / PUBLIC_KEY, key)
    verification.append({"name": PUBLIC_DESKTOP_KEY, "sha256": sha256(key), "bytes": key.stat().st_size})
    tag = f"v{version}" if channel is Channel.STABLE else f"v{version}-internal.{build_number}"
    metadata = {
        "schemaVersion": 1, "platform": "linux", "channel": channel.value, "version": version,
        "buildNumber": build_number, "sourceSha": source_sha, "tag": tag,
        "repository": repository, "packagingRun": run_id, "producerWorkflowSha": run["head_sha"],
        "preparationSourceSha": tooling_sha, "signerFingerprint": TRUSTED_PRIMARY_FINGERPRINT,
        "artifacts": artifacts, "verificationFiles": verification,
        "proofBoundary": "This run verified signed native DEB/RPM/AppImage packages and container package "
                         "fixtures. Native GUI/login/keyring/tray and N-to-N+1 upgrades were qualified "
                         "separately on earlier builds, not for this build. Repositories publish separately.",
    }
    (output / MANIFEST).write_text(json.dumps(metadata, indent=2) + "\n")
    return metadata


def publish(*, root: Path, output: Path, source_sha: str, tooling_sha: str, channel: Channel,
            repository: str, run_id: int, current_run_id: int | None,
            version: str, build_number: int) -> None:
    metadata = prepare(root=root, output=output, source_sha=source_sha, tooling_sha=tooling_sha,
                       channel=channel, repository=repository, run_id=run_id, current_run_id=current_run_id,
                       version=version, build_number=build_number)
    tag = metadata["tag"]
    release = json.loads(github(arguments=["api", f"repos/{repository}/releases/tags/{tag}"]))
    # Same rule as macOS: stable may stay a pre-release until its bridge rollout is promoted.
    require(not release["draft"], "Shared release must already be public")
    if channel is Channel.INTERNAL:
        require(release["prerelease"], "Internal desktop packages require an internal pre-release")
    commit = json.loads(github(arguments=["api", f"repos/{repository}/commits/{tag}"]))
    require(commit["sha"] == source_sha, "Shared release tag source differs from desktop source")
    existing = {asset["name"] for asset in release["assets"]}
    assets = [(output / row["name"], row["sha256"]) for row in metadata["artifacts"] + metadata["verificationFiles"]]
    # Linux completion is independent of macOS and follows every anonymous public-byte check.
    assets.append((output / MANIFEST, sha256(output / MANIFEST)))
    for path, digest in assets:
        if path.name not in existing:
            github(arguments=["release", "upload", tag, str(path), "--repo", repository])
        actual = public_sha256(url=f"https://github.com/{repository}/releases/download/{tag}/{path.name}")
        require(actual == digest, f"Public asset digest mismatch; refusing replacement: {path.name}")
        print(f"Verified public Linux desktop asset: {path.name} sha256:{actual}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    for name in ("source-sha", "tooling-sha", "repository", "version"):
        parser.add_argument(f"--{name}", required=True)
    for name in ("run-id", "build-number"):
        parser.add_argument(f"--{name}", type=int, required=True)
    parser.add_argument("--channel", type=Channel, choices=list(Channel), required=True)
    publish(**vars(parser.parse_args()), current_run_id=int(os.environ.get("GITHUB_RUN_ID", "0")) or None)


if __name__ == "__main__":
    main()
