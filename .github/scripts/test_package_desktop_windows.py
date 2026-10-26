import io
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

import package_desktop_linux as packaging_linux
import package_desktop_windows as packaging


def pe(*, machine: int) -> bytes:
    header = bytearray(70)
    header[:2] = b"MZ"
    struct.pack_into("<I", header, 60, 64)
    header[64:68] = b"PE\0\0"
    struct.pack_into("<H", header, 68, machine)
    return bytes(header)


class WindowsPackagingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="windows packaging ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bundle = self.root / "staged bundle"
        self.version = "1.8.4"
        for path in (self.bundle / "sesori_desktop.exe", self.bundle / "bridge/bin/bridge.exe",
                     self.bundle / "bridge/lib/sqlite3.dll"):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(pe(machine=0x8664))
        (self.bundle / "bridge/desktop-bundle.json").write_text(json.dumps({
            "version": self.version,
            "buildNumber": 42,
            "sourceSha": "test-source",
            "os": "windows",
            "architecture": "x64",
        }), encoding="utf-8")
        (self.root / "dart-defines.env").write_text("SESORI_DESKTOP_RELEASE_CHANNEL=internal\n", encoding="utf-8")

    def package(self, *, output: Path, packed_bundle: Path | None = None, nupkg: bytes = b"vpk package",
                setup_machine: int = 0x8664, embed_package: bool = True):
        """Run package() with a fake vpk whose Setup embeds a full package of `packed_bundle`, or of the
        directory it was asked to pack."""
        commands = []

        def fake_run(*, command, cwd=packaging.ROOT, merge_stderr=True):
            commands.append(command)
            if command[:3] == ["git", "rev-parse", "HEAD"]:
                return "packager-source\n"
            if command[:3] == ["dotnet", "tool", "install"]:
                tools = Path(command[command.index("--tool-path") + 1])
                tools.mkdir()
                (tools / "vpk").write_text("#!/bin/sh\n")
                (tools / "vpk").chmod(0o755)
                return "Tool 'vpk' (version '1.2.161') was successfully installed.\n"
            options = dict(zip(command[2:-1:2], command[3:-1:2]))
            releases = Path(options["--outputDir"])
            releases.mkdir()
            channel, version = options["--channel"], options["--packVersion"]
            full = releases / f"sesori-desktop-{version}-{channel}-full.nupkg"
            with zipfile.ZipFile(full, "w") as archive:
                source = packed_bundle or Path(options["--packDir"])
                for path in sorted(source.rglob("*")):
                    if path.is_file():
                        archive.write(path, f"lib/app/{path.relative_to(source).as_posix()}")
                for name in ("Squirrel.exe", "Sesori_ExecutionStub.exe"):
                    archive.writestr(f"lib/app/{name}", pe(machine=0x8664))
                archive.writestr("lib/app/sq.version", "<package/>")
            setup = pe(machine=setup_machine) + (full.read_bytes() if embed_package else b"")
            (releases / f"sesori-desktop-{channel}-Setup.exe").write_bytes(setup)
            (releases / f"releases.{channel}.json").write_text("{}")
            (releases / f"assets.{channel}.json").write_text("[]")
            return "Setup bundle created\n"

        libraries = io.BytesIO()
        with zipfile.ZipFile(libraries, "w") as archive:
            archive.writestr("lib/velopack_libc_win_x64_msvc.dll", pe(machine=0x8664))
        downloads = {packaging.VPK_PACKAGE_URL: nupkg, packaging_linux.VELOPACK_LIBRARY_URL: libraries.getvalue()}

        def fake_urlopen(url, timeout):
            response = mock.MagicMock()
            response.__enter__.return_value = io.BytesIO(downloads[url])
            return response

        with mock.patch.object(packaging, "VPK_PACKAGE_SHA256", packaging.hashlib.sha256(b"vpk package").hexdigest()), \
                mock.patch.object(packaging, "VELOPACK_LIBRARY_SHA256",
                                  packaging.hashlib.sha256(libraries.getvalue()).hexdigest()), \
                mock.patch.object(packaging_linux, "VELOPACK_LIBRARY_SHA256",
                                  packaging.hashlib.sha256(libraries.getvalue()).hexdigest()), \
                mock.patch.object(packaging.urllib.request, "urlopen", side_effect=fake_urlopen), \
                mock.patch.object(packaging, "run", side_effect=fake_run):
            installer = packaging.package(bundle=self.bundle, output=output, arch="x64", version=self.version)
        return installer, commands

    def test_verifies_identity_and_complete_native_inventory(self):
        evidence = packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
        self.assertEqual(evidence["identity"]["buildNumber"], 42)
        self.assertEqual({row["path"] for row in evidence["binaries"]}, {
            "sesori_desktop.exe", "bridge/bin/bridge.exe", "bridge/lib/sqlite3.dll",
        })

    def test_installed_current_directory_verifies_with_velopack_manifest(self):
        (self.bundle / "sq.version").write_text("<package/>")
        evidence = packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
        self.assertNotIn("sq.version", {row["path"] for row in evidence["binaries"]})
        (self.bundle / "Squirrel.exe").write_bytes(pe(machine=0xAA64))
        with self.assertRaisesRegex(ValueError, "Wrong native target"):
            packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)

    def test_wrong_architecture_refuses_before_vpk(self):
        with mock.patch.object(packaging, "run") as command:
            with self.assertRaisesRegex(ValueError, "Bundle identity mismatch|Wrong native target"):
                packaging.package(bundle=self.bundle, output=self.root / "out", arch="arm64", version=self.version)
        command.assert_not_called()

    def test_missing_helper_manifest_or_library_refuses(self):
        cases = (self.bundle / "bridge/desktop-bundle.json", self.bundle / "bridge/bin/bridge.exe",
                 self.bundle / "bridge/lib")
        for missing in cases:
            with self.subTest(missing=missing):
                moved = missing.with_name(missing.name + ".missing")
                missing.rename(moved)
                with self.assertRaisesRegex(ValueError, "Required staged entry missing"):
                    packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
                moved.rename(missing)

    def test_library_must_be_directory_and_executable_must_be_file(self):
        for path in (self.bundle / "bridge/lib", self.bundle / "sesori_desktop.exe"):
            with self.subTest(path=path):
                moved = path.with_name(path.name + ".saved")
                path.rename(moved)
                if moved.is_dir():
                    path.write_text("not a directory")
                else:
                    path.mkdir()
                with self.assertRaisesRegex(ValueError, "wrong type"):
                    packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
                if path.is_dir():
                    path.rmdir()
                else:
                    path.unlink()
                moved.rename(path)

    def test_setup_is_packed_by_pinned_vpk_from_the_exact_bundle(self):
        output = self.root / "installer output"
        installer, commands = self.package(output=output)
        install, pack = commands[0], commands[1]
        # Only the verified local package can be installed.
        self.assertEqual(install[:6], ["dotnet", "tool", "install", "vpk", "--version", "1.2.161"])
        feed = Path(install[install.index("--source") + 1])
        self.assertEqual(feed.name, "vpk-feed")
        options = dict(zip(pack[2:-1:2], pack[3:-1:2]))
        self.assertEqual([pack[1], pack[-1]], ["pack", "--noPortable"])
        self.assertEqual({key: value for key, value in options.items() if key != "--outputDir"}, {
            "--packId": "sesori-desktop", "--packVersion": f"{self.version}-internal.42",
            "--packDir": str(feed.parent / "pack"), "--mainExe": "sesori_desktop.exe", "--packTitle": "Sesori",
            "--packAuthors": "Sesori", "--icon": str(packaging.ICON_SOURCE), "--runtime": "win-x64",
            "--channel": "internal", "--shortcuts": "StartMenu",
        })
        self.assertTrue(packaging.ICON_SOURCE.is_file())
        self.assertEqual(installer, output.resolve() / f"Sesori-windows-x64-{self.version}.exe")
        velopack = output / "velopack"
        self.assertEqual(sorted(path.name for path in velopack.iterdir()),
                         ["releases.internal.json", f"sesori-desktop-{self.version}-internal.42-internal-full.nupkg"])
        report = json.loads((output / "packaging.json").read_text(encoding="utf-8"))
        self.assertEqual(report["velopack"]["vpkVersion"], "1.2.161")
        # The app loads the pinned Velopack library from beside its executable; the staged bundle stays unchanged.
        with zipfile.ZipFile(velopack / f"sesori-desktop-{self.version}-internal.42-internal-full.nupkg") as archive:
            self.assertEqual(archive.read("lib/app/velopack_libc.dll"), pe(machine=0x8664))
        self.assertFalse((self.bundle / "velopack_libc.dll").exists())
        self.assertEqual([row["name"] for row in report["velopack"]["releaseFiles"]],
                         sorted(path.name for path in velopack.iterdir()))
        self.assertEqual(len(report["installer"]["sha256"]), 64)
        self.assertIn("Unsigned installer", report["proofBoundary"])

    def test_velopack_versions_increase_within_each_channel(self):
        identity = {"version": self.version, "buildNumber": 42}
        self.assertEqual(packaging.velopack_version(identity=identity, channel="stable"), self.version)
        self.assertEqual(packaging.velopack_version(identity=identity, channel="internal"), f"{self.version}-internal.42")

    def test_vpk_package_digest_mismatch_refuses(self):
        with self.assertRaisesRegex(ValueError, "vpk package digest mismatch"):
            self.package(output=self.root / "out", nupkg=b"tampered")

    def test_package_without_the_exact_bundle_refuses(self):
        changed = self.root / "changed bundle"
        packaging.shutil.copytree(self.bundle, changed)
        (changed / "bridge/lib/sqlite3.dll").write_bytes(pe(machine=0x8664) + b"changed")
        with self.assertRaisesRegex(ValueError, "exact staged bundle"):
            self.package(output=self.root / "out", packed_bundle=changed)

    def test_setup_for_another_cpu_or_without_the_package_refuses(self):
        with self.assertRaisesRegex(ValueError, "Wrong native target"):
            self.package(output=self.root / "arm64 setup", setup_machine=0xAA64)
        with self.assertRaisesRegex(ValueError, "does not embed the full release package"):
            self.package(output=self.root / "empty setup", embed_package=False)

    def test_existing_output_is_never_replaced(self):
        output = self.root / "existing"
        output.mkdir()
        sentinel = output / "keep.log"
        sentinel.write_text("failed diagnostics", encoding="utf-8")
        with mock.patch.object(packaging, "run") as command, self.assertRaises(FileExistsError):
            packaging.package(bundle=self.bundle, output=output, arch="x64", version=self.version)
        command.assert_not_called()
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "failed diagnostics")

    def test_runner_answers_velopack_hooks_before_flutter_and_uninstall_clears_login(self):
        source = (packaging.ROOT / "client/desktop/windows/runner/main.cpp").read_text(encoding="utf-8")
        self.assertIn('"--veloapp-"', source)
        self.assertLess(source.index("IsVelopackHook(command_line_arguments)"),
                        source.index("flutter::DartProject project"))
        self.assertIn('L"Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run", L"Sesori"', source)
        self.assertNotIn("CreateMutexW", source)
        login = (packaging.ROOT / "client/desktop/lib/core/platform/io_launch_at_login.dart").read_text(encoding="utf-8")
        self.assertIn('_appName = "Sesori"', login)
        self.assertIn('_windowsRunSubKey = r"Software\\Microsoft\\Windows\\CurrentVersion\\Run"', login)

    def test_fixture_installs_with_velopack_and_checks_payload_and_uninstall(self):
        workflow = (packaging.ROOT / ".github/workflows/desktop-qualification.yml").read_text()
        self.assertIn("if ($LASTEXITCODE -ne 0) { throw 'Installed payload verification failed' }", workflow)
        self.assertIn('Get-FileHash $installedPath -Algorithm SHA256', workflow)
        self.assertIn("'--installto'", workflow)
        self.assertIn("@('uninstall', '--silent')", workflow)
        self.assertIn('foreach ($payload in $recordedPayload)', workflow)
        self.assertNotIn("Inno", workflow)


if __name__ == "__main__":
    unittest.main()
