"""Build and inspect unsigned private Windows installers; never signs or publishes."""

import argparse
import hashlib
import json
import re
from pathlib import Path

from qualify_desktop import ROOT, inventory, run

INNO_VERSION = "7.1.0"
INSTALLER_SOURCE = ROOT / "client/desktop/tool/windows_installer.iss"


def verify_bundle(*, bundle: Path, arch: str, version: str, installed: bool = False) -> dict:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"Version must be semantic major.minor.patch: {version}")
    manifest_path = bundle / "bridge/desktop-bundle.json"
    required = (bundle / "sesori_desktop.exe", bundle / "bridge/bin/bridge.exe", bundle / "bridge/lib", manifest_path)
    for path in required:
        if not path.exists():
            raise ValueError(f"Required staged entry missing: {path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected = {"os": "windows", "architecture": arch, "version": version}
    actual = {key: manifest.get(key) for key in expected}
    if actual != expected:
        raise ValueError(f"Bundle identity mismatch: {actual}; expected {expected}")
    # Inno's own x64 uninstaller launcher is allowed under emulation on ARM64;
    # every product binary remains subject to native target validation.
    ignored = frozenset({"unins000.exe"}) if installed else frozenset()
    return {"identity": manifest,
            "binaries": inventory(root=bundle, target_os="windows", arch=arch, ignored_paths=ignored)}


def package(*, bundle: Path, output: Path, arch: str, version: str, iscc: Path) -> Path:
    bundle, output, iscc = bundle.resolve(), output.resolve(), iscc.resolve()
    evidence = verify_bundle(bundle=bundle, arch=arch, version=version)
    output.mkdir(parents=True)  # Preserve any failed attempt; never replace its diagnostics.
    log = output / "packaging.log"
    command = [str(iscc), str(INSTALLER_SOURCE), f"/DBundleDir={bundle}", f"/DOutputDir={output}",
               f"/DAppVersion={version}", f"/DArchitecture={arch}"]
    compiler_output = run(command=command)
    log.write_text("$ " + " ".join(command) + "\n" + compiler_output, encoding="utf-8")
    if INNO_VERSION not in compiler_output:
        raise RuntimeError(f"Compiler did not identify pinned Inno Setup {INNO_VERSION}; see {log}")
    installer = output / f"Sesori-windows-{arch}-{version}.exe"
    if not installer.is_file():
        raise RuntimeError(f"Compiler did not create expected installer: {installer}")
    with installer.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {
        "packagerSourceSha": run(command=["git", "rev-parse", "HEAD"]).strip(),
        "architecture": arch,
        "innoSetupVersion": INNO_VERSION,
        "bundle": evidence,
        "installer": {"name": installer.name, "sha256": digest, "bytes": installer.stat().st_size},
        "proofBoundary": "Unsigned installer compilation and native payload inventory; not signing, GUI, account, "
                         "SmartScreen, upgrade, publication or interactive product QA",
    }
    (output / "packaging.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Compiled unsigned private Windows/{arch} installer: {installer}")
    return installer


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("package", "verify", "verify-installed"))
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--arch", choices=("x64", "arm64"), required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--iscc", type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    if args.operation in ("verify", "verify-installed"):
        evidence = verify_bundle(bundle=bundle, arch=args.arch, version=args.version,
                                 installed=args.operation == "verify-installed")
        print(json.dumps(evidence, indent=2))
        return
    if args.output is None or args.iscc is None:
        parser.error("package requires --output and --iscc")
    package(bundle=bundle, output=args.output.resolve(), arch=args.arch, version=args.version,
            iscc=args.iscc.resolve())


if __name__ == "__main__":
    main()
