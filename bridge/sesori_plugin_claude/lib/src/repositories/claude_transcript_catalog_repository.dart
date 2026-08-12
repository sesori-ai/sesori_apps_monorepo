import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/claude_transcript_api.dart";
import "../api/models/claude_transcript_record_dto.dart";
import "models/claude_session_record.dart";
import "models/claude_transcript_record.dart";

/// Layer-2 session catalog over the on-disk transcript tree.
///
/// Holds no peer repository: everything it needs comes from its Layer-1
/// transcript API, and any composition with the process catalog happens a layer
/// up.
class ClaudeTranscriptCatalogRepository({required final ClaudeTranscriptApi _transcriptApi}) {
  /// Builds the catalog synchronously.
  ///
  /// Public and overridable so tests can bypass the isolate; call
  /// [listSessionRecordsInIsolate] in production.
  List<ClaudeSessionRecord> listSessionRecords() {
    final records = <ClaudeSessionRecord>[];
    for (final path in _listTranscriptPaths()) {
      final record = _readSessionRecord(path);
      if (record != null) records.add(record);
    }

    // Newest first, undated last, so an unreadable header never displaces a
    // session with a real timestamp.
    records.sort((a, b) {
      final left = a.updatedAt ?? a.createdAt;
      final right = b.updatedAt ?? b.createdAt;
      if (left == null && right == null) return a.id.compareTo(b.id);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return records;
  }

  /// Scanning hundreds of transcripts must not stall the bridge's event loop.
  Future<List<ClaudeSessionRecord>> listSessionRecordsInIsolate() => Isolate.run(listSessionRecords);

  /// Reads and maps every record for one session.
  List<ClaudeTranscriptRecord> readTranscriptRecords({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    if (path == null) throw StateError("Claude transcript not found for session $sessionId");
    return _transcriptApi.readTranscript(transcriptPath: path).map(_mapTranscriptRecord).toList(growable: false);
  }

  /// Full transcript reads can reach tens of megabytes, so keep them off the
  /// bridge event loop.
  Future<List<ClaudeTranscriptRecord>> readTranscriptRecordsInIsolate({required String sessionId}) =>
      Isolate.run(() => readTranscriptRecords(sessionId: sessionId));

  /// Every session, for bridge-derived project discovery.
  ///
  /// [knownDirectories] is part of the discovery contract so a plugin can keep
  /// sessions the bridge already tracks while hiding its own noise. Claude has
  /// no such noise — every transcript under `projects/` is a real session in a
  /// real directory — so nothing is filtered and the argument is unused.
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final records = await listSessionRecordsInIsolate();
    return records.map(_toPluginSession).toList(growable: false);
  }

  /// Sessions for one bridge-derived project, paginated.
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await listSessionRecordsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
        .map(_toPluginSession)
        .where((session) => session.directory == target)
        .toList(growable: false);

    final from = (start ?? 0).clamp(0, sessions.length);
    if (from >= sessions.length) return const [];
    final pageSize = limit?.clamp(0, sessions.length);
    final until = pageSize == null ? sessions.length : (from + pageSize).clamp(from, sessions.length);
    return sessions.sublist(from, until);
  }

  /// Resolves a transcript by session id without reading any file.
  String? findTranscriptPath({required String sessionId}) {
    for (final path in _listTranscriptPaths()) {
      if (_sessionIdFromTranscriptName(p.basename(path)) == sessionId) return path;
    }
    return null;
  }

  ClaudeSessionRecord? findSessionById({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    return path == null ? null : _readSessionRecord(path);
  }

  /// Deletes a session's transcript. Returns false only when it was not found.
  bool deleteSession({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    if (path == null) return false;
    _transcriptApi.deleteTranscript(transcriptPath: path);
    return true;
  }

  List<String> _listTranscriptPaths() => _transcriptApi.listTranscriptPaths();

  /// Reads one transcript's header into a catalog record, or null when it is
  /// not a session.
  ClaudeSessionRecord? _readSessionRecord(String path) {
    final id = _sessionIdFromTranscriptName(p.basename(path));
    if (id == null) return null;

    final List<ClaudeTranscriptLineDto> header;
    final DateTime? updatedAt;
    try {
      header = _transcriptApi.readHeader(transcriptPath: path);
      updatedAt = _transcriptApi.lastModified(transcriptPath: path);
    } on Object catch (error, stackTrace) {
      Log.w("[claude] failed to read transcript header", error, stackTrace);
      return null;
    }
    if (header.isEmpty) return null;

    String? cwd;
    String? title;
    String? gitBranch;
    String? cliVersion;
    DateTime? createdAt;
    var sawContent = false;

    for (final line in header) {
      final record = _mapTranscriptRecord(line);
      switch (record) {
        case ClaudeTranscriptAttributedRecord():
          // A subagent's records never describe the parent session.
          if (record.isSidechain ?? false) continue;
          // The filename is authoritative. A present record id is only a
          // cross-check and records for another session cannot supply metadata.
          if (record.sessionId != null && record.sessionId != id) continue;
          sawContent = true;
          cwd ??= _nonEmpty(record.cwd);
          gitBranch ??= _nonEmpty(record.gitBranch);
          cliVersion ??= _nonEmpty(record.version);
          createdAt ??= record.timestamp;
        case ClaudeTranscriptTitleRecord():
          if (record.sessionId != null && record.sessionId != id) continue;
          title ??= record.title;
        case ClaudeTranscriptUnknownRecord():
          break;
      }
    }

    // A file whose header is entirely subagent records is a subagent
    // transcript that happens to be UUID-named, not a session.
    if (!sawContent) return null;
    // Without a directory the bridge cannot attribute the session to a project.
    if (cwd == null) return null;

    return ClaudeSessionRecord(
      id: id,
      transcriptPath: path,
      cwd: cwd,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      gitBranch: gitBranch,
      cliVersion: cliVersion,
    );
  }

  PluginSession _toPluginSession(ClaudeSessionRecord record) {
    final directory = normalizeProjectDirectory(directory: record.cwd);
    final created = (record.createdAt ?? record.updatedAt)?.millisecondsSinceEpoch;
    final updated = (record.updatedAt ?? record.createdAt)?.millisecondsSinceEpoch;
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: record.title,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(created: created, updated: updated, archived: null),
    );
  }
}

/// The transcript filename minus `.jsonl`, or null when it is not a session id.
///
/// This is the catalog's primary filter, not a formality: subagent transcripts
/// share the `projects/` tree and are named `agent-<slug>-<hex>.jsonl`. On the
/// machine this was measured on they were 1,695 of 1,888 files, so accepting
/// every `.jsonl` would have reported roughly ten times too many sessions.
String? _sessionIdFromTranscriptName(String fileName) {
  if (!fileName.endsWith(".jsonl")) return null;
  final stem = fileName.substring(0, fileName.length - ".jsonl".length);
  return _uuidPattern.hasMatch(stem) ? stem : null;
}

final RegExp _uuidPattern = RegExp(
  r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
);

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Maps the generated API DTO into the closed variants the repository uses.
ClaudeTranscriptRecord _mapTranscriptRecord(ClaudeTranscriptLineDto line) {
  final dto = line.record;
  final type = dto.type;
  if (type == null) {
    return ClaudeTranscriptUnknownRecord(type: null, sessionId: dto.sessionId, raw: line.raw);
  }

  if (type == ClaudeTranscriptUserRecord.wireType) {
    final id = _nonEmpty(dto.uuid);
    if (id != null) {
      return ClaudeTranscriptUserRecord(
        id: id,
        content: dto.message?.content,
        isMeta: dto.isMeta ?? false,
        isVisibleInTranscriptOnly: dto.isVisibleInTranscriptOnly ?? false,
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        gitBranch: dto.gitBranch,
        version: dto.version,
        sessionId: dto.sessionId,
        raw: line.raw,
      );
    }
    return _unreplayableMessageRecord(line: line);
  }

  if (type == ClaudeTranscriptAssistantRecord.wireType) {
    final id = _nonEmpty(dto.message?.id);
    if (id != null) {
      return ClaudeTranscriptAssistantRecord(
        id: id,
        model: _nonEmpty(dto.message?.model),
        content: dto.message?.content,
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        gitBranch: dto.gitBranch,
        version: dto.version,
        sessionId: dto.sessionId,
        raw: line.raw,
      );
    }
    return _unreplayableMessageRecord(line: line);
  }

  final contextKind = ClaudeTranscriptContextKind.tryParse(type);
  if (contextKind != null) {
    return ClaudeTranscriptContextRecord(
      kind: contextKind,
      cwd: dto.cwd,
      timestamp: dto.timestamp,
      isSidechain: dto.isSidechain,
      gitBranch: dto.gitBranch,
      version: dto.version,
      sessionId: dto.sessionId,
      raw: line.raw,
    );
  }

  if (type == ClaudeTranscriptTitleRecord.wireType) {
    final title = dto.aiTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return ClaudeTranscriptTitleRecord(title: title, sessionId: dto.sessionId, raw: line.raw);
    }
  }

  return ClaudeTranscriptUnknownRecord(type: type, sessionId: dto.sessionId, raw: line.raw);
}

ClaudeTranscriptUnreplayableMessageRecord _unreplayableMessageRecord({required ClaudeTranscriptLineDto line}) {
  final dto = line.record;
  return ClaudeTranscriptUnreplayableMessageRecord(
    cwd: dto.cwd,
    timestamp: dto.timestamp,
    isSidechain: dto.isSidechain,
    gitBranch: dto.gitBranch,
    version: dto.version,
    sessionId: dto.sessionId,
    raw: line.raw,
  );
}
