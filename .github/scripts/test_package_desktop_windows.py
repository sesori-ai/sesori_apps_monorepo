import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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

    def test_verifies_identity_and_complete_native_inventory(self):
        evidence = packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
        self.assertEqual(evidence["identity"]["buildNumber"], 42)
        self.assertEqual({row["path"] for row in evidence["binaries"]}, {
            "sesori_desktop.exe", "bridge/bin/bridge.exe", "bridge/lib/sqlite3.dll",
        })

    def test_installed_verification_allows_only_inno_emulation_launcher(self):
        uninstaller = self.bundle / "unins000.exe"
        uninstaller.write_bytes(pe(machine=0xAA64))
        with self.assertRaisesRegex(ValueError, "Wrong native target"):
            packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version)
        evidence = packaging.verify_bundle(bundle=self.bundle, arch="x64", version=self.version, installed=True)
        self.assertNotIn("unins000.exe", {row["path"] for row in evidence["binaries"]})

    def test_wrong_architecture_refuses_before_compiler(self):
        with mock.patch.object(packaging, "run") as command:
            with self.assertRaisesRegex(ValueError, "Bundle identity mismatch|Wrong native target"):
                packaging.package(bundle=self.bundle, output=self.root / "out", arch="arm64",
                                  version=self.version, iscc=self.root / "ISCC.exe")
        command.assert_not_called()

    def test_missing_helper_manifest_or_library_refuses(self):
        cases = (self.bundle / "bridge/desktop-bundle.json", self.bundle / "bridge/bin/bridge.exe",
                 self.bundle / "bridge/lib")
        for index, missing in enumerate(cases):
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

    def test_package_passes_absolute_inputs_and_records_unsigned_hash(self):
        output = self.root / "installer output"

        def fake_run(*, command, cwd=packaging.ROOT, merge_stderr=True):
            if command[:3] == ["git", "rev-parse", "HEAD"]:
                return "packager-source\n"
            (output / f"Sesori-windows-x64-{self.version}.exe").write_bytes(b"unsigned installer")
            return "Inno Setup 7 Command-Line Compiler\nCompiler engine version: Inno Setup 7.1.0\n"

        with mock.patch.object(packaging, "run", side_effect=fake_run) as commands:
            installer = packaging.package(bundle=self.bundle, output=output, arch="x64",
                                          version=self.version, iscc=self.root / "ISCC.exe")
        compile_command = commands.call_args_list[0].kwargs["command"]
        self.assertIn(f"/DBundleDir={self.bundle.resolve()}", compile_command)
        self.assertIn(f"/DOutputDir={output.resolve()}", compile_command)
        self.assertEqual(installer.name, f"Sesori-windows-x64-{self.version}.exe")
        report = json.loads((output / "packaging.json").read_text(encoding="utf-8"))
        self.assertEqual(report["innoSetupVersion"], "7.1.0")
        self.assertEqual(len(report["installer"]["sha256"]), 64)
        self.assertIn("Unsigned installer", report["proofBoundary"])

    def test_existing_output_is_never_replaced(self):
        output = self.root / "existing"
        output.mkdir()
        sentinel = output / "keep.log"
        sentinel.write_text("failed diagnostics", encoding="utf-8")
        with mock.patch.object(packaging, "run") as command, self.assertRaises(FileExistsError):
            packaging.package(bundle=self.bundle, output=output, arch="x64", version=self.version,
                              iscc=self.root / "ISCC.exe")
        command.assert_not_called()
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "failed diagnostics")

    def test_runner_marker_precedes_flutter_and_is_not_single_instance_gate(self):
        source = (packaging.ROOT / "client/desktop/windows/runner/main.cpp").read_text(encoding="utf-8")
        marker = 'CreateMutexW(nullptr, FALSE, running_mutex_name.c_str())'
        self.assertIn('L"Global\\\\com.sesori.desktop.running."', source)
        for api in ("OpenProcessToken", "GetTokenInformation", "ConvertSidToStringSidW"):
            self.assertIn(api, source)
        self.assertIn(marker, source)
        self.assertLess(source.index(marker), source.index('flutter::DartProject project'))
        self.assertNotIn("ERROR_ALREADY_EXISTS", source)
        self.assertNotIn("CloseHandle(g_running_mutex", source)

    def test_installer_contract_is_bounded_and_mutex_protected(self):
        script = packaging.INSTALLER_SOURCE.read_text(encoding="utf-8")
        for directive in ("AppId={#AppId}", "DefaultDirName={localappdata}\\Programs\\Sesori",
                          "PrivilegesRequired=lowest", "SetupArchitecture=x64", "AppMutex={code:RunningMutexName}",
                          "CloseApplications=no", "RestartApplications=no"):
            self.assertIn(directive, script)
        self.assertIn('RegDeleteValue(HKCU, \'Software\\Microsoft\\Windows\\CurrentVersion\\Run\', \'Sesori\')', script)
        self.assertIn('#define RunningMutexPrefix "Global\\com.sesori.desktop.running."', script)
        for api in ("OpenProcessToken", "GetTokenInformation", "ConvertSidToStringSidW"):
            self.assertIn(api, script)
        for architecture, allowed in (("x64", "x64os"), ("arm64", "arm64")):
            self.assertIn(f'#if Architecture == "{architecture}"' if architecture == "x64"
                          else f'#elif Architecture == "{architecture}"', script)
            self.assertIn(f'#define AllowedArchitecture "{allowed}"', script)
        self.assertNotIn("x64compatible", script)
        workflow = (packaging.ROOT / ".github/workflows/desktop-qualification.yml").read_text()
        self.assertIn("if ($LASTEXITCODE -ne 0) { throw 'Installed payload verification failed' }", workflow)
        self.assertIn('[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value', workflow)
        self.assertIn('Get-FileHash $installedPath -Algorithm SHA256', workflow)
        self.assertIn("'^unins[0-9]{3}\\.(dat|exe|msg)$'", workflow)
        self.assertIn('foreach ($payload in $recordedPayload)', workflow)
        self.assertNotIn("[Run]", script)
        self.assertNotIn("[Registry]", script)
        self.assertNotIn("[UninstallDelete]", script)


if __name__ == "__main__":
    unittest.main()
