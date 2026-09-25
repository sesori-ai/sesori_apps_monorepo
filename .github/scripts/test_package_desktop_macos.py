import json
import plistlib
import shutil
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import package_desktop_macos as packaging


class MacPackagingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="mac packaging ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / "Sesori.app"
        self.helper = self.app / "Contents/Helpers/bridge/bin/bridge"
        self.libraries = [self.app / "Contents/Helpers/bridge/lib" / name
                          for name in ("libsqlite3.dylib", "macos_power_observer.dylib")]
        self.frameworks = []
        self.write_plist(path=self.app / "Contents/Info.plist", executable="Sesori")
        self.manifest = self.app / "Contents/Resources/desktop-bundle.json"
        self.manifest.parent.mkdir()
        self.manifest.write_text("{}\n")
        for binary in (self.app / "Contents/MacOS/Sesori", self.helper, *self.libraries):
            self.write_binary(path=binary)
        for name in ("App", "FlutterMacOS", "objective_c"):
            framework = self.app / "Contents/Frameworks" / f"{name}.framework"
            version = framework / "Versions/A"
            self.write_binary(path=version / name)
            self.write_plist(path=version / "Resources/Info.plist", executable=name)
            (framework / "Versions/Current").symlink_to("A", target_is_directory=True)
            (framework / name).symlink_to(f"Versions/Current/{name}")
            (framework / "Resources").symlink_to("Versions/Current/Resources", target_is_directory=True)
            self.frameworks.append(framework)
        self.keychain = self.root / "private.keychain-db"
        self.log = self.root / "packaging.log"

    @staticmethod
    def write_binary(*, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(struct.pack("<II", 0xFEEDFACF, 0x0100000C) + bytes(56))

    @staticmethod
    def write_plist(*, path, executable):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps({"CFBundleExecutable": executable}))

    def test_native_leaves_then_frameworks_then_app_without_signing_symlink_aliases(self):
        order = packaging.signing_order(app=self.app, arch="arm64")
        self.assertEqual(set(order[:3]), {self.helper, *self.libraries})
        self.assertEqual(set(order[3:-1]), set(self.frameworks))
        self.assertEqual(order[-1], self.app)
        self.assertEqual(len(order), 7)
        self.assertNotIn(self.manifest, order)
        self.assertTrue(all(not path.is_symlink() for path in order))

    def test_wrong_native_architecture_refuses_before_any_signing_command(self):
        with mock.patch.object(packaging, "execute") as execute:
            with self.assertRaisesRegex(ValueError, "Wrong native target"):
                packaging.sign_app(app=self.app, arch="x64", identity="Expected publisher",
                                   keychain=self.keychain, log=self.log)
        execute.assert_not_called()

    def test_hardened_executables_use_exact_publisher_and_separate_runtime_entitlements(self):
        with mock.patch.object(packaging, "execute") as execute:
            packaging.sign_app(app=self.app, arch="arm64", identity="Expected publisher",
                               keychain=self.keychain, log=self.log)
        for call in execute.call_args_list:
            command = call.kwargs["command"]
            target = Path(command[-1])
            self.assertEqual(command[command.index("--sign") + 1], "Expected publisher")
            self.assertEqual(command[command.index("--keychain") + 1], str(self.keychain))
            self.assertIn("--timestamp", command)
            self.assertEqual("--options" in command, target in (self.app, self.helper))
            self.assertEqual("--entitlements" in command, target in (self.app, self.helper))
            if target in (self.app, self.helper):
                entitlements = packaging.ENTITLEMENTS if target == self.app else packaging.BRIDGE_ENTITLEMENTS
                self.assertEqual(command[command.index("--entitlements") + 1], str(entitlements))
            self.assertNotIn("--deep", command)  # Deep verification, never deep signing.
        self.assertEqual(execute.call_args_list[-1].kwargs["command"][-1], str(self.app))

    def test_bridge_entitlements_allow_aot_memory_without_disabling_library_validation(self):
        with packaging.BRIDGE_ENTITLEMENTS.open("rb") as stream:
            entitlements = plistlib.load(stream)
        self.assertEqual(entitlements, {"com.apple.security.cs.allow-unsigned-executable-memory": True})
        with packaging.ENTITLEMENTS.open("rb") as stream:
            self.assertNotIn("com.apple.security.cs.allow-unsigned-executable-memory", plistlib.load(stream))

    def test_extracted_verification_checks_every_native_binary_and_gatekeeper(self):
        with mock.patch.object(packaging, "execute", return_value="1.8.4\n") as execute:
            evidence = packaging.verify_app(app=self.app, arch="arm64", log=self.log)
        commands = [call.kwargs["command"] for call in execute.call_args_list]
        verified = {Path(command[-1]) for command in commands if command[:3] == ["codesign", "--verify", "--strict"]}
        self.assertEqual(len(verified), 7)
        self.assertTrue(set(self.libraries).issubset(verified))
        self.assertIn(["codesign", "--verify", "--deep", "--strict", str(self.app)], commands)
        self.assertIn(["xcrun", "stapler", "validate", str(self.app)], commands)
        self.assertIn(["spctl", "--assess", "--type", "execute", "--verbose=2", str(self.app)], commands)
        self.assertEqual(evidence["helperVersion"], "1.8.4")

    def test_notarization_uses_profile_not_password_and_saves_authoritative_receipt(self):
        receipt = self.root / "receipt.json"
        result = json.dumps({"status": "Accepted", "id": "submission-id"})
        with mock.patch.object(packaging, "execute", return_value=result) as execute:
            packaging.notarize(artifact=self.root / "probe.zip", profile="ci-profile", keychain=self.keychain,
                               evidence=receipt, log=self.log)
        self.assertEqual(receipt.read_text(), result)
        command = execute.call_args_list[0].kwargs["command"]
        self.assertIn("--wait", command)
        self.assertIn("--keychain-profile", command)
        self.assertIn("ci-profile", command)
        self.assertNotIn("--password", command)
        self.assertNotIn("--apple-id", command)

    def test_notary_invalid_pending_and_unknown_status_never_count_as_acceptance(self):
        for status in ("Invalid", "In Progress", "Unexpected Future Status"):
            with self.subTest(status=status):
                result = json.dumps({"status": status, "id": "submission-id"})
                with mock.patch.object(packaging, "execute", return_value=result):
                    with self.assertRaisesRegex(RuntimeError, "Notarization submission-id returned"):
                        packaging.notarize(artifact=self.root / "probe.zip", profile="ci-profile",
                                           keychain=self.keychain, evidence=self.root / "receipt.json", log=self.log)

    def test_rejection_preserves_diagnostics_and_never_creates_final_archives(self):
        output = self.root / "result"

        def execute(*, command, log):
            if command[0] == "ditto" and command[1] == str(self.app):
                shutil.copytree(command[1], command[2], symlinks=True)
            return ""

        with mock.patch.object(packaging, "execute", side_effect=execute) as commands, \
                mock.patch.object(packaging, "sign_app"), \
                mock.patch.object(packaging, "notarize", side_effect=RuntimeError("Rejected submission")):
            with self.assertRaisesRegex(RuntimeError, "Rejected submission"):
                packaging.package(app=self.app, output=output, arch="arm64", identity="Expected publisher",
                                  keychain=self.keychain, profile="ci-profile")
        self.assertTrue((output / "work/Sesori.app").is_dir())
        self.assertFalse(list(output.glob("Sesori-macos-*")))
        self.assertTrue(all(call.kwargs["command"][0] != "hdiutil" for call in commands.call_args_list))

    def test_divergent_payloads_fail_without_a_verified_report_and_detach_the_dmg(self):
        output = self.root / "divergent"

        def execute(*, command, log):
            if command[:3] == ["ditto", "-c", "-k"] or command[:2] == ["hdiutil", "create"]:
                Path(command[-1]).write_bytes(b"archive")
            elif command[:3] == ["ditto", "-x", "-k"]:
                manifest = Path(command[-1]) / "Sesori.app/Contents/Resources/desktop-bundle.json"
                manifest.parent.mkdir(parents=True)
                shutil.copyfile(self.manifest, manifest)
            return ""

        with mock.patch.object(packaging, "execute", side_effect=execute) as commands, \
                mock.patch.object(packaging, "run", return_value="test-source"), \
                mock.patch.object(packaging, "sign_app"), mock.patch.object(packaging, "notarize"), \
                mock.patch.object(packaging, "verify_app", side_effect=[
                    {"binaries": [{"sha256": "zip"}], "helperVersion": "1.8.4"},
                    {"binaries": [{"sha256": "dmg"}], "helperVersion": "1.8.4"},
                ]):
            with self.assertRaisesRegex(RuntimeError, "ZIP and DMG extracted payload evidence differ"):
                packaging.package(app=self.app, output=output, arch="arm64", identity="Expected publisher",
                                  keychain=self.keychain, profile="ci-profile")
        self.assertEqual(commands.call_args.kwargs["command"][:2], ["hdiutil", "detach"])
        self.assertFalse((output / "packaging.json").exists())

    def test_existing_output_is_never_deleted_or_replaced(self):
        output = self.root / "existing"
        output.mkdir()
        sentinel = output / "diagnostics.log"
        sentinel.write_text("keep this failed attempt")
        with mock.patch.object(packaging, "execute") as execute:
            with self.assertRaises(FileExistsError):
                packaging.package(app=self.app, output=output, arch="arm64", identity="Expected publisher",
                                  keychain=self.keychain, profile="ci-profile")
        execute.assert_not_called()
        self.assertEqual(sentinel.read_text(), "keep this failed attempt")


if __name__ == "__main__":
    unittest.main()
