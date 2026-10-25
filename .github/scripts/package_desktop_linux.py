"""Build private native Linux DEB/RPM packages and AppImages; never signs, publishes, or runs payloads."""

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
import urllib.request
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
    Path("etc"), Path("etc/apt"), Path("etc/apt/apt.conf.d"), Path("etc/apt/keyrings"), Path("etc/apt/sources.list.d"),
    Path("etc/pki"), Path("etc/pki/rpm-gpg"), Path("etc/yum.repos.d"),
}
# Installing a package registers its channel's signed repository, so the system updater delivers new versions.
# These are the website's manual-setup paths: an earlier manual setup is replaced, never duplicated.
LINUX_REPOSITORY = "https://storage.googleapis.com/sesori-ai-linux-packages"
REPOSITORY_KEY_SOURCE = ROOT / "client/desktop/linux/packaging/sesori-linux-public.asc"
APT_KEY = Path("etc/apt/keyrings/sesori.asc")
APT_SOURCE = Path("etc/apt/sources.list.d/sesori.list")
# unattended-upgrades installs only allowed origins; this list entry adds Sesori to the system defaults.
APT_UNATTENDED = Path("etc/apt/apt.conf.d/52sesori-unattended-upgrades")
RPM_KEY = Path("etc/pki/rpm-gpg/RPM-GPG-KEY-sesori")
RPM_REPOSITORY = Path("etc/yum.repos.d/sesori.repo")
REPOSITORY_PATHS = {"deb": {APT_KEY, APT_SOURCE, APT_UNATTENDED}, "rpm": {RPM_KEY, RPM_REPOSITORY}}
CHANNELS = ("stable", "internal")
DYNAMIC_LOAD_PATTERN = re.compile(rb"\b(?:dlopen|DynamicLibrary\.open)\s*\(")
DESKTOP_ENTRY_TEXT = ("[Desktop Entry]\nType=Application\nName=Sesori\nComment=AI coding cockpit\n"
                      "Exec={exec}\nIcon=sesori-desktop\nTerminal=false\nCategories=Development;Utility;\n")
APPIMAGE_HOST_REQUIREMENTS = ["glibc >= 2.39", "GTK 3", "libsecret", "libEGL.so.1", "libGLESv2.so.2", "FUSE"]
# Velopack's vpk builds the AppImage and its release package. The vpk tool package carries the static type2
# AppImage runtime and UpdateNix that go into the image, so this one digest pins all three.
VPK_VERSION = "1.2.161"
VPK_PACKAGE_URL = f"https://github.com/velopack/velopack/releases/download/{VPK_VERSION}/vpk.{VPK_VERSION}.nupkg"
VPK_PACKAGE_SHA256 = "2b56ce117f803fc70c103cb423bd040e395e40370f6ff6e10818e9ff9c26a323"
# vpk places the bundle in the image's usr/bin and adds its updater and manifest beside it.
VELOPACK_ADDED_FILES = {"UpdateNix", "sq.version"}


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


def compiled_channel(*, bundle: Path) -> str:
    defines = dict(line.split("=", 1) for line in
                   (bundle.parent / "dart-defines.env").read_text(encoding="utf-8").splitlines())
    channel = defines.get("SESORI_DESKTOP_RELEASE_CHANNEL")
    if channel not in CHANNELS:
        raise ValueError(f"Bundle has no compiled release channel: {channel}")
    return channel


def repository_files(*, package_format: str, channel: str) -> dict[Path, str]:
    key = REPOSITORY_KEY_SOURCE.read_text(encoding="utf-8")
    if package_format == "deb":
        return {APT_KEY: key, APT_SOURCE: f"deb [signed-by=/{APT_KEY}] {LINUX_REPOSITORY}/apt {channel} main\n",
                APT_UNATTENDED: 'Unattended-Upgrade::Origins-Pattern { "origin=Sesori"; };\n'}
    name = "Sesori internal previews" if channel == "internal" else "Sesori"
    return {RPM_KEY: key, RPM_REPOSITORY: (
        f"[sesori-{channel}]\nname={name}\nbaseurl={LINUX_REPOSITORY}/rpm/{channel}/$basearch\n"
        # An unreachable Sesori repository must never block the system's other updates.
        f"enabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=file:///{RPM_KEY}\nskip_if_unavailable=1\n")}


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


def verify_owned_paths(*, paths: list[str], package_format: str) -> dict:
    owned = {PurePosixPath(path.strip()) for path in paths if path.strip()}
    required = {PurePosixPath("/" + path.as_posix())
                for path in SYSTEM_INTEGRATION_PATHS | REPOSITORY_PATHS[package_format]}
    parents = {PurePosixPath("/" if path == Path(".") else "/" + path.as_posix()) for path in SYSTEM_PARENT_PATHS}
    install_root = PurePosixPath("/" + INSTALL_ROOT.as_posix())
    unexpected = sorted(str(path) for path in owned if path not in required | parents
                        and path != install_root and install_root not in path.parents)
    missing = sorted(str(path) for path in required | {install_root} if path not in owned)
    if unexpected or missing:
        raise ValueError(f"Package ownership mismatch; missing={missing}; unexpected={unexpected}")
    return {"ownedPaths": len(owned), "boundedSystemOwnership": True}


def assemble_payload(*, bundle: Path, root: Path, package_format: str) -> None:
    destination = root / INSTALL_ROOT
    shutil.copytree(bundle, destination, symlinks=True)
    launcher = root / LAUNCHER
    launcher.parent.mkdir(parents=True)
    launcher.symlink_to("/opt/sesori-desktop/sesori_desktop")
    desktop = root / DESKTOP_ENTRY
    desktop.parent.mkdir(parents=True)
    desktop.write_text(DESKTOP_ENTRY_TEXT.format(exec="/usr/bin/sesori-desktop"), encoding="utf-8")
    verify_icon(path=ICON_SOURCE)
    icon = root / ICON
    icon.parent.mkdir(parents=True)
    shutil.copy2(ICON_SOURCE, icon)
    for path, contents in repository_files(package_format=package_format, channel=compiled_channel(bundle=bundle)).items():
        (root / path).parent.mkdir(parents=True, exist_ok=True)
        (root / path).write_text(contents, encoding="utf-8")
        (root / path).chmod(0o644)


def elf_files(*, root: Path) -> list[Path]:
    return [path for path in sorted(root.rglob("*")) if path.is_file() and not path.is_symlink()
            and native_arch(path=path) is not None]


# Flutter's GTK embedder dlopens EGL/GLES through libepoxy, so neither dpkg-shlibdeps nor rpm AutoReq sees them;
# clean Debian 13 and Fedora 44 abort at first frame with "Couldn't open libEGL.so.1" / "libGLESv2.so.2" without these.
DLOPEN_DEB_DEPENDENCIES = "libegl1, libgles2"
DLOPEN_RPM_REQUIRES = ("libEGL.so.1()(64bit)", "libGLESv2.so.2()(64bit)")


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
    dependencies = f'{line.removeprefix("shlibs:Depends=")}, {DLOPEN_DEB_DEPENDENCIES}'
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
        f"BuildArch: {rpm_arch}\nAutoReqProv: yes\n"
        + "".join(f"Requires: {soname}\n" for soname in DLOPEN_RPM_REQUIRES)
        + "\n%description\nSesori desktop cockpit\n\n"
        "%prep\n\n%build\n\n%install\nmkdir -p %{buildroot}\ncp -a %{_sourcedir}/payload/. %{buildroot}/\n\n"
        "%files\n/opt/sesori-desktop\n/usr/bin/sesori-desktop\n"
        "/usr/share/applications/sesori-desktop.desktop\n/usr/share/icons/hicolor/512x512/apps/sesori-desktop.png\n"
        # A user who edits or disables the repository keeps that choice; the key always follows releases.
        + f"/{RPM_KEY}\n%config(noreplace) /{RPM_REPOSITORY}\n",
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
    return tools / "vpk"


def velopack_version(*, identity: dict, channel: str) -> str:
    # Velopack orders releases by SemVer 2. Internal builds share the product version, so the build number orders them.
    if channel == "stable":
        return identity["version"]
    return f"{identity['version']}-internal.{identity['buildNumber']}"


def squashfs_offset(*, image: Path) -> int:
    # The runtime is a 64-bit ELF; the squashfs starts where its section headers end (as --appimage-offset reports).
    with image.open("rb") as stream:
        header = stream.read(64)
    section_headers = int.from_bytes(header[0x28:0x30], "little")
    entry_size = int.from_bytes(header[0x3A:0x3C], "little")
    entries = int.from_bytes(header[0x3C:0x3E], "little")
    return section_headers + entry_size * entries


def build_appimage(*, bundle: Path, work: Path, output: Path, arch: str, identity: dict) -> tuple[Path, dict]:
    channel = compiled_channel(bundle=bundle)
    version = velopack_version(identity=identity, channel=channel)
    vpk = install_vpk(work=work)
    verify_icon(path=ICON_SOURCE)
    releases = work / "velopack"
    command = [str(vpk), "pack", "--packId", PACKAGE_NAME, "--packVersion", version, "--packDir", str(bundle),
               "--mainExe", "sesori_desktop", "--packTitle", "Sesori", "--icon", str(ICON_SOURCE),
               "--categories", "Development;Utility", "--channel", channel, "--outputDir", str(releases)]
    print(run(command=command, cwd=work))
    package = output / f"Sesori-linux-{arch}-{identity['version']}-{identity['buildNumber']}.AppImage"
    shutil.move(releases / f"{PACKAGE_NAME}-{channel}.AppImage", package)
    # The full release package and its feed stay with the run's artifacts until feed publication.
    velopack = output / "velopack"
    velopack.mkdir()
    for name in (f"{PACKAGE_NAME}-{version}-{channel}-full.nupkg", f"releases.{channel}.json"):
        shutil.copy2(releases / name, velopack / name)
    # Read the embedded image back without executing the runtime and require the exact staged bundle.
    offset = squashfs_offset(image=package)
    extracted = work / "extracted"
    run(command=["unsquashfs", "-offset", str(offset), "-no-progress", "-d", str(extracted), str(package)], cwd=work)
    contents = extracted / "usr/bin"
    bundled = [row for row in payload_inventory(root=contents) if row["path"] not in VELOPACK_ADDED_FILES]
    added = all((contents / name).is_file() for name in VELOPACK_ADDED_FILES)
    if bundled != payload_inventory(root=bundle) or not added:
        raise ValueError("AppImage does not contain the exact staged bundle")
    if sha256(extracted / f"{PACKAGE_NAME}.png") != sha256(ICON_SOURCE):
        raise ValueError("AppImage icon differs from the application icon")
    with package.open("rb") as stream:
        runtime_digest = hashlib.sha256(stream.read(offset)).hexdigest()
    # A portable image has no package-manager dependencies; record what the host must provide.
    return package, {"dependencies": [], "dependencyCommand": command, "hostRequirements": APPIMAGE_HOST_REQUIREMENTS,
                     "velopack": {"vpkVersion": VPK_VERSION, "vpkPackageSha256": VPK_PACKAGE_SHA256,
                                  "packVersion": version, "channel": channel,
                                  "runtime": {"sha256": runtime_digest, "bytes": offset},
                                  "releaseFiles": [{"name": path.name, "sha256": sha256(path),
                                                    "bytes": path.stat().st_size}
                                                   for path in sorted(velopack.iterdir())]},
                     "packageFiles": run(command=["unsquashfs", "-offset", str(offset), "-lls", str(package)],
                                         cwd=work).splitlines()}


def verify_installed(*, bundle: Path, installed_root: Path, arch: str, package_format: str) -> dict:
    evidence = verify_bundle(bundle=bundle, arch=arch)
    with tempfile.TemporaryDirectory(prefix="sesori-linux-expected-") as temporary:
        expected_root = Path(temporary)
        assemble_payload(bundle=bundle, root=expected_root, package_format=package_format)
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
        if package_format == "appimage":
            payload = payload_inventory(root=bundle)
            artifact, package_evidence = build_appimage(bundle=bundle, work=work, output=output, arch=arch,
                                                        identity=evidence["identity"])
        else:
            root = work / "root"
            assemble_payload(bundle=bundle, root=root, package_format=package_format)
            payload = payload_inventory(root=root)
            builder = {"deb": build_deb, "rpm": build_rpm}[package_format]
            artifact, package_evidence = builder(root=root, work=work, output=output, arch=arch,
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
    parser.add_argument("--format", choices=("deb", "rpm", "appimage"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--package-config", type=Path)
    parser.add_argument("--installed-root", type=Path, default=Path("/"))
    args = parser.parse_args()
    if args.operation == "verify-owned-paths":
        if args.format not in REPOSITORY_PATHS:
            parser.error("verify-owned-paths requires --format deb or rpm")
        print(json.dumps(verify_owned_paths(paths=sys.stdin.read().splitlines(), package_format=args.format), indent=2))
        return
    if args.bundle is None or args.arch is None:
        parser.error(f"{args.operation} requires --bundle and --arch")
    if args.operation == "verify":
        print(json.dumps(verify_bundle(bundle=args.bundle.resolve(), arch=args.arch), indent=2))
        return
    if args.operation == "verify-installed":
        if args.format not in REPOSITORY_PATHS:
            parser.error("verify-installed requires --format deb or rpm")
        print(json.dumps(verify_installed(bundle=args.bundle.resolve(), installed_root=args.installed_root.resolve(),
                                          arch=args.arch, package_format=args.format), indent=2))
        return
    if args.format is None or args.output is None or args.package_config is None:
        parser.error("package requires --format, --output and --package-config")
    package(bundle=args.bundle, output=args.output, arch=args.arch, package_format=args.format,
            package_config=args.package_config)


if __name__ == "__main__":
    main()
