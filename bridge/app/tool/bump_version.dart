import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Validates that a version string is valid semver (X.Y.Z).
/// Returns true if valid, false otherwise.
bool isValidSemver({required String version}) {
  final parts = version.split('.');
  if (parts.length != 3) {
    return false;
  }

  for (final part in parts) {
    if (part.isEmpty) {
      return false;
    }
    final num = int.tryParse(part);
    if (num == null || num < 0) {
      return false;
    }
  }

  return true;
}

/// Reads a file and returns its content as a string.
Future<String> readFile({required String path}) async {
  return File(path).readAsString();
}

/// Writes content to a file.
Future<void> writeFile({required String path, required String content}) async {
  await File(path).writeAsString(content);
}

/// Updates the version in pubspec.yaml.
Future<void> updatePubspec({
  required String appDir,
  required String oldVersion,
  required String newVersion,
}) async {
  final filePath = p.join(appDir, 'pubspec.yaml');
  final content = await readFile(path: filePath);
  final updated = content.replaceFirst(
    'version: $oldVersion',
    'version: $newVersion',
  );
  await writeFile(path: filePath, content: updated);
}

/// Updates the version in lib/src/version.dart.
Future<void> updateVersionDart({
  required String appDir,
  required String oldVersion,
  required String newVersion,
}) async {
  final filePath = p.join(appDir, 'lib', 'src', 'version.dart');
  final content = await readFile(path: filePath);
  final updated = content.replaceFirst(
    "const String appVersion = '$oldVersion';",
    "const String appVersion = '$newVersion';",
  );
  await writeFile(path: filePath, content: updated);
}

/// Updates the version in a package.json file.
Future<void> updatePackageJson({
  required String path,
  required String oldVersion,
  required String newVersion,
}) async {
  final content = await readFile(path: path);
  final json = jsonDecode(content) as Map<String, dynamic>;

  // Update main version field
  json['version'] = newVersion;

  // Update optionalDependencies if present
  if (json.containsKey('optionalDependencies')) {
    final optionalDeps = json['optionalDependencies'] as Map<String, dynamic>;
    optionalDeps.updateAll((final key, final value) {
      if (value == oldVersion) {
        return newVersion;
      }
      return value;
    });
  }

  if (json.containsKey('sesoriBridge')) {
    final metadata = json['sesoriBridge'] as Map<String, dynamic>;
    if (metadata['releaseTag'] == 'bridge-v$oldVersion') {
      metadata['releaseTag'] = 'bridge-v$newVersion';
    }
  }

  // Write back with 2-space indent and trailing newline
  final formatted = const JsonEncoder.withIndent('  ').convert(json);
  await writeFile(path: path, content: '$formatted\n');
}

Future<void> main(final List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/bump_version.dart <version>');
    stderr.writeln('Example: dart run tool/bump_version.dart 0.3.0');
    exit(1);
  }

  final newVersion = args[0];

  // Validate semver
  if (!isValidSemver(version: newVersion)) {
    stderr.writeln('Error: Invalid version format "$newVersion"');
    stderr.writeln('Expected format: X.Y.Z (e.g., 0.3.0)');
    exit(1);
  }

  // Determine app directory (script is in bridge/app/tool/)
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final appDir = File(scriptDir).parent.path;

  // Read current version from pubspec.yaml
  final pubspecPath = p.join(appDir, 'pubspec.yaml');
  final pubspecContent = await readFile(path: pubspecPath);
  final versionMatch = RegExp('version: (.+)').firstMatch(pubspecContent);
  if (versionMatch == null) {
    stderr.writeln('Error: Could not find version in pubspec.yaml');
    exit(1);
  }

  final oldVersion = versionMatch.group(1)!.trim();

  if (oldVersion == newVersion) {
    stderr.writeln('Error: New version is the same as current version ($oldVersion)');
    exit(1);
  }

  try {
    // Update all 8 files
    await updatePubspec(appDir: appDir, oldVersion: oldVersion, newVersion: newVersion);
    await updateVersionDart(appDir: appDir, oldVersion: oldVersion, newVersion: newVersion);

    // Update wrapper package.json
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );

    // Update platform-specific package.json files
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge-darwin-arm64', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge-darwin-x64', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge-linux-x64', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge-linux-arm64', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );
    await updatePackageJson(
      path: p.join(appDir, 'npm', 'sesori-bridge-win32-x64', 'package.json'),
      oldVersion: oldVersion,
      newVersion: newVersion,
    );

    // Print summary
    stdout.writeln('✓ Version bumped from $oldVersion to $newVersion');
    stdout.writeln('');
    stdout.writeln('Updated files:');
    stdout.writeln('  1. pubspec.yaml');
    stdout.writeln('  2. lib/src/version.dart');
    stdout.writeln('  3. npm/sesori-bridge/package.json');
    stdout.writeln('  4. npm/sesori-bridge-darwin-arm64/package.json');
    stdout.writeln('  5. npm/sesori-bridge-darwin-x64/package.json');
    stdout.writeln('  6. npm/sesori-bridge-linux-x64/package.json');
    stdout.writeln('  7. npm/sesori-bridge-linux-arm64/package.json');
    stdout.writeln('  8. npm/sesori-bridge-win32-x64/package.json');

    exit(0);
  } on Object catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
