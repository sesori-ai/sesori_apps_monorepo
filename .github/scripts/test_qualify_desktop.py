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

    def test_gui_inspection_records_arm_compiler_and_target_without_running_target(self) -> None:
        for arch, machine in (("x64", 0x01000007), ("arm64", 0x0100000C)):
            with self.subTest(arch=arch), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                gui = root / "Sesori.app"
                source = root / "product"
                for relative in ("Contents/MacOS/Sesori", "Contents/Frameworks/App.framework/App"):
                    binary = gui / relative
                    binary.parent.mkdir(parents=True, exist_ok=True)
                    binary.write_bytes(macho(machine=machine))

                def fake_run(*, command: list[str], cwd: Path = qualification.ROOT) -> str:
                    if command == ["git", "rev-parse", "HEAD"]:
                        return "product-sha" if cwd == source else "tooling-sha"
                    if command == ["flutter", "--version", "--machine"]:
                        return json.dumps({"frameworkVersion": "3.47.5"})
                    if command == ["xcodebuild", "-version"]:
                        return "Xcode 27.0"
                    self.fail(f"Unexpected command (must not execute target code): {command}")

                with patch.object(qualification, "run", side_effect=fake_run), \
                     patch.object(qualification.shutil, "which", return_value="flutter"), \
                     patch.object(qualification.platform, "machine", return_value="arm64"), \
                     patch.object(qualification.sys, "stdout", new_callable=StringIO):
                    qualification.inspect_gui(gui=gui, arch=arch, source=source)
                report = json.loads((root / "gui-inventory.json").read_text())
                self.assertEqual(report["sourceSha"], "product-sha")
                self.assertEqual(report["toolingSourceSha"], "tooling-sha")
                self.assertEqual(report["buildHostCpu"], "arm64")
                self.assertEqual(report["targetCpu"], arch)
                self.assertEqual(report["xcode"], "Xcode 27.0")
                self.assertEqual(len(report["binaries"]), 2)

    def test_only_gui_header_inspection_allows_a_different_host_cpu(self) -> None:
        with patch.object(qualification.sys, "platform", "darwin"), \
             patch.object(qualification.platform, "machine", return_value="arm64"), \
             patch.object(qualification, "inspect_gui") as inspect_gui:
            args = ["qualify_desktop.py", "inspect-gui", "--arch", "x64", "--bundle-dir", "gui",
                    "--source-root", "selected-source"]
            with patch.object(qualification.sys, "argv", args):
                qualification.main()
            inspect_gui.assert_called_once_with(gui=qualification.ROOT / "gui", arch="x64",
                                                source=Path("selected-source"))
            for operation in ("bootstrap", "inspect"):
                with self.subTest(operation=operation), patch.object(
                    qualification.sys, "argv", ["qualify_desktop.py", operation, "--arch", "x64"]
                ), self.assertRaisesRegex(ValueError, "Native host required"):
                    qualification.main()

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

    def test_bootstrap_selects_native_sdk_without_overriding_gui_target(self) -> None:
        cases = (("macos", "x64", macho(machine=0x01000007)),
                 ("macos", "arm64", macho(machine=0x0100000C)),
                 ("linux", "x64", elf(machine=62)),
                 ("linux", "arm64", elf(machine=183)),
                 ("windows", "x64", pe(machine=0x8664)),
                 ("windows", "arm64", pe(machine=0xAA64)))
        for target_os, arch, executable in cases:
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
                self.assertEqual(environment.read_text(encoding="utf-8"), "EXISTING=value\n")
                self.assertEqual((output / "github-path").read_text(encoding="utf-8"), str(sdk / "bin") + "\n")

    def test_macos_arm_producer_and_native_consumers_preserve_release_boundaries(self) -> None:
        workflow = (qualification.ROOT / ".github/workflows/desktop-qualification.yml").read_text(encoding="utf-8")
        gui = workflow.split("  macos-gui:\n", 1)[1].split("\n  macos-distribution:", 1)[0]
        macos = workflow.split("  macos-distribution:\n", 1)[1].split("\n  macos-upgrade:", 1)[0]
        native = workflow.split("  macos-native-build:\n", 1)[1].split("\n  native-build:", 1)[0]
        other = workflow.split("  native-build:\n", 1)[1]
        self.assertIn("runs-on: xcode-27", gui)
        self.assertIn("arch: [x64, arm64]", gui)
        self.assertIn("bootstrap --arch arm64", gui)
        self.assertNotIn("secrets.", gui)
        self.assertNotIn("environment:", gui)
        self.assertIn("git merge-base --is-ancestor HEAD origin/main", gui)
        self.assertIn("if: inputs.mode == 'macos-packaging'", gui)
        modes = [gui.index(f"--mode {mode}") for mode in ("gui", "probe")]
        self.assertLess(gui.index("Bootstrap pinned ARM SDK"), modes[0])
        self.assertLess(modes[0], modes[1])
        self.assertIn("tar -czf", gui)  # Preserve framework links and executable modes across Actions artifacts.
        self.assertIn("--source-root \"$GITHUB_WORKSPACE\"", gui)
        for job in (gui, macos, native):
            self.assertIn(".ci-workflow/client/desktop/tool/stage_desktop_bundle.dart", job)
            self.assertIn('--packages="$GITHUB_WORKSPACE/client/.dart_tool/package_config.json"', job)
        for job in (macos, native):
            self.assertIn("needs: [tooling, macos-gui]", job)
            self.assertIn("runner: macos-26-intel", job)
            self.assertIn("runner: xcode-27", job)
            self.assertIn("name: desktop-macos-gui-${{ matrix.arch }}", job)
            self.assertIn("--mode assemble --gui-input build/desktop-macos-gui/product", job)
            self.assertNotIn("flutter build", job)
            self.assertIn("supervised_e2e_test.dart", job)
            self.assertIn("product-gui-inventory.json", job)
            self.assertIn("probe-gui-inventory.json", job)
        self.assertIn("environment: macos-signing", macos)
        self.assertIn("!cancelled() && needs.tooling.result == 'success'", macos)
        self.assertIn("inputs.mode != 'macos-packaging' || needs.macos-gui.result == 'success'", macos)
        self.assertLess(macos.index("--mode assemble"), macos.index("Use existing credentials"))
        self.assertIn("build/desktop-platform-probe/Sesori.app", macos)
        self.assertNotIn("secrets.", native)
        self.assertIn("Typecheck supported Sparkle lifecycle API", native)
        self.assertIn("needs: tooling", other)
        self.assertNotIn("macos-gui", other)  # Other platforms must not wait on macOS compilation.
        self.assertNotIn("target: macos", other)

    def test_bootstrap_cannot_replace_local_sdk(self) -> None:
        with patch.dict(qualification.os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaisesRegex(ValueError, "CI-only"):
                qualification.bootstrap(sdk=Path("unused"), target_os="macos", arch="arm64")


if __name__ == "__main__":
    unittest.main()
