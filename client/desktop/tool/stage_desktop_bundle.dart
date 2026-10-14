import "dart:convert";
import "dart:ffi";
import "dart:io";

import "package:args/args.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

DesktopReleaseChannel parseDesktopReleaseChannel({required String value}) => DesktopReleaseChannel.values.byName(value);

String desktopBundleDefines({required DesktopBundleIdentity identity, required DesktopReleaseChannel channel}) =>
    "${DesktopBundleIdentity.defineName}=${identity.encode()}\n${DesktopReleaseChannel.defineName}=${channel.name}\n";

enum DesktopBundleBuildMode() {
  native,
  gui,
  probe,
  assemble,
}

ArgParser desktopBundleArgumentParser() => ArgParser()
  ..addOption(
    "mode",
    allowed: DesktopBundleBuildMode.values.map((mode) => mode.name),
    defaultsTo: DesktopBundleBuildMode.native.name,
  )
  ..addOption("architecture", allowed: DesktopBundleArchitecture.values.map((architecture) => architecture.name))
  ..addOption("gui-input", help: "Prepared macOS GUI directory, required by assemble mode.")
  ..addOption("source-root", help: "Committed product checkout; defaults to this tool's checkout.")
  ..addOption("build-number", help: "Required positive desktop build number.")
  ..addOption("channel", allowed: DesktopReleaseChannel.values.map((channel) => channel.name), defaultsTo: "stable")
  ..addOption("output", help: "Required new output directory; existing directories are never replaced.");

DesktopBundleArchitecture desktopBuildArchitecture({
  required DesktopBundleBuildMode mode,
  required DesktopBundleArchitecture nativeArchitecture,
  required String? targetArchitecture,
}) {
  switch (mode) {
    case DesktopBundleBuildMode.gui || DesktopBundleBuildMode.probe:
      if (targetArchitecture == null) throw ArgumentError("GUI/probe builds require --architecture");
      return DesktopBundleArchitecture.values.byName(targetArchitecture);
    case DesktopBundleBuildMode.native || DesktopBundleBuildMode.assemble:
      if (targetArchitecture != null) throw ArgumentError("Helper builds must use the native host architecture");
      return nativeArchitecture;
  }
}

String macosXcodeArchitecture({required DesktopBundleArchitecture architecture}) => switch (architecture) {
  DesktopBundleArchitecture.x64 => "x86_64",
  DesktopBundleArchitecture.arm64 => "arm64",
};

/// Builds a complete native bundle, or hands macOS GUI/probe builds from an ARM
/// compiler to a native helper/packaging host. No operation signs or installs.
Future<void> main(List<String> arguments) async {
  final ArgParser parser = desktopBundleArgumentParser();
  try {
    final ArgResults options = parser.parse(arguments);
    final String? numberOption = options.option("build-number");
    final String? outputOption = options.option("output");
    if (numberOption == null || outputOption == null) {
      throw ArgumentError("Both --build-number and --output are required");
    }
    final DesktopBundleBuildMode mode = DesktopBundleBuildMode.values.byName(
      options.option("mode") ?? DesktopBundleBuildMode.native.name,
    );
    if (mode != DesktopBundleBuildMode.native && !Platform.isMacOS) {
      throw UnsupportedError("Split GUI builds are macOS-only");
    }
    final DesktopReleaseChannel channel = parseDesktopReleaseChannel(
      value: options.option("channel") ?? DesktopReleaseChannel.stable.name,
    );
    final int buildNumber = int.parse(numberOption);
    if (buildNumber < 1) {
      throw ArgumentError.value(buildNumber, "build-number", "Must be positive");
    }
    final Directory output = Directory(path.absolute(outputOption));
    if (output.existsSync()) {
      throw StateError("Output already exists: ${output.path}. Choose a new staging directory.");
    }
    final String? sourceOption = options.option("source-root");
    final Directory root = sourceOption == null
        ? File(Platform.script.toFilePath()).parent.parent.parent.parent
        : Directory(path.absolute(sourceOption));
    final Directory desktop = Directory(path.join(root.path, "client", "desktop"));
    final Directory bridge = Directory(path.join(root.path, "bridge", "app"));
    await validateDesktopBundleSource(root: root);
    final String version = _version(pubspec: File(path.join(desktop.path, "pubspec.yaml")));
    if (_version(pubspec: File(path.join(bridge.path, "pubspec.yaml"))) != version) {
      throw StateError("Desktop and bridge versions differ. Run make bump-version VERSION=$version to align them.");
    }
    final DesktopBundleIdentity identity = DesktopBundleIdentity(
      version: version,
      buildNumber: buildNumber,
      sourceSha: await _capture(executable: "git", arguments: ["rev-parse", "HEAD"], directory: root),
      os: DesktopBundleOs.values.byName(Platform.operatingSystem),
      architecture: desktopBuildArchitecture(
        mode: mode,
        nativeArchitecture: DesktopBundleArchitecture.fromAbi(abi: Abi.current()),
        targetArchitecture: options.option("architecture"),
      ),
    );
    await output.create(recursive: true);
    // A dotenv file avoids shell-dependent escaping of JSON in Flutter's command
    // line, especially through flutter.bat on Windows. Values come from the model.
    final File defines = File(path.join(output.path, "dart-defines.env"));
    await defines.writeAsString(
      desktopBundleDefines(identity: identity, channel: channel),
      encoding: utf8,
    );
    // Use the Flutter SDK that supplied this Dart VM, not a second SDK on PATH.
    final String flutter = path.join(
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path,
      Platform.isWindows ? "flutter.bat" : "flutter",
    );
    final Directory gui;
    if (mode == DesktopBundleBuildMode.assemble) {
      final String? input = options.option("gui-input");
      if (input == null) throw ArgumentError("Assembly requires --gui-input");
      gui = await preparedDesktopGui(directory: Directory(path.absolute(input)), identity: identity, channel: channel);
    } else {
      if (options.wasParsed("gui-input")) throw ArgumentError("--gui-input is only valid for assembly");
      gui = await _buildGui(
        desktop: desktop,
        flutter: flutter,
        identity: identity,
        defines: defines,
        platformProbe: mode == DesktopBundleBuildMode.probe,
      );
    }
    final Directory stagedGui = Directory(
      path.join(output.path, identity.os == DesktopBundleOs.macos ? "Sesori.app" : "bundle"),
    );
    switch (mode) {
      case DesktopBundleBuildMode.gui || DesktopBundleBuildMode.probe:
        await _copyDirectory(source: gui, destination: stagedGui);
      case DesktopBundleBuildMode.native || DesktopBundleBuildMode.assemble:
        final Directory helper = await _buildHelper(bridge: bridge, identity: identity);
        await stageDesktopBundle(gui: gui, helper: helper, destination: stagedGui, identity: identity);
    }
    await _capture(
      executable: "git",
      arguments: ["diff", "--exit-code", "--", "bridge/pubspec.lock", "client/pubspec.lock"],
      directory: root,
    );
    // Flutter may regenerate tracked native project files on a host. Keep the
    // actual diff, not just a dirty bit; do not call this a clean signed release.
    final String buildChanges = await _capture(executable: "git", arguments: ["diff", "HEAD"], directory: root);
    await File(path.join(output.path, "build-source-changes.patch")).writeAsString(buildChanges, encoding: utf8);
    stdout.writeln("Staged unsigned ${identity.os.name}/${identity.architecture.name}: ${stagedGui.path}");
    stdout.writeln("Identity: ${identity.encode()}");
    if (buildChanges.isNotEmpty) {
      stdout.writeln("Build-generated source changes recorded in ${output.path}/build-source-changes.patch");
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    stderr.writeln(parser.usage);
    exitCode = 1;
  }
}

/// A same-run GUI must match the native assembler's committed source and channel.
/// No new manifest schema: compare the exact typed defines passed to Flutter.
Future<Directory> preparedDesktopGui({
  required Directory directory,
  required DesktopBundleIdentity identity,
  required DesktopReleaseChannel channel,
}) async {
  final String defines = await File(path.join(directory.path, "dart-defines.env")).readAsString(encoding: utf8);
  if (defines != desktopBundleDefines(identity: identity, channel: channel)) {
    throw StateError("Prepared GUI identity/channel differs from the selected product: ${directory.path}");
  }
  final String changes = await File(path.join(directory.path, "build-source-changes.patch"))
      .readAsString(encoding: utf8);
  if (changes.isNotEmpty) throw StateError("Prepared GUI contains build-generated source changes: ${directory.path}");
  return Directory(path.join(directory.path, "Sesori.app"));
}

Future<Directory> _buildGui({
  required Directory desktop,
  required String flutter,
  required DesktopBundleIdentity identity,
  required File defines,
  required bool platformProbe,
}) async {
  await _build(
    executable: flutter,
    arguments: ["pub", "get", "--enforce-lockfile"],
    directory: desktop.parent,
    environment: {},
  );
  await _build(
    executable: flutter,
    arguments: [
      "build",
      identity.os.name,
      "--release",
      "--no-pub",
      "--build-name=${identity.version}",
      "--build-number=${identity.buildNumber}",
      "--dart-define-from-file=${defines.path}",
      if (platformProbe) ...["--target", "test/native/packaged_platform_probe.dart"],
    ],
    directory: desktop,
    environment: {
      if (identity.os == DesktopBundleOs.macos)
        "FLUTTER_XCODE_ARCHS": macosXcodeArchitecture(architecture: identity.architecture),
    },
  );
  final String guiRelativePath = switch (identity.os) {
    DesktopBundleOs.macos => "macos/Build/Products/Release/Sesori.app",
    DesktopBundleOs.windows => "windows/${identity.architecture.name}/runner/Release",
    DesktopBundleOs.linux => "linux/${identity.architecture.name}/release/bundle",
  };
  return Directory(path.join(desktop.path, "build", guiRelativePath));
}

Future<Directory> _buildHelper({required Directory bridge, required DesktopBundleIdentity identity}) async {
  await _build(
    executable: Platform.resolvedExecutable,
    arguments: ["pub", "get", "--enforce-lockfile"],
    directory: bridge.parent,
    environment: {},
  );
  await _build(
    executable: Platform.resolvedExecutable,
    arguments: ["build", "cli", "-o", "build/cli"],
    directory: bridge,
    environment: {},
  );
  final Directory helper = Directory(path.join(bridge.path, "build", "cli", "bundle"));
  final String bridgeName = identity.os == DesktopBundleOs.windows ? "bridge.exe" : "bridge";
  final String helperVersion = await _capture(
    executable: path.join(helper.path, "bin", bridgeName),
    arguments: ["--version"],
    directory: bridge,
  );
  if (helperVersion != identity.version) {
    throw StateError("Built helper reports $helperVersion, expected ${identity.version}");
  }
  return helper;
}

/// Preserves the GUI and complete native CLI bundle, including native libraries
/// and framework symlinks. The compiled GUI and helper share [identity].
Future<void> stageDesktopBundle({
  required Directory gui,
  required Directory helper,
  required Directory destination,
  required DesktopBundleIdentity identity,
}) async {
  if (destination.existsSync()) {
    throw StateError("Staging destination already exists: ${destination.path}");
  }
  await _copyDirectory(source: gui, destination: destination);
  final Directory stagedHelper = Directory(
    identity.os == DesktopBundleOs.macos
        ? path.join(destination.path, "Contents", "Helpers", "bridge")
        : path.join(destination.path, "bridge"),
  );
  await _copyDirectory(source: helper, destination: stagedHelper);
  // macOS treats Helpers as code-only; the identity is a sealed app resource.
  final Directory manifestDirectory = identity.os == DesktopBundleOs.macos
      ? Directory(path.join(destination.path, "Contents", "Resources"))
      : stagedHelper;
  await manifestDirectory.create(recursive: true);
  await File(path.join(manifestDirectory.path, DesktopBundleIdentity.manifestName)).writeAsString(
    "${identity.encode()}\n",
    encoding: utf8,
  );
}

Future<void> _copyDirectory({required Directory source, required Directory destination}) async {
  await destination.create(recursive: true);
  await for (final FileSystemEntity entity in source.list(followLinks: false)) {
    final String target = path.join(destination.path, path.basename(entity.path));
    switch (entity) {
      case Link():
        await Link(target).create(await entity.target());
      case Directory():
        await _copyDirectory(source: entity, destination: Directory(target));
      case File():
        await entity.copy(target);
    }
  }
}

/// Requires committed source without mistaking Git checkout metadata for edits.
Future<void> validateDesktopBundleSource({required Directory root}) async {
  // With autocrlf, regenerating LF files can leave status reporting stat-only
  // changes. Compare canonical tracked content without modifying the Git index.
  final String tracked = await _capture(
    executable: "git",
    arguments: ["diff", "--name-only", "HEAD"],
    directory: root,
  );
  final String untracked = await _capture(
    executable: "git",
    arguments: ["ls-files", "--others", "--exclude-standard"],
    directory: root,
  );
  final String dirty = [tracked, untracked].where((String files) => files.isNotEmpty).join("\n");
  if (dirty.isNotEmpty) {
    throw StateError("Commit source changes before building a versioned desktop bundle:\n$dirty");
  }
}

String _version({required File pubspec}) {
  final String? version = RegExp(
    r"^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$",
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())?.group(1);
  if (version == null) {
    throw FormatException("Missing semantic version in ${pubspec.path}");
  }
  return version;
}

Future<String> _capture({
  required String executable,
  required List<String> arguments,
  required Directory directory,
}) async {
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: directory.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  final String errors = result.stderr.toString();
  if (result.exitCode != 0) {
    throw ProcessException(executable, arguments, "$errors${result.stdout.toString()}", result.exitCode);
  }
  if (errors.isNotEmpty) {
    stderr.write(errors);
  }
  return result.stdout.toString().trim();
}

Future<void> _build({
  required String executable,
  required List<String> arguments,
  required Directory directory,
  required Map<String, String> environment,
}) async {
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory.path,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final int result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, "Build failed; see output above", result);
  }
}
