"""Build private native Linux DEB/RPM packages; never signs, publishes, or runs payloads."""

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlparse

from qualify_desktop import CPU_NAMES, ROOT, inventory, native_arch

PACKAGE_NAME = "sesori-desktop"
INSTALL_ROOT = Path("opt/sesori-desktop")
LAUNCHER = Path("usr/bin/sesori-desktop")
DESKTOP_ENTRY = Path("usr/share/applications/sesori-desktop.desktop")
ICON = Path("usr/share/icons/hicolor/512x512/apps/sesori-desktop.png")
ICON_SOURCE = ROOT / "client/app/android/app/src/main/ic_launcher-playstore.png"
LINUX_PLUGINS = ROOT / "client/desktop/linux/flutter/generated_plugins.cmake"
SYSTEM_INTEGRATION_PATHS = {LAUNCHER, DESKTOP_ENTRY, ICON}
SYSTEM_PARENT_PATHS = {
    Path("."), Path("opt"), Path("usr"), Path("usr/bin"), Path("usr/share"),
    Path("usr/share/applications"), Path("usr/share/icons"), Path("usr/share/icons/hicolor"),
    Path("usr/share/icons/hicolor/512x512"), Path("usr/share/icons/hicolor/512x512/apps"),
}
DYNAMIC_LOAD_PATTERN = re.compile(rb"\b(?:dlopen|DynamicLibrary\.open)\s*\(")


def run(*, command: list[str], cwd: Path, env: dict[str, str] | None = None) -> str:
    try:
        return subprocess.check_output(command, cwd=cwd, env=env, text=True, encoding="utf-8",
                                       stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as error:
        print(error.output, file=sys.stderr)
        raise


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_icon(*, path: Path) -> None:
    header = path.read_bytes()[:26]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) != 26:
        raise ValueError(f"Application icon is not PNG: {path}")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    color_type = header[25]
    if (width, height, color_type) != (512, 512, 6):
        raise ValueError(f"Application icon must be 512x512 RGBA PNG: {path}: {width}x{height}, type {color_type}")


def verify_bundle(*, bundle: Path, arch: str) -> dict:
    manifest_path = bundle / "bridge/desktop-bundle.json"
    required = {
        bundle / "sesori_desktop": "file",
        bundle / "bridge/bin/bridge": "file",
        bundle / "bridge/lib": "directory",
        manifest_path: "file",
    }
    for path, expected_type in required.items():
        valid = path.is_dir() if expected_type == "directory" else path.is_file()
        if path.is_symlink() or not valid:
            raise ValueError(f"Required staged entry missing or wrong type: {path}; expected {expected_type}")
    identity = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = identity.get("version")
    if not isinstance(version, str) or re.fullmatch(r"\d+\.\d+\.\d+", version) is None:
        raise ValueError(f"Bundle version must be semantic major.minor.patch: {version}")
    if isinstance(identity.get("buildNumber"), bool) or not isinstance(identity.get("buildNumber"), int) \
            or identity["buildNumber"] < 1:
        raise ValueError("Bundle buildNumber must be a positive integer")
    if not isinstance(identity.get("sourceSha"), str) or not identity["sourceSha"]:
        raise ValueError("Bundle sourceSha must be non-empty")
    expected = {"os": "linux", "architecture": arch}
    actual = {key: identity.get(key) for key in expected}
    if actual != expected:
        raise ValueError(f"Bundle identity mismatch: {actual}; expected {expected}")
    return {"identity": identity, "binaries": inventory(root=bundle, target_os="linux", arch=arch)}


def linux_plugin_packages() -> tuple[str, ...]:
    contents = LINUX_PLUGINS.read_text(encoding="utf-8")
    match = re.search(r"list\(APPEND FLUTTER_PLUGIN_LIST\s+(.*?)\)", contents, re.DOTALL)
    if match is None:
        raise ValueError(f"Could not read FLUTTER_PLUGIN_LIST from {LINUX_PLUGINS}")
    packages = tuple(match.group(1).split())
    if not packages:
        raise ValueError(f"FLUTTER_PLUGIN_LIST is empty in {LINUX_PLUGINS}")
    return packages


def audit_dynamic_loading(*, package_config: Path) -> dict:
    config = json.loads(package_config.read_text(encoding="utf-8"))
    packages = {item["name"]: item for item in config["packages"]}
    audited_packages = linux_plugin_packages()
    scanned: list[str] = []
    findings: list[str] = []
    for name in audited_packages:
        if name not in packages:
            raise ValueError(f"Required Linux plugin missing from package config: {name}")
        uri = packages[name]["rootUri"]
        parsed = urlparse(uri)
        if parsed.scheme != "file":
            raise ValueError(f"Linux plugin source is not local file URI: {name}: {uri}")
        root = Path(unquote(parsed.path))
        linux = root / "linux"
        if not linux.is_dir():
            raise ValueError(f"Linux plugin source missing: {linux}")
        for source in sorted(path for path in linux.rglob("*") if path.suffix in (".c", ".cc", ".cpp", ".h", ".hpp", ".dart")):
            scanned.append(f"{name}/{source.relative_to(root).as_posix()}")
            if DYNAMIC_LOAD_PATTERN.search(source.read_bytes()):
                findings.append(f"{name}/{source.relative_to(root).as_posix()}")
    if findings:
        raise ValueError("Explicit dynamic loading requires a source-derived package dependency: " + ", ".join(findings))
    return {"packages": list(audited_packages), "files": scanned, "explicitDependencies": []}


def payload_inventory(*, root: Path) -> list[dict]:
    rows = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            rows.append({"path": relative, "type": "symlink", "target": os.readlink(path)})
        elif path.is_file():
            rows.append({"path": relative, "type": "file", "sha256": sha256(path), "bytes": path.stat().st_size})
    return rows


def verify_owned_paths(*, paths: list[str]) -> dict:
    owned = {PurePosixPath(path.strip()) for path in paths if path.strip()}
    required = {PurePosixPath("/" + path.as_posix()) for path in SYSTEM_INTEGRATION_PATHS}
    parents = {PurePosixPath("/" if path == Path(".") else "/" + path.as_posix()) for path in SYSTEM_PARENT_PATHS}
    install_root = PurePosixPath("/" + INSTALL_ROOT.as_posix())
    unexpected = sorted(str(path) for path in owned if path not in required | parents
                        and path != install_root and install_root not in path.parents)
    missing = sorted(str(path) for path in required | {install_root} if path not in owned)
    if unexpected or missing:
        raise ValueError(f"Package ownership mismatch; missing={missing}; unexpected={unexpected}")
    return {"ownedPaths": len(owned), "boundedSystemOwnership": True}


def assemble_payload(*, bundle: Path, root: Path) -> None:
    destination = root / INSTALL_ROOT
    shutil.copytree(bundle, destination, symlinks=True)
    launcher = root / LAUNCHER
    launcher.parent.mkdir(parents=True)
    launcher.symlink_to("/opt/sesori-desktop/sesori_desktop")
    desktop = root / DESKTOP_ENTRY
    desktop.parent.mkdir(parents=True)
    desktop.write_text(
        "[Desktop Entry]\nType=Application\nName=Sesori\nComment=AI coding cockpit\n"
        "Exec=/usr/bin/sesori-desktop\nIcon=sesori-desktop\nTerminal=false\nCategories=Development;Utility;\n",
        encoding="utf-8",
    )
    verify_icon(path=ICON_SOURCE)
    icon = root / ICON
    icon.parent.mkdir(parents=True)
    shutil.copy2(ICON_SOURCE, icon)


def elf_files(*, root: Path) -> list[Path]:
    return [path for path in sorted(root.rglob("*")) if path.is_file() and not path.is_symlink()
            and native_arch(path=path) is not None]


def deb_dependencies(*, root: Path, work: Path, identity: dict) -> tuple[str, list[str]]:
    debian = work / "debian"
    debian.mkdir()
    (debian / "control").write_text(
        f"Source: {PACKAGE_NAME}\nSection: devel\nPriority: optional\nMaintainer: Sesori <support@sesori.com>\n\n"
        f"Package: {PACKAGE_NAME}\nArchitecture: any\nDescription: Sesori desktop cockpit\n",
        encoding="utf-8",
    )
    binaries = elf_files(root=root / INSTALL_ROOT)
    library_dirs = sorted({str(path.parent) for path in binaries if ".so" in path.name})
    command = ["dpkg-shlibdeps", "-O"]
    if library_dirs:
        command.append("-l" + ":".join(library_dirs))
    command.extend("-e" + str(path) for path in binaries)
    output = run(command=command, cwd=work, env={**os.environ, "LD_LIBRARY_PATH": ":".join(library_dirs)})
    line = next((item for item in output.splitlines() if item.startswith("shlibs:Depends=")), None)
    if line is None:
        raise RuntimeError(f"dpkg-shlibdeps emitted no dependency manifest: {output}")
    dependencies = line.removeprefix("shlibs:Depends=")
    return dependencies, command


def build_deb(*, root: Path, work: Path, output: Path, arch: str, identity: dict) -> tuple[Path, dict]:
    dependencies, dependency_command = deb_dependencies(root=root, work=work, identity=identity)
    debian_arch = {"x64": "amd64", "arm64": "arm64"}[arch]
    control = root / "DEBIAN/control"
    control.parent.mkdir()
    control.write_text(
        f"Package: {PACKAGE_NAME}\nVersion: {identity['version']}-{identity['buildNumber']}\n"
        f"Architecture: {debian_arch}\nMaintainer: Sesori <support@sesori.com>\n"
        f"Section: devel\nPriority: optional\nDepends: {dependencies}\n"
        "Description: Sesori desktop cockpit\n",
        encoding="utf-8",
    )
    package = output / f"Sesori-linux-{arch}-{identity['version']}-{identity['buildNumber']}.deb"
    run(command=["dpkg-deb", "--root-owner-group", "--build", str(root), str(package)], cwd=work)
    return package, {"dependencies": dependencies, "dependencyCommand": dependency_command,
                     "metadata": run(command=["dpkg-deb", "--field", str(package)], cwd=work),
                     "packageFiles": run(command=["dpkg-deb", "--contents", str(package)], cwd=work).splitlines()}


def build_rpm(*, root: Path, work: Path, output: Path, arch: str, identity: dict) -> tuple[Path, dict]:
    top = work / "rpmbuild"
    for directory in ("BUILD", "BUILDROOT", "RPMS", "SOURCES", "SPECS", "SRPMS"):
        (top / directory).mkdir(parents=True)
    payload = top / "SOURCES/payload"
    shutil.copytree(root, payload, symlinks=True)
    rpm_arch = {"x64": "x86_64", "arm64": "aarch64"}[arch]
    spec = top / "SPECS/sesori-desktop.spec"
    spec.write_text(
        # Package already-built, identity-verified binaries without stripping them.
        # Keep Fedora's RUNPATH validation and automatic dependency generation.
        "%global __strip /bin/true\n%global debug_package %{nil}\n"
        f"Name: {PACKAGE_NAME}\nVersion: {identity['version']}\nRelease: {identity['buildNumber']}%{{?dist}}\n"
        "Summary: Sesori desktop cockpit\nLicense: Proprietary\n"
        f"BuildArch: {rpm_arch}\nAutoReqProv: yes\n\n%description\nSesori desktop cockpit\n\n"
        "%prep\n\n%build\n\n%install\nmkdir -p %{buildroot}\ncp -a %{_sourcedir}/payload/. %{buildroot}/\n\n"
        "%files\n/opt/sesori-desktop\n/usr/bin/sesori-desktop\n"
        "/usr/share/applications/sesori-desktop.desktop\n/usr/share/icons/hicolor/512x512/apps/sesori-desktop.png\n",
        encoding="utf-8",
    )
    command = ["rpmbuild", "-bb", "--define", f"_topdir {top}", str(spec)]
    run(command=command, cwd=work)
    built = list((top / f"RPMS/{rpm_arch}").glob("*.rpm"))
    if len(built) != 1:
        raise RuntimeError(f"rpmbuild produced {len(built)} binary packages")
    package = output / f"Sesori-linux-{arch}-{identity['version']}-{identity['buildNumber']}.rpm"
    shutil.copy2(built[0], package)
    return package, {"dependencies": run(command=["rpm", "-qp", "--requires", str(package)], cwd=work).splitlines(),
                     "dependencyCommand": command,
                     "metadata": run(command=["rpm", "-qip", str(package)], cwd=work),
                     "packageFiles": run(command=["rpm", "-qlp", str(package)], cwd=work).splitlines()}


def verify_installed(*, bundle: Path, installed_root: Path, arch: str) -> dict:
    evidence = verify_bundle(bundle=bundle, arch=arch)
    with tempfile.TemporaryDirectory(prefix="sesori-linux-expected-") as temporary:
        expected_root = Path(temporary)
        assemble_payload(bundle=bundle, root=expected_root)
        expected = payload_inventory(root=expected_root)
    actual = []
    for row in expected:
        path = installed_root / row["path"]
        if row["type"] == "symlink":
            if not path.is_symlink() or os.readlink(path) != row["target"]:
                raise ValueError(f"Installed symlink mismatch: {path}")
            actual.append({"path": row["path"], "type": "symlink", "target": os.readlink(path)})
        else:
            if not path.is_file() or path.is_symlink() or sha256(path) != row["sha256"]:
                raise ValueError(f"Installed file mismatch: {path}")
            actual.append({"path": row["path"], "type": "file", "sha256": sha256(path),
                           "bytes": path.stat().st_size})
        stat = path.lstat()
        if stat.st_uid != 0 or stat.st_gid != 0:
            raise ValueError(f"Installed package path is not root-owned: {path}")
    installed_bundle_paths = {
        item["path"] for item in payload_inventory(root=installed_root / INSTALL_ROOT)
    }
    expected_bundle_paths = {
        str(Path(item["path"]).relative_to(INSTALL_ROOT))
        for item in expected if item["path"].startswith(INSTALL_ROOT.as_posix() + "/")
    }
    if installed_bundle_paths != expected_bundle_paths:
        raise ValueError("Installed /opt payload has missing or unexpected paths")
    return {"identity": evidence["identity"], "architecture": arch, "payload": actual,
            "rootOwned": True, "exactOptPayload": True}


def package(*, bundle: Path, output: Path, arch: str, package_format: str, package_config: Path) -> Path:
    bundle, output, package_config = bundle.resolve(), output.resolve(), package_config.resolve()
    evidence = verify_bundle(bundle=bundle, arch=arch)
    source_audit = audit_dynamic_loading(package_config=package_config)
    if output.exists():
        raise FileExistsError(f"Output already exists: {output}")
    host_arch = CPU_NAMES.get(platform.machine())
    if host_arch != arch:
        raise ValueError(f"Native host required: expected {arch}, found {host_arch}")
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="sesori-linux-package-") as temporary:
        work = Path(temporary)
        root = work / "root"
        assemble_payload(bundle=bundle, root=root)
        payload = payload_inventory(root=root)
        if package_format == "deb":
            artifact, package_evidence = build_deb(root=root, work=work, output=output, arch=arch,
                                                   identity=evidence["identity"])
        else:
            artifact, package_evidence = build_rpm(root=root, work=work, output=output, arch=arch,
                                                   identity=evidence["identity"])
    report = {
        "packagerSourceSha": run(command=["git", "rev-parse", "HEAD"], cwd=ROOT).strip(),
        "format": package_format,
        "architecture": arch,
        "bundle": evidence,
        "dynamicLoadSourceAudit": source_audit,
        "payload": payload,
        "package": {"name": artifact.name, "sha256": sha256(artifact), "bytes": artifact.stat().st_size},
        **package_evidence,
        "proofBoundary": "Unsigned native package construction and dependency metadata; not GUI, desktop session, "
                         "account, signing, repository publication, or N-to-N+1 upgrade QA",
    }
    (output / "packaging.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Built unsigned private Linux {package_format}/{arch} package: {artifact}")
    return artifact


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("verify", "verify-installed", "verify-owned-paths", "package"))
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--arch", choices=("x64", "arm64"))
    parser.add_argument("--format", choices=("deb", "rpm"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--package-config", type=Path)
    parser.add_argument("--installed-root", type=Path, default=Path("/"))
    args = parser.parse_args()
    if args.operation == "verify-owned-paths":
        print(json.dumps(verify_owned_paths(paths=sys.stdin.read().splitlines()), indent=2))
        return
    if args.bundle is None or args.arch is None:
        parser.error(f"{args.operation} requires --bundle and --arch")
    if args.operation == "verify":
        print(json.dumps(verify_bundle(bundle=args.bundle.resolve(), arch=args.arch), indent=2))
        return
    if args.operation == "verify-installed":
        print(json.dumps(verify_installed(bundle=args.bundle.resolve(), installed_root=args.installed_root.resolve(),
                                          arch=args.arch), indent=2))
        return
    if args.format is None or args.output is None or args.package_config is None:
        parser.error("package requires --format, --output and --package-config")
    package(bundle=args.bundle, output=args.output, arch=args.arch, package_format=args.format,
            package_config=args.package_config)


if __name__ == "__main__":
    main()
