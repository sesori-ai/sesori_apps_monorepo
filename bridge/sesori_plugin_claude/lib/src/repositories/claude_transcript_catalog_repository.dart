import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/claude_transcript_api.dart";
import "../api/models/claude_transcript_record.dart";
import "models/claude_session_record.dart";

/// Layer-2 session catalog over the on-disk transcript tree.
///
/// Holds no peer repository: everything it needs comes from its Layer-1
/// transcript API, and any composition with the process catalog happens a layer
/// up.
class ClaudeTranscriptCatalogRepository {
  ClaudeTranscriptCatalogRepository({required ClaudeTranscriptApi transcriptApi}) : _transcriptApi = transcriptApi;

  final ClaudeTranscriptApi _transcriptApi;

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

  /// Every session, for bridge-derived project discovery.
  ///
  /// [knownDirectories] is part of the discovery contract so a plugin can keep
  /// sessions the bridge already tracks while hiding its own noise. Claude has
  /// no such noise — every transcript under `projects/` is a real session in a
  /// real directory — so nothing is filtered and the argument is unused.
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final records = await listSessionRecordsInIsolate();
    return records.map(_toPluginSession).nonNulls.toList(growable: false);
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
        .nonNulls
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

  /// Deletes a session's transcript. Returns false when it was not found or the
  /// delete failed; the caller decides whether that is an error.
  bool deleteSession({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    if (path == null) return false;
    try {
      _transcriptApi.deleteTranscript(transcriptPath: path);
      return true;
    } on Object catch (error, stackTrace) {
      Log.w("[claude] failed to delete transcript for session $sessionId", error, stackTrace);
      return false;
    }
  }

  List<String> _listTranscriptPaths() {
    try {
      return _transcriptApi.listTranscriptPaths();
    } on Object catch (error, stackTrace) {
      Log.w("[claude] failed to enumerate transcripts", error, stackTrace);
      return const [];
    }
  }

  /// Reads one transcript's header into a catalog record, or null when it is
  /// not a session.
  ClaudeSessionRecord? _readSessionRecord(String path) {
    final id = _sessionIdFromTranscriptName(p.basename(path));
    if (id == null) return null;

    final List<ClaudeTranscriptRecord> header;
    try {
      header = _transcriptApi.readHeader(transcriptPath: path);
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
    var sawOwnRecord = false;

    for (final record in header) {
      switch (record) {
        case ClaudeTranscriptContentRecord():
          // A subagent's records never describe the parent session.
          if (record.isSidechain ?? false) continue;
          sawContent = true;
          if (record.sessionId == id) sawOwnRecord = true;
          cwd ??= _nonEmpty(record.cwd);
          gitBranch ??= _nonEmpty(record.gitBranch);
          cliVersion ??= _nonEmpty(record.version);
          createdAt ??= record.timestamp;
        case ClaudeTranscriptTitleRecord():
          title ??= record.title;
        case ClaudeTranscriptUnknownRecord():
          break;
      }
    }

    // A file whose header is entirely subagent records is a subagent
    // transcript that happens to be UUID-named, not a session.
    if (!sawContent) return null;
    // The filename is authoritative, but a transcript whose own records claim a
    // different session is not one this catalog can reason about.
    if (!sawOwnRecord) {
      Log.w("[claude] skipping transcript whose records do not match its filename id");
      return null;
    }
    // Without a directory the bridge cannot attribute the session to a project.
    if (cwd == null) return null;

    return ClaudeSessionRecord(
      id: id,
      transcriptPath: path,
      cwd: cwd,
      title: title,
      createdAt: createdAt,
      updatedAt: _transcriptApi.lastModified(transcriptPath: path) ?? createdAt,
      gitBranch: gitBranch,
      cliVersion: cliVersion,
    );
  }

  PluginSession? _toPluginSession(ClaudeSessionRecord record) {
    final cwd = record.cwd;
    if (cwd == null) return null;
    final directory = normalizeProjectDirectory(directory: cwd);
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
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
