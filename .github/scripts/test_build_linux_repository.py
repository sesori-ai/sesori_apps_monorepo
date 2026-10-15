"""Real signed repository fixtures; inert packages never launch Sesori or access user state."""

import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from email.utils import parsedate_to_datetime
from unittest import mock
import xml.etree.ElementTree as ET

import build_linux_repository as repository
import linux_signing as keys
import publish_linux_repository as hosting
import sign_desktop_linux as signing


@unittest.skipUnless(os.environ.get("SESORI_LINUX_SIGNING_TEST_REQUIRED") == "1",
                     "real repository tools run inside the pinned Fedora signing image")
class LinuxRepositoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ("gpg", "gpgv", "gpgconf", "rpmbuild", "rpmkeys", "rpmsign", "dpkg-deb", "apt-ftparchive",
                     "apt-get", "createrepo_c", "dnf"):
            if shutil.which(tool) is None:
                raise RuntimeError(f"Required repository fixture tool missing: {tool}")
        cls.temporary = tempfile.TemporaryDirectory(prefix="sesori-repository-fixture-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.home = cls.root / "key"
        cls.home.mkdir(mode=0o700)
        cls.env = {**os.environ, "GNUPGHOME": str(cls.home), "LC_ALL": "C"}
        cls.debian_arch = keys.run(command=["dpkg", "--print-architecture"], env=cls.env).strip()
        cls.rpm_arch = {"amd64": "x86_64", "arm64": "aarch64"}[cls.debian_arch]
        cls.addClassCleanup(lambda: keys.run(command=["gpgconf", "--homedir", str(cls.home), "--kill", "all"],
                                            env=cls.env))
        cls.passphrase = "disposable repository fixture"
        keys.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                          "--quick-generate-key", "Repository fixture <fixture@example.invalid>",
                          "rsa2048", "cert", "1d"], env=cls.env, input_text=cls.passphrase)
        cls.fingerprint = keys.primary_fingerprints(listing=keys.run(
            command=["gpg", "--batch", "--with-colons", "--list-secret-keys"], env=cls.env))[0]
        keys.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                          "--quick-add-key", cls.fingerprint, "rsa2048", "sign", "1d"],
                 env=cls.env, input_text=cls.passphrase)
        cls.secret = keys.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                                      "--armor", "--export-secret-subkeys", cls.fingerprint],
                              env=cls.env, input_text=cls.passphrase)
        cls.secrets = {keys.KEY_SECRET: cls.secret, keys.PASSPHRASE_SECRET: cls.passphrase}
        try:
            cls.releases = {number: cls.prepare_release(number=number) for number in (42, 43)}
        except subprocess.CalledProcessError as error:
            raise RuntimeError(
                f"Disposable package setup failed: {error.cmd}\n{error.stdout}\n{error.stderr}") from error

    @classmethod
    def prepare_release(cls, *, number: int) -> Path:
        prepared = cls.root / f"prepared-{number}"
        prepared.mkdir()
        artifacts = []
        for arch, (debian_arch, rpm_arch) in repository.ARCHITECTURES.items():
            work = cls.root / f"packages-{number}-{arch}"
            deb_root = work / "deb-root"
            (deb_root / "DEBIAN").mkdir(parents=True)
            (deb_root / "DEBIAN/control").write_text(
                f"Package: sesori-desktop\nVersion: 9.8.7-{number}\nArchitecture: {debian_arch}\n"
                "Maintainer: Fixture <fixture@example.invalid>\nDescription: Inert repository fixture\n")
            payload = deb_root / "opt/sesori-desktop/fixture.txt"
            payload.parent.mkdir(parents=True)
            payload.write_text(str(number))
            for kind in ("deb", "rpm"):
                (work / kind).mkdir()
            name = f"Sesori-linux-{arch}-9.8.7-{number}"
            keys.run(command=["dpkg-deb", "--root-owner-group", "--build", str(deb_root),
                              str(work / "deb" / f"{name}.deb")], env=cls.env)
            spec = work / "fixture.spec"
            spec.write_text(
                f"Name: sesori-desktop\nVersion: 9.8.7\nRelease: {number}\nSummary: Repository fixture\n"
                f"License: MIT\nBuildArch: {rpm_arch}\n%description\nInert repository fixture\n"
                "%install\nmkdir -p %{buildroot}/opt/sesori-desktop\n"
                f"printf '{number}' > %{{buildroot}}/opt/sesori-desktop/fixture.txt\n"
                "%files\n/opt/sesori-desktop\n")
            # These fixtures contain text only. Permit both header architectures
            # without pretending this is a cross-compiled/native application test.
            rpmrc = work / "rpmrc"
            rpmrc.write_text(f"buildarch_compat: {cls.rpm_arch}: {cls.rpm_arch} {rpm_arch}\n")
            keys.run(command=["rpmbuild", "--rcfile", f"/usr/lib/rpm/rpmrc:{rpmrc}", "-bb", "--target", rpm_arch,
                              "--define", f"_topdir {work / 'rpmbuild'}", str(spec)], env=cls.env)
            shutil.copyfile(next((work / "rpmbuild/RPMS").rglob("*.rpm")), work / "rpm" / f"{name}.rpm")
            identity = {"os": "linux", "architecture": arch, "version": "9.8.7",
                        "buildNumber": number, "sourceSha": "b" * 40}
            for kind in ("deb", "rpm"):
                package = work / kind / f"{name}.{kind}"
                (work / kind / "packaging.json").write_text(json.dumps({
                    "format": kind, "bundle": {"identity": identity},
                    "package": {"name": package.name, "sha256": keys.sha256(path=package),
                                "bytes": package.stat().st_size},
                }))
            signed = work / "signed"
            with mock.patch.dict(os.environ, cls.secrets):
                report = signing.sign_packages(root=work, output=signed, fingerprint=cls.fingerprint)
            for row in report["artifacts"]:
                shutil.copyfile(signed / row["name"], prepared / row["name"])
                artifacts.append({**row, "architecture": arch, "format": Path(row["name"]).suffix[1:]})
            for suffix in ("", ".asc"):
                shutil.copyfile(signed / (signing.CHECKSUMS + suffix),
                                prepared / f"desktop-linux-{arch}-checksums.txt{suffix}")
            shutil.copyfile(signed / signing.PUBLIC_KEY, prepared / repository.PUBLIC_DESKTOP_KEY)
        (prepared / repository.MANIFEST).write_text(json.dumps({
            "schemaVersion": 1, "platform": "linux", "channel": "internal", "version": "9.8.7",
            "buildNumber": number, "sourceSha": "b" * 40, "signerFingerprint": cls.fingerprint,
            "artifacts": artifacts,
        }))
        return prepared

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)

    def build(self, *, root: Path, output: Path, channel: repository.Channel = repository.Channel.INTERNAL) -> dict:
        with mock.patch.dict(os.environ, self.secrets):
            try:
                return repository.build(root=root, output=output, channel=channel, fingerprint=self.fingerprint)
            except subprocess.CalledProcessError as error:
                # Diagnostics are safe only for these disposable keys/inert packages.
                self.fail(f"Repository fixture command failed: {error.cmd}\n{error.stdout}\n{error.stderr}")

    def public_keyring(self, *, output: Path) -> Path:
        home = self.work / "public"
        home.mkdir(mode=0o700)
        keyring = home / "trusted.gpg"
        keys.run(command=["gpg", "--homedir", str(home), "--batch", "--dearmor", "--output", str(keyring),
                          str(output / keys.PUBLIC_KEY)], env=self.env)
        return keyring

    def test_signed_indexes_both_cpus_channels_and_immutable_package_bytes(self):
        for channel in repository.Channel:
            with self.subTest(channel=channel):
                root = self.work / f"input-{channel}"
                shutil.copytree(self.releases[42], root)
                manifest = root / repository.MANIFEST
                metadata = json.loads(manifest.read_text())
                metadata["channel"] = channel.value
                manifest.write_text(json.dumps(metadata))
                output = self.work / channel.value
                report = self.build(root=root, output=output, channel=channel)
                self.assertEqual(report["channel"], channel.value)
                self.assertEqual(report["signerFingerprint"], self.fingerprint)
                self.assertEqual({row["name"] for row in report["files"]},
                                 {p.relative_to(output).as_posix() for p in output.rglob("*")
                                  if p.is_file() and p.name != repository.REPORT})
                for row in report["files"]:
                    self.assertEqual(keys.sha256(path=output / row["name"]), row["sha256"])
                # A separate public home verifies every repository signature.
                keyring = self.public_keyring(output=output)
                verify = ["gpgv", "--homedir", str(keyring.parent), "--keyring", str(keyring)]
                release = output / "apt/dists" / channel.value / "Release"
                keys.run(command=[*verify, str(release.with_name("InRelease"))], env=self.env)
                keys.run(command=[*verify, str(release.with_name("Release.gpg")), str(release)], env=self.env)
                self.assertIn("Acquire-By-Hash: yes", release.read_text())
                self.assertNotIn("SHA512:", release.read_text())
                for arch, (debian_arch, rpm_arch) in repository.ARCHITECTURES.items():
                    index = release.parent / "main" / f"binary-{debian_arch}" / "Packages"
                    self.assertIn(f"Architecture: {debian_arch}", index.read_text())
                    self.assertEqual(gzip.decompress(index.with_name("Packages.gz").read_bytes()), index.read_bytes())
                    for path in (index, index.with_name("Packages.gz")):
                        self.assertEqual((index.parent / "by-hash/SHA256" / keys.sha256(path=path)).read_bytes(),
                                         path.read_bytes())
                    rpm = output / "rpm" / channel.value / rpm_arch
                    repomd = rpm / "repodata/repomd.xml"
                    keys.run(command=[*verify, str(repomd) + ".asc", str(repomd)], env=self.env)
                    for data in ET.parse(repomd).getroot().findall("{*}data"):
                        location = data.find("{*}location").attrib["href"]
                        self.assertEqual(keys.sha256(path=rpm / location), data.find("{*}checksum").text)
                    for kind, directory in (("deb", output / "apt/pool" / channel.value / debian_arch),
                                            ("rpm", rpm / "Packages")):
                        name = f"Sesori-linux-{arch}-9.8.7-42.{kind}"
                        self.assertEqual((directory / name).read_bytes(), (root / name).read_bytes())
                shutil.rmtree(keyring.parent)

    def test_apt_rejects_expired_but_authentic_metadata(self):
        output = self.work / "expired"
        issued_at = datetime.now(UTC) - timedelta(days=31)
        with mock.patch.object(repository, "datetime") as clock:
            clock.now.return_value = issued_at
            self.build(root=self.releases[42], output=output)
        release = output / "apt/dists/internal/Release"
        fields = dict(line.split(": ", 1) for line in release.read_text().splitlines() if ": " in line)
        issued = parsedate_to_datetime(fields["Date"])
        expires = parsedate_to_datetime(fields["Valid-Until"])
        self.assertEqual(issued, issued_at.replace(microsecond=0))
        self.assertEqual(expires - issued, timedelta(days=30))
        with self.assertRaisesRegex(ValueError, "expired"):
            hosting.verify(root=output, fingerprint=self.fingerprint)
        keyring = self.public_keyring(output=output)
        keys.run(command=["gpgv", "--homedir", str(keyring.parent), "--keyring", str(keyring),
                          str(release.with_name("InRelease"))], env=self.env)
        apt = self.apt(client=self.work / "expired-client", output=output)
        with self.assertRaises(subprocess.CalledProcessError) as caught:
            keys.run(command=[*apt, "update"], env=self.env)
        self.assertIn("expired", caught.exception.stderr.lower())
        # Refresh metadata from the same accepted packages; do not bypass expiry.
        refreshed = self.work / "refreshed"
        self.build(root=self.releases[42], output=refreshed)
        shutil.copytree(refreshed, output, dirs_exist_ok=True)
        keys.run(command=[*apt, "update"], env=self.env)

    def test_publication_authenticates_references_not_just_producer_inventory(self):
        original = self.work / "original"
        self.build(root=self.releases[42], output=original)
        hosting.verify(root=original, fingerprint=self.fingerprint)
        targets = ["apt/dists/internal/main/binary-amd64/Packages",
                   next(original.glob("apt/pool/internal/amd64/*.deb")).relative_to(original).as_posix(),
                   next(original.glob("rpm/internal/x86_64/repodata/*primary*")).relative_to(original).as_posix(),
                   "rpm/internal/x86_64/repodata/repomd.xml.asc"]
        for index, target in enumerate(targets):
            with self.subTest(target=target):
                output = self.work / f"tampered-{index}"
                shutil.copytree(original, output)
                path = output / target
                path.write_bytes(b"invalid signature" if target.endswith(".asc") else path.read_bytes() + b"changed")
                report = json.loads((output / repository.REPORT).read_text())
                for row in report["files"]:
                    if row["name"] == target:
                        row.update(sha256=keys.sha256(path=path), bytes=path.stat().st_size)
                (output / repository.REPORT).write_text(json.dumps(report))
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    hosting.verify(root=output, fingerprint=self.fingerprint)
        report = json.loads((original / repository.REPORT).read_text())
        report["signerFingerprint"] = "0" * 40
        (original / repository.REPORT).write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "Unexpected repository signer"):
            hosting.verify(root=original, fingerprint="0" * 40)
        report["signerFingerprint"] = self.fingerprint
        extra = original / "unrelated-private-file"
        extra.write_text("must never be published")
        report["files"].append({"name": extra.name, "sha256": keys.sha256(path=extra), "bytes": extra.stat().st_size})
        (original / repository.REPORT).write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "unauthenticated"):
            hosting.verify(root=original, fingerprint=self.fingerprint)

    def test_mixed_channel_missing_cpu_wrong_signer_and_tampering_refuse_completion(self):
        for failure in ("channel", "missing", "signer", "package", "checksums", "signature"):
            with self.subTest(failure=failure):
                root = self.work / failure
                shutil.copytree(self.releases[42], root)
                path = root / repository.MANIFEST
                metadata = json.loads(path.read_text())
                if failure == "channel":
                    metadata["channel"] = "stable"
                elif failure == "missing":
                    metadata["artifacts"].pop()
                elif failure == "signer":
                    metadata["signerFingerprint"] = "A" * 40
                elif failure == "package":
                    (root / metadata["artifacts"][0]["name"]).write_bytes(b"tampered")
                else:
                    target = root / ("desktop-linux-x64-checksums.txt" + (".asc" if failure == "signature" else ""))
                    target.write_text("tampered\n")
                path.write_text(json.dumps(metadata))
                output = self.work / f"failed-{failure}"
                with mock.patch.dict(os.environ, self.secrets), self.assertRaises(ValueError):
                    repository.build(root=root, output=output, channel=repository.Channel.INTERNAL,
                                     fingerprint=self.fingerprint)
                self.assertFalse((output / repository.REPORT).exists())

    def apt(self, *, client: Path, output: Path) -> list[str]:
        for path in ("var/lib/apt/lists/partial", "var/cache/apt/archives/partial", "var/lib/dpkg",
                     "var/log/apt", "etc/apt/preferences.d"):
            (client / path).mkdir(parents=True, exist_ok=True)
        (client / "var/lib/dpkg/status").touch()
        sources = client / "etc/apt/sources.list"
        sources.write_text(f"deb [arch={self.debian_arch} signed-by={output / keys.PUBLIC_KEY}] "
                           f"file:{output / 'apt'} internal main\n")
        return ["apt-get", "-o", f"Dir={client}", "-o", f"APT::Architecture={self.debian_arch}",
                "-o", "Dir::Etc::sourceparts=-", "-o", "APT::Sandbox::User=root",
                "-o", f"DPkg::Options::=--root={client}", "-o", f"DPkg::Options::=--log={client / 'dpkg.log'}",
                "-o", "APT::Get::Assume-Yes=true", "-o", "APT::Update::Error-Mode=any"]

    def dnf(self, *, client: Path, output: Path) -> list[str]:
        configuration = client / "etc/yum.repos.d/sesori.repo"
        configuration.parent.mkdir(parents=True)
        # Every test refresh observes current fixture bytes, without waiting for a
        # production cache TTL or relying on --refresh for a local-file repository.
        configuration.write_text(
            f"[sesori]\nname=Sesori fixture\nbaseurl=file://{output / 'rpm/internal' / self.rpm_arch}\n"
            f"enabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=file://{output / keys.PUBLIC_KEY}\n"
            "skip_if_unavailable=0\nmetadata_expire=0\n")
        return ["dnf", "--installroot", str(client), "--releasever=44", "--assumeyes"]

    def test_clients_refuse_untrusted_key_and_changed_packages(self):
        output = self.work / "repository"
        self.build(root=self.releases[42], output=output)
        public_key = output / keys.PUBLIC_KEY
        original_key = public_key.read_bytes()
        keys.run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0",
                          "--quick-generate-key", "Untrusted fixture <untrusted@example.invalid>",
                          "rsa2048", "sign", "1d"], env=self.env, input_text=self.passphrase)
        public_key.write_text(keys.run(command=["gpg", "--batch", "--armor", "--export",
                                               "untrusted@example.invalid"], env=self.env))
        for arguments in ([*self.apt(client=self.work / "wrong-apt", output=output), "update"],
                          [*self.dnf(client=self.work / "wrong-rpm", output=output), "makecache"]):
            with self.assertRaises(subprocess.CalledProcessError) as caught:
                keys.run(command=arguments, env=self.env)
            self.assertRegex(caught.exception.stdout + caught.exception.stderr, r"(?i)signature|signed|gpg|key")
        public_key.write_bytes(original_key)
        apt = self.apt(client=self.work / "damaged-apt", output=output)
        keys.run(command=[*apt, "update"], env=self.env)
        for directory in (output / "apt/pool/internal" / self.debian_arch,
                          output / "rpm/internal" / self.rpm_arch / "Packages"):
            package = next(directory.iterdir())
            package.write_bytes(package.read_bytes() + b"changed package bytes")
        for arguments in ([*apt, "install", "sesori-desktop"],
                          [*self.dnf(client=self.work / "damaged-rpm", output=output), "install", "sesori-desktop"]):
            with self.assertRaises(subprocess.CalledProcessError) as caught:
                keys.run(command=arguments, env=self.env)
            self.assertRegex(caught.exception.stdout + caught.exception.stderr,
                             r"(?i)hash|size|checksum|digest|signature")
        for client in (self.work / "damaged-apt", self.work / "damaged-rpm"):
            self.assertFalse((client / "opt/sesori-desktop/fixture.txt").exists())

    def test_real_package_managers_install_upgrade_remove_and_reject_tampered_metadata(self):
        output = self.work / "repository"
        self.build(root=self.releases[42], output=output)
        apt = self.apt(client=self.work / "apt-client", output=output)
        dnf = self.dnf(client=self.work / "rpm-client", output=output)
        for client in (self.work / "apt-client", self.work / "rpm-client"):
            (client / "shared-state").write_text("untouched fixture state")
        try:
            keys.run(command=[*apt, "update"], env=self.env)
            keys.run(command=[*apt, "install", "sesori-desktop"], env=self.env)
            keys.run(command=[*dnf, "install", "sesori-desktop"], env=self.env)
            for client in (self.work / "apt-client", self.work / "rpm-client"):
                self.assertEqual((client / "opt/sesori-desktop/fixture.txt").read_text(), "42")
            successor = self.work / "successor"
            self.build(root=self.releases[43], output=successor)
            # Mirror a publishing update without pruning old packages or content hashes.
            shutil.copytree(successor, output, dirs_exist_ok=True)
            keys.run(command=[*apt, "update"], env=self.env)
            apt_upgrade = keys.run(command=[*apt, "install", "--only-upgrade", "sesori-desktop"], env=self.env)
            rpm_upgrade = keys.run(command=[*dnf, "--refresh", "upgrade", "sesori-desktop"], env=self.env)
            upgrades = ((self.work / "apt-client", apt_upgrade), (self.work / "rpm-client", rpm_upgrade))
            for client, diagnostics in upgrades:
                actual = (client / "opt/sesori-desktop/fixture.txt").read_text()
                self.assertEqual(actual, "43", f"{client.name}: {diagnostics}")
                self.assertEqual((client / "shared-state").read_text(), "untouched fixture state")
            keys.run(command=[*apt, "remove", "sesori-desktop"], env=self.env)
            keys.run(command=[*dnf, "remove", "sesori-desktop"], env=self.env)
            for client in (self.work / "apt-client", self.work / "rpm-client"):
                self.assertFalse((client / "opt/sesori-desktop/fixture.txt").exists())
                self.assertEqual((client / "shared-state").read_text(), "untouched fixture state")
        except subprocess.CalledProcessError as error:
            self.fail(f"Disposable repository client failed: {error.cmd}\n{error.stdout}\n{error.stderr}")
        (output / "apt/dists/internal/InRelease").write_text("tampered repository metadata")
        (output / "rpm/internal" / self.rpm_arch / "repodata/repomd.xml.asc").write_text("tampered signature")
        for arguments in ([*self.apt(client=self.work / "bad-apt", output=output), "update"],
                          [*self.dnf(client=self.work / "bad-rpm", output=output), "makecache"]):
            with self.assertRaises(subprocess.CalledProcessError) as caught:
                keys.run(command=arguments, env=self.env)
            self.assertRegex(caught.exception.stdout + caught.exception.stderr, r"(?i)signature|signed|gpg|clearsigned")


if __name__ == "__main__":
    unittest.main()
