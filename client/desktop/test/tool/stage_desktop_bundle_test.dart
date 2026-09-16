import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "../../tool/stage_desktop_bundle.dart"
    show
        desktopBundleArgumentParser,
        desktopBundleDefines,
        parseDesktopReleaseChannel,
        stageDesktopBundle,
        validateDesktopBundleSource;

void main() {
  late Directory temporary;
  setUp(() async => temporary = await Directory.systemTemp.createTemp("desktop staging "));
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test("staging defaults to stable and rejects unknown channels before building", () {
    final parser = desktopBundleArgumentParser();
    expect(parser.parse([]).option("channel"), "stable");
    expect(parser.parse(["--channel", "internal"]).option("channel"), "internal");
    expect(() => parser.parse(["--channel", "preview"]), throwsFormatException);
    expect(() => parseDesktopReleaseChannel(value: "preview"), throwsArgumentError);
  });

  for (final channel in DesktopReleaseChannel.values) {
    test("${channel.name} define remains separate from the unchanged bundle identity", () {
      const identity = DesktopBundleIdentity(
        version: "1.8.4",
        buildNumber: 24,
        sourceSha: "source",
        os: DesktopBundleOs.macos,
        architecture: DesktopBundleArchitecture.arm64,
      );
      expect(parseDesktopReleaseChannel(value: channel.name), channel);
      expect(
        desktopBundleDefines(identity: identity, channel: channel),
        "${DesktopBundleIdentity.defineName}=${identity.encode()}\n${DesktopReleaseChannel.defineName}=${channel.name}\n",
      );
      expect(identity.toJson().containsKey("channel"), isFalse);
    });
  }

  test("accepts unchanged LF source regenerated after an autocrlf checkout", () async {
    final File source = await _committedSource(root: temporary);
    await source.writeAsString("");
    await _git(root: temporary, arguments: ["checkout", "--", "source.dart"]);
    expect(await source.readAsString(), "committed\r\n");
    await source.writeAsString("committed\n");
    await expectLater(validateDesktopBundleSource(root: temporary), completes);
  });

  test("rejects tracked, staged, deleted and untracked source changes", () async {
    final File source = await _committedSource(root: temporary);
    await source.writeAsString("changed\n");
    await expectLater(validateDesktopBundleSource(root: temporary), throwsStateError);
    await _git(root: temporary, arguments: ["add", "source.dart"]);
    await expectLater(validateDesktopBundleSource(root: temporary), throwsStateError);
    await source.writeAsString("committed\n");
    await _git(root: temporary, arguments: ["add", "source.dart"]);
    await source.delete();
    await expectLater(validateDesktopBundleSource(root: temporary), throwsStateError);
    await source.writeAsString("committed\n");
    await expectLater(validateDesktopBundleSource(root: temporary), completes);
    await _file(root: temporary, name: "untracked.dart", contents: "uncommitted\n");
    await expectLater(validateDesktopBundleSource(root: temporary), throwsStateError);
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
      final String manifestDirectory = os == DesktopBundleOs.macos
          ? path.join(output.path, "Contents", "Resources")
          : helperRoot;
      expect(
        DesktopBundleIdentity.decode(
          encoded: await File(path.join(manifestDirectory, DesktopBundleIdentity.manifestName)).readAsString(),
        ),
        identity,
      );
      if (os == DesktopBundleOs.macos) {
        // Data in this code-only subtree prevents signing the enclosing app.
        expect(File(path.join(helperRoot, DesktopBundleIdentity.manifestName)).existsSync(), isFalse);
      }
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

Future<File> _committedSource({required Directory root}) async {
  await _git(root: root, arguments: ["init", "--quiet"]);
  await _git(root: root, arguments: ["config", "core.autocrlf", "true"]);
  final File source = File(path.join(root.path, "source.dart"));
  await source.writeAsString("committed\n");
  await _git(root: root, arguments: ["add", "source.dart"]);
  await _git(root: root, arguments: ["commit", "--quiet", "-m", "fixture"]);
  return source;
}

Future<void> _git({required Directory root, required List<String> arguments}) async {
  final ProcessResult result = await Process.run("git", [
    "-c",
    "user.name=Fixture",
    "-c",
    "user.email=fixture@example.invalid",
    "-c",
    "commit.gpgsign=false",
    "-c",
    "core.hooksPath=${path.join(root.path, "no-hooks")}",
    ...arguments,
  ], workingDirectory: root.path);
  expect(result.exitCode, 0, reason: result.stderr.toString());
}

Future<void> _file({required Directory root, required String name, required String contents}) async {
  final File file = File(path.join(root.path, name));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
