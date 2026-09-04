import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/claude_transcript_api.dart";
import "../api/models/claude_subagent_meta_dto.dart";
import "../api/models/claude_transcript_record_dto.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_subagent_session_id.dart";
import "models/claude_session_record.dart";
import "models/claude_transcript_record.dart";

/// Layer-2 session catalog over the on-disk transcript tree.
///
/// Holds no peer repository: everything it needs comes from its Layer-1
/// transcript API, and any composition with the process catalog happens a layer
/// up.
///
/// Two transcript kinds are sessions here: a root `<uuid>.jsonl`, and a
/// sub-agent `<root-uuid>/subagents/agent-<agentId>.jsonl` whose root is in the
/// same scan. The older flat `agent-<slug>-<hex>.jsonl` layout beside the root
/// has no meta file and no tool link, and stays excluded.
class ClaudeTranscriptCatalogRepository({required final ClaudeTranscriptApi _transcriptApi}) {
  /// Builds the catalog synchronously.
  ///
  /// Public and overridable so tests can bypass the isolate; call
  /// [listSessionRecordsInIsolate] in production.
  List<ClaudeSessionRecord> listSessionRecords() {
    final paths = _listTranscriptPaths();
    final roots = <String, ClaudeSessionRecord>{};
    for (final path in paths) {
      if (_rootIdFromPath(path) == null) continue;
      final record = _readRootRecord(path);
      if (record != null) roots[record.id] = record;
    }
    final records = roots.values.toList();
    for (final path in paths) {
      final child = _readChildRecord(path, roots: roots);
      if (child != null) records.add(child);
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

  /// Every session — roots and their sub-agent children — for bridge-derived
  /// project discovery.
  ///
  /// [knownDirectories] is part of the discovery contract so a plugin can keep
  /// sessions the bridge already tracks while hiding its own noise. Claude has
  /// no such noise — every transcript under `projects/` is a real session in a
  /// real directory — so nothing is filtered and the argument is unused.
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final records = await listSessionRecordsInIsolate();
    return records.map(_toPluginSession).toList(growable: false);
  }

  /// Root sessions for one bridge-derived project, paginated.
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await listSessionRecordsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
        .where((record) => record.parentId == null)
        .map(_toPluginSession)
        .where((session) => session.directory == target)
        .toList(growable: false);

    final from = (start ?? 0).clamp(0, sessions.length);
    if (from >= sessions.length) return const [];
    final pageSize = limit?.clamp(0, sessions.length);
    final until = pageSize == null ? sessions.length : (from + pageSize).clamp(from, sessions.length);
    return sessions.sublist(from, until);
  }

  /// The sub-agent sessions persisted under one root.
  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    final records = await listSessionRecordsInIsolate();
    return records.where((record) => record.parentId == sessionId).map(_toPluginSession).toList(growable: false);
  }

  /// Resolves a transcript by session id without reading any file.
  String? findTranscriptPath({required String sessionId}) {
    for (final path in _listTranscriptPaths()) {
      if (_rootIdFromPath(path) == sessionId || _childIdFromPath(path) == sessionId) return path;
    }
    return null;
  }

  ClaudeSessionRecord? findSessionById({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    if (path == null) return null;
    if (_rootIdFromPath(path) != null) return _readRootRecord(path);
    final rootId = _rootIdOfChildPath(path);
    final root = rootId == null ? null : findSessionById(sessionId: rootId);
    return root == null ? null : _readChildRecord(path, roots: {root.id: root});
  }

  /// Deletes a session's transcript — for a root also its `<id>/` directory
  /// holding the sub-agent transcripts, for a child also its meta file.
  /// Returns false only when it was not found.
  bool deleteSession({required String sessionId}) {
    final path = findTranscriptPath(sessionId: sessionId);
    if (path == null) return false;
    _transcriptApi.deleteTranscript(transcriptPath: path);
    if (_rootIdFromPath(path) != null) {
      _transcriptApi.deleteDirectory(directoryPath: p.join(p.dirname(path), sessionId));
    } else {
      _transcriptApi.deleteTranscript(transcriptPath: ClaudeTranscriptApi.subagentMetaPath(transcriptPath: path));
    }
    return true;
  }

  List<String> _listTranscriptPaths() => _transcriptApi.listTranscriptPaths();

  /// Reads one root transcript's header into a catalog record, or null when it
  /// is not a session.
  ClaudeSessionRecord? _readRootRecord(String path) {
    final id = _rootIdFromPath(path);
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
      parentId: null,
      cwd: cwd,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      gitBranch: gitBranch,
      cliVersion: cliVersion,
    );
  }

  /// A sub-agent transcript under a root present in [roots]: a meta read and
  /// two stats, no header scan. Null for anything else.
  ClaudeSessionRecord? _readChildRecord(String path, {required Map<String, ClaudeSessionRecord> roots}) {
    final id = _childIdFromPath(path);
    final root = roots[_rootIdOfChildPath(path)];
    if (id == null || root == null) return null;
    final ClaudeSubagentMetaDto? meta;
    final DateTime? createdAt;
    final DateTime? updatedAt;
    try {
      meta = _transcriptApi.readSubagentMeta(transcriptPath: path);
      createdAt = _transcriptApi.lastModified(
        transcriptPath: ClaudeTranscriptApi.subagentMetaPath(transcriptPath: path),
      );
      updatedAt = _transcriptApi.lastModified(transcriptPath: path);
    } on Object catch (error, stackTrace) {
      // A child racing its own deletion, or a corrupt meta, costs one child in
      // this scan; the rest of the catalog still lists.
      Log.w("[claude] skipping unreadable subagent transcript $path", error, stackTrace);
      return null;
    }
    return ClaudeSessionRecord(
      id: id,
      transcriptPath: path,
      parentId: root.id,
      cwd: root.cwd,
      title: meta?.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      gitBranch: root.gitBranch,
      cliVersion: root.cliVersion,
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
      parentID: record.parentId,
      title: record.title,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(created: created, updated: updated, archived: null),
    );
  }
}

/// The root session id a `<uuid>.jsonl` path names, or null.
///
/// This is the catalog's primary filter, not a formality: legacy flat subagent
/// transcripts share the `projects/` tree as `agent-<slug>-<hex>.jsonl`. On the
/// machine this was measured on they were 1,695 of 1,888 files, so accepting
/// every `.jsonl` would have reported roughly ten times too many sessions.
String? _rootIdFromPath(String path) {
  final stem = _stem(path);
  return stem != null && _uuidPattern.hasMatch(stem) ? stem : null;
}

/// The child session id an `<root>/subagents/agent-<agentId>.jsonl` path names,
/// or null — including for the legacy flat layout, which has no `subagents/`.
String? _childIdFromPath(String path) {
  final stem = _stem(path);
  if (stem == null || ClaudeSubagentSessionId.agentIdOf(stem) == null) return null;
  return _rootIdOfChildPath(path) == null ? null : stem;
}

String? _rootIdOfChildPath(String path) {
  final subagents = p.dirname(path);
  if (p.basename(subagents) != "subagents") return null;
  final root = p.basename(p.dirname(subagents));
  return _uuidPattern.hasMatch(root) ? root : null;
}

String? _stem(String path) {
  final fileName = p.basename(path);
  if (!fileName.endsWith(".jsonl")) return null;
  return fileName.substring(0, fileName.length - ".jsonl".length);
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
        toolUseResult: dto.toolUseResult,
        isTaskNotification: dto.originKind == "task-notification",
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        agentId: dto.agentId,
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
      if (dto.isApiErrorMessage ?? false) {
        return ClaudeTranscriptApiErrorRecord(
          id: id,
          content: dto.message?.content,
          apiErrorStatus: dto.apiErrorStatus,
          cwd: dto.cwd,
          timestamp: dto.timestamp,
          isSidechain: dto.isSidechain,
          agentId: dto.agentId,
          gitBranch: dto.gitBranch,
          version: dto.version,
          sessionId: dto.sessionId,
          raw: line.raw,
        );
      }
      return ClaudeTranscriptAssistantRecord(
        id: id,
        model: _nonEmpty(dto.message?.model),
        effort: ClaudeEffortLevel.tryParse(dto.effort),
        content: dto.message?.content,
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        agentId: dto.agentId,
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
      agentId: dto.agentId,
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
    agentId: dto.agentId,
    gitBranch: dto.gitBranch,
    version: dto.version,
    sessionId: dto.sessionId,
    raw: line.raw,
  );
}
