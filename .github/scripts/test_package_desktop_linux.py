import io
import json
import struct
import tempfile
import unittest
import zipfile
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
        (self.root / "dart-defines.env").write_text(
            'SESORI_DESKTOP_BUNDLE_IDENTITY={}\nSESORI_DESKTOP_RELEASE_CHANNEL=internal\n', encoding="utf-8")
        self.plugin_root = self.root / "plugins"
        packages = []
        for name in packaging.linux_plugin_packages():
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
        with self.assertRaisesRegex(ValueError, "Bundle identity mismatch"):
            packaging.verify_bundle(bundle=self.bundle, arch="arm64")
        native = self.bundle / "lib/libapp.so"
        native.write_bytes(elf(machine=183))
        with self.assertRaisesRegex(ValueError, "Wrong native target"):
            packaging.verify_bundle(bundle=self.bundle, arch="x64")
        native.write_bytes(elf(machine=62))
        manifest = self.bundle / "bridge/desktop-bundle.json"
        identity = json.loads(manifest.read_text())
        for key, value in (("version", "1.2"), ("buildNumber", 0), ("buildNumber", True),
                           ("sourceSha", ""), ("os", "windows")):
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

    def test_symlinked_required_entries_refuse(self):
        for entry in (self.bundle / "sesori_desktop", self.bundle / "bridge/bin/bridge",
                      self.bundle / "bridge/lib", self.bundle / "bridge/desktop-bundle.json"):
            with self.subTest(entry=entry):
                saved = entry.with_name(entry.name + ".saved")
                entry.rename(saved)
                entry.symlink_to(saved.name, target_is_directory=saved.is_dir())
                with self.assertRaisesRegex(ValueError, "missing or wrong type"):
                    packaging.verify_bundle(bundle=self.bundle, arch="x64")
                entry.unlink()
                saved.rename(entry)

    def test_payload_preserves_complete_bundle_and_owns_only_bounded_system_paths(self):
        package_root = self.root / "package root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root, package_format="deb")
        installed = package_root / packaging.INSTALL_ROOT
        self.assertEqual(packaging.payload_inventory(root=installed), packaging.payload_inventory(root=self.bundle))
        launcher = package_root / packaging.LAUNCHER
        self.assertEqual(launcher.readlink(), Path("/opt/sesori-desktop/sesori_desktop"))
        desktop = (package_root / packaging.DESKTOP_ENTRY).read_text()
        self.assertIn("Exec=/usr/bin/sesori-desktop", desktop)
        self.assertIn("Icon=sesori-desktop", desktop)
        self.assertTrue((package_root / packaging.ICON).is_file())
        package_paths = ["/", "/opt", "/opt/sesori-desktop", "/usr", "/usr/bin", "/usr/share",
                         "/usr/share/applications", "/usr/share/icons", "/usr/share/icons/hicolor",
                         "/usr/share/icons/hicolor/512x512", "/usr/share/icons/hicolor/512x512/apps",
                         "/etc", "/etc/apt", "/etc/apt/apt.conf.d", "/etc/apt/keyrings", "/etc/apt/sources.list.d"]
        package_paths.extend("/" + item["path"] for item in packaging.payload_inventory(root=package_root))
        self.assertTrue(packaging.verify_owned_paths(paths=package_paths, package_format="deb")["boundedSystemOwnership"])
        with self.assertRaisesRegex(ValueError, "unexpected=.*usr/bin/sesori-bridge"):
            packaging.verify_owned_paths(paths=package_paths + ["/usr/bin/sesori-bridge"], package_format="deb")
        with self.assertRaisesRegex(ValueError, "missing=.*sesori.repo"):
            packaging.verify_owned_paths(paths=package_paths, package_format="rpm")

    def test_packages_register_their_compiled_channel_repository(self):
        key = packaging.REPOSITORY_KEY_SOURCE.read_text()
        self.assertIn("BEGIN PGP PUBLIC KEY BLOCK", key)
        for channel in packaging.CHANNELS:
            with self.subTest(channel=channel):
                (self.root / "dart-defines.env").write_text(f"SESORI_DESKTOP_RELEASE_CHANNEL={channel}\n")
                deb_root, rpm_root = self.root / f"deb {channel}", self.root / f"rpm {channel}"
                packaging.assemble_payload(bundle=self.bundle, root=deb_root, package_format="deb")
                packaging.assemble_payload(bundle=self.bundle, root=rpm_root, package_format="rpm")
                # Byte-identical to the website's manual setup line, so dpkg replaces it in place.
                self.assertEqual((deb_root / packaging.APT_SOURCE).read_text(),
                                 "deb [signed-by=/etc/apt/keyrings/sesori.asc] "
                                 f"https://storage.googleapis.com/sesori-ai-linux-packages/apt {channel} main\n")
                self.assertEqual((deb_root / packaging.APT_KEY).read_text(), key)
                self.assertEqual((deb_root / packaging.APT_UNATTENDED).read_text(),
                                 'Unattended-Upgrade::Origins-Pattern { "origin=Sesori"; };\n')
                self.assertFalse((deb_root / "etc/yum.repos.d").exists())
                repository = (rpm_root / packaging.RPM_REPOSITORY).read_text()
                self.assertTrue(repository.startswith(f"[sesori-{channel}]\n"))
                self.assertIn(f"baseurl=https://storage.googleapis.com/sesori-ai-linux-packages/rpm/{channel}/$basearch\n",
                              repository)
                self.assertIn("enabled=1\ngpgcheck=1\nrepo_gpgcheck=1\n"
                              "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-sesori\nskip_if_unavailable=1\n", repository)
                self.assertEqual((rpm_root / packaging.RPM_KEY).read_text(), key)
                self.assertEqual((rpm_root / packaging.RPM_REPOSITORY).stat().st_mode & 0o777, 0o644)
        (self.root / "dart-defines.env").write_text("SESORI_DESKTOP_RELEASE_CHANNEL=beta\n")
        with self.assertRaisesRegex(ValueError, "compiled release channel"):
            packaging.assemble_payload(bundle=self.bundle, root=self.root / "unknown", package_format="deb")

    def test_actual_plugin_sources_are_checked_for_explicit_dynamic_loading(self):
        audit = packaging.audit_dynamic_loading(package_config=self.package_config)
        self.assertEqual(audit["explicitDependencies"], [])
        self.assertEqual(audit["packages"], [
            "file_selector_linux", "flutter_secure_storage_linux", "pasteboard", "record_linux",
            "screen_retriever_linux", "url_launcher_linux", "window_manager",
        ])
        source = self.plugin_root / "url_launcher_linux/linux/plugin.cc"
        source.write_text('void *x = dlopen("libguessed.so", 1);\n')
        with self.assertRaisesRegex(ValueError, "source-derived package dependency"):
            packaging.audit_dynamic_loading(package_config=self.package_config)

    def test_dpkg_shlibdeps_generates_dependencies_from_every_elf(self):
        package_root = self.root / "deb root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root, package_format="deb")
        work = self.root / "deb work"
        work.mkdir()
        with mock.patch.object(packaging, "run", return_value="shlibs:Depends=libc6 (>= 2.34), libgtk-3-0\n") as command:
            dependencies, invocation = packaging.deb_dependencies(
                root=package_root,
                work=work,
                identity={"version": self.version, "buildNumber": 42},
            )
        self.assertEqual(dependencies, "libc6 (>= 2.34), libgtk-3-0, libegl1, libgles2")
        invoked = command.call_args.kwargs["command"]
        self.assertEqual(invoked[:2], ["dpkg-shlibdeps", "-O"])
        self.assertNotIn("--ignore-missing-info", invoked)
        elf_arguments = {item.removeprefix("-e") for item in invoked if item.startswith("-e")}
        expected = {str(path) for path in packaging.elf_files(root=package_root / packaging.INSTALL_ROOT)}
        self.assertEqual(elf_arguments, expected)
        self.assertTrue(any(item.startswith("-l") for item in invocation))

    def test_package_report_records_payload_before_deb_metadata(self):
        output = self.root / "package output"

        def fake_build_deb(*, root, work, output, arch, identity):
            control = root / "DEBIAN/control"
            control.parent.mkdir()
            control.write_text("metadata")
            artifact = output / "package.deb"
            artifact.write_bytes(b"deb")
            return artifact, {"dependencies": "libc6", "dependencyCommand": [], "metadata": "", "packageFiles": []}

        with mock.patch.object(packaging, "audit_dynamic_loading", return_value={}), mock.patch.object(
            packaging, "build_deb", side_effect=fake_build_deb
        ), mock.patch.object(packaging.platform, "machine", return_value="x86_64"), mock.patch.object(
            packaging, "run", return_value="0123456789abcdef0123456789abcdef01234567\n"
        ):
            packaging.package(bundle=self.bundle, output=output, arch="x64", package_format="deb",
                              package_config=self.package_config)
        report = json.loads((output / "packaging.json").read_text())
        self.assertFalse(any(item["path"].startswith("DEBIAN/") for item in report["payload"]))
        opt_payload = [{**item, "path": item["path"].removeprefix("opt/sesori-desktop/")}
                       for item in report["payload"] if item["path"].startswith("opt/sesori-desktop/")]
        self.assertEqual(opt_payload, packaging.payload_inventory(root=self.bundle))

    def test_deb_metadata_has_no_maintainer_scripts_and_uses_staged_version(self):
        package_root = self.root / "deb root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root, package_format="deb")
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
        self.assertIn("Depends: libc6 (>= 2.34), libegl1, libgles2\nRecommends: pulseaudio-utils, ffmpeg\n", control)
        self.assertEqual(list((package_root / "DEBIAN").iterdir()), [package_root / "DEBIAN/control"])
        self.assertNotIn("postinst", "\n".join(evidence["packageFiles"]))

    def test_rpm_uses_auto_elf_requirements_without_scriptlets(self):
        package_root = self.root / "rpm root"
        packaging.assemble_payload(bundle=self.bundle, root=package_root, package_format="rpm")
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
        self.assertIn("Requires: libEGL.so.1()(64bit)\nRequires: libGLESv2.so.2()(64bit)\n", spec)
        self.assertIn("Recommends: /usr/bin/parecord\nRecommends: /usr/bin/ffmpeg\n", spec)
        self.assertIn("%global __strip /bin/true", spec)
        self.assertIn("%global debug_package %{nil}", spec)
        self.assertNotIn("__os_install_post", spec)
        self.assertNotRegex(spec, r"(?m)^%(pre|post|preun|postun)\b")
        self.assertIn("/etc/pki/rpm-gpg/RPM-GPG-KEY-sesori\n%config(noreplace) /etc/yum.repos.d/sesori.repo\n", spec)
        self.assertEqual(evidence["dependencies"], ["libc.so.6()(64bit)"])

    def build_appimage(self, *, image_bundle: Path | None = None, nupkg: bytes = b"vpk package",
                       image_icon: bytes | None = None, library_machine: int = 62,
                       library_digest: str | None = None):
        """Run build_appimage with a fake vpk that writes a runtime-prefixed image of `image_bundle`, or of the
        directory it was asked to pack."""
        work, output = self.root / "appimage work", self.root / "appimage output"
        work.mkdir()
        output.mkdir()
        # A 64-bit ELF runtime whose single 64-byte section header ends at byte 128.
        runtime = bytearray(128)
        runtime[:4] = b"\x7fELF"
        struct.pack_into("<Q", runtime, 0x28, 64)
        struct.pack_into("<HH", runtime, 0x3A, 64, 1)
        commands = []
        packed = {}

        def fake_run(*, command, cwd, env=None):
            commands.append(command)
            if command[1] == "pack":
                options = dict(zip(command[2::2], command[3::2]))
                packed["dir"] = Path(options["--packDir"])
                releases = Path(options["--outputDir"])
                releases.mkdir()
                channel, version = options["--channel"], options["--packVersion"]
                (releases / f"sesori-desktop-{channel}.AppImage").write_bytes(bytes(runtime) + b"hsqs")
                (releases / f"sesori-desktop-{version}-{channel}-full.nupkg").write_bytes(b"full")
                (releases / f"releases.{channel}.json").write_text("{}")
                (releases / f"assets.{channel}.json").write_text("[]")
            elif "-d" in command:
                appdir = Path(command[command.index("-d") + 1])
                packaging.shutil.copytree(image_bundle or packed["dir"], appdir / "usr/bin", symlinks=True)
                (appdir / "usr/bin/UpdateNix").write_bytes(elf(machine=62))
                (appdir / "usr/bin/sq.version").write_text("<package/>")
                packaging.shutil.copy2(packaging.ICON_SOURCE, appdir / "sesori-desktop.png")
                if image_icon is not None:
                    (appdir / "sesori-desktop.png").write_bytes(image_icon)
            return "squashfs-root/AppRun\n"

        libraries = io.BytesIO()
        with zipfile.ZipFile(libraries, "w") as archive:
            archive.writestr("lib/velopack_libc_linux_x64_gnu.so", elf(machine=library_machine))
        downloads = {packaging.VPK_PACKAGE_URL: nupkg, packaging.VELOPACK_LIBRARY_URL: libraries.getvalue()}

        def fake_urlopen(url, timeout):
            response = mock.MagicMock()
            response.__enter__.return_value = io.BytesIO(downloads[url])
            return response

        with mock.patch.object(packaging, "VPK_PACKAGE_SHA256", packaging.hashlib.sha256(b"vpk package").hexdigest()), \
                mock.patch.object(packaging, "VELOPACK_LIBRARY_SHA256",
                                  library_digest or packaging.hashlib.sha256(libraries.getvalue()).hexdigest()), \
                mock.patch.object(packaging.urllib.request, "urlopen", side_effect=fake_urlopen), \
                mock.patch.object(packaging, "run", side_effect=fake_run):
            artifact, evidence = packaging.build_appimage(
                bundle=self.bundle, work=work, output=output, arch="x64",
                identity={"version": self.version, "buildNumber": 42},
            )
        return artifact, evidence, commands

    def test_appimage_is_packed_by_pinned_vpk_from_the_exact_bundle(self):
        artifact, evidence, commands = self.build_appimage()
        self.assertEqual(artifact.name, f"Sesori-linux-x64-{self.version}-42.AppImage")
        install, pack = commands[0], commands[1]
        # Only the verified local package can be installed.
        self.assertEqual(install[:6], ["dotnet", "tool", "install", "vpk", "--version", "1.2.161"])
        self.assertEqual(install[install.index("--source") + 1], str(self.root / "appimage work/vpk-feed"))
        self.assertTrue((self.root / "appimage work/vpk-feed/vpk.1.2.161.nupkg").is_file())
        options = dict(zip(pack[2::2], pack[3::2]))
        self.assertEqual(options, {
            "--packId": "sesori-desktop", "--packVersion": f"{self.version}-internal.42",
            "--packDir": str(self.root / "appimage work/pack"), "--mainExe": "sesori_desktop", "--packTitle": "Sesori",
            "--icon": str(packaging.ICON_SOURCE), "--categories": "Development;Utility", "--channel": "internal",
            "--outputDir": str(self.root / "appimage work/velopack"),
        })
        self.assertTrue(all(command[1:3] == ["-offset", "128"] for command in commands[2:]))
        velopack = artifact.parent / "velopack"
        self.assertEqual(sorted(path.name for path in velopack.iterdir()),
                         ["releases.internal.json", f"sesori-desktop-{self.version}-internal.42-internal-full.nupkg"])
        self.assertEqual(evidence["velopack"]["runtime"]["bytes"], 128)
        self.assertEqual([row["name"] for row in evidence["velopack"]["releaseFiles"]],
                         sorted(path.name for path in velopack.iterdir()))
        self.assertIn("FUSE", evidence["hostRequirements"])

    def test_velopack_versions_increase_within_each_channel(self):
        identity = {"version": self.version, "buildNumber": 42}
        self.assertEqual(packaging.velopack_version(identity=identity, channel="stable"), self.version)
        self.assertEqual(packaging.velopack_version(identity=identity, channel="internal"), f"{self.version}-internal.42")

    def test_vpk_package_digest_mismatch_refuses(self):
        with self.assertRaisesRegex(ValueError, "vpk package digest mismatch"):
            self.build_appimage(nupkg=b"tampered")

    def test_appimage_packs_the_pinned_velopack_library_into_the_bundle(self):
        _, evidence, _ = self.build_appimage()
        pack_dir = self.root / "appimage work/pack"
        self.assertEqual((pack_dir / "lib/libvelopack_libc.so").read_bytes(), elf(machine=62))
        self.assertEqual(sorted(row["path"] for row in packaging.payload_inventory(root=pack_dir)),
                         sorted([row["path"] for row in packaging.payload_inventory(root=self.bundle)]
                                + ["lib/libvelopack_libc.so"]))
        self.assertEqual(len(evidence["velopack"]["libraryArchiveSha256"]), 64)
        # Only Velopack packages carry the library; the staged bundle that DEB and RPM install stays unchanged.
        self.assertFalse((self.bundle / "lib/libvelopack_libc.so").exists())

    def test_velopack_library_digest_mismatch_or_wrong_cpu_refuses(self):
        with self.assertRaisesRegex(ValueError, "Velopack library archive digest mismatch"):
            self.build_appimage(library_digest="0" * 64)
        packaging.shutil.rmtree(self.root / "appimage work")
        packaging.shutil.rmtree(self.root / "appimage output")
        with self.assertRaisesRegex(ValueError, "Wrong native target"):
            self.build_appimage(library_machine=183)

    def test_appimage_without_the_exact_bundle_refuses(self):
        changed = self.root / "changed bundle"
        packaging.shutil.copytree(self.bundle, changed, symlinks=True)
        (changed / "data/flutter_assets/NOTICE").unlink()
        with self.assertRaisesRegex(ValueError, "exact staged bundle"):
            self.build_appimage(image_bundle=changed)

    def test_appimage_without_the_velopack_manifest_refuses(self):
        # A Velopack file the fake image does not contain stands in for a missing sq.version.
        with mock.patch.object(packaging, "VELOPACK_ADDED_FILES", {"UpdateNix", "sq.version", "missing"}), \
                self.assertRaisesRegex(ValueError, "exact staged bundle"):
            self.build_appimage()

    def test_appimage_with_a_different_icon_refuses(self):
        with self.assertRaisesRegex(ValueError, "icon differs"):
            self.build_appimage(image_icon=b"other icon")

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
