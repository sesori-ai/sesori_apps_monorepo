import 'dart:convert';
import 'dart:io';

const List<String> _bridgePackageManifests = <String>[
  'bridge/app/npm/sesori-bridge/package.json',
  'bridge/app/npm/sesori-bridge-darwin-arm64/package.json',
  'bridge/app/npm/sesori-bridge-darwin-x64/package.json',
  'bridge/app/npm/sesori-bridge-linux-arm64/package.json',
  'bridge/app/npm/sesori-bridge-linux-x64/package.json',
  'bridge/app/npm/sesori-bridge-win32-x64/package.json',
];

final RegExp _semverPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
final RegExp _mobileVersionPattern = RegExp(r'^(\d+\.\d+\.\d+)(?:\+(\d+))?$');
final RegExp _pubspecVersionPattern = RegExp(
  r'^version:\s*([^#\s]+)\s*$',
  multiLine: true,
);
final RegExp _versionDartPattern = RegExp(
  r"^const String appVersion = '([^']+)';$",
  multiLine: true,
);

class _CliError implements Exception {
  const _CliError(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.dryRun,
    required this.type,
    required this.version,
  });

  final bool dryRun;
  final String? type;
  final String? version;
}

class _MobileVersion {
  const _MobileVersion({required this.semver, required this.build});

  final String semver;
  final String? build;
}

Future<void> main(final List<String> args) async {
  try {
    final parsed = _parseArgs(args);
    final repoRoot = Directory(
      File(Platform.script.toFilePath()).parent.parent.path,
    ).path;
    final mobilePubspecPath = _join(repoRoot, <String>[
      'mobile',
      'app',
      'pubspec.yaml',
    ]);
    final bridgePubspecPath = _join(repoRoot, <String>[
      'bridge',
      'app',
      'pubspec.yaml',
    ]);
    final bridgeVersionDartPath = _join(repoRoot, <String>[
      'bridge',
      'app',
      'lib',
      'src',
      'version.dart',
    ]);

    final mobileVersion = _readMobileVersion(
      await _readFile(path: mobilePubspecPath),
    );
    final bridgeCurrentVersion = _readBridgeVersion(
      await _readFile(path: bridgePubspecPath),
    );

    // Only enforce sync guard for automatic bumps; explicit --version can realign.
    if (parsed.version == null && mobileVersion.semver != bridgeCurrentVersion) {
      throw _CliError(
        'Error: Bridge ($bridgeCurrentVersion) and mobile (${mobileVersion.semver}) versions are out of sync. '
        'Run `make bump-version VERSION=${mobileVersion.semver}` to align them before bumping.',
      );
    }

    final targetBridgeVersion =
        parsed.version ??
        _bumpVersion(baseVersion: mobileVersion.semver, type: parsed.type!);
    _validateSemver(version: targetBridgeVersion);

    final targetMobileVersion = mobileVersion.build != null
        ? '$targetBridgeVersion+${mobileVersion.build}'
        : targetBridgeVersion;

    final plannedPaths = <String>[
      'bridge/app/pubspec.yaml',
      'bridge/app/lib/src/version.dart',
      ..._bridgePackageManifests,
      'mobile/app/pubspec.yaml',
    ];

    if (parsed.dryRun) {
      stdout.writeln('Target bridge version: $targetBridgeVersion');
      stdout.writeln('Target mobile version: $targetMobileVersion');
      stdout.writeln('Planned releaseTag: bridge-v$targetBridgeVersion');
      stdout.writeln('Files that would change:');
      for (final relativePath in plannedPaths) {
        stdout.writeln('  - $relativePath');
      }
      stdout.writeln('Dry run: no files were modified.');
      return;
    }

    await _writePubspecVersion(
      path: bridgePubspecPath,
      newVersion: targetBridgeVersion,
    );
    await _writeVersionDart(
      path: bridgeVersionDartPath,
      newVersion: targetBridgeVersion,
    );
    for (final relativePath in _bridgePackageManifests) {
      await _writePackageJson(
        path: _join(repoRoot, relativePath.split('/')),
        oldVersion: bridgeCurrentVersion,
        newVersion: targetBridgeVersion,
      );
    }
    await _writePubspecVersion(
      path: mobilePubspecPath,
      newVersion: targetMobileVersion,
    );

    stdout.writeln(
      'Synced bridge version: $bridgeCurrentVersion -> $targetBridgeVersion',
    );
    stdout.writeln(
      'Synced mobile version: ${mobileVersion.semver}${mobileVersion.build != null ? "+${mobileVersion.build}" : ""} -> $targetMobileVersion',
    );
  } on _CliError catch (error) {
    stderr.writeln(error.message);
    exit(1);
  } on Object catch (error) {
    stderr.writeln('Error: $error');
    exit(1);
  }
}

_ParsedArgs _parseArgs(final List<String> args) {
  bool dryRun = false;
  String? type;
  String? version;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--dry-run') {
      dryRun = true;
      continue;
    }

    if (arg.startsWith('--type=')) {
      type = _valueFromFlag(arg, '--type=');
      continue;
    }

    if (arg == '--type') {
      index = _consumeNextValue(
        args: args,
        index: index,
        flag: '--type',
        assign: (final value) => type = value,
      );
      continue;
    }

    if (arg.startsWith('--version=')) {
      version = _valueFromFlag(arg, '--version=');
      continue;
    }

    if (arg == '--version') {
      index = _consumeNextValue(
        args: args,
        index: index,
        flag: '--version',
        assign: (final value) => version = value,
      );
      continue;
    }

    throw _CliError('Error: Unexpected argument "$arg"');
  }

  if ((type == null && version == null) || (type != null && version != null)) {
    throw _CliError('Error: Provide exactly one of --type or --version');
  }

  if (type != null) {
    switch (type) {
      case 'patch':
      case 'minor':
      case 'major':
        break;
      default:
        throw _CliError('Error: Invalid type "$type"');
    }
  } else {
    _validateSemver(version: version!);
  }

  return _ParsedArgs(dryRun: dryRun, type: type, version: version);
}

int _consumeNextValue({
  required List<String> args,
  required int index,
  required String flag,
  required void Function(String value) assign,
}) {
  final nextIndex = index + 1;
  if (nextIndex >= args.length) {
    throw _CliError('Error: Missing value for $flag');
  }
  final value = args[nextIndex];
  if (value.startsWith('--')) {
    throw _CliError('Error: Missing value for $flag');
  }
  assign(value);
  return nextIndex;
}

String _valueFromFlag(final String arg, final String prefix) {
  final value = arg.substring(prefix.length);
  if (value.isEmpty) {
    throw _CliError(
      'Error: Missing value for ${prefix.substring(0, prefix.length - 1)}',
    );
  }
  return value;
}

String _join(final String root, final List<String> segments) {
  var path = root;
  for (final segment in segments) {
    path = '$path${Platform.pathSeparator}$segment';
  }
  return path;
}

Future<String> _readFile({required String path}) => File(path).readAsString();

Future<void> _writeFile({required String path, required String content}) =>
    File(path).writeAsString(content);

_MobileVersion _readMobileVersion(final String content) {
  final match = _pubspecVersionPattern.firstMatch(content);
  if (match == null) {
    throw const _CliError('Error: Could not find version in mobile pubspec');
  }

  final rawVersion = match.group(1)!;
  final parsed = _mobileVersionPattern.firstMatch(rawVersion);
  if (parsed == null) {
    throw _CliError('Error: Invalid mobile version "$rawVersion"');
  }

  return _MobileVersion(semver: parsed.group(1)!, build: parsed.group(2));
}

String _readBridgeVersion(final String content) {
  final match = _pubspecVersionPattern.firstMatch(content);
  if (match == null) {
    throw const _CliError('Error: Could not find version in bridge pubspec');
  }

  final version = match.group(1)!;
  _validateSemver(version: version);
  return version;
}

void _validateSemver({required String? version}) {
  if (version == null || _semverPattern.firstMatch(version) == null) {
    throw _CliError('Error: Invalid semver "$version"');
  }
}

String _bumpVersion({required String baseVersion, required String type}) {
  final match = _semverPattern.firstMatch(baseVersion);
  if (match == null) {
    throw _CliError('Error: Invalid mobile semver "$baseVersion"');
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);

  switch (type) {
    case 'patch':
      return '$major.$minor.${patch + 1}';
    case 'minor':
      return '$major.${minor + 1}.0';
    case 'major':
      return '${major + 1}.0.0';
    default:
      throw _CliError('Error: Invalid type "$type"');
  }
}

Future<void> _writePubspecVersion({
  required String path,
  required String newVersion,
}) async {
  final content = await _readFile(path: path);
  if (!_pubspecVersionPattern.hasMatch(content)) {
    throw _CliError('Error: Could not update pubspec version at $path');
  }
  final updated = content.replaceFirst(
    _pubspecVersionPattern,
    'version: $newVersion',
  );
  if (updated != content) {
    await _writeFile(path: path, content: updated);
  }
}

Future<void> _writeVersionDart({
  required String path,
  required String newVersion,
}) async {
  final content = await _readFile(path: path);
  if (!_versionDartPattern.hasMatch(content)) {
    throw _CliError('Error: Could not update version.dart at $path');
  }
  final updated = content.replaceFirst(
    _versionDartPattern,
    "const String appVersion = '$newVersion';",
  );
  if (updated != content) {
    await _writeFile(path: path, content: updated);
  }
}

Future<void> _writePackageJson({
  required String path,
  required String oldVersion,
  required String newVersion,
}) async {
  final content = await _readFile(path: path);
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw _CliError('Error: Invalid package.json at $path');
  }

  decoded['version'] = newVersion;

  final optionalDependencies = decoded['optionalDependencies'];
  if (optionalDependencies is Map<String, dynamic>) {
    optionalDependencies.updateAll(
      (final _, final value) => value == oldVersion ? newVersion : value,
    );
  }

  final sesoriBridge = decoded['sesoriBridge'];
  if (sesoriBridge is Map<String, dynamic> &&
      sesoriBridge.containsKey('releaseTag')) {
    sesoriBridge['releaseTag'] = 'bridge-v$newVersion';
  }

  final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
  await _writeFile(path: path, content: '$formatted\n');
}
