import 'dart:convert';
import 'dart:io';

const List<String> _bridgePackageManifests = <String>[
  'bridge/app/npm/sesori-bridge/package.json',
  'bridge/app/npm/sesori-bridge-darwin-arm64/package.json',
  'bridge/app/npm/sesori-bridge-darwin-x64/package.json',
  'bridge/app/npm/sesori-bridge-linux-arm64/package.json',
  'bridge/app/npm/sesori-bridge-linux-x64/package.json',
  'bridge/app/npm/sesori-bridge-win32-arm64/package.json',
  'bridge/app/npm/sesori-bridge-win32-x64/package.json',
];

final RegExp _semverPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
final RegExp _clientVersionPattern = RegExp(r'^(\d+\.\d+\.\d+)(?:\+(\d+))?$');
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

class _ClientVersion {
  const _ClientVersion({required this.semver, required this.build});

  final String semver;
  final String? build;
}

Future<void> main(final List<String> args) async {
  try {
    final parsed = _parseArgs(args);
    final repoRoot = Directory(
      File(Platform.script.toFilePath()).parent.parent.path,
    ).path;
    final clientPubspecPath = _join(repoRoot, <String>[
      'client',
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

    final clientVersion = _readClientVersion(
      await _readFile(path: clientPubspecPath),
    );
    final bridgeCurrentVersion = _readBridgeVersion(
      await _readFile(path: bridgePubspecPath),
    );

    // Only enforce sync guard for automatic bumps; explicit --version can realign.
    if (parsed.version == null && clientVersion.semver != bridgeCurrentVersion) {
      throw _CliError(
        'Error: Bridge ($bridgeCurrentVersion) and client (${clientVersion.semver}) versions are out of sync. '
        'Run `make bump-version VERSION=${clientVersion.semver}` to align them before bumping.',
      );
    }

    final targetBridgeVersion =
        parsed.version ??
        _bumpVersion(baseVersion: clientVersion.semver, type: parsed.type!);
    _validateSemver(version: targetBridgeVersion);

    final targetClientVersion = clientVersion.build != null
        ? '$targetBridgeVersion+${clientVersion.build}'
        : targetBridgeVersion;

    final plannedPaths = <String>[
      'bridge/app/pubspec.yaml',
      'bridge/app/lib/src/version.dart',
      ..._bridgePackageManifests,
      'client/app/pubspec.yaml',
    ];

    if (parsed.dryRun) {
    stdout.writeln('Target bridge version: $targetBridgeVersion');
    stdout.writeln('Target client version: $targetClientVersion');
    stdout.writeln('Planned releaseTag: v$targetBridgeVersion');
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
      path: clientPubspecPath,
      newVersion: targetClientVersion,
    );

    stdout.writeln(
      'Synced bridge version: $bridgeCurrentVersion -> $targetBridgeVersion',
    );
    stdout.writeln(
      'Synced client version: ${clientVersion.semver}${clientVersion.build != null ? "+${clientVersion.build}" : ""} -> $targetClientVersion',
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

_ClientVersion _readClientVersion(final String content) {
  final match = _pubspecVersionPattern.firstMatch(content);
  if (match == null) {
    throw const _CliError('Error: Could not find version in client pubspec');
  }

  final rawVersion = match.group(1)!;
  final parsed = _clientVersionPattern.firstMatch(rawVersion);
  if (parsed == null) {
    throw _CliError('Error: Invalid client version "$rawVersion"');
  }

  return _ClientVersion(semver: parsed.group(1)!, build: parsed.group(2));
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
    throw _CliError('Error: Invalid client semver "$baseVersion"');
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
    sesoriBridge['releaseTag'] = 'v$newVersion';
  }

  final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
  await _writeFile(path: path, content: '$formatted\n');
}
