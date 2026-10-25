"""Build and inspect unsigned private Windows Velopack installers; never signs or publishes."""

import argparse
import hashlib
import json
import re
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from package_desktop_linux import VPK_PACKAGE_SHA256, VPK_PACKAGE_URL, VPK_VERSION, compiled_channel, velopack_version
from qualify_desktop import ROOT, inventory, native_arch, run

PACK_ID = "sesori-desktop"
ICON_SOURCE = ROOT / "client/desktop/windows/runner/resources/app_icon.ico"
# vpk adds its updater, a launcher stub and its manifest beside the bundle. Setup installs the updater as
# Update.exe and the stub as Sesori.exe in the install root, and only the manifest joins the bundle in current\.
VELOPACK_ADDED_FILES = frozenset({"Squirrel.exe", "Sesori_ExecutionStub.exe", "sq.version"})


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_bundle(*, bundle: Path, arch: str, version: str) -> dict:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"Version must be semantic major.minor.patch: {version}")
    manifest_path = bundle / "bridge/desktop-bundle.json"
    required = (bundle / "sesori_desktop.exe", bundle / "bridge/bin/bridge.exe", bundle / "bridge/lib", manifest_path)
    for path in required:
        valid = path.is_dir() if path == bundle / "bridge/lib" else path.is_file()
        if not valid:
            raise ValueError(f"Required staged entry missing or wrong type: {path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected = {"os": "windows", "architecture": arch, "version": version}
    actual = {key: manifest.get(key) for key in expected}
    if actual != expected:
        raise ValueError(f"Bundle identity mismatch: {actual}; expected {expected}")
    return {"identity": manifest, "binaries": inventory(root=bundle, target_os="windows", arch=arch)}


def install_vpk(*, work: Path) -> Path:
    feed = work / "vpk-feed"
    feed.mkdir()
    package = feed / f"vpk.{VPK_VERSION}.nupkg"
    with urllib.request.urlopen(VPK_PACKAGE_URL, timeout=60) as response, package.open("wb") as stream:
        shutil.copyfileobj(response, stream)
    if sha256(package) != VPK_PACKAGE_SHA256:
        raise ValueError(f"vpk package digest mismatch: {sha256(package)}; expected {VPK_PACKAGE_SHA256}")
    tools = work / "vpk-tool"
    # --source replaces every NuGet source, so only the verified package can be installed.
    run(command=["dotnet", "tool", "install", "vpk", "--version", VPK_VERSION, "--tool-path", str(tools),
                 "--source", str(feed)], cwd=work)
    return Path(shutil.which("vpk", path=str(tools)))  # vpk.exe on Windows


def payload_digests(*, root: Path) -> dict[str, str]:
    return {path.relative_to(root).as_posix(): sha256(path) for path in root.rglob("*") if path.is_file()}


def package(*, bundle: Path, output: Path, arch: str, version: str) -> Path:
    bundle, output = bundle.resolve(), output.resolve()
    evidence = verify_bundle(bundle=bundle, arch=arch, version=version)
    channel = compiled_channel(bundle=bundle)
    pack_version = velopack_version(identity=evidence["identity"], channel=channel)
    output.mkdir(parents=True)  # Preserve any failed attempt; never replace its diagnostics.
    installer = output / f"Sesori-windows-{arch}-{version}.exe"
    velopack = output / "velopack"
    velopack.mkdir()
    full_package = velopack / f"{PACK_ID}-{pack_version}-{channel}-full.nupkg"
    with tempfile.TemporaryDirectory(prefix="sesori-windows-package-") as temporary:
        work = Path(temporary)
        vpk = install_vpk(work=work)
        releases = work / "releases"
        # The only shortcut is Start menu\Programs\Sesori\Sesori: StartMenu nests it in the authors folder,
        # and no desktop shortcut is created.
        command = [str(vpk), "pack", "--packId", PACK_ID, "--packVersion", pack_version, "--packDir", str(bundle),
                   "--mainExe", "sesori_desktop.exe", "--packTitle", "Sesori", "--packAuthors", "Sesori",
                   "--icon", str(ICON_SOURCE), "--runtime", f"win-{arch}", "--channel", channel,
                   "--shortcuts", "StartMenu", "--outputDir", str(releases), "--noPortable"]
        compiler_output = run(command=command, cwd=work)
        (output / "packaging.log").write_text("$ " + " ".join(command) + "\n" + compiler_output, encoding="utf-8")
        shutil.move(releases / f"{PACK_ID}-{channel}-Setup.exe", installer)
        # The full release package and its feed stay with the run's artifacts until feed publication.
        for name in (full_package.name, f"releases.{channel}.json"):
            shutil.copy2(releases / name, velopack / name)
        # Setup is vpk's stub with the full package appended; that package must hold the exact bundle.
        extracted = work / "extracted"
        with zipfile.ZipFile(full_package) as archive:
            archive.extractall(extracted)
        packaged = payload_digests(root=extracted / "lib/app")
        # vpk ships a native updater and stub per CPU, so the whole package is held to the target CPU.
        inventory(root=extracted / "lib/app", target_os="windows", arch=arch)
    if {path: digest for path, digest in packaged.items() if path not in VELOPACK_ADDED_FILES} != \
            payload_digests(root=bundle):
        raise ValueError("Velopack package does not contain the exact staged bundle")
    if native_arch(path=installer) != ("PE", [arch]):
        raise ValueError(f"Wrong native target: {installer}: {native_arch(path=installer)}; expected windows/{arch}")
    if not installer.read_bytes().endswith(full_package.read_bytes()):
        raise ValueError("Velopack Setup does not embed the full release package")
    report = {
        "packagerSourceSha": run(command=["git", "rev-parse", "HEAD"]).strip(),
        "architecture": arch,
        "velopack": {"vpkVersion": VPK_VERSION, "vpkPackageSha256": VPK_PACKAGE_SHA256, "packVersion": pack_version,
                     "channel": channel,
                     "releaseFiles": [{"name": path.name, "sha256": sha256(path), "bytes": path.stat().st_size}
                                      for path in sorted(velopack.iterdir())]},
        "bundle": evidence,
        "installer": {"name": installer.name, "sha256": sha256(installer), "bytes": installer.stat().st_size},
        "proofBoundary": "Unsigned installer compilation and native payload inventory; not signing, GUI, account, "
                         "SmartScreen, upgrade, publication or interactive product QA",
    }
    (output / "packaging.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Compiled unsigned private Windows/{arch} Velopack installer: {installer}")
    return installer


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("package", "verify"))
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--arch", choices=("x64", "arm64"), required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    if args.operation == "verify":
        print(json.dumps(verify_bundle(bundle=bundle, arch=args.arch, version=args.version), indent=2))
        return
    if args.output is None:
        parser.error("package requires --output")
    package(bundle=bundle, output=args.output.resolve(), arch=args.arch, version=args.version)


if __name__ == "__main__":
    main()
