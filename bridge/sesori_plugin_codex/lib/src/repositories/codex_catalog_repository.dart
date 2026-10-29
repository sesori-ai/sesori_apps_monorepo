import "dart:async";
import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "mappers/codex_sub_agent_name_mapper.dart";
import "models/codex_session_record.dart";

/// Layer-2 aggregation, mapping, selection, and deletion for the rollout catalog.
class CodexCatalogRepository({required final CodexRolloutApi _rolloutApi}) {
  /// Every recognized rollout of the last scan by path, with its parsed
  /// header, so a rescan only parses new or growing rollouts.
  final Map<String, _CachedRollout> _rollouts = {};

  /// Session id to rollout path over [_rollouts].
  final Map<String, String> _pathsById = {};

  /// The session index as of the last scan; later index lines win.
  Map<String, CodexSessionIndexEntryDto> _indexById = const {};

  /// Every rollout-backed session, newest first. Listing, stats and header
  /// parses run in an isolate: a cold catalog decodes tens of megabytes.
  Future<List<CodexSessionRecord>> listSessionRecords() async {
    await _rescan();
    final records = <CodexSessionRecord>[];
    var unreadableOrMissingMetadata = 0;
    var mismatchedMetadata = 0;
    for (final MapEntry(key: id, value: rolloutPath) in _pathsById.entries) {
      final metadata = _rollouts[rolloutPath]?.parsed?.metadata;
      if (metadata == null) unreadableOrMissingMetadata++;
      if (metadata != null && metadata.id != id) mismatchedMetadata++;
      if (_cachedRecord(id: id, rolloutPath: rolloutPath) case final record?) records.add(record);
    }
    records.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    Log.d(
      "[codex] rollout catalog records: "
      "unreadableOrMissingMetadata=$unreadableOrMissingMetadata, "
      "mismatchedMetadata=$mismatchedMetadata, records=${records.length}",
    );
    return records;
  }

  /// Scans run one at a time so an older scan never replaces a newer one.
  Future<bool>? _scanInFlight;

  /// The one scan queued behind [_scanInFlight], shared by every caller that
  /// arrives meanwhile, so each of them sees the disk as of after its call.
  Future<bool>? _queuedScan;

  /// Rollouts deleted while the current scan runs; its result must not re-add
  /// them.
  final Set<String> _deletedDuringScan = {};

  /// Completes with false when the rollouts could not be listed; the last
  /// scan's state is then kept.
  Future<bool> _rescan() {
    final queued = _queuedScan;
    if (queued != null) return queued;
    final inFlight = _scanInFlight;
    if (inFlight == null) return _startScan();
    // The in-flight caller receives its error; the queued scan runs anyway.
    return _queuedScan = inFlight.then((_) {}, onError: (_) {}).then((_) {
      _queuedScan = null;
      return _startScan();
    });
  }

  Future<bool> _startScan() => _scanInFlight = _scan().whenComplete(() => _scanInFlight = null);

  /// Lists, stats and reads the index in an isolate that parses only new or
  /// grown headers, then replaces the cache with the result.
  Future<bool> _scan() async {
    _deletedDuringScan.clear();
    // Locals only: the isolate must not copy this repository's cache.
    final rolloutApi = _rolloutApi;
    final logLevel = Log.level;
    final known = {
      for (final MapEntry(:key, :value) in _rollouts.entries)
        if (value.parsed case final parsed?) key: parsed.shortFileLength,
    };
    final scan = await Isolate.run(() {
      Log.level = logLevel;
      return _scanRollouts(rolloutApi: rolloutApi, known: known);
    });
    if (scan == null) return false;
    final previous = Map.of(_rollouts);
    _rollouts.clear();
    _pathsById.clear();
    for (final MapEntry(key: path, value: modified) in scan.modifiedByPath.entries) {
      if (_deletedDuringScan.contains(path)) continue;
      final parsed = scan.parsed.containsKey(path) ? scan.parsed[path] : previous[path]?.parsed;
      _rollouts[path] = _CachedRollout(modified: modified, parsed: parsed);
      if (_sessionIdFromRolloutName(p.basename(path)) case final id?) _pathsById[id] = path;
    }
    _indexById = scan.indexById;
    Log.d(
      "[codex] rollout catalog scan: files=${scan.fileCount}, "
      "recognizedRollouts=${_pathsById.length}, "
      "parsedHeaders=${scan.parsed.length}, "
      "indexEntries=${scan.indexById.length}",
    );
    return true;
  }

  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final projectlessThreadIds = await _readProjectlessThreadIds();
    final normalizedKnownDirectories = {
      for (final directory in knownDirectories)
        if (directory.trim().isNotEmpty) normalizeProjectDirectory(directory: directory),
    };
    final documentsCodexDirectory = _rolloutApi.documentsCodexDirectory;
    final excludedDirectory = documentsCodexDirectory == null
        ? null
        : normalizeProjectDirectory(directory: documentsCodexDirectory);
    final records = await listSessionRecords();
    final sessions = <PluginSession>[];
    final projectDirectories = <String>{};
    var noiseExcluded = 0;
    var missingCwd = 0;
    for (final record in records) {
      if (_isExcludedFromDiscovery(
        record: record,
        projectlessThreadIds: projectlessThreadIds,
        documentsCodexDirectory: excludedDirectory,
        knownDirectories: normalizedKnownDirectories,
      )) {
        noiseExcluded++;
        continue;
      }
      final session = _toPluginSession(record);
      if (session == null) {
        missingCwd++;
      } else {
        sessions.add(session);
        projectDirectories.add(session.directory);
      }
    }
    Log.d(
      "[codex] catalog discovery: records=${records.length}, "
      "knownDirectories=${normalizedKnownDirectories.length}, "
      "noiseExcluded=$noiseExcluded, missingCwd=$missingCwd, "
      "projectDirectories=${projectDirectories.length}, "
      "sessions=${sessions.length}",
    );
    return sessions;
  }

  /// Lists root sessions only, filtered by normalized rollout CWD before
  /// applying pagination. Sub-agent rollouts are reachable through
  /// [getChildSessions] and [listAllSessions].
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await listSessionRecords();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
        .where((record) => record.parentId == null)
        .map(_toPluginSession)
        .nonNulls
        .where((session) => session.directory == target)
        .toList(growable: false);
    final from = (start ?? 0).clamp(0, sessions.length);
    final pageSize = limit?.clamp(0, sessions.length);
    final until = pageSize == null ? sessions.length : (from + pageSize).clamp(from, sessions.length);
    if (from >= sessions.length) return const [];
    return sessions.sublist(from, until);
  }

  /// Persisted sub-agent rollouts whose direct parent is [sessionId].
  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    final records = await listSessionRecords();
    return records
        .where((record) => record.parentId == sessionId)
        .map(_toPluginSession)
        .nonNulls
        .toList(growable: false);
  }

  /// A rollout path from the last scan, or from one rescan on a miss.
  Future<String?> findRolloutPath({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId)) await _rescan();
    return _pathsById[sessionId];
  }

  /// A session from the last scan, or from one rescan on a miss.
  Future<CodexSessionRecord?> findSessionById({required String sessionId}) async {
    final rolloutPath = await findRolloutPath(sessionId: sessionId);
    if (rolloutPath == null) return null;
    return _cachedRecord(id: sessionId, rolloutPath: rolloutPath);
  }

  /// [findSessionById] for callers that cannot wait. A miss queues a rescan
  /// and answers null; a later lookup sees its result. A connected plugin has
  /// scanned once, so only a session newer than that scan can miss.
  CodexSessionRecord? cachedSessionById({required String sessionId}) {
    final rolloutPath = _pathsById[sessionId];
    if (rolloutPath == null) {
      unawaited(
        _rescan().then(
          (_) {},
          onError: (Object error, StackTrace stackTrace) =>
              Log.w("[codex] rollout catalog rescan failed", error, stackTrace),
        ),
      );
      return null;
    }
    return _cachedRecord(id: sessionId, rolloutPath: rolloutPath);
  }

  /// A rollout from its creation-date directories only, for a live tail
  /// polling for a rollout Codex had not written when the tail started.
  String? findRecentRolloutPath({required String sessionId}) =>
      _rolloutApi.findRecentRolloutPath(sessionId: sessionId, now: DateTime.now());

  /// Deletes [sessionId]'s rollout and its session index lines, rescanning
  /// once when the last scan does not know the session. Returns false when
  /// the rollout's absence cannot be confirmed or a write fails.
  Future<bool> deleteSession({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId) && !await _rescan()) return false;
    final rolloutPath = _pathsById[sessionId];
    if (rolloutPath != null) {
      try {
        _rolloutApi.deleteRollout(rolloutPath: rolloutPath);
      } on Object catch (error, stackTrace) {
        Log.w("[codex] failed to delete rollout for $sessionId", error, stackTrace);
        return false;
      }
      _rollouts.remove(rolloutPath);
      _pathsById.remove(sessionId);
      _deletedDuringScan.add(rolloutPath);
    }

    final List<CodexSessionIndexLine> indexLines;
    try {
      indexLines = _rolloutApi.readSessionIndexLines();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to read the session index", error, stackTrace);
      return false;
    }
    final filtered = [
      for (final line in indexLines)
        if (line.entry?.id != sessionId) line.raw,
    ];
    if (filtered.length == indexLines.length) return true;
    try {
      _rolloutApi.writeSessionIndex(lines: filtered);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to remove $sessionId from the session index",
        error,
        stackTrace,
      );
      return false;
    }
    return true;
  }

  /// Null when the rollout's header names another session.
  CodexSessionRecord? _cachedRecord({required String id, required String rolloutPath}) {
    final rollout = _rollouts[rolloutPath];
    final metadata = rollout?.parsed?.metadata;
    if (metadata != null && metadata.id != id) {
      Log.w("[codex] rollout session id mismatch: filename=$id header=${metadata.id}");
      return null;
    }
    final indexEntry = _indexById[id];
    return CodexSessionRecord(
      id: id,
      rolloutPath: rolloutPath,
      cwd: metadata?.cwd,
      threadName: indexEntry?.threadName,
      createdAt: metadata?.timestamp,
      updatedAt: _latest(
        // Native turns append to the rollout without necessarily updating the
        // session index, so its modification time counts as activity too.
        [metadata?.timestamp, _tryParseDate(indexEntry?.updatedAt), rollout?.modified],
      ),
      cliVersion: metadata?.cliVersion,
      modelProvider: metadata?.modelProvider,
      model: metadata?.model,
      agentNickname: metadata?.agentNickname,
      agentPath: metadata?.agentPath,
      parentId: metadata?.parentId,
    );
  }

  DateTime? _latest(List<DateTime?> candidates) {
    DateTime? latest;
    for (final candidate in candidates.nonNulls) {
      if (latest == null || candidate.isAfter(latest)) latest = candidate;
    }
    return latest;
  }

  Future<Set<String>> _readProjectlessThreadIds() async {
    try {
      return (await _rolloutApi.readDesktopState()).projectlessThreadIds;
    } on CodexDesktopStateReadException catch (error, stackTrace) {
      Log.w(
        "[codex] Codex Desktop state is unreadable; continuing discovery without its projectless thread ids",
        error,
        stackTrace,
      );
      return const {};
    }
  }

  bool _isExcludedFromDiscovery({
    required CodexSessionRecord record,
    required Set<String> projectlessThreadIds,
    required String? documentsCodexDirectory,
    required Set<String> knownDirectories,
  }) {
    final cwd = record.cwd?.trim();
    String? directory;
    if (cwd != null && cwd.isNotEmpty) {
      directory = normalizeProjectDirectory(directory: cwd);
      if (knownDirectories.contains(directory)) return false;
    }
    if (projectlessThreadIds.contains(record.id)) return true;
    if (documentsCodexDirectory == null || directory == null) return false;
    return p.equals(directory, documentsCodexDirectory) || p.isWithin(documentsCodexDirectory, directory);
  }

  PluginSession? _toPluginSession(CodexSessionRecord record) {
    final cwd = record.cwd?.trim();
    if (cwd == null || cwd.isEmpty) return null;
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    final directory = normalizeProjectDirectory(directory: cwd);
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: record.parentId,
      title: record.parentId == null
          ? _usefulText(record.threadName)
          : const CodexSubAgentNameMapper().map(
              name: record.threadName,
              nickname: record.agentNickname,
              agentPath: record.agentPath,
            ),
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

  String? _usefulText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// A recognized rollout as of the last scan. [parsed] is null when its header
/// could not be read; the next scan retries it.
class const _CachedRollout({
  required final DateTime? modified,
  required final _ParsedRollout? parsed,
});

/// [modifiedByPath] holds one recognized rollout per session id; [parsed]
/// only the headers this scan read.
typedef _ScanResult = ({
  int fileCount,
  Map<String, DateTime?> modifiedByPath,
  Map<String, _ParsedRollout?> parsed,
  Map<String, CodexSessionIndexEntryDto> indexById,
});

/// Runs in the scan isolate: lists and stats every rollout, parses the
/// headers missing from [known] or grown past their known short length, and
/// reads the session index. Null when the rollouts could not be listed.
_ScanResult? _scanRollouts({
  required CodexRolloutApi rolloutApi,
  required Map<String, int?> known,
}) {
  final List<String> paths;
  try {
    paths = rolloutApi.listRolloutPaths();
  } on Object catch (error, stackTrace) {
    Log.w("[codex] failed to enumerate rollout files", error, stackTrace);
    return null;
  }
  // A later path wins when two rollouts claim the same session id.
  final pathsById = {
    for (final path in paths) ?_sessionIdFromRolloutName(p.basename(path)): path,
  };
  final modifiedByPath = <String, DateTime?>{};
  final parsed = <String, _ParsedRollout?>{};
  for (final path in pathsById.values) {
    try {
      modifiedByPath[path] = rolloutApi.lastModified(rolloutPath: path);
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to read rollout modification time for $path", error, stackTrace);
      modifiedByPath[path] = null;
    }
    final isCurrent =
        known.containsKey(path) &&
        switch (known[path]) {
          null => true,
          final shortFileLength => rolloutApi.rolloutLength(rolloutPath: path) == shortFileLength,
        };
    if (!isCurrent) parsed[path] = _parseRollout(rolloutApi: rolloutApi, rolloutPath: path);
  }
  return (
    fileCount: paths.length,
    modifiedByPath: modifiedByPath,
    parsed: parsed,
    indexById: _readSessionIndexById(rolloutApi: rolloutApi),
  );
}

/// Later index lines win, matching Codex's append-only index updates.
Map<String, CodexSessionIndexEntryDto> _readSessionIndexById({required CodexRolloutApi rolloutApi}) {
  final List<CodexSessionIndexEntryDto> entries;
  try {
    entries = rolloutApi.readSessionIndex();
  } on Object catch (error, stackTrace) {
    Log.w("[codex] failed to read the session index", error, stackTrace);
    return const {};
  }
  return {
    for (final entry in entries)
      if (entry.id case final id? when id.isNotEmpty) id: entry,
  };
}

String? _sessionIdFromRolloutName(String fileName) {
  if (!fileName.endsWith(".jsonl")) return null;
  final stem = fileName.substring(0, fileName.length - ".jsonl".length);
  final parts = stem.split("-");
  if (parts.length < 5) return null;
  final uuid = parts.sublist(parts.length - 5).join("-");
  return uuid.length == 36 ? uuid : null;
}

class const _CodexSessionMetadata({
  required final String id,
  required final String? cwd,
  required final DateTime? timestamp,
  required final String? modelProvider,
  required final String? model,
  required final String? cliVersion,
  required final String? agentNickname,
  required final String? agentPath,
  required final String? parentId,
});

/// A parsed rollout header. Rollouts are append-only, so a header that filled
/// its line window is final ([shortFileLength] null); a short one stays valid
/// only while the file keeps [shortFileLength] bytes.
class const _ParsedRollout({
  required final _CodexSessionMetadata? metadata,
  required final int? shortFileLength,
});

/// Null when the rollout could not be read. Top-level so the parsing isolate
/// captures only its arguments.
_ParsedRollout? _parseRollout({
  required CodexRolloutApi rolloutApi,
  required String rolloutPath,
}) {
  final CodexRolloutHeader header;
  try {
    header = rolloutApi.readHeader(rolloutPath: rolloutPath);
  } on Object catch (error, stackTrace) {
    Log.w("[codex] failed to read rollout metadata", error, stackTrace);
    return null;
  }

  String? id;
  String? cwd;
  DateTime? timestamp;
  String? modelProvider;
  String? cliVersion;
  String? model;
  String? agentNickname;
  String? agentPath;
  String? parentId;
  for (final line in header.lines) {
    switch (line) {
      case CodexRolloutSessionMetadataLineDto(:final payload):
        // Forked/subagent rollouts begin with their own metadata and then
        // include the parent's copied session metadata. The leading header
        // remains authoritative for the file.
        if (id != null) continue;
        final metadataId = payload.id;
        if (metadataId == null || metadataId.isEmpty) continue;
        id = metadataId;
        cwd = payload.cwd;
        timestamp = _tryParseDate(payload.timestamp);
        modelProvider = payload.modelProvider;
        cliVersion = payload.cliVersion;
        if (payload.threadSource == CodexRolloutThreadSource.subagent) {
          parentId = payload.parentThreadId;
          agentNickname = payload.agentNickname;
          agentPath = payload.agentPath;
        }
      case CodexRolloutTurnContextLineDto(:final payload):
        final candidate = payload.model;
        if (candidate != null && candidate.isNotEmpty) model = candidate;
      case CodexRolloutResponseItemLineDto() ||
          CodexRolloutEventMessageLineDto() ||
          CodexRolloutInterAgentCommunicationMetadataLineDto() ||
          CodexRolloutCompactedLineDto() ||
          CodexRolloutUnknownLineDto():
        break;
    }
  }
  return _ParsedRollout(
    metadata: id == null
        ? null
        : _CodexSessionMetadata(
            id: id,
            cwd: cwd,
            timestamp: timestamp,
            modelProvider: modelProvider,
            model: model,
            cliVersion: cliVersion,
            agentNickname: agentNickname,
            agentPath: agentPath,
            parentId: parentId,
          ),
    shortFileLength: header.reachedLineLimit ? null : header.fileLength,
  );
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
