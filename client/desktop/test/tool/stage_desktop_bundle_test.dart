import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "../../tool/stage_desktop_bundle.dart" show stageDesktopBundle;

void main() {
  late Directory temporary;
  setUp(() async => temporary = await Directory.systemTemp.createTemp("desktop staging "));
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  for (final DesktopBundleOs os in DesktopBundleOs.values) {
    test("$os preserves the complete GUI/helper layout and serializes its identity", () async {
      final Directory gui = Directory(path.join(temporary.path, "gui"));
      final Directory helper = Directory(path.join(temporary.path, "helper"));
      final Directory output = Directory(path.join(temporary.path, "relocated payload"));
      final DesktopBundleIdentity identity = DesktopBundleIdentity(
        version: "1.8.4",
        buildNumber: 21,
        sourceSha: "source",
        os: os,
        architecture: DesktopBundleArchitecture.arm64,
      );
      final String guiEntry = os == DesktopBundleOs.macos ? "Contents/MacOS/Sesori" : "sesori_desktop";
      await _file(root: gui, name: guiEntry, contents: "gui");
      await _file(root: gui, name: "data/flutter_assets/asset.txt", contents: "asset");
      await _file(
        root: helper,
        name: "bin/${os == DesktopBundleOs.windows ? 'bridge.exe' : 'bridge'}",
        contents: "helper",
      );
      await _file(root: helper, name: "lib/native-asset", contents: "native asset");
      await stageDesktopBundle(gui: gui, helper: helper, destination: output, identity: identity);
      final String helperRoot = os == DesktopBundleOs.macos
          ? path.join(output.path, "Contents", "Helpers", "bridge")
          : path.join(output.path, "bridge");
      expect(await File(path.join(output.path, guiEntry)).readAsString(), "gui");
      expect(await File(path.join(output.path, "data/flutter_assets/asset.txt")).readAsString(), "asset");
      expect(await File(path.join(helperRoot, "lib", "native-asset")).readAsString(), "native asset");
      expect(
        DesktopBundleIdentity.decode(
          encoded: await File(path.join(helperRoot, DesktopBundleIdentity.manifestName)).readAsString(),
        ),
        identity,
      );
      await expectLater(
        stageDesktopBundle(gui: gui, helper: helper, destination: output, identity: identity),
        throwsStateError,
      );
    });
  }

  test("preserves framework symlinks and executable permissions", () async {
    final Directory gui = Directory(path.join(temporary.path, "gui"));
    final Directory helper = Directory(path.join(temporary.path, "helper"));
    final Directory output = Directory(path.join(temporary.path, "output"));
    await _file(root: gui, name: "Framework/Versions/A/native", contents: "framework");
    await Link(path.join(gui.path, "Framework/Versions/Current")).create("A");
    await _file(root: helper, name: "bin/bridge", contents: "#!/bin/sh\necho staged-helper\n");
    final ProcessResult chmod = await Process.run("chmod", ["755", path.join(helper.path, "bin/bridge")]);
    expect(chmod.exitCode, 0);
    await stageDesktopBundle(
      gui: gui,
      helper: helper,
      destination: output,
      identity: const DesktopBundleIdentity(
        version: "1.8.4",
        buildNumber: 1,
        sourceSha: "source",
        os: DesktopBundleOs.linux,
        architecture: DesktopBundleArchitecture.x64,
      ),
    );
    expect(await Link(path.join(output.path, "Framework/Versions/Current")).target(), "A");
    final ProcessResult executable = await Process.run(path.join(output.path, "bridge/bin/bridge"), []);
    expect(executable.exitCode, 0);
    expect(executable.stdout, contains("staged-helper"));
  }, skip: Platform.isWindows ? "Unix framework/permission behavior" : false);
}

Future<void> _file({required Directory root, required String name, required String contents}) async {
  final File file = File(path.join(root.path, name));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
