import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show normalizeProjectDirectory, stripWorktreeSystemContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/claude_transcript_api.dart";
import "../api/models/claude_transcript_record_dto.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_message_origin_kind.dart";
import "../models/claude_subagent_session_id.dart";
import "mappers/claude_content_mapper.dart";
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
  /// Every session-named transcript of the last scan by path, with the stats
  /// it was parsed at, so a rescan only parses new or changed files.
  final Map<String, _CachedTranscript> _transcripts = {};

  /// Session id to transcript path over [_transcripts].
  final Map<String, String> _pathsById = {};

  /// Every session, newest first. Scanning thousands of transcripts must not
  /// stall the bridge's event loop, so listing and parsing run in an isolate.
  Future<List<ClaudeSessionRecord>> listSessionRecordsInIsolate() async {
    await _rescan();
    final roots = <String, ClaudeSessionRecord>{
      for (final entry in _transcripts.values)
        if (entry case _CachedRoot(:final record?)) record.id: record,
    };
    final records = roots.values.toList();
    for (final MapEntry(key: path, value: entry) in _transcripts.entries) {
      if (entry is! _CachedChild) continue;
      final child = _childRecord(path: path, entry: entry, root: roots[_rootIdOfChildPath(path)]);
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

  /// Scans run one at a time so an older scan never merges over a newer one.
  Future<void>? _scanInFlight;

  /// The one scan queued behind [_scanInFlight], shared by every caller that
  /// arrives meanwhile, so each of them sees the disk as of after its call.
  Future<void>? _queuedScan;

  /// Paths deleted while the current scan runs; its merge must not re-add
  /// them. A deleted root's `<id>/` directory covers its sub-agents.
  final Set<String> _deletedDuringScan = {};

  Future<void> _rescan() {
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

  Future<void> _startScan() => _scanInFlight = _scan().whenComplete(() => _scanInFlight = null);

  /// Lists and stats every transcript in an isolate that parses only the new
  /// or changed ones, then merges the parses and evicts vanished paths.
  Future<void> _scan() async {
    _deletedDuringScan.clear();
    // Locals only: the isolate must not copy this repository's cache.
    final transcriptApi = _transcriptApi;
    final logLevel = Log.level;
    final known = {for (final MapEntry(:key, :value) in _transcripts.entries) key: value.stamp};
    final scan = await Isolate.run(() {
      Log.level = logLevel;
      return _scanTranscripts(transcriptApi: transcriptApi, known: known);
    });
    _transcripts.removeWhere((path, _) => !scan.present.contains(path));
    for (final MapEntry(key: path, value: parsed) in scan.parsed.entries) {
      final deleted = _deletedDuringScan.any((gone) => path == gone || p.isWithin(gone, path));
      if (!deleted) _transcripts[path] = parsed;
    }
    _pathsById
      ..clear()
      ..addAll({
        for (final path in _transcripts.keys) ?_sessionIdFromPath(path): path,
      });
    Log.d("[claude] transcript catalog scan: files=${scan.present.length}, parsed=${scan.parsed.length}");
  }

  /// Reads and maps every record for one session. Full transcript reads can
  /// reach tens of megabytes, so they stay off the bridge event loop.
  Future<List<ClaudeTranscriptRecord>> readTranscriptRecordsInIsolate({required String sessionId}) async {
    final path = await findTranscriptPath(sessionId: sessionId);
    if (path == null) throw StateError("Claude transcript not found for session $sessionId");
    final transcriptApi = _transcriptApi;
    return await Isolate.run(
      () => transcriptApi.readTranscript(transcriptPath: path).map(_mapTranscriptRecord).toList(growable: false),
    );
  }

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

  /// Root sessions for one bridge-derived project.
  Future<List<PluginSession>> getSessions({required String projectId}) async {
    final records = await listSessionRecordsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    return records
        .where((record) => record.parentId == null)
        .map(_toPluginSession)
        .where((session) => session.directory == target)
        .toList(growable: false);
  }

  /// The sub-agent sessions persisted under one root, from the last scan
  /// unless the root is not in it.
  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId)) await _rescan();
    final root = cachedSessionById(sessionId: sessionId);
    if (root == null) return const [];
    return [
      for (final MapEntry(key: path, value: entry) in _transcripts.entries)
        if (entry is _CachedChild && _rootIdOfChildPath(path) == sessionId)
          if (_childRecord(path: path, entry: entry, root: root) case final child?) _toPluginSession(child),
    ];
  }

  /// Resolves a transcript by session id without reading any file, from the
  /// last scan or one rescan on a miss.
  Future<String?> findTranscriptPath({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId)) await _rescan();
    return _pathsById[sessionId];
  }

  /// A session from the last scan, or from one rescan on a miss.
  Future<ClaudeSessionRecord?> findSessionById({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId)) await _rescan();
    return cachedSessionById(sessionId: sessionId);
  }

  /// A session from the last scan only, for callers that cannot wait for a
  /// rescan. A session that is running was resolved by its send, so it is in
  /// the cache.
  ClaudeSessionRecord? cachedSessionById({required String sessionId}) {
    final path = _pathsById[sessionId];
    if (path == null) return null;
    switch (_transcripts[path]) {
      case _CachedRoot(:final record):
        return record;
      case final _CachedChild entry:
        final root = switch (_transcripts[_pathsById[_rootIdOfChildPath(path)]]) {
          _CachedRoot(:final record) => record,
          _ => null,
        };
        return _childRecord(path: path, entry: entry, root: root);
      case _CachedUnreadableChild() || null:
        return null;
    }
  }

  /// Deletes a session's transcript — for a root also its `<id>/` directory
  /// holding the sub-agent transcripts, for a child also its meta file.
  /// Returns false only when it was not found.
  Future<bool> deleteSession({required String sessionId}) async {
    final path = await findTranscriptPath(sessionId: sessionId);
    if (path == null) return false;
    _transcriptApi.deleteTranscript(transcriptPath: path);
    _evict(path: path);
    _deletedDuringScan.add(path);
    if (_rootIdFromPath(path) != null) {
      final directory = p.join(p.dirname(path), sessionId);
      _transcriptApi.deleteDirectory(directoryPath: directory);
      _deletedDuringScan.add(directory);
      for (final child in _transcripts.keys.where((child) => p.isWithin(directory, child)).toList()) {
        _evict(path: child);
      }
    } else {
      _transcriptApi.deleteTranscript(transcriptPath: ClaudeTranscriptApi.subagentMetaPath(transcriptPath: path));
    }
    return true;
  }

  void _evict({required String path}) {
    _transcripts.remove(path);
    _pathsById.remove(_sessionIdFromPath(path));
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

/// A transcript's own stat plus, for a sub-agent, its meta file's stat (null
/// when it has none). A changed stamp means the transcript is parsed again.
typedef _TranscriptStamp = ({ClaudeFileStat transcript, ClaudeFileStat? meta});

/// One session-named transcript as of its [stamp].
sealed class _CachedTranscript({required final _TranscriptStamp stamp});

/// A `<uuid>.jsonl`; [record] is null when the file is not a session.
final class _CachedRoot({required super.stamp, required final ClaudeSessionRecord? record}) extends _CachedTranscript;

/// A sub-agent transcript and its meta description.
final class _CachedChild({required super.stamp, required final String? description}) extends _CachedTranscript;

/// A sub-agent transcript whose meta could not be read. It stays out of the
/// catalog until its stamp changes.
final class _CachedUnreadableChild({required super.stamp}) extends _CachedTranscript;

typedef _ScanResult = ({Set<String> present, Map<String, _CachedTranscript> parsed});

/// Runs in the scan isolate: stats every session-named transcript and parses
/// those whose stamp differs from [known].
_ScanResult _scanTranscripts({
  required ClaudeTranscriptApi transcriptApi,
  required Map<String, _TranscriptStamp> known,
}) {
  final present = <String>{};
  final parsed = <String, _CachedTranscript>{};
  for (final path in transcriptApi.listTranscriptPaths()) {
    final isRoot = _rootIdFromPath(path) != null;
    if (!isRoot && _childIdFromPath(path) == null) continue;
    // A transcript deleted since the listing is simply gone.
    final stat = transcriptApi.statFile(path: path);
    if (stat == null) continue;
    final _TranscriptStamp stamp = (
      transcript: stat,
      meta: isRoot ? null : transcriptApi.statFile(path: ClaudeTranscriptApi.subagentMetaPath(transcriptPath: path)),
    );
    present.add(path);
    if (known[path] == stamp) continue;
    parsed[path] = isRoot
        ? _CachedRoot(
            stamp: stamp,
            record: _readRootRecord(transcriptApi: transcriptApi, path: path, modified: stat.modified),
          )
        : _readChild(transcriptApi: transcriptApi, path: path, stamp: stamp);
  }
  return (present: present, parsed: parsed);
}

/// Reads one root transcript's header and tail into a catalog record, or
/// null when it is not a session.
///
/// The title is the newest `/rename`, else the CLI's newest own title, else
/// the opening of the first prompt.
ClaudeSessionRecord? _readRootRecord({
  required ClaudeTranscriptApi transcriptApi,
  required String path,
  required DateTime modified,
}) {
  final id = _rootIdFromPath(path);
  if (id == null) return null;

  final List<ClaudeTranscriptLineDto> header;
  final List<ClaudeTranscriptLineDto> tail;
  try {
    header = transcriptApi.readHeader(transcriptPath: path);
    tail = transcriptApi.readTailTitleRecords(transcriptPath: path);
  } on Object catch (error, stackTrace) {
    Log.w("[claude] failed to read transcript header or tail", error, stackTrace);
    return null;
  }
  if (header.isEmpty) return null;

  String? cwd;
  String? gitBranch;
  String? cliVersion;
  DateTime? createdAt;
  var sawContent = false;
  final titles = <ClaudeTranscriptTitleKind, String>{};
  final prompts = <ClaudeTranscriptUserRecord>[];

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
        if (record is ClaudeTranscriptUserRecord) prompts.add(record);
      case ClaudeTranscriptTitleRecord():
        if (record.sessionId != null && record.sessionId != id) continue;
        titles[record.kind] = record.title;
      case ClaudeTranscriptUnknownRecord():
        break;
    }
  }

  // A file whose header is entirely subagent records is a subagent
  // transcript that happens to be UUID-named, not a session.
  if (!sawContent) return null;
  // Without a directory the bridge cannot attribute the session to a project.
  if (cwd == null) return null;

  // The tail holds the newest title records. A small file is read twice,
  // which repeats the same records in the same order.
  for (final line in tail) {
    if (_mapTranscriptRecord(line) case ClaudeTranscriptTitleRecord(:final kind, :final title, :final sessionId)
        when sessionId == null || sessionId == id) {
      titles[kind] = title;
    }
  }

  return ClaudeSessionRecord(
    id: id,
    transcriptPath: path,
    parentId: null,
    cwd: cwd,
    title:
        titles[ClaudeTranscriptTitleKind.custom] ??
        titles[ClaudeTranscriptTitleKind.generated] ??
        prompts.map(_promptTitle).nonNulls.firstOrNull,
    createdAt: createdAt,
    updatedAt: modified,
    gitBranch: gitBranch,
    cliVersion: cliVersion,
  );
}

/// A sub-agent transcript: a meta read, no header scan.
_CachedTranscript _readChild({
  required ClaudeTranscriptApi transcriptApi,
  required String path,
  required _TranscriptStamp stamp,
}) {
  try {
    final meta = transcriptApi.readSubagentMeta(transcriptPath: path);
    return _CachedChild(stamp: stamp, description: meta?.description);
  } on Object catch (error, stackTrace) {
    // A child racing its own deletion, or a corrupt meta, costs one child;
    // the rest of the catalog still lists.
    Log.w("[claude] skipping unreadable subagent transcript $path", error, stackTrace);
    return _CachedUnreadableChild(stamp: stamp);
  }
}

/// A sub-agent's record, attributed to its [root]; null without a root.
ClaudeSessionRecord? _childRecord({
  required String path,
  required _CachedChild entry,
  required ClaudeSessionRecord? root,
}) {
  final id = _childIdFromPath(path);
  if (id == null || root == null) return null;
  return ClaudeSessionRecord(
    id: id,
    transcriptPath: path,
    parentId: root.id,
    cwd: root.cwd,
    title: entry.description,
    createdAt: entry.stamp.meta?.modified,
    updatedAt: entry.stamp.transcript.modified,
    gitBranch: root.gitBranch,
    cliVersion: root.cliVersion,
  );
}

/// The session id a root or sub-agent transcript path names, or null.
String? _sessionIdFromPath(String path) => _rootIdFromPath(path) ?? _childIdFromPath(path);

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

/// How much of a first prompt can title a session nobody named.
const int _promptTitleLength = 100;

final RegExp _whitespace = RegExp(r"\s+");

/// The opening of a prompt the user typed, on one line. Null for anything
/// else: harness-generated turns, compaction summaries, peer messages, task
/// outcomes and slash-command envelopes.
String? _promptTitle(ClaudeTranscriptUserRecord record) {
  if (record.isMeta || record.isCompactSummary || record.isVisibleInTranscriptOnly) return null;
  if (record.originKind != ClaudeMessageOriginKind.unknown) return null;
  const mapper = ClaudeContentMapper();
  final blocks = mapper.map(content: record.content);
  if (mapper.containsInternalCommandOutput(blocks: blocks) ||
      mapper.isTaskNotification(blocks: blocks, originKind: record.originKind)) {
    return null;
  }
  for (final block in blocks) {
    if (block is! ClaudeMappedTextContentBlock) continue;
    // The bridge strips its worktree note from messages, but not from a title
    // already truncated here, so this one use strips it locally.
    final visible = stripWorktreeSystemContext(text: block.text);
    if (visible == null) continue;
    final text = visible.replaceAll(_whitespace, " ").trim();
    if (text.isEmpty) continue;
    final runes = text.runes;
    if (runes.length <= _promptTitleLength) return text;
    return "${String.fromCharCodes(runes.take(_promptTitleLength)).trimRight()}…";
  }
  return null;
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
        isCompactSummary: dto.isCompactSummary ?? false,
        toolUseResult: dto.toolUseResult,
        originKind: dto.originKind,
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

  final attachment = dto.attachment;
  if (type == ClaudeTranscriptContextKind.attachment.wireType &&
      attachment != null &&
      attachment.type == ClaudeTranscriptQueuedCommandRecord.attachmentType) {
    final id = _nonEmpty(attachment.sourceUuid) ?? _nonEmpty(dto.uuid);
    if (id != null) {
      return ClaudeTranscriptQueuedCommandRecord(
        id: id,
        prompt: attachment.prompt,
        isMeta: attachment.isMeta ?? false,
        // The command mode shares the origin vocabulary (`task-notification`).
        originKind: attachment.originKind == ClaudeMessageOriginKind.unknown
            ? ClaudeMessageOriginKind.parse(kind: attachment.commandMode)
            : attachment.originKind,
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
  }

  if (type == ClaudeTranscriptContextKind.system.wireType &&
      dto.subtype == ClaudeTranscriptCompactBoundaryRecord.subtype) {
    return ClaudeTranscriptCompactBoundaryRecord(
      metadata: dto.compactMetadata,
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

  final titleKind = ClaudeTranscriptTitleKind.tryParse(type);
  if (titleKind != null) {
    final title = _nonEmpty(switch (titleKind) {
      ClaudeTranscriptTitleKind.custom => dto.customTitle,
      ClaudeTranscriptTitleKind.generated => dto.aiTitle,
    });
    if (title != null) {
      return ClaudeTranscriptTitleRecord(kind: titleKind, title: title, sessionId: dto.sessionId, raw: line.raw);
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
