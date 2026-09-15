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
            path.write_bytes(b"\xca\xfe\xba\xbe" + struct.pack(">I", 2)
                             + struct.pack(">IIIII", 0x01000007, 0, 0, 0, 0)
                             + struct.pack(">IIIII", 0x0100000C, 0, 0, 0, 0))
            self.assertEqual(qualification.native_arch(path=path), ("Mach-O", ["arm64", "x64"]))

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

    def test_bootstrap_cannot_replace_local_sdk(self) -> None:
        with patch.dict(qualification.os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaisesRegex(ValueError, "CI-only"):
                qualification.bootstrap(sdk=Path("unused"), target_os="macos", arch="arm64")


if __name__ == "__main__":
    unittest.main()
