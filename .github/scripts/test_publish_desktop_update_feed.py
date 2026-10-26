"""Feed signing, the desktop-updates/ prefix guard and hosting order; no network or cloud writes."""

import hashlib
import json
import plistlib
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from unittest import mock

import publish_desktop_update_feed as feed
import sign_desktop_update as signing

VERSION, BUILD = "1.10.1", 194


class DesktopUpdateFeedTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.key = self.base / "update.pem"
        subprocess.run(["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(self.key)], check=True,
                       capture_output=True)
        self.public_key = signing.public_key(key=self.key)
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(feed, "PUBLIC_KEY", self.public_key).start()
        self.input, self.output = self.base / "input", self.base / "output"

    def velopack(self, *, channel: str, version: str, arches=feed.ARCHITECTURES) -> None:
        for arch in arches:
            directory = self.input / f"desktop-velopack-linux-{arch}"
            directory.mkdir(parents=True)
            name = f"sesori-desktop-{version}-{channel}-full.nupkg"
            package = directory / name
            package.write_bytes(f"package {arch}".encode())
            asset = {"PackageId": "sesori-desktop", "Version": version, "Type": "Full", "FileName": name,
                     "SHA256": hashlib.sha256(package.read_bytes()).hexdigest().upper(),
                     "Size": package.stat().st_size}
            (directory / f"releases.{channel}.json").write_text(json.dumps({"Assets": [asset]}))

    def sign_linux(self, *, channel: str) -> None:
        feed.sign(key=self.key, platform="linux", channel=channel, version=VERSION, build_number=BUILD,
                  root=self.input, output=self.output)

    def test_signs_both_cpu_feeds_with_the_compiled_key_under_the_channel_prefix(self):
        self.velopack(channel="internal", version=f"{VERSION}-internal.{BUILD}")
        self.sign_linux(channel="internal")
        names = feed.verify(root=self.output, channel="internal")
        self.assertEqual(len(names), 6)
        directory = self.output / "desktop-updates/k1/internal/linux-arm64"
        self.assertTrue(signing.verify(public_key_b64=self.public_key, payload=directory / "releases.internal.json",
                                       signature_b64=(directory / "releases.internal.json.sig").read_text().strip()))
        # One run's feeds never cross channels.
        with self.assertRaisesRegex(ValueError, "only desktop-updates/k1/stable/ feeds"):
            feed.verify(root=self.output, channel="stable")

    def test_stable_refuses_an_internal_build(self):
        self.velopack(channel="stable", version=f"{VERSION}-internal.{BUILD}")
        with self.assertRaisesRegex(ValueError, "differs from the published"):
            self.sign_linux(channel="stable")

    def test_refuses_a_secret_that_is_not_the_compiled_key(self):
        self.velopack(channel="stable", version=VERSION)
        with mock.patch.object(feed, "PUBLIC_KEY", "fX8esm5FEY71sv0tGsx2Wdb0DB5IECuPdtdYHd5Wun4="):
            with self.assertRaisesRegex(ValueError, "not the compiled update key"):
                self.sign_linux(channel="stable")

    def test_a_pre_velopack_run_publishes_nothing_but_one_cpu_alone_fails(self):
        self.sign_linux(channel="stable")
        self.assertFalse(self.output.exists())
        self.velopack(channel="stable", version=VERSION, arches=("x64",))
        with self.assertRaisesRegex(ValueError, "both CPUs"):
            self.sign_linux(channel="stable")

    def test_hosting_refuses_tampering_and_objects_outside_the_feed_prefix(self):
        self.velopack(channel="stable", version=VERSION)
        self.sign_linux(channel="stable")
        directory = self.output / "desktop-updates/k1/stable/linux-x64"
        feed_file = directory / "releases.stable.json"
        original = feed_file.read_bytes()
        feed_file.write_bytes(original.replace(b'"Full"', b'"Full" '))
        with self.assertRaisesRegex(ValueError, "signature does not match"):
            feed.verify(root=self.output, channel="stable")
        feed_file.write_bytes(original)
        (directory / f"sesori-desktop-{VERSION}-stable-full.nupkg").write_bytes(b"swapped")
        with self.assertRaisesRegex(ValueError, "differs from its feed"):
            feed.verify(root=self.output, channel="stable")
        for stray in ("apt/dists/stable/InRelease", "desktop-updates/k1/stable/linux-x64/extra.json",
                      "desktop-updates/k2/stable/linux-x64/releases.stable.json"):
            with self.subTest(stray=stray):
                path = self.output / stray
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("x")
                with self.assertRaisesRegex(ValueError, "only desktop-updates/k1/stable/ feeds"):
                    feed.verify(root=self.output, channel="stable")
                path.unlink()

    def macos_zips(self, *, build_number: int) -> None:
        self.input.mkdir(parents=True)
        info = plistlib.dumps({"CFBundleVersion": str(build_number), "CFBundleShortVersionString": VERSION,
                               "LSMinimumSystemVersion": "12.0"}, fmt=plistlib.FMT_BINARY)
        for arch in feed.ARCHITECTURES:
            with zipfile.ZipFile(self.input / f"Sesori-macos-{arch}.zip", "w") as archive:
                archive.writestr("Sesori.app/Contents/Info.plist", info)
                archive.writestr("Sesori.app/Contents/MacOS/Sesori", arch)

    def test_appcast_signs_the_published_zip_with_the_app_versions(self):
        self.macos_zips(build_number=BUILD)
        feed.sign(key=self.key, platform="macos", channel="internal", version=VERSION, build_number=BUILD,
                  root=self.input, output=self.output)
        self.assertEqual(feed.verify(root=self.output, channel="internal"),
                         [f"desktop-updates/k1/internal/macos-{arch}/appcast.xml" for arch in ("arm64", "x64")])
        item = ET.parse(self.output / "desktop-updates/k1/internal/macos-arm64/appcast.xml").find("channel/item")
        sparkle = f"{{{feed.SPARKLE}}}"
        self.assertEqual((item.findtext(f"{sparkle}version"), item.findtext(f"{sparkle}shortVersionString"),
                          item.findtext(f"{sparkle}minimumSystemVersion")), (str(BUILD), VERSION, "12.0"))
        enclosure = item.find("enclosure")
        archive = self.input / "Sesori-macos-arm64.zip"
        self.assertEqual(enclosure.get("url"), f"https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/"
                                               f"v{VERSION}-internal.{BUILD}/Sesori-macos-arm64.zip")
        self.assertEqual(enclosure.get("length"), str(archive.stat().st_size))
        self.assertTrue(signing.verify(public_key_b64=self.public_key, payload=archive,
                                       signature_b64=enclosure.get(f"{sparkle}edSignature")))

    def test_appcast_refuses_an_app_from_another_build(self):
        self.macos_zips(build_number=BUILD - 1)
        with self.assertRaisesRegex(ValueError, "differs from the published release"):
            feed.sign(key=self.key, platform="macos", channel="stable", version=VERSION, build_number=BUILD,
                      root=self.input, output=self.output)

    def test_macos_download_checks_the_release_identity_and_zip_digests(self):
        published = {"Sesori-macos-arm64.zip": b"arm64", "Sesori-macos-x64.zip": b"x64"}
        manifest = {"platform": "macos", "tag": f"v{VERSION}", "channel": "stable", "version": VERSION,
                    "buildNumber": BUILD, "artifacts": [{"name": name, "sha256": hashlib.sha256(data).hexdigest()}
                                                        for name, data in published.items()]}
        published[feed.MACOS_MANIFEST] = json.dumps(manifest).encode()
        urls = []

        def fetch(*, url, output):
            urls.append(url)
            output.write_bytes(published[url.rsplit("/", 1)[1]])

        with mock.patch.object(feed, "fetch", side_effect=fetch):
            feed.download_macos(channel="stable", version=VERSION, build_number=BUILD, output=self.input)
            self.assertTrue(all(url.startswith(f"{feed.RELEASE_DOWNLOADS}v{VERSION}/") for url in urls))
            published["Sesori-macos-x64.zip"] = b"swapped"
            with self.assertRaisesRegex(ValueError, "differs from its release manifest"):
                feed.download_macos(channel="stable", version=VERSION, build_number=BUILD, output=self.base / "b")
            with self.assertRaisesRegex(ValueError, "differs from the requested feed"):
                feed.download_macos(channel="internal", version=VERSION, build_number=BUILD, output=self.base / "c")


class DesktopUpdateFeedHostingTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        directory = "desktop-updates/k1/stable/linux-x64"
        self.package = f"{directory}/sesori-desktop-{VERSION}-stable-full.nupkg"
        self.names = [f"{directory}/releases.stable.json.sig", self.package, f"{directory}/releases.stable.json",
                      "desktop-updates/k1/stable/macos-x64/appcast.xml"]
        for name in self.names:
            (self.root / name).parent.mkdir(parents=True, exist_ok=True)
            (self.root / name).write_text(name)
        self.remote, self.writes = {}, []
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(feed, "verify", return_value=self.names).start()
        mock.patch.object(feed, "public_digest", side_effect=lambda *, name: self.remote.get(name)).start()
        mock.patch.object(feed.subprocess, "run", side_effect=self.upload).start()

    def upload(self, command, **_):
        name = command[4].removeprefix(f"gs://{feed.BUCKET}/")
        self.writes.append((name, command[5:]))
        self.remote[name] = hashlib.sha256(Path(command[3]).read_bytes()).hexdigest()

    def test_packages_first_then_feeds_then_signatures_with_immutable_preconditions(self):
        feed.publish(root=self.root, channel="stable")
        self.assertEqual([name for name, _ in self.writes], [self.names[1], self.names[2], self.names[3],
                                                             self.names[0]])
        self.assertEqual(self.writes[0][1], ["--cache-control=public,max-age=31536000,immutable",
                                             "--if-generation-match=0"])
        self.assertTrue(all(options == ["--cache-control=no-store"] for _, options in self.writes[1:]))

    def test_retry_skips_identical_bytes_and_refuses_a_conflicting_package(self):
        self.remote[self.package] = hashlib.sha256(self.package.encode()).hexdigest()
        feed.publish(root=self.root, channel="stable")
        self.assertNotIn(self.package, [name for name, _ in self.writes])
        self.remote = {self.package: "0" * 64}
        self.writes.clear()
        with self.assertRaisesRegex(ValueError, "Conflicting immutable feed package"):
            feed.publish(root=self.root, channel="stable")
        self.assertEqual(self.writes, [])

    def test_failed_anonymous_delivery_stops_before_the_signed_entrypoints(self):
        with mock.patch.object(feed, "public_digest", return_value=None):
            with self.assertRaisesRegex(ValueError, "Anonymous delivery differs"):
                feed.publish(root=self.root, channel="stable")
        self.assertEqual([name for name, _ in self.writes], [self.package])


if __name__ == "__main__":
    unittest.main()
