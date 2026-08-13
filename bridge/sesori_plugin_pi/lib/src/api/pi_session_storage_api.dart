import "dart:convert" show utf8;
import "dart:io";
import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/pi_session_metadata_dto.dart";

final class const PiSessionMetadata({
  required final String id,
  required final String cwd,
  required final String? parentId,
  required final String? title,
  required final DateTime? createdAt,
  required final DateTime updatedAt,
});

final class const PiSessionStorageConflictException({
  required final String sessionId,
  required final String firstPath,
  required final String secondPath,
}) implements Exception {
  @override
  String toString() => "More than one Pi session file declares session id $sessionId: '$firstPath' and '$secondPath'";
}

class PiSessionStorageApi({required Map<String, String> environment}) {
  static const int metadataRecordByteLimit = 1024 * 1024;
  static const int metadataDiscriminatorByteLimit = 256;
  static const int settingsByteLimit = 1024 * 1024;
  static const int externalParentLimit = 256;
  static const int externalParentHeaderByteLimit = 1024 * 1024;
  static const int diagnosticFailureLimit = 32;

  final Map<String, String> _environment = Map.unmodifiable(environment);

  Future<List<PiSessionMetadata>> listSessionMetadata({required Set<String> knownDirectories}) async {
    final result = await _scan(knownDirectories: knownDirectories);
    return result.sessions;
  }

  Future<String?> resolveSessionPath({required String sessionId, required Set<String> knownDirectories}) async {
    final result = await _scan(knownDirectories: knownDirectories);
    return result.pathsById[sessionId];
  }

  Future<String?> resolveEffectiveSessionDirectory({required String directory}) async {
    final environment = _environment;
    final result = await Isolate.run(
      () => _resolveEffectiveSessionDirectory(environment: environment, directory: directory),
    );
    _logDiagnostics(result.diagnostics);
    return result.path;
  }

  Future<_PiScanResult> _scan({required Set<String> knownDirectories}) async {
    final environment = _environment;
    final directories = Set<String>.of(knownDirectories);
    final result = await Isolate.run(
      () => _scanPiSessions(environment: environment, knownDirectories: directories),
    );
    _logDiagnostics(result.diagnostics);
    return result;
  }

  void _logDiagnostics(_PiScanDiagnostics diagnostics) {
    for (final failure in diagnostics.malformedMetadataFailures) {
      final validationReason = switch (failure.error) {
        _PiInvalidSessionHeaderException(:final reason) => ": $reason",
        _ => "",
      };
      Log.w(
        "[pi] skipped malformed session metadata$validationReason at '${failure.path}'",
        _PiMetadataParseException(cause: failure.error),
        failure.stackTrace,
      );
    }
    final unreportedMalformedMetadata =
        diagnostics.malformedMetadataRecords - diagnostics.malformedMetadataFailures.length;
    if (unreportedMalformedMetadata > 0) {
      Log.w("[pi] skipped $unreportedMalformedMetadata additional malformed session metadata record(s)");
    }
    for (final path in diagnostics.oversizedMetadataPaths) {
      Log.w("[pi] skipped oversized session metadata record at '$path'");
    }
    final unreportedOversizedMetadata =
        diagnostics.oversizedMetadataRecords - diagnostics.oversizedMetadataPaths.length;
    if (unreportedOversizedMetadata > 0) {
      Log.w("[pi] skipped $unreportedOversizedMetadata additional oversized session metadata record(s)");
    }
    for (final failure in diagnostics.storageFailures) {
      Log.w(
        "[pi] failed to ${failure.operation} at '${failure.path}'; continuing",
        failure.error,
        failure.stackTrace,
      );
    }
    final unreportedFailures = diagnostics.unreadableStorageEntries - diagnostics.storageFailures.length;
    if (unreportedFailures > 0) {
      Log.w("[pi] skipped $unreportedFailures additional unreadable session storage entry/entries");
    }
    for (final failure in diagnostics.malformedSettingsFailures) {
      Log.w(
        "[pi] ignored malformed session settings at '${failure.path}'",
        _PiSettingsParseException(cause: failure.error),
        failure.stackTrace,
      );
    }
    final unreportedMalformedSettings =
        diagnostics.malformedSettingsFiles - diagnostics.malformedSettingsFailures.length;
    if (unreportedMalformedSettings > 0) {
      Log.w("[pi] ignored $unreportedMalformedSettings additional malformed session settings file(s)");
    }
    for (final path in diagnostics.oversizedSettingsPaths) {
      Log.w("[pi] ignored oversized session settings at '$path'");
    }
    final unreportedOversizedSettings =
        diagnostics.oversizedSettingsFiles - diagnostics.oversizedSettingsPaths.length;
    if (unreportedOversizedSettings > 0) {
      Log.w("[pi] ignored $unreportedOversizedSettings additional oversized session settings file(s)");
    }
    if (diagnostics.externalParentLimitReached) {
      Log.w("[pi] stopped resolving external session parents at metadata scan bound");
    }
    if (diagnostics.oversizedExternalParentHeaders > 0) {
      Log.w(
        "[pi] skipped ${diagnostics.oversizedExternalParentHeaders} external parent session header(s) "
        "beyond the byte scan bound",
      );
    }
  }
}

_PiScanResult _scanPiSessions({
  required Map<String, String> environment,
  required Set<String> knownDirectories,
}) {
  final diagnostics = _PiScanDiagnostics();
  final layout = _buildStorageLayout(
    environment: environment,
    knownDirectories: knownDirectories,
    diagnostics: diagnostics,
  );
  final candidatePaths = <String>{};
  for (final root in layout.roots) {
    switch (root.kind) {
      case _PiScanRootKind.flat:
        candidatePaths.addAll(_listJsonlFiles(directoryPath: root.path, diagnostics: diagnostics));
      case _PiScanRootKind.defaultTree:
        for (final child in _listDirectories(directoryPath: root.path, diagnostics: diagnostics)) {
          candidatePaths.addAll(_listJsonlFiles(directoryPath: child, diagnostics: diagnostics));
        }
    }
  }

  final byPath = <String, _PiScannedSession>{};
  for (final path in candidatePaths) {
    final session = _readSessionMetadata(path: path, scanSessionInfo: true, diagnostics: diagnostics);
    if (session != null) byPath[session.path] = session;
  }

  final pendingParents = <String>[
    for (final session in byPath.values) ?session.parentPath,
  ];
  var externalParentsRead = 0;
  while (pendingParents.isNotEmpty) {
    final parentPath = pendingParents.removeLast();
    if (byPath.containsKey(parentPath)) continue;
    if (externalParentsRead == PiSessionStorageApi.externalParentLimit) {
      diagnostics.externalParentLimitReached = true;
      break;
    }
    externalParentsRead += 1;
    final parent = _readSessionMetadata(path: parentPath, scanSessionInfo: false, diagnostics: diagnostics);
    if (parent == null) continue;
    byPath[parent.path] = parent;
    if (parent.parentPath case final ancestorPath?) pendingParents.add(ancestorPath);
  }

  final pathsById = <String, String>{};
  for (final session in byPath.values) {
    final previous = pathsById[session.id];
    if (previous != null && previous != session.path) {
      throw PiSessionStorageConflictException(
        sessionId: session.id,
        firstPath: previous,
        secondPath: session.path,
      );
    }
    pathsById[session.id] = session.path;
  }

  final sessions = [
    for (final session in byPath.values)
      PiSessionMetadata(
        id: session.id,
        cwd: session.cwd,
        parentId: session.parentPath == null ? null : byPath[session.parentPath]?.id,
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      ),
  ];
  sessions.sort((left, right) {
    final timeOrder = right.updatedAt.compareTo(left.updatedAt);
    return timeOrder == 0 ? left.id.compareTo(right.id) : timeOrder;
  });
  return _PiScanResult(
    sessions: List.unmodifiable(sessions),
    pathsById: Map.unmodifiable(pathsById),
    diagnostics: diagnostics,
  );
}

_PiEffectiveDirectoryResult _resolveEffectiveSessionDirectory({
  required Map<String, String> environment,
  required String directory,
}) {
  final diagnostics = _PiScanDiagnostics();
  final home = resolveUserHomeDirectory(environment: environment);
  final cwd = _absolute(directory);
  final environmentSessionDirectory = _pathValue(environment["PI_CODING_AGENT_SESSION_DIR"]);
  if (environmentSessionDirectory != null) {
    return _PiEffectiveDirectoryResult(
      path: _resolvePath(value: environmentSessionDirectory, home: home, baseDirectory: cwd),
      diagnostics: diagnostics,
    );
  }

  final projectSettings = _readSettings(
    path: p.join(cwd, ".pi", "settings.json"),
    diagnostics: diagnostics,
  );
  if (projectSettings case _PiSettingsConfigured(:final sessionDirectory)) {
    final configuredPath = _pathValue(sessionDirectory);
    if (configuredPath != null) {
      return _PiEffectiveDirectoryResult(
        path: _resolvePath(value: configuredPath, home: home, baseDirectory: cwd),
        diagnostics: diagnostics,
      );
    }
  }
  final agentDirectory = _resolveAgentDirectory(
    environment: environment,
    home: home,
    baseDirectory: cwd,
  );
  if (agentDirectory == null) {
    return _PiEffectiveDirectoryResult(path: null, diagnostics: diagnostics);
  }
  final globalSettings = _readSettings(
    path: p.join(agentDirectory, "settings.json"),
    diagnostics: diagnostics,
  );
  final configured = switch (projectSettings) {
    _PiSettingsConfigured(:final sessionDirectory) => sessionDirectory,
    _PiSettingsAbsent() => switch (globalSettings) {
      _PiSettingsConfigured(:final sessionDirectory) => sessionDirectory,
      _PiSettingsAbsent() => null,
    },
  };
  final configuredPath = _pathValue(configured);
  return _PiEffectiveDirectoryResult(
    path: configuredPath == null
        ? _defaultSessionDirectory(cwd: cwd, agentDirectory: agentDirectory)
        : _resolvePath(value: configuredPath, home: home, baseDirectory: cwd),
    diagnostics: diagnostics,
  );
}

_PiStorageLayout _buildStorageLayout({
  required Map<String, String> environment,
  required Set<String> knownDirectories,
  required _PiScanDiagnostics diagnostics,
}) {
  final home = resolveUserHomeDirectory(environment: environment);
  final bases = knownDirectories.map(_absolute).toSet().toList()..sort();
  final scopes = <_PiAgentScope>[];
  final scopeKeys = <String>{};
  final scopeBases = bases.isEmpty ? const <String?>[null] : bases;
  for (final base in scopeBases) {
    final agentDirectory = _resolveAgentDirectory(
      environment: environment,
      home: home,
      baseDirectory: base,
    );
    if (agentDirectory == null) continue;
    final key = "$agentDirectory\u0000${base ?? ""}";
    if (scopeKeys.add(key)) scopes.add(_PiAgentScope(agentDirectory: agentDirectory, baseDirectory: base));
  }

  final roots = <_PiScanRoot>[];
  final rootKeys = <String>{};
  void addRoot({required String? path, required _PiScanRootKind kind}) {
    if (path == null) return;
    final key = "${kind.name}\u0000$path";
    if (rootKeys.add(key)) roots.add(_PiScanRoot(path: path, kind: kind));
  }

  final environmentSessionDirectory = _pathValue(environment["PI_CODING_AGENT_SESSION_DIR"]);
  if (environmentSessionDirectory != null) {
    if (bases.isEmpty) {
      addRoot(
        path: _resolvePath(value: environmentSessionDirectory, home: home, baseDirectory: null),
        kind: _PiScanRootKind.flat,
      );
    } else {
      for (final base in bases) {
        addRoot(
          path: _resolvePath(value: environmentSessionDirectory, home: home, baseDirectory: base),
          kind: _PiScanRootKind.flat,
        );
      }
    }
  }

  final globalSettingsByPath = <String, _PiSettingsValue>{};
  for (final base in bases) {
    final projectSettings = _readSettings(
      path: p.join(base, ".pi", "settings.json"),
      diagnostics: diagnostics,
    );
    if (projectSettings case _PiSettingsConfigured(:final sessionDirectory)) {
      addRoot(
        path: _resolvePath(
          value: _pathValue(sessionDirectory),
          home: home,
          baseDirectory: base,
        ),
        kind: _PiScanRootKind.flat,
      );
    }
  }
  for (final scope in scopes) {
    final settingsPath = p.join(scope.agentDirectory, "settings.json");
    final settings = globalSettingsByPath.putIfAbsent(
      settingsPath,
      () => _readSettings(path: settingsPath, diagnostics: diagnostics),
    );
    if (settings case _PiSettingsConfigured(:final sessionDirectory)) {
      addRoot(
        path: _resolvePath(
          value: _pathValue(sessionDirectory),
          home: home,
          baseDirectory: scope.baseDirectory,
        ),
        kind: _PiScanRootKind.flat,
      );
    }
  }
  for (final agentDirectory in scopes.map((scope) => scope.agentDirectory).toSet()) {
    addRoot(path: p.join(agentDirectory, "sessions"), kind: _PiScanRootKind.defaultTree);
  }
  for (final scope in scopes) {
    final base = scope.baseDirectory;
    if (base == null) continue;
    addRoot(
      path: _defaultSessionDirectory(cwd: base, agentDirectory: scope.agentDirectory),
      kind: _PiScanRootKind.flat,
    );
  }
  return _PiStorageLayout(roots: List.unmodifiable(roots));
}

_PiScannedSession? _readSessionMetadata({
  required String path,
  required bool scanSessionInfo,
  required _PiScanDiagnostics diagnostics,
}) {
  final normalizedPath = _absolute(path);
  final resolvedPath = _resolveExistingFilePath(
    path: normalizedPath,
    operation: "resolve Pi session file",
    diagnostics: diagnostics,
  );
  if (resolvedPath == null) return null;
  final file = File(resolvedPath);
  RandomAccessFile? handle;
  try {
    final updatedAt = file.lastModifiedSync().toUtc();
    handle = file.openSync();
    final scanner = _PiMetadataLineScanner();
    PiSessionHeaderDto? header;
    String? title;
    var invalidBeforeHeader = false;
    var externalHeaderBytesRemaining = PiSessionStorageApi.externalParentHeaderByteLimit;
    var externalHeaderLimitReached = false;

    void consume(_PiScannedLine line, {required bool isFinal}) {
      switch (line) {
        case _PiScannedLineIgnored():
          return;
        case _PiScannedLineNonMetadata():
          if (header == null) invalidBeforeHeader = true;
          return;
        case _PiScannedLineOversizedMetadata():
          diagnostics.recordOversizedMetadata(path: resolvedPath);
          if (header == null) invalidBeforeHeader = true;
          return;
        case _PiScannedLineMetadata(:final bytes):
          final PiSessionMetadataDto record;
          try {
            record = PiSessionMetadataDto.fromJson(jsonDecodeMap(utf8.decode(bytes)));
          } on Object catch (error, stackTrace) {
            if (!isFinal) {
              diagnostics.recordMalformedMetadata(
                path: resolvedPath,
                error: error,
                stackTrace: stackTrace,
              );
            }
            return;
          }
          switch (record) {
            case PiSessionHeaderDto():
              if (header != null || invalidBeforeHeader) return;
              final id = _pathValue(record.id);
              final cwd = _pathValue(record.cwd);
              if (id == null || cwd == null || !p.isAbsolute(cwd)) {
                diagnostics.recordMalformedMetadata(
                  path: resolvedPath,
                  error: _PiInvalidSessionHeaderException(
                    reason: id == null
                        ? "invalid session id"
                        : cwd == null
                        ? "invalid working directory"
                        : "non-absolute working directory",
                  ),
                  stackTrace: StackTrace.current,
                );
                invalidBeforeHeader = true;
                return;
              }
              header = record;
            case PiSessionInfoDto():
              if (header == null) {
                invalidBeforeHeader = true;
                return;
              }
              title = _trimmedNonEmpty(record.name);
          }
      }
    }

    scan:
    while (true) {
      final readLength = scanSessionInfo
          ? 8192
          : (externalHeaderBytesRemaining + 1).clamp(1, 8192);
      final chunk = handle.readSync(readLength);
      if (chunk.isEmpty) break;
      final consumedLength = scanSessionInfo
          ? chunk.length
          : chunk.length.clamp(0, externalHeaderBytesRemaining);
      for (var index = 0; index < consumedLength; index += 1) {
        final byte = chunk[index];
        if (byte == 0x0A) {
          consume(scanner.finish(), isFinal: false);
          if (!scanSessionInfo && header != null) break scan;
        } else {
          scanner.add(byte);
        }
      }
      if (!scanSessionInfo) {
        externalHeaderBytesRemaining -= consumedLength;
        if (chunk.length > consumedLength) {
          externalHeaderLimitReached = true;
          break;
        }
      }
    }
    if (externalHeaderLimitReached) {
      diagnostics.oversizedExternalParentHeaders += 1;
      return null;
    }
    if (scanner.hasBytes) consume(scanner.finish(), isFinal: true);
    final parsedHeader = header;
    final id = _pathValue(parsedHeader?.id);
    final cwd = _pathValue(parsedHeader?.cwd);
    if (parsedHeader == null || id == null || cwd == null || !p.isAbsolute(cwd) || invalidBeforeHeader) return null;
    final parentValue = _pathValue(parsedHeader.parentSession);
    return _PiScannedSession(
      path: resolvedPath,
      id: id,
      cwd: _absolute(cwd),
      parentPath: parentValue == null || !p.isAbsolute(parentValue)
          ? null
          : _resolveExistingFilePath(
              path: parentValue,
              operation: "resolve Pi parent session file",
              diagnostics: diagnostics,
            ),
      title: title,
      createdAt: parsedHeader.timestamp,
      updatedAt: updatedAt,
    );
  } on Object catch (error, stackTrace) {
    diagnostics.recordStorageFailure(
      operation: "read Pi session metadata",
      path: resolvedPath,
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  } finally {
    try {
      handle?.closeSync();
    } on Object catch (error, stackTrace) {
      diagnostics.recordStorageFailure(
        operation: "close Pi session file",
        path: resolvedPath,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

List<String> _listJsonlFiles({required String directoryPath, required _PiScanDiagnostics diagnostics}) {
  final directory = Directory(directoryPath);
  try {
    if (!directory.existsSync()) return const [];
    final paths = <String>[];
    for (final entity in directory.listSync(followLinks: false)) {
      final path = _absolute(entity.path);
      if (!p.basename(path).endsWith(".jsonl")) continue;
      final resolvedPath = _resolveExistingFilePath(
        path: path,
        operation: "resolve Pi session file",
        diagnostics: diagnostics,
      );
      if (resolvedPath != null) paths.add(resolvedPath);
    }
    paths.sort();
    return paths;
  } on Object catch (error, stackTrace) {
    diagnostics.recordStorageFailure(
      operation: "list Pi session files",
      path: directoryPath,
      error: error,
      stackTrace: stackTrace,
    );
    return const [];
  }
}

List<String> _listDirectories({required String directoryPath, required _PiScanDiagnostics diagnostics}) {
  final directory = Directory(directoryPath);
  try {
    if (!directory.existsSync()) return const [];
    final paths = <String>[];
    for (final entity in directory.listSync(followLinks: false)) {
      final path = _absolute(entity.path);
      if (FileSystemEntity.typeSync(path, followLinks: true) == FileSystemEntityType.directory) paths.add(path);
    }
    paths.sort();
    return paths;
  } on Object catch (error, stackTrace) {
    diagnostics.recordStorageFailure(
      operation: "list Pi session directories",
      path: directoryPath,
      error: error,
      stackTrace: stackTrace,
    );
    return const [];
  }
}

_PiSettingsValue _readSettings({required String path, required _PiScanDiagnostics diagnostics}) {
  final normalizedPath = _absolute(path);
  final file = File(normalizedPath);
  RandomAccessFile? handle;
  late final List<int> bytes;
  try {
    if (!file.existsSync()) return const _PiSettingsAbsent();
    handle = file.openSync();
    bytes = handle.readSync(PiSessionStorageApi.settingsByteLimit + 1);
  } on Object catch (error, stackTrace) {
    diagnostics.recordStorageFailure(
      operation: "read Pi session settings",
      path: normalizedPath,
      error: error,
      stackTrace: stackTrace,
    );
    return const _PiSettingsAbsent();
  } finally {
    try {
      handle?.closeSync();
    } on Object catch (error, stackTrace) {
      diagnostics.recordStorageFailure(
        operation: "close Pi session settings",
        path: normalizedPath,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  if (bytes.length > PiSessionStorageApi.settingsByteLimit) {
    diagnostics.recordOversizedSettings(path: normalizedPath);
    return const _PiSettingsAbsent();
  }
  try {
    final json = jsonDecodeMap(utf8.decode(bytes));
    final settings = PiSettingsDto.fromJson(json);
    return json.containsKey("sessionDir")
        ? _PiSettingsConfigured(sessionDirectory: settings.sessionDir)
        : const _PiSettingsAbsent();
  } on Object catch (error, stackTrace) {
    diagnostics.recordMalformedSettings(
      path: normalizedPath,
      error: error,
      stackTrace: stackTrace,
    );
    return const _PiSettingsAbsent();
  }
}

String? _resolveExistingFilePath({
  required String path,
  required String operation,
  required _PiScanDiagnostics diagnostics,
}) {
  final normalizedPath = _absolute(path);
  try {
    final type = FileSystemEntity.typeSync(normalizedPath, followLinks: true);
    if (type != FileSystemEntityType.file) {
      if (type != FileSystemEntityType.notFound ||
          FileSystemEntity.typeSync(normalizedPath, followLinks: false) != FileSystemEntityType.link) {
        return null;
      }
    }
    return _absolute(File(normalizedPath).resolveSymbolicLinksSync());
  } on Object catch (error, stackTrace) {
    diagnostics.recordStorageFailure(
      operation: operation,
      path: normalizedPath,
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

String? _resolveAgentDirectory({
  required Map<String, String> environment,
  required String? home,
  required String? baseDirectory,
}) {
  final explicit = _pathValue(environment["PI_CODING_AGENT_DIR"]);
  if (explicit != null) return _resolvePath(value: explicit, home: home, baseDirectory: baseDirectory);
  return home == null ? null : _absolute(p.join(home, ".pi", "agent"));
}

String _defaultSessionDirectory({required String cwd, required String agentDirectory}) {
  final resolvedCwd = _absolute(cwd);
  final withoutLeadingSeparator = resolvedCwd.startsWith("/") || resolvedCwd.codeUnitAt(0) == 0x5C
      ? resolvedCwd.substring(1)
      : resolvedCwd;
  final safePath = "--${withoutLeadingSeparator.replaceAll(RegExp(r"[/\\:]"), "-")}--";
  return _absolute(p.join(agentDirectory, "sessions", safePath));
}

String? _resolvePath({required String? value, required String? home, required String? baseDirectory}) {
  if (value == null) return null;
  var expanded = value;
  if (expanded == "~") {
    if (home == null) return null;
    expanded = home;
  } else if (expanded.startsWith("~/") ||
      (expanded.length >= 2 && expanded.codeUnitAt(0) == 0x7E && expanded.codeUnitAt(1) == 0x5C)) {
    if (home == null) return null;
    expanded = p.join(home, expanded.substring(2));
  }
  if (p.isAbsolute(expanded)) return _absolute(expanded);
  return baseDirectory == null ? null : _absoluteFrom(value: expanded, baseDirectory: baseDirectory);
}

String _absolute(String value) => p.normalize(p.absolute(value));

String _absoluteFrom({required String value, required String baseDirectory}) =>
    p.normalize(p.join(p.absolute(baseDirectory), value));

String? _pathValue(String? value) => value == null || value.trim().isEmpty ? null : value;

String? _trimmedNonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

enum _PiScanRootKind() {
  flat,
  defaultTree,
}

enum _PiLineClassification() {
  pending,
  ignored,
  nonMetadata,
  metadata,
}

final class const _PiScanRoot({required final String path, required final _PiScanRootKind kind});

final class const _PiStorageLayout({required final List<_PiScanRoot> roots});

final class const _PiAgentScope({required final String agentDirectory, required final String? baseDirectory});

sealed class const _PiSettingsValue();

final class const _PiSettingsAbsent() extends _PiSettingsValue;

final class const _PiSettingsConfigured({required final String? sessionDirectory}) extends _PiSettingsValue;

sealed class const _PiScannedLine();

final class const _PiScannedLineIgnored() extends _PiScannedLine;

final class const _PiScannedLineNonMetadata() extends _PiScannedLine;

final class const _PiScannedLineMetadata({required final List<int> bytes}) extends _PiScannedLine;

final class const _PiScannedLineOversizedMetadata() extends _PiScannedLine;

final class const _PiScannedSession({
  required final String path,
  required final String id,
  required final String cwd,
  required final String? parentPath,
  required final String? title,
  required final DateTime? createdAt,
  required final DateTime updatedAt,
});

final class const _PiScanResult({
  required final List<PiSessionMetadata> sessions,
  required final Map<String, String> pathsById,
  required final _PiScanDiagnostics diagnostics,
});

final class const _PiEffectiveDirectoryResult({
  required final String? path,
  required final _PiScanDiagnostics diagnostics,
});

final class _PiScanDiagnostics() {
  int malformedMetadataRecords = 0;
  int oversizedMetadataRecords = 0;
  int unreadableStorageEntries = 0;
  int malformedSettingsFiles = 0;
  int oversizedSettingsFiles = 0;
  int oversizedExternalParentHeaders = 0;
  bool externalParentLimitReached = false;
  final List<_PiStorageFailure> storageFailures = [];
  final List<_PiStorageFailure> malformedMetadataFailures = [];
  final List<String> oversizedMetadataPaths = [];
  final List<_PiStorageFailure> malformedSettingsFailures = [];
  final List<String> oversizedSettingsPaths = [];

  void recordStorageFailure({
    required String operation,
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    unreadableStorageEntries += 1;
    if (storageFailures.length >= PiSessionStorageApi.diagnosticFailureLimit) return;
    storageFailures.add(
      _PiStorageFailure(
        operation: operation,
        path: path,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void recordMalformedSettings({
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    malformedSettingsFiles += 1;
    if (malformedSettingsFailures.length >= PiSessionStorageApi.diagnosticFailureLimit) return;
    malformedSettingsFailures.add(
      _PiStorageFailure(
        operation: "parse Pi session settings",
        path: path,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void recordMalformedMetadata({
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    malformedMetadataRecords += 1;
    if (malformedMetadataFailures.length >= PiSessionStorageApi.diagnosticFailureLimit) return;
    malformedMetadataFailures.add(
      _PiStorageFailure(
        operation: "parse Pi session metadata",
        path: path,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void recordOversizedMetadata({required String path}) {
    oversizedMetadataRecords += 1;
    if (oversizedMetadataPaths.length < PiSessionStorageApi.diagnosticFailureLimit) {
      oversizedMetadataPaths.add(path);
    }
  }

  void recordOversizedSettings({required String path}) {
    oversizedSettingsFiles += 1;
    if (oversizedSettingsPaths.length < PiSessionStorageApi.diagnosticFailureLimit) {
      oversizedSettingsPaths.add(path);
    }
  }
}

final class const _PiStorageFailure({
  required final String operation,
  required final String path,
  required final Object error,
  required final StackTrace stackTrace,
});

final class const _PiSettingsParseException({required final Object cause}) implements Exception {
  @override
  String toString() => "Invalid Pi session settings";
}

final class const _PiMetadataParseException({required final Object cause}) implements Exception {
  @override
  String toString() => "Invalid Pi session metadata";
}

final class const _PiInvalidSessionHeaderException({required final String reason}) implements Exception {
  @override
  String toString() => "Invalid Pi session header: $reason";
}

final class _PiMetadataLineScanner() {
  final List<int> _prefix = [];
  List<int>? _metadataBytes;
  _PiLineClassification _classification = _PiLineClassification.pending;
  bool _oversized = false;
  bool _sawByte = false;

  bool get hasBytes => _sawByte;

  void add(int byte) {
    _sawByte = true;
    if (_classification == _PiLineClassification.pending) {
      if (_prefix.length == PiSessionStorageApi.metadataDiscriminatorByteLimit) {
        _classification = _PiLineClassification.ignored;
        return;
      }
      _prefix.add(byte);
      _classification = _classifyPrefix(_prefix);
      if (_classification == _PiLineClassification.metadata) {
        _metadataBytes = List<int>.of(_prefix);
      }
      return;
    }
    if (_classification != _PiLineClassification.metadata || _oversized) return;
    final metadataBytes = _metadataBytes!;
    if (metadataBytes.length == PiSessionStorageApi.metadataRecordByteLimit) {
      _oversized = true;
      _metadataBytes = null;
      return;
    }
    metadataBytes.add(byte);
  }

  _PiScannedLine finish() {
    final result = switch ((_classification, _oversized)) {
      (_, true) => const _PiScannedLineOversizedMetadata(),
      (_PiLineClassification.metadata, false) => _PiScannedLineMetadata(
          bytes: List<int>.unmodifiable(_metadataBytes!),
        ),
      (_PiLineClassification.nonMetadata, false) => const _PiScannedLineNonMetadata(),
      (_PiLineClassification.pending || _PiLineClassification.ignored, false) => const _PiScannedLineIgnored(),
    };
    _prefix.clear();
    _metadataBytes = null;
    _classification = _PiLineClassification.pending;
    _oversized = false;
    _sawByte = false;
    return result;
  }

  _PiLineClassification _classifyPrefix(List<int> bytes) {
    var index = 0;
    while (index < bytes.length && _isJsonWhitespace(bytes[index])) {
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    if (bytes[index] != 0x7B) return _PiLineClassification.ignored;
    index += 1;
    while (index < bytes.length && _isJsonWhitespace(bytes[index])) {
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    if (bytes[index] != 0x22) return _PiLineClassification.ignored;
    index += 1;
    const key = [0x74, 0x79, 0x70, 0x65];
    for (final expected in key) {
      if (index == bytes.length) return _PiLineClassification.pending;
      if (bytes[index] != expected) return _PiLineClassification.ignored;
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    if (bytes[index] != 0x22) return _PiLineClassification.ignored;
    index += 1;
    while (index < bytes.length && _isJsonWhitespace(bytes[index])) {
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    if (bytes[index] != 0x3A) return _PiLineClassification.ignored;
    index += 1;
    while (index < bytes.length && _isJsonWhitespace(bytes[index])) {
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    if (bytes[index] != 0x22) return _PiLineClassification.ignored;
    index += 1;
    final value = <int>[];
    while (index < bytes.length && bytes[index] != 0x22) {
      if (bytes[index] == 0x5C) return _PiLineClassification.nonMetadata;
      value.add(bytes[index]);
      index += 1;
    }
    if (index == bytes.length) return _PiLineClassification.pending;
    final type = String.fromCharCodes(value);
    return type == "session" || type == "session_info"
        ? _PiLineClassification.metadata
        : _PiLineClassification.nonMetadata;
  }

  bool _isJsonWhitespace(int byte) => byte == 0x20 || byte == 0x09 || byte == 0x0D;
}
