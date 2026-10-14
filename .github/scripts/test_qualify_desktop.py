import json
import struct
import tempfile
import unittest
from io import BytesIO, StringIO
from pathlib import Path
from unittest.mock import patch

import qualify_desktop as qualification


def elf(*, machine: int) -> bytes:
    header = bytearray(64)
    header[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<H", header, 18, machine)
    return bytes(header)


def pe(*, machine: int) -> bytes:
    header = bytearray(70)
    header[:2] = b"MZ"
    struct.pack_into("<I", header, 60, 64)
    header[64:68] = b"PE\0\0"
    struct.pack_into("<H", header, 68, machine)
    return bytes(header)


def macho(*, machine: int) -> bytes:
    return b"\xcf\xfa\xed\xfe" + struct.pack("<I", machine) + bytes(56)


def universal_macho() -> bytes:
    return (b"\xca\xfe\xba\xbe" + struct.pack(">I", 2)
            + struct.pack(">IIIII", 0x01000007, 0, 0, 0, 0)
            + struct.pack(">IIIII", 0x0100000C, 0, 0, 0, 0))


class NativeInventoryTest(unittest.TestCase):
    def test_reads_all_six_native_targets(self) -> None:
        cases = [(elf(machine=62), "ELF", "x64"), (elf(machine=183), "ELF", "arm64"),
                 (pe(machine=0x8664), "PE", "x64"), (pe(machine=0xAA64), "PE", "arm64"),
                 (macho(machine=0x01000007), "Mach-O", "x64"),
                 (macho(machine=0x0100000C), "Mach-O", "arm64")]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "binary"
            for data, binary_format, arch in cases:
                with self.subTest(binary_format=binary_format, arch=arch):
                    path.write_bytes(data)
                    self.assertEqual(qualification.native_arch(path=path), (binary_format, [arch]))

    def test_universal_macos_is_reported_honestly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "App"
            path.write_bytes(universal_macho())
            self.assertEqual(qualification.native_arch(path=path), ("Mach-O", ["arm64", "x64"]))

    def test_compiled_macos_targets_are_thin_but_prebuilt_frameworks_may_be_universal(self) -> None:
        compiled = ("Contents/MacOS/Sesori", "Contents/Frameworks/App.framework/App")
        for arch, machine in (("x64", 0x01000007), ("arm64", 0x0100000C)):
            with self.subTest(arch=arch), tempfile.TemporaryDirectory() as directory:
                gui = Path(directory)
                for relative in compiled:
                    binary = gui / relative
                    binary.parent.mkdir(parents=True, exist_ok=True)
                    binary.write_bytes(macho(machine=machine))
                engine = gui / "Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS"
                engine.parent.mkdir(parents=True)
                engine.write_bytes(universal_macho())
                qualification.require_macos_build_architecture(gui=gui, arch=arch)
                self.assertEqual(len(qualification.inventory(root=gui, target_os="macos", arch=arch)), 3)
                for relative in compiled:
                    binary = gui / relative
                    binary.write_bytes(universal_macho())
                    with self.assertRaisesRegex(ValueError, f"Expected single-architecture macos/{arch}"):
                        qualification.require_macos_build_architecture(gui=gui, arch=arch)
                    binary.write_bytes(macho(machine=machine))

    def test_rejects_x64_library_in_arm64_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "app.exe").write_bytes(pe(machine=0xAA64))
            (root / "plugin.dll").write_bytes(pe(machine=0x8664))
            with self.assertRaisesRegex(ValueError, "Wrong native target.*plugin.dll"):
                qualification.inventory(root=root, target_os="windows", arch="arm64")

    def test_rejects_mislabeled_or_wrong_format_binaries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "plugin.dll"
            path.write_bytes(b"not an executable")
            with self.assertRaisesRegex(ValueError, "Unrecognized native"):
                qualification.inventory(root=root, target_os="windows", arch="x64")
            path.write_bytes(elf(machine=62))
            with self.assertRaisesRegex(ValueError, "Wrong native target"):
                qualification.inventory(root=root, target_os="windows", arch="x64")

    def test_windows_dart_aot_is_elf_but_still_requires_native_cpu(self) -> None:
        for arch, machine in (("x64", 62), ("arm64", 183)):
            with self.subTest(arch=arch), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "data").mkdir()
                snapshot = root / "data/app.so"
                snapshot.write_bytes(elf(machine=machine))
                report = qualification.inventory(root=root, target_os="windows", arch=arch)
                self.assertEqual(report[0]["format"], "ELF")
                self.assertEqual(report[0]["architectures"], [arch])
                snapshot.write_bytes(elf(machine=183 if arch == "x64" else 62))
                with self.assertRaisesRegex(ValueError, "Wrong native target"):
                    qualification.inventory(root=root, target_os="windows", arch=arch)

    def test_hashes_binaries_and_ignores_resources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "app").write_bytes(elf(machine=183))
            (root / "config.json").write_text("{}")
            report = qualification.inventory(root=root, target_os="linux", arch="arm64")
            self.assertEqual(len(report), 1)
            self.assertEqual(report[0]["path"], "app")
            self.assertEqual(len(report[0]["sha256"]), 64)

    def test_missing_archived_sdk_can_resolve_official_source(self) -> None:
        manifest = {"releases": [{"version": "3.47.4", "channel": "stable", "hash": "same-revision",
                                  "dart_sdk_arch": "x64"}]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".tool-versions").write_text("flutter 3.47.4-stable\n")
            with patch.object(qualification, "ROOT", root), patch.object(
                qualification.urllib.request, "urlopen", return_value=BytesIO(json.dumps(manifest).encode())
            ):
                self.assertEqual(qualification.resolve_flutter(target_os="linux")["revision"], "same-revision")

    def test_failed_command_keeps_captured_diagnostics(self) -> None:
        error = qualification.subprocess.CalledProcessError(1, ["compiler"], output="missing native SDK")
        with patch.object(qualification.subprocess, "check_output", side_effect=error), patch.object(
            qualification.sys, "stderr", new_callable=StringIO
        ) as diagnostics:
            with self.assertRaises(qualification.subprocess.CalledProcessError) as raised:
                qualification.run(command=["compiler"])
            self.assertIs(raised.exception, error)
            self.assertIn("missing native SDK", diagnostics.getvalue())

    def test_inspection_writes_utf8_diagnostics_with_windows_default_encoding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "evidence"
            output.mkdir()
            gui = root / "staged/bundle"
            helper = gui / "bridge"
            gui.mkdir(parents=True)
            (helper / "bin").mkdir(parents=True)
            (helper / "lib").mkdir()
            for binary in (gui / "sesori_desktop.exe", helper / "bin/bridge.exe", helper / "lib/sqlite3.dll"):
                binary.write_bytes(pe(machine=0x8664))
            (root / ".tool-versions").write_text("flutter 3.47.4-stable\n", encoding="utf-8")
            doctor = "√ Flutter SDK — diagnostics 雪\n"

            def fake_run(*, command: list[str], cwd: Path = root, merge_stderr: bool = True) -> str:
                if command[0].endswith("bridge.exe"):
                    return "1.8.4\n"
                if command == ["flutter", "--version", "--machine"]:
                    return json.dumps({"frameworkVersion": "3.47.4"})
                if command == ["flutter", "doctor", "-v"]:
                    return doctor
                if command[:2] == ["git", "rev-parse"]:
                    return "test-sha\n"
                if command == ["git", "diff", "--name-status", "HEAD"]:
                    self.assertFalse(merge_stderr)
                    return ""
                self.fail(f"Unexpected command: {command}")

            with patch.object(qualification, "ROOT", root), patch.object(qualification, "OUTPUT", output), \
                 patch.object(qualification, "run", side_effect=fake_run), \
                 patch.object(qualification.shutil, "which", return_value="flutter"), \
                 patch.dict(qualification.os.environ, {"GITHUB_ENV": str(output / "github-env")}), \
                 patch("io.text_encoding", side_effect=lambda encoding, *args: encoding or "cp1252"), \
                 patch.object(qualification.sys, "stdout", new_callable=StringIO):
                qualification.inspect(target_os="windows", arch="x64", gui=gui)
            self.assertEqual((output / "flutter-doctor.log").read_text(encoding="utf-8"), doctor)
            self.assertIn("SESORI_DESKTOP_BRIDGE_PATH=", (output / "github-env").read_text(encoding="utf-8"))

    def test_machine_output_can_keep_diagnostics_on_stderr(self) -> None:
        with patch.object(qualification.subprocess, "check_output", return_value="") as command:
            self.assertEqual(qualification.run(command=["git", "diff", "--name-status", "HEAD"], merge_stderr=False), "")
        self.assertIsNone(command.call_args.kwargs["stderr"])

    def test_bootstrap_exports_native_xcode_architecture_only_on_macos(self) -> None:
        cases = (("macos", "x64", macho(machine=0x01000007), "x86_64"),
                 ("macos", "arm64", macho(machine=0x0100000C), "arm64"),
                 ("linux", "x64", elf(machine=62), None),
                 ("linux", "arm64", elf(machine=183), None),
                 ("windows", "x64", pe(machine=0x8664), None),
                 ("windows", "arm64", pe(machine=0xAA64), None))
        for target_os, arch, executable, xcode_arch in cases:
            with self.subTest(target_os=target_os, arch=arch), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                sdk = output / "sdk"
                dart = sdk / "bin/cache/dart-sdk/bin" / ("dart.exe" if target_os == "windows" else "dart")
                dart.parent.mkdir(parents=True)
                dart.write_bytes(executable)
                environment = output / "github-env"
                environment.write_text("EXISTING=value\n", encoding="utf-8")
                release = {"version": "3.47.5", "revision": "test-revision"}
                version = {"frameworkRevision": "test-revision"}
                with patch.dict(qualification.os.environ, {
                    "GITHUB_ACTIONS": "true", "GITHUB_ENV": str(environment),
                    "GITHUB_PATH": str(output / "github-path"),
                }), patch.object(qualification, "OUTPUT", output), \
                     patch.object(qualification, "resolve_flutter", return_value=release), \
                     patch.object(qualification, "run", side_effect=["", "test-revision", "", json.dumps(version)]), \
                     patch.object(qualification.sys, "stdout", new_callable=StringIO):
                    qualification.bootstrap(sdk=sdk, target_os=target_os, arch=arch)
                expected = "EXISTING=value\n"
                if xcode_arch is not None:
                    expected += f"FLUTTER_XCODE_ARCHS={xcode_arch}\n"
                self.assertEqual(environment.read_text(encoding="utf-8"), expected)
                self.assertEqual((output / "github-path").read_text(encoding="utf-8"), str(sdk / "bin") + "\n")

    def test_macos_packaging_separates_bootstrap_from_compilation(self) -> None:
        workflow = (qualification.ROOT / ".github/workflows/desktop-qualification.yml").read_text(encoding="utf-8")
        macos = workflow.split("  macos-distribution:\n", 1)[1].split("\n  macos-upgrade:", 1)[0]
        names = ("Bootstrap pinned native SDK", "Resolve locked workspaces",
                 "Build and stage native desktop bundle", "Build separate native platform probe")
        positions = [macos.index(f"      - name: {name}\n") for name in names]
        self.assertEqual(positions, sorted(positions))
        for name in names:
            step = macos.split(f"      - name: {name}\n", 1)[1].split("\n      - ", 1)[0]
            self.assertIn("if: inputs.mode == 'macos-packaging'", step)
        bootstrap = macos[positions[0]:positions[1]]
        self.assertNotIn("flutter build", bootstrap)
        self.assertNotIn("stage_desktop_bundle.dart", bootstrap)
        self.assertNotIn('export PATH="$SDK_DIR/bin:$PATH"', macos)
        self.assertLess(positions[-1], macos.index("      - name: Use existing credentials"))

    def test_bootstrap_cannot_replace_local_sdk(self) -> None:
        with patch.dict(qualification.os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaisesRegex(ValueError, "CI-only"):
                qualification.bootstrap(sdk=Path("unused"), target_os="macos", arch="arm64")


if __name__ == "__main__":
    unittest.main()
