import "dart:convert";
import "dart:ffi";
import "dart:io";

import "package:args/args.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

DesktopReleaseChannel parseDesktopReleaseChannel({required String value}) => DesktopReleaseChannel.values.byName(value);

String desktopBundleDefines({required DesktopBundleIdentity identity, required DesktopReleaseChannel channel}) =>
    "${DesktopBundleIdentity.defineName}=${identity.encode()}\n${DesktopReleaseChannel.defineName}=${channel.name}\n";

ArgParser desktopBundleArgumentParser() => ArgParser()
  ..addOption("build-number", help: "Required positive desktop build number.")
  ..addOption("channel", allowed: DesktopReleaseChannel.values.map((channel) => channel.name), defaultsTo: "stable")
  ..addOption("output", help: "Required new output directory; existing directories are never replaced.");

/// Builds both components from this checkout and stages an unsigned native
/// desktop bundle. Signing/installers remain platform-specific subsequent steps.
Future<void> main(List<String> arguments) async {
  final ArgParser parser = desktopBundleArgumentParser();
  try {
    final ArgResults options = parser.parse(arguments);
    final String? numberOption = options.option("build-number");
    final String? outputOption = options.option("output");
    if (numberOption == null || outputOption == null) {
      throw ArgumentError("Both --build-number and --output are required");
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
    final Directory desktop = File(Platform.script.toFilePath()).parent.parent;
    final Directory root = desktop.parent.parent;
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
      architecture: DesktopBundleArchitecture.fromAbi(abi: Abi.current()),
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
    await _build(
      executable: Platform.resolvedExecutable,
      arguments: ["pub", "get", "--enforce-lockfile"],
      directory: bridge.parent,
    );
    await _build(executable: flutter, arguments: ["pub", "get", "--enforce-lockfile"], directory: desktop.parent);
    await _build(
      executable: Platform.resolvedExecutable,
      arguments: ["build", "cli", "-o", "build/cli"],
      directory: bridge,
    );
    final Directory helper = Directory(path.join(bridge.path, "build", "cli", "bundle"));
    final String bridgeName = identity.os == DesktopBundleOs.windows ? "bridge.exe" : "bridge";
    final String helperVersion = await _capture(
      executable: path.join(helper.path, "bin", bridgeName),
      arguments: ["--version"],
      directory: root,
    );
    if (helperVersion != version) {
      throw StateError("Built helper reports $helperVersion, expected $version");
    }
    await _build(
      executable: flutter,
      arguments: [
        "build",
        identity.os.name,
        "--release",
        "--build-name=$version",
        "--build-number=$buildNumber",
        "--dart-define-from-file=${defines.path}",
      ],
      directory: desktop,
    );
    await _capture(
      executable: "git",
      arguments: ["diff", "--exit-code", "--", "bridge/pubspec.lock", "client/pubspec.lock"],
      directory: root,
    );
    final String guiRelativePath = switch (identity.os) {
      DesktopBundleOs.macos => "macos/Build/Products/Release/Sesori.app",
      DesktopBundleOs.windows => "windows/${identity.architecture.name}/runner/Release",
      DesktopBundleOs.linux => "linux/${identity.architecture.name}/release/bundle",
    };
    final Directory stagedGui = Directory(
      path.join(output.path, identity.os == DesktopBundleOs.macos ? "Sesori.app" : "bundle"),
    );
    await stageDesktopBundle(
      gui: Directory(path.join(desktop.path, "build", guiRelativePath)),
      helper: helper,
      destination: stagedGui,
      identity: identity,
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

/// Preserves the GUI and complete CLI bundle, including native libraries and
/// framework symlinks. The caller builds both with [identity] from one checkout.
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

Future<void> _build({required String executable, required List<String> arguments, required Directory directory}) async {
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory.path,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final int result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, "Build failed; see output above", result);
  }
}
