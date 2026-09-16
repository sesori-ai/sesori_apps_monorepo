import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import package_desktop_linux as packaging


def elf(*, machine: int) -> bytes:
    header = bytearray(64)
    header[:4] = b"\x7fELF"
    header[4] = 2
    header[5] = 1
    struct.pack_into("<H", header, 18, machine)
    return bytes(header)


class LinuxPackagingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="linux packaging ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bundle = self.root / "staged bundle"
        self.version = "9.8.7"
        for relative in ("sesori_desktop", "lib/libapp.so", "bridge/bin/bridge", "bridge/lib/libsqlite3.so"):
            path = self.bundle / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(elf(machine=62))
        asset = self.bundle / "data/flutter_assets/NOTICE"
        asset.parent.mkdir(parents=True)
        asset.write_text("licenses", encoding="utf-8")
        target = self.bundle / "lib/libtarget.so"
        target.write_bytes(elf(machine=62))
        (self.bundle / "lib/libalias.so").symlink_to("libtarget.so")
        (self.bundle / "bridge/desktop-bundle.json").write_text(json.dumps({
            "version": self.version,
            "buildNumber": 42,
            "sourceSha": "0123456789abcdef0123456789abcdef01234567",
            "os": "linux",
            "architecture": "x64",
        }), encoding="utf-8")
        self.plugin_root = self.root / "plugins"
        packages = []
        for name in packaging.AUDITED_PLUGIN_PACKAGES:
            source = self.plugin_root / name / "linux/plugin.cc"
            source.parent.mkdir(parents=True)
            source.write_text("// linked normally\n", encoding="utf-8")
            packages.append({"name": name, "rootUri": (self.plugin_root / name).as_uri()})
        self.package_config = self.root / "package_config.json"
        self.package_config.write_text(json.dumps({"packages": packages}), encoding="utf-8")

    def test_verifies_synthetic_identity_cpu_and_complete_inventory(self):
        evidence = packaging.verify_bundle(bundle=self.bundle, arch="x64")
        self.assertEqual(evidence["identity"]["version"], self.version)
        self.assertEqual(evidence["identity"]["buildNumber"], 42)
        self.assertEqual({item["path"] for item in evidence["binaries"]}, {
            "sesori_desktop", "lib/libapp.so", "lib/libtarget.so",
            "bridge/bin/bridge", "bridge/lib/libsqlite3.so",
        })

    def test_wrong_architecture_and_identity_refuse(self):
        with self.assertRaisesRegex(ValueError, "Bundle identity mismatch|Wrong native target"):
            packaging.verify_bundle(bundle=self.bundle, arch="arm64")
        manifest = self.bundle / "bridge/desktop-bundle.json"
        identity = json.loads(manifest.read_text())
        for key, value in (("version", "1.2"), ("buildNumber", 0), ("sourceSha", ""), ("os", "windows")):
            with self.subTest(key=key):
                changed = dict(identity)
                changed[key] = value
                manifest.write_text(json.dumps(changed))
                with self.assertRaisesRegex(ValueError, "version|buildNumber|sourceSha|identity"):
                    packaging.verify_bundle(bundle=self.bundle, arch="x64")
        manifest.write_text(json.dumps(identity))

    def test_missing_or_wrong_type_required_entries_refuse(self):
        for missing in (self.bundle / "sesori_desktop", self.bundle / "bridge/bin/bridge",
                        self.bundle / "bridge/lib", self.bundle / "bridge/desktop-bundle.json"):
            with self.subTest(missing=missing):
                saved = missing.with_name(missing.name + ".saved")
                missing.rename(saved)
                if saved.is_dir():
                    missing.write_text("wrong")
                else:
                    missing.mkdir()
                with self.assertRaisesRegex(ValueError, "missing or wrong type"):
                    packaging.verify_bundle(bundle=self.bundle, arch="x64")
                if missing.is_dir():
                    missing.rmdir()
                else:
                    missing.unlink()
                saved.rename(missing)

    def test_payload_preserves_bundle_and_owns_only_bounded_system_paths(self):
        package_root = self.root / "package root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root)
        installed = package_root / packaging.INSTALL_ROOT
        self.assertEqual((installed / "data/flutter_assets/NOTICE").read_text(), "licenses")
        self.assertTrue((installed / "lib/libalias.so").is_symlink())
        self.assertEqual((installed / "lib/libalias.so").readlink(), Path("libtarget.so"))
        launcher = package_root / packaging.LAUNCHER
        self.assertEqual(launcher.readlink(), Path("/opt/sesori-desktop/sesori_desktop"))
        desktop = (package_root / packaging.DESKTOP_ENTRY).read_text()
        self.assertIn("Exec=/usr/bin/sesori-desktop", desktop)
        self.assertIn("Icon=sesori-desktop", desktop)
        self.assertTrue((package_root / packaging.ICON).is_file())
        paths = {item["path"] for item in packaging.payload_inventory(root=package_root)}
        self.assertNotIn("usr/bin/sesori-bridge", paths)
        self.assertFalse(any(path.startswith(("home/", "etc/xdg/autostart/")) for path in paths))

    def test_actual_plugin_sources_are_checked_for_explicit_dynamic_loading(self):
        audit = packaging.audit_dynamic_loading(package_config=self.package_config)
        self.assertEqual(audit["explicitDependencies"], [])
        self.assertEqual(set(audit["packages"]), set(packaging.AUDITED_PLUGIN_PACKAGES))
        source = self.plugin_root / "tray_manager/linux/plugin.cc"
        source.write_text('void *x = dlopen("libguessed.so", 1);\n')
        with self.assertRaisesRegex(ValueError, "source-derived package dependency"):
            packaging.audit_dynamic_loading(package_config=self.package_config)

    def test_dpkg_shlibdeps_generates_dependencies_from_every_elf(self):
        package_root = self.root / "deb root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root)
        work = self.root / "deb work"
        work.mkdir()
        with mock.patch.object(packaging, "run", return_value="shlibs:Depends=libc6 (>= 2.34), libgtk-3-0\n") as command:
            dependencies, invocation = packaging.deb_dependencies(
                root=package_root,
                work=work,
                identity={"version": self.version, "buildNumber": 42},
            )
        self.assertEqual(dependencies, "libc6 (>= 2.34), libgtk-3-0")
        invoked = command.call_args.kwargs["command"]
        self.assertEqual(invoked[:3], ["dpkg-shlibdeps", "-O", "--ignore-missing-info"])
        elf_arguments = {item.removeprefix("-e") for item in invoked if item.startswith("-e")}
        expected = {str(path) for path in packaging.elf_files(root=package_root / packaging.INSTALL_ROOT)}
        self.assertEqual(elf_arguments, expected)
        self.assertTrue(any(item.startswith("-l") for item in invocation))

    def test_deb_metadata_has_no_maintainer_scripts_and_uses_staged_version(self):
        package_root = self.root / "deb root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root)
        work, output = self.root / "deb work", self.root / "deb output"
        work.mkdir()
        output.mkdir()

        def fake_run(*, command, cwd, env=None):
            if command[0] == "dpkg-shlibdeps":
                return "shlibs:Depends=libc6 (>= 2.34)\n"
            if command[:2] == ["dpkg-deb", "--root-owner-group"]:
                Path(command[-1]).write_bytes(b"deb")
                return "built"
            if command[:2] == ["dpkg-deb", "--field"]:
                return "Package: sesori-desktop\n"
            return "drwxr-xr-x root/root ./opt/sesori-desktop/\n"

        with mock.patch.object(packaging, "run", side_effect=fake_run):
            artifact, evidence = packaging.build_deb(
                root=package_root, work=work, output=output, arch="x64",
                identity={"version": self.version, "buildNumber": 42},
            )
        self.assertEqual(artifact.name, f"Sesori-linux-x64-{self.version}-42.deb")
        control = (package_root / "DEBIAN/control").read_text()
        self.assertIn(f"Version: {self.version}-42", control)
        self.assertIn("Architecture: amd64", control)
        self.assertIn("Depends: libc6 (>= 2.34)", control)
        self.assertEqual(list((package_root / "DEBIAN").iterdir()), [package_root / "DEBIAN/control"])
        self.assertNotIn("postinst", "\n".join(evidence["packageFiles"]))

    def test_rpm_uses_auto_elf_requirements_without_scriptlets(self):
        package_root = self.root / "rpm root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root)
        work, output = self.root / "rpm work", self.root / "rpm output"
        work.mkdir()
        output.mkdir()

        def fake_run(*, command, cwd, env=None):
            if command[0] == "rpmbuild":
                target = work / "rpmbuild/RPMS/x86_64/sesori-desktop.rpm"
                target.parent.mkdir(parents=True)
                target.write_bytes(b"rpm")
                return "built"
            if "--requires" in command:
                return "libc.so.6()(64bit)\n"
            if "-qip" in command:
                return "Name: sesori-desktop\n"
            return "/opt/sesori-desktop\n/usr/bin/sesori-desktop\n"

        with mock.patch.object(packaging, "run", side_effect=fake_run):
            artifact, evidence = packaging.build_rpm(
                root=package_root, work=work, output=output, arch="x64",
                identity={"version": self.version, "buildNumber": 42},
            )
        self.assertEqual(artifact.name, f"Sesori-linux-x64-{self.version}-42.rpm")
        spec = (work / "rpmbuild/SPECS/sesori-desktop.spec").read_text()
        self.assertIn(f"Version: {self.version}", spec)
        self.assertIn("Release: 42%{?dist}", spec)
        self.assertIn("AutoReqProv: yes", spec)
        self.assertIn("%global __strip /bin/true", spec)
        self.assertIn("%global debug_package %{nil}", spec)
        self.assertNotIn("__os_install_post", spec)
        self.assertNotRegex(spec, r"(?m)^%(pre|post|preun|postun)\b")
        self.assertEqual(evidence["dependencies"], ["libc.so.6()(64bit)"])

    def test_existing_output_refuses_before_tools_or_payload_changes(self):
        output = self.root / "existing"
        output.mkdir()
        sentinel = output / "keep"
        sentinel.write_text("diagnostics")
        with mock.patch.object(packaging, "run") as command, mock.patch.object(
            packaging.platform, "machine", return_value="x86_64"
        ), self.assertRaises(FileExistsError):
            packaging.package(bundle=self.bundle, output=output, arch="x64", package_format="deb",
                              package_config=self.package_config)
        command.assert_not_called()
        self.assertEqual(sentinel.read_text(), "diagnostics")


if __name__ == "__main__":
    unittest.main()
