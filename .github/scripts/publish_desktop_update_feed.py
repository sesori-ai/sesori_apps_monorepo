"""Sign and host desktop update feeds after a platform's GitHub release assets are public.

AppImage installs read a Velopack feed (`releases.<channel>.json`, its `.sig` and the full
`.nupkg`); macOS installs read a Sparkle `appcast.xml` whose enclosure is the published release
ZIP. `download-macos` and `sign` run in the signing job, which alone holds the update key.
`publish` runs in the hosting job, which alone holds bucket federation. That federation can write
the whole bucket, so `publish` refuses every object outside `desktop-updates/k1/<channel>/`.
"""

import argparse
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

import sign_desktop_update as signing
from package_desktop_linux import velopack_version
from prepare_desktop_release import read_json, require, sha256
from publish_linux_repository import BUCKET, fetch, public_digest

REPOSITORY = "sesori-ai/sesori_apps_monorepo"
# The update key compiled into the apps (desktopUpdatePublicKey and SUPublicEDKey). Feed paths carry
# its ID; a rotation ships the next key and path from a release signed with this one.
PUBLIC_KEY = "fX8esm5FEY71sv0tGsx2Wdb0DB5IECuPdtdYHd5Wun4="
KEY_ID = "k1"
CHANNELS = ("stable", "internal")
ARCHITECTURES = ("x64", "arm64")
PACKAGE_ID = "sesori-desktop"
MACOS_MANIFEST = "desktop-release.json"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
RELEASE_DOWNLOADS = f"https://github.com/{REPOSITORY}/releases/download/"
FEED_OBJECT = re.compile(
    rf"desktop-updates/{KEY_ID}/(?P<channel>stable|internal)/(?:linux|macos)-(?:x64|arm64)/"
    r"(?:releases\.(?P<feed>stable|internal)\.json(?:\.sig)?|appcast\.xml|sesori-desktop-[0-9A-Za-z.+-]+-full\.nupkg)")


def feed_directory(*, channel: str, target: str) -> str:
    return f"desktop-updates/{KEY_ID}/{channel}/{target}"


def release_tag(*, channel: str, version: str, build_number: int) -> str:
    return f"v{version}" if channel == "stable" else f"v{version}-internal.{build_number}"


def download_macos(*, channel: str, version: str, build_number: int, output: Path) -> None:
    # The enclosures are the public release ZIPs, so sign the bytes users download, not a CI copy.
    tag = release_tag(channel=channel, version=version, build_number=build_number)
    output.mkdir(parents=True)
    fetch(url=f"{RELEASE_DOWNLOADS}{tag}/{MACOS_MANIFEST}", output=output / MACOS_MANIFEST)
    manifest = read_json(output / MACOS_MANIFEST)
    require(manifest.get("platform") == "macos" and manifest.get("tag") == tag and manifest.get("channel") == channel
            and manifest.get("version") == version and manifest.get("buildNumber") == build_number,
            "Published macOS release differs from the requested feed")
    digests = {row["name"]: row["sha256"] for row in manifest["artifacts"]}
    for arch in ARCHITECTURES:
        name = f"Sesori-macos-{arch}.zip"
        fetch(url=f"{RELEASE_DOWNLOADS}{tag}/{name}", output=output / name)
        require(digests.get(name) == sha256(output / name), f"Published ZIP differs from its release manifest: {name}")


def velopack_package(*, directory: Path, channel: str) -> tuple[Path, str]:
    """The full package and version the feed in [directory] names, checked against its digest and size."""
    assets = read_json(directory / f"releases.{channel}.json").get("Assets")
    require(isinstance(assets, list) and len(assets) == 1, "Expected exactly one release in the Velopack feed")
    asset = assets[0]
    version = asset.get("Version")
    name = f"{PACKAGE_ID}-{version}-{channel}-full.nupkg"
    require(asset.get("PackageId") == PACKAGE_ID and asset.get("Type") == "Full" and asset.get("FileName") == name,
            "Unexpected Velopack release package")
    package = directory / name
    require(package.is_file() and not package.is_symlink() and str(asset.get("SHA256")).lower() == sha256(package)
            and asset.get("Size") == package.stat().st_size, f"Velopack package differs from its feed: {name}")
    return package, version


def sign_velopack(*, key: Path, channel: str, version: str, build_number: int, root: Path, output: Path) -> None:
    sources = [root / f"desktop-velopack-linux-{arch}" for arch in ARCHITECTURES]
    if not any(source.is_dir() for source in sources):
        print("This run has no Velopack packages (pre-Velopack source); Linux feeds stay unchanged", file=sys.stderr)
        return
    require(all(source.is_dir() for source in sources), "Expected Velopack packages for both CPUs")
    expected = velopack_version(identity={"version": version, "buildNumber": build_number}, channel=channel)
    feed = f"releases.{channel}.json"
    for arch, source in zip(ARCHITECTURES, sources):
        package, packed = velopack_package(directory=source, channel=channel)
        require(packed == expected, f"Velopack release {packed} differs from the published {expected}")
        target = output / feed_directory(channel=channel, target=f"linux-{arch}")
        target.mkdir(parents=True)
        shutil.copyfile(package, target / package.name)
        shutil.copyfile(source / feed, target / feed)
        (target / f"{feed}.sig").write_text(signing.sign(key=key, payload=target / feed) + "\n")
        print(f"Signed the linux-{arch} {channel} feed for {packed}", file=sys.stderr)


def appcast(*, url: str, length: int, version: str, short_version: str, minimum_system_version: str,
            signature: str) -> bytes:
    # Inputs are validated digits, versions, a release URL and base64, so nothing needs escaping.
    return (f'<?xml version="1.0" encoding="utf-8"?>\n'
            f'<rss version="2.0" xmlns:sparkle="{SPARKLE}">\n'
            f'  <channel>\n'
            f'    <title>Sesori</title>\n'
            f'    <item>\n'
            f'      <title>{short_version}</title>\n'
            f'      <sparkle:version>{version}</sparkle:version>\n'
            f'      <sparkle:shortVersionString>{short_version}</sparkle:shortVersionString>\n'
            f'      <sparkle:minimumSystemVersion>{minimum_system_version}</sparkle:minimumSystemVersion>\n'
            f'      <enclosure url="{url}" length="{length}" type="application/octet-stream" '
            f'sparkle:edSignature="{signature}"/>\n'
            f'    </item>\n'
            f'  </channel>\n'
            f'</rss>\n').encode()


def sign_appcasts(*, key: Path, channel: str, version: str, build_number: int, root: Path, output: Path) -> None:
    tag = release_tag(channel=channel, version=version, build_number=build_number)
    for arch in ARCHITECTURES:
        archive = root / f"Sesori-macos-{arch}.zip"
        with zipfile.ZipFile(archive) as bundle:
            info = plistlib.loads(bundle.read("Sesori.app/Contents/Info.plist"))
        minimum = info.get("LSMinimumSystemVersion")
        # Sparkle compares CFBundleVersion, which is the build number on every channel.
        require(info.get("CFBundleVersion") == str(build_number) and info.get("CFBundleShortVersionString") == version
                and isinstance(minimum, str) and re.fullmatch(r"\d+(\.\d+)*", minimum) is not None,
                f"The app in {archive.name} differs from the published release")
        target = output / feed_directory(channel=channel, target=f"macos-{arch}")
        target.mkdir(parents=True)
        (target / "appcast.xml").write_bytes(appcast(
            url=f"{RELEASE_DOWNLOADS}{tag}/{archive.name}", length=archive.stat().st_size, version=str(build_number),
            short_version=version, minimum_system_version=minimum, signature=signing.sign(key=key, payload=archive)))
        print(f"Signed the macos-{arch} {channel} appcast for build {build_number}", file=sys.stderr)


def sign(*, key: Path, platform: str, channel: str, version: str, build_number: int, root: Path,
         output: Path) -> None:
    require(signing.public_key(key=key) == PUBLIC_KEY, "The signing key is not the compiled update key")
    signer = sign_velopack if platform == "linux" else sign_appcasts
    signer(key=key, channel=channel, version=version, build_number=build_number, root=root, output=output)


def verify(*, root: Path, channel: str) -> list[str]:
    """Every object to host, after the prefix guard and an independent check of each feed."""
    names = []
    for path in sorted(root.rglob("*")):
        name = path.relative_to(root).as_posix()
        require(not path.is_symlink(), f"Refusing a symlinked feed object: {name}")
        if path.is_dir():
            continue
        match = FEED_OBJECT.fullmatch(name)
        require(match is not None and match["channel"] == channel and match["feed"] in (None, channel),
                f"Refusing an unexpected object; only desktop-updates/{KEY_ID}/{channel}/ feeds are hosted: {name}")
        names.append(name)
    require(bool(names), "No feed objects to publish")
    feed = f"releases.{channel}.json"
    for directory in sorted({name.rsplit("/", 1)[0] for name in names}):
        files = {name.rsplit("/", 1)[1] for name in names if name.rsplit("/", 1)[0] == directory}
        if "/macos-" in directory:
            require(files == {"appcast.xml"}, f"Unexpected appcast files: {directory}")
            enclosures = ET.parse(root / directory / "appcast.xml").getroot().findall("channel/item/enclosure")
            require(len(enclosures) == 1 and enclosures[0].get("url", "").startswith(RELEASE_DOWNLOADS)
                    and bool(enclosures[0].get(f"{{{SPARKLE}}}edSignature")), f"Unexpected appcast: {directory}")
        else:
            package, _ = velopack_package(directory=root / directory, channel=channel)
            require(files == {feed, f"{feed}.sig", package.name}, f"Unexpected Velopack feed files: {directory}")
            require(signing.verify(public_key_b64=PUBLIC_KEY, payload=root / directory / feed,
                                   signature_b64=(root / directory / f"{feed}.sig").read_text().strip()),
                    f"Feed signature does not match the compiled update key: {directory}")
    return names


def publication_order(*, name: str) -> int:
    # Packages before the feeds that name them, and signatures after their feeds.
    return 0 if name.endswith(".nupkg") else 2 if name.endswith(".sig") else 1


def publish(*, root: Path, channel: str) -> None:
    for name in sorted(verify(root=root, channel=channel), key=lambda name: (publication_order(name=name), name)):
        immutable = name.endswith(".nupkg")
        digest = sha256(root / name)
        existing = public_digest(name=name)
        if existing == digest:
            print(f"Verified unchanged public object: {name}")
            continue
        require(existing is None or not immutable, f"Conflicting immutable feed package: {name}")
        command = ["gcloud", "storage", "cp", str(root / name), f"gs://{BUCKET}/{name}",
                   "--cache-control=" + ("public,max-age=31536000,immutable" if immutable else "no-store")]
        if immutable:
            command.append("--if-generation-match=0")
        subprocess.run(command, check=True, timeout=600)
        require(public_digest(name=name) == digest, f"Anonymous delivery differs: {name}")
        print(f"Verified published public object: {name}")
    print(f"Published the {channel} desktop update feeds")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("download-macos", "sign"):
        command = commands.add_parser(name)
        command.add_argument("--channel", choices=CHANNELS, required=True)
        command.add_argument("--version", required=True)
        command.add_argument("--build-number", type=int, required=True)
        command.add_argument("--output", type=Path, required=True)
        if name == "sign":
            command.add_argument("--key", type=Path, required=True)
            command.add_argument("--platform", choices=("linux", "macos"), required=True)
            command.add_argument("--root", type=Path, required=True)
    publication = commands.add_parser("publish")
    publication.add_argument("--channel", choices=CHANNELS, required=True)
    publication.add_argument("--root", type=Path, required=True)
    arguments = vars(parser.parse_args())
    command = arguments.pop("command")
    {"download-macos": download_macos, "sign": sign, "publish": publish}[command](**arguments)


if __name__ == "__main__":
    main()
