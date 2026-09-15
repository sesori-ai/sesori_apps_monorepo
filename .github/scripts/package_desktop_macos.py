"""Sign/notarize private macOS test artifacts; never publish or launch the GUI."""

import argparse
import hashlib
import json
import plistlib
import shlex
import shutil
import subprocess
from enum import Enum
from pathlib import Path

from qualify_desktop import ROOT, inventory, run

ENTITLEMENTS = ROOT / "client/desktop/macos/Runner/Release.entitlements"


class NotaryStatus(Enum):
    ACCEPTED = "Accepted"
    INVALID = "Invalid"
    IN_PROGRESS = "In Progress"
    UNKNOWN = "Unknown"

    @classmethod
    def _missing_(cls, value):
        return cls.UNKNOWN


def execute(*, command: list[str], log: Path) -> str:
    # Authentication uses a temporary Keychain profile, never password arguments.
    with log.open("a", encoding="utf-8") as stream:
        stream.write("$ " + shlex.join(command) + "\n")
        try:
            output = run(command=command)
        except subprocess.CalledProcessError as error:
            stream.write(error.output or "")
            raise
        stream.write(output + "\n")
    return output


def signing_order(*, app: Path, arch: str) -> list[Path]:
    """Leaf native code, versioned frameworks, then the enclosing application."""
    entries = inventory(root=app, target_os="macos", arch=arch)
    frameworks = sorted((p for p in app.rglob("*.framework") if p.is_dir() and not p.is_symlink()),
                        key=lambda p: len(p.parts), reverse=True)
    container_executables = set()
    for framework in frameworks:
        with (framework / "Resources/Info.plist").open("rb") as stream:
            executable = plistlib.load(stream)["CFBundleExecutable"]
        container_executables.add((framework / executable).resolve())
    with (app / "Contents/Info.plist").open("rb") as stream:
        executable = plistlib.load(stream)["CFBundleExecutable"]
    container_executables.add((app / "Contents/MacOS" / executable).resolve())
    leaves = [app / row["path"] for row in entries if (app / row["path"]).resolve() not in container_executables]
    return sorted(leaves, key=lambda p: len(p.parts), reverse=True) + frameworks + [app]


def sign_app(*, app: Path, arch: str, identity: str, keychain: Path, log: Path) -> None:
    helper = app / "Contents/Helpers/bridge/bin/bridge"
    for target in signing_order(app=app, arch=arch):
        command = ["codesign", "--force", "--timestamp", "--sign", identity, "--keychain", str(keychain)]
        if target in (app, helper):
            command += ["--options", "runtime"]
        if target == app:
            command += ["--entitlements", str(ENTITLEMENTS)]
        execute(command=command + [str(target)], log=log)


def notarize(*, artifact: Path, profile: str, keychain: Path, evidence: Path, log: Path) -> None:
    credentials = ["--keychain-profile", profile, "--keychain", str(keychain)]
    result = execute(command=["xcrun", "notarytool", "submit", str(artifact), *credentials,
                              "--wait", "--timeout", "20m", "--output-format", "json"], log=log)
    evidence.write_text(result, encoding="utf-8")
    response = json.loads(result)
    details = evidence.with_name(evidence.stem + "-details.json")
    try:
        execute(command=["xcrun", "notarytool", "log", response["id"], str(details), *credentials], log=log)
    except subprocess.CalledProcessError as error:
        # The submission result remains authoritative; retain this secondary failure in the local log.
        print(f"Could not retrieve notarization details (exit {error.returncode}); see {log}")
    if NotaryStatus(response["status"]) != NotaryStatus.ACCEPTED:
        # A rejected submission is not a failed command on every notarytool version.
        raise RuntimeError(f"Notarization {response['id']} returned {response['status']}; see {evidence}")


def verify_app(*, app: Path, arch: str, log: Path) -> dict:
    entries = inventory(root=app, target_os="macos", arch=arch)
    # Explicitly verify helper dylibs too: the bin/lib layout is not a nested app bundle.
    for row in entries:
        execute(command=["codesign", "--verify", "--strict", str(app / row["path"])], log=log)
    execute(command=["codesign", "--verify", "--deep", "--strict", str(app)], log=log)
    execute(command=["xcrun", "stapler", "validate", str(app)], log=log)
    execute(command=["spctl", "--assess", "--type", "execute", "--verbose=2", str(app)], log=log)
    version = execute(command=[str(app / "Contents/Helpers/bridge/bin/bridge"), "--version"], log=log).strip()
    return {"binaries": entries, "helperVersion": version}


def package(*, app: Path, output: Path, arch: str, identity: str, keychain: Path, profile: str) -> None:
    output.mkdir(parents=True)  # Refuse an existing destination; preserve failed output for diagnosis.
    work = output / "work"
    work.mkdir()
    log = output / "packaging.log"
    staged = work / "Sesori.app"
    execute(command=["ditto", str(app), str(staged)], log=log)
    sign_app(app=staged, arch=arch, identity=identity, keychain=keychain, log=log)
    submission = work / "notary-input.zip"
    execute(command=["ditto", "-c", "-k", "--keepParent", str(staged), str(submission)], log=log)
    notarize(artifact=submission, profile=profile, keychain=keychain,
             evidence=output / "app-notarization.json", log=log)
    execute(command=["xcrun", "stapler", "staple", str(staged)], log=log)

    # Rebuild the final ZIP only after the app carries its ticket.
    archive = output / f"Sesori-macos-{arch}.zip"
    execute(command=["ditto", "-c", "-k", "--keepParent", str(staged), str(archive)], log=log)
    volume = work / "volume"
    volume.mkdir()
    execute(command=["ditto", str(staged), str(volume / "Sesori.app")], log=log)
    (volume / "Applications").symlink_to("/Applications", target_is_directory=True)
    dmg = output / f"Sesori-macos-{arch}.dmg"
    execute(command=["hdiutil", "create", "-volname", "Sesori", "-srcfolder", str(volume),
                     "-format", "UDZO", "-fs", "HFS+", str(dmg)], log=log)
    execute(command=["codesign", "--sign", identity, "--keychain", str(keychain), "--timestamp", str(dmg)], log=log)
    notarize(artifact=dmg, profile=profile, keychain=keychain,
             evidence=output / "dmg-notarization.json", log=log)
    execute(command=["xcrun", "stapler", "staple", str(dmg)], log=log)
    execute(command=["xcrun", "stapler", "validate", str(dmg)], log=log)
    execute(command=["codesign", "--verify", "--strict", str(dmg)], log=log)
    execute(command=["spctl", "--assess", "--type", "open", "--context", "context:primary-signature",
                     "--verbose=2", str(dmg)], log=log)
    execute(command=["hdiutil", "verify", str(dmg)], log=log)

    extracted = output / "verified-zip"
    execute(command=["ditto", "-x", "-k", str(archive), str(extracted)], log=log)
    zip_evidence = verify_app(app=extracted / "Sesori.app", arch=arch, log=log)
    mount = work / "mounted volume"
    mount.mkdir()
    execute(command=["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(dmg)],
            log=log)
    try:
        dmg_evidence = verify_app(app=mount / "Sesori.app", arch=arch, log=log)
    finally:
        execute(command=["hdiutil", "detach", str(mount)], log=log)
    shutil.copyfile(extracted / "Sesori.app/Contents/Resources/desktop-bundle.json",
                    output / "desktop-bundle.json")
    digests = {}
    for artifact in (archive, dmg):
        with artifact.open("rb") as stream:
            digests[artifact.name] = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {"packagerSourceSha": run(command=["git", "rev-parse", "HEAD"]).strip(), "architecture": arch,
              "artifacts": digests, "zip": zip_evidence, "dmg": dmg_evidence,
              "proofBoundary": "Signed/notarized payloads, extracted native inventory, Gatekeeper assessment and helper "
                               "version; not installed GUI, account, minimum-OS, update or public-release QA"}
    (output / "packaging.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Verified private native macOS/{arch} ZIP and DMG: {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--arch", choices=("x64", "arm64"), required=True)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--keychain", type=Path, required=True)
    parser.add_argument("--notary-profile", required=True)
    args = parser.parse_args()
    package(app=args.app.resolve(), output=args.output.resolve(), arch=args.arch, identity=args.identity,
            keychain=args.keychain.resolve(), profile=args.notary_profile)


if __name__ == "__main__":
    main()
