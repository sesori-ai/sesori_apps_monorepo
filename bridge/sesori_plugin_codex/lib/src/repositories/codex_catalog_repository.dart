import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "models/codex_session_record.dart";

/// Layer-2 aggregation, mapping, selection, and deletion for the rollout catalog.
class CodexCatalogRepository {
  CodexCatalogRepository({required CodexRolloutApi rolloutApi}) : _rolloutApi = rolloutApi;

  final CodexRolloutApi _rolloutApi;

  List<CodexSessionRecord> listSessionRecords() {
    final rollouts = <String, String>{};
    for (final path in _listRolloutPaths()) {
      final id = _sessionIdFromRolloutName(p.basename(path));
      if (id != null) rollouts[id] = path;
    }

    final indexEntries = <String, CodexSessionIndexEntryDto>{};
    for (final entry in _readSessionIndex()) {
      final id = entry.id;
      if (id != null && id.isNotEmpty) {
        indexEntries[id] = entry;
      }
    }

    final records = <CodexSessionRecord>[];
    for (final id in {...rollouts.keys, ...indexEntries.keys}) {
      final rolloutPath = rollouts[id];
      if (rolloutPath == null) continue;
      final indexEntry = indexEntries[id];
      final metadata = _readMetadata(rolloutPath);
      records.add(
        CodexSessionRecord(
          id: id,
          rolloutPath: rolloutPath,
          cwd: metadata?.cwd,
          threadName: indexEntry?.threadName,
          createdAt: metadata?.timestamp,
          updatedAt: _tryParseDate(indexEntry?.updatedAt) ?? metadata?.timestamp,
          cliVersion: metadata?.cliVersion,
          modelProvider: metadata?.modelProvider,
          model: metadata?.model,
          branch: metadata?.branch,
        ),
      );
    }
    records.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return records;
  }

  Future<List<CodexSessionRecord>> listSessionRecordsInIsolate() => Isolate.run(listSessionRecords);

  Future<List<PluginSession>> listAllSessions() async {
    final records = await listSessionRecordsInIsolate();
    return records.map(_toPluginSession).nonNulls.toList(growable: false);
  }

  /// Filters by normalized rollout CWD before applying pagination.
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await listSessionRecordsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
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

  CodexSessionRecord? findSessionById({required String sessionId}) {
    for (final record in listSessionRecords()) {
      if (record.id == sessionId) return record;
    }
    return null;
  }

  String? findRolloutPath({required String sessionId}) {
    for (final path in _listRolloutPaths()) {
      if (_sessionIdFromRolloutName(p.basename(path)) == sessionId) {
        return path;
      }
    }
    return null;
  }

  void deleteSession({required String sessionId}) {
    final rolloutPath = findRolloutPath(sessionId: sessionId);
    if (rolloutPath != null) {
      try {
        _rolloutApi.deleteRollout(rolloutPath: rolloutPath);
      } on Object catch (error, stackTrace) {
        Log.w("[codex] failed to delete rollout for $sessionId", error, stackTrace);
      }
    }

    final indexLines = _readSessionIndexLines();
    final filtered = [
      for (final line in indexLines)
        if (line.entry?.id != sessionId) line.raw,
    ];
    if (filtered.length == indexLines.length) return;
    try {
      _rolloutApi.writeSessionIndex(lines: filtered);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to remove $sessionId from the session index",
        error,
        stackTrace,
      );
    }
  }

  List<String> _listRolloutPaths() {
    try {
      return _rolloutApi.listRolloutPaths();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to enumerate rollout files", error, stackTrace);
      return const [];
    }
  }

  List<CodexSessionIndexEntryDto> _readSessionIndex() {
    try {
      return _rolloutApi.readSessionIndex();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to read the session index", error, stackTrace);
      return const [];
    }
  }

  List<CodexSessionIndexLine> _readSessionIndexLines() {
    try {
      return _rolloutApi.readSessionIndexLines();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to read the session index", error, stackTrace);
      return const [];
    }
  }

  _CodexSessionMetadata? _readMetadata(String rolloutPath) {
    final List<CodexRolloutLineDto> lines;
    try {
      lines = _rolloutApi.readHeader(rolloutPath: rolloutPath);
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
    String? branch;
    for (final line in lines) {
      switch (line.type) {
        case CodexRolloutLineType.sessionMeta:
          final payload = line.payload;
          final metadataId = payload?.id;
          if (metadataId == null || metadataId.isEmpty) continue;
          id = metadataId;
          cwd = payload?.cwd;
          timestamp = _tryParseDate(payload?.timestamp);
          modelProvider = payload?.modelProvider;
          cliVersion = payload?.cliVersion;
          branch = payload?.git?.branch;
        case CodexRolloutLineType.turnContext:
          final candidate = line.payload?.model;
          if (candidate != null && candidate.isNotEmpty) model = candidate;
        case CodexRolloutLineType.responseItem:
        case CodexRolloutLineType.unknown:
        case null:
          break;
      }
    }
    if (id == null) return null;
    return _CodexSessionMetadata(
      cwd: cwd,
      timestamp: timestamp,
      modelProvider: modelProvider,
      model: model,
      cliVersion: cliVersion,
      branch: branch,
    );
  }

  PluginSession? _toPluginSession(CodexSessionRecord record) {
    final cwd = record.cwd?.trim();
    if (cwd == null || cwd.isEmpty) return null;
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    final directory = normalizeProjectDirectory(directory: cwd);
    return PluginSession(
      branchName: _usefulText(record.branch),
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: record.threadName,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

  String? _sessionIdFromRolloutName(String fileName) {
    if (!fileName.endsWith(".jsonl")) return null;
    final stem = fileName.substring(0, fileName.length - ".jsonl".length);
    final parts = stem.split("-");
    if (parts.length < 5) return null;
    final uuid = parts.sublist(parts.length - 5).join("-");
    return uuid.length == 36 ? uuid : null;
  }

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class _CodexSessionMetadata {
  const _CodexSessionMetadata({
    required this.cwd,
    required this.timestamp,
    required this.modelProvider,
    required this.model,
    required this.cliVersion,
    required this.branch,
  });

  final String? cwd;
  final DateTime? timestamp;
  final String? modelProvider;
  final String? model;
  final String? cliVersion;
  final String? branch;
}
