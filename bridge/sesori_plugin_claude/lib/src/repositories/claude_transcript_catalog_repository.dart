import "dart:isolate";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show normalizeProjectDirectory, stripSystemContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginSession,
        PluginSessionActivityAvailable,
        PluginSessionActivityResult,
        PluginSessionActivityUnavailable,
        PluginSessionTime;
import "package:sesori_shared/sesori_shared.dart" show unwrapDictatedText;

import "../api/claude_transcript_api.dart";
import "../api/models/claude_transcript_record_dto.dart";
import "../foundation/trimmed_or_null.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_message_origin_kind.dart";
import "../models/claude_subagent_session_id.dart";
import "mappers/claude_content_mapper.dart";
import "models/claude_fork_result.dart";
import "models/claude_rewind_point.dart";
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

  /// When root session [sessionId] was last active, by the same rule the
  /// catalog lists it with: a project-directory lookup and a bounded tail
  /// read, never a transcript scan, so a dormant plugin can answer. It runs in
  /// an isolate like the other transcript reads. A sub-agent id is
  /// unavailable.
  Future<PluginSessionActivityResult> readRootSessionActivity({required String sessionId}) {
    if (!_uuidPattern.hasMatch(sessionId)) return Future.value(const PluginSessionActivityUnavailable());
    final transcriptApi = _transcriptApi;
    return Isolate.run(() {
      final path = transcriptApi.findRootTranscriptPath(sessionId: sessionId);
      final stat = path == null ? null : transcriptApi.statFile(path: path);
      if (path == null || stat == null) return const PluginSessionActivityUnavailable();
      final activeAt = _rootActivity(
        tail: transcriptApi.readTailRecords(transcriptPath: path, sessionId: sessionId),
        id: sessionId,
        modified: stat.modified,
      );
      return PluginSessionActivityAvailable(updatedAt: activeAt.millisecondsSinceEpoch);
    });
  }

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

  /// Reads and maps the records of one session's active branch. Full
  /// transcript reads can reach tens of megabytes, so they stay off the bridge
  /// event loop.
  Future<List<ClaudeTranscriptRecord>> readTranscriptRecordsInIsolate({required String sessionId}) async {
    final path = await findTranscriptPath(sessionId: sessionId);
    if (path == null) throw StateError("Claude transcript not found for session $sessionId");
    final transcriptApi = _transcriptApi;
    return await Isolate.run(
      () => _activeBranch(
        records: transcriptApi.readTranscript(transcriptPath: path),
      ).map(_mapTranscriptRecord).toList(growable: false),
    );
  }

  /// Where a rewind that removes the user prompt [messageId] and everything
  /// after it resumes [sessionId]: the prompt's parent on the active branch.
  Future<ClaudeRewindPoint> rewindPointBefore({required String sessionId, required String messageId}) async {
    final path = await findTranscriptPath(sessionId: sessionId);
    if (path == null) return const ClaudeRewindUnavailable(reason: ClaudeRewindRefusal.notOnActiveBranch);
    final transcriptApi = _transcriptApi;
    return await Isolate.run(
      () => _rewindPointBefore(
        records: transcriptApi.readTranscript(transcriptPath: path),
        messageId: messageId,
      ),
    );
  }

  /// Writes root session [forkSessionId] beside [sessionId], holding
  /// [sessionId]'s active branch through the end of the turn whose last shown
  /// message is [throughMessageId].
  ///
  /// Claude Code's own `--fork-session` writes nothing until the fork's first
  /// prompt (checked live on 2.1.322), so the fork would not exist on disk
  /// until then. This writes the records the CLI's fork keeps, verbatim except
  /// for their `sessionId`, and a plain `--resume` continues from them. The
  /// origin's file is only read, so a later turn may still be running in it.
  /// Sub-agent transcripts stay with the origin, as with the CLI's fork: a
  /// sub-agent's session id is global, so a copy would list it twice.
  Future<ClaudeForkResult> forkTranscript({
    required String sessionId,
    required String throughMessageId,
    required String forkSessionId,
  }) async {
    final path = await findTranscriptPath(sessionId: sessionId);
    if (path == null || _rootIdFromPath(path) == null) {
      return const ClaudeForkUnavailable(reason: ClaudeForkRefusal.transcriptMissing);
    }
    final forkPath = p.join(p.dirname(path), "$forkSessionId.jsonl");
    final transcriptApi = _transcriptApi;
    return await Isolate.run(() {
      final prefix = _forkPrefix(
        entries: transcriptApi.readTranscriptEntries(transcriptPath: path),
        messageId: throughMessageId,
      );
      switch (prefix) {
        case _ForkRefused(:final reason):
          return ClaudeForkUnavailable(reason: reason);
        case _ForkKept(:final records):
          transcriptApi.writeTranscript(
            transcriptPath: forkPath,
            records: [
              for (final record in records) {...record, "sessionId": forkSessionId},
            ],
          );
          return const ClaudeForkWritten();
      }
    });
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
  Future<PluginSession?> findSessionById({required String sessionId}) async {
    if (!_pathsById.containsKey(sessionId)) await _rescan();
    return switch (cachedSessionById(sessionId: sessionId)) {
      final record? => _toPluginSession(record),
      null => null,
    };
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
          _CachedChild() || _CachedUnreadableChild() || null => null,
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

  final List<ClaudeTranscriptRecordDto> header;
  final List<ClaudeTranscriptRecordDto> tail;
  try {
    header = transcriptApi.readHeader(transcriptPath: path);
    tail = transcriptApi.readTailRecords(transcriptPath: path, sessionId: id);
  } on Object catch (error, stackTrace) {
    Log.w("[claude] failed to read transcript header or tail", error, stackTrace);
    return null;
  }
  if (header.isEmpty) return null;

  String? cwd;
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
        cwd ??= trimmedOrNull(value: record.cwd);
        createdAt ??= record.timestamp;
        if (record is ClaudeTranscriptUserRecord) {
          // Another root prompt is a rewind to before the first message, which
          // started the conversation over. Deeper rewinds keep the first
          // prompt, so the header alone decides the title.
          if (line.parentUuid == null && _isPrompt(line)) prompts.clear();
          prompts.add(record);
        }
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

  // The tail holds the newest title records and the newest timestamped one.
  // A small file is read twice, which repeats the same records in the same
  // order.
  for (final line in tail) {
    if (line.sessionId != null && line.sessionId != id) continue;
    if (_mapTranscriptRecord(line) case ClaudeTranscriptTitleRecord(:final kind, :final title)) {
      titles[kind] = title;
    }
  }

  return ClaudeSessionRecord(
    id: id,
    parentId: null,
    cwd: cwd,
    title:
        titles[ClaudeTranscriptTitleKind.custom] ??
        titles[ClaudeTranscriptTitleKind.generated] ??
        prompts.map(_promptTitle).nonNulls.firstOrNull,
    createdAt: createdAt,
    updatedAt: _rootActivity(tail: tail, id: id, modified: modified),
  );
}

/// The newest timestamped record of root session [id] in its [tail]. The
/// file's mtime also moves when the CLI appends metadata without a turn, such
/// as `cost-state` when its process exits, so it is only the fallback.
DateTime _rootActivity({
  required List<ClaudeTranscriptRecordDto> tail,
  required String id,
  required DateTime modified,
}) {
  DateTime? activeAt;
  for (final line in tail) {
    if (line.sessionId != null && line.sessionId != id) continue;
    activeAt = line.timestamp ?? activeAt;
  }
  return activeAt ?? modified;
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
    parentId: root.id,
    cwd: root.cwd,
    title: entry.description,
    createdAt: entry.stamp.meta?.modified,
    updatedAt: entry.stamp.transcript.modified,
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

/// The entrypoint an SDK-mode CLI, the mode the plugin runs, records.
const String _sdkEntrypoint = "sdk-cli";

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
    // The bridge strips its notes from messages, but not from a title
    // already truncated here, so this one use strips them locally.
    final visible = stripSystemContext(text: block.text);
    if (visible == null) continue;
    final text = unwrapDictatedText(text: visible).replaceAll(_whitespace, " ").trim();
    if (text.isEmpty) continue;
    final runes = text.runes;
    if (runes.length <= _promptTitleLength) return text;
    return "${String.fromCharCodes(runes.take(_promptTitleLength)).trimRight()}…";
  }
  return null;
}

/// The records of a transcript's active branch, in file order.
///
/// A transcript is a tree. A rewind, from the terminal's Esc Esc or from
/// `--resume-session-at`, leaves the old turns in the file and parents the
/// next prompt to an earlier record, so the conversation is the chain from the
/// active leaf back to the root. That is what Claude Code resumes, so history
/// shows the same.
///
/// The leaf is the newest main-chain record, unless a later `last-prompt`
/// record names another one. A `last-prompt` naming no record, such as the
/// all-zero id the CLI writes after a rewind, is ignored.
///
/// Only a branch that a user prompt or a compaction starts beside the chain is
/// dropped: that is what a rewind leaves behind. Everything else off the chain
/// stays:
/// - parallel tool calls, whose results hang off the separate records of one
///   assistant message rather than off the chain;
/// - records above a link the file no longer resolves, such as a skipped
///   malformed line;
/// - records without an id, which carry metadata, not turns.
///
/// A `compact_boundary` continues its [ClaudeTranscriptRecordDto.logicalParentUuid],
/// so the turns before a compaction still show. Sub-agent records are not part
/// of the main chain and stay as they are.
List<ClaudeTranscriptRecordDto> _activeBranch({required List<ClaudeTranscriptRecordDto> records}) {
  final active = _activeChain(records: records);
  if (active == null) return records;
  final (:parents, :chain, leaf: _, :reachesRoot) = active;

  // A parent precedes its children in the file, so one pass decides every
  // parent before its children.
  final dropped = <String>{};
  final branch = <ClaudeTranscriptRecordDto>[];
  for (final record in records) {
    final id = _chainId(record);
    if (id != null && !chain.contains(id)) {
      final parent = parents[id];
      final forksFromChain = parent == null ? reachesRoot : chain.contains(parent);
      if (dropped.contains(parent) || (forksFromChain && _startsBranch(record))) {
        dropped.add(id);
        continue;
      }
    }
    branch.add(record);
  }
  return branch;
}

/// Every main-chain record's parent link and the chain from the active leaf
/// back to the root, as [_activeBranch] describes; null for a transcript with
/// no main-chain record. [reachesRoot] is whether the walk ended at a record
/// with no parent.
({Map<String, String?> parents, Set<String> chain, String leaf, bool reachesRoot})? _activeChain({
  required List<ClaudeTranscriptRecordDto> records,
}) {
  final parents = <String, String?>{};
  String? leaf;
  for (final record in records) {
    if (_chainId(record) case final id?) {
      parents[id] = record.parentUuid ?? record.logicalParentUuid;
      leaf = id;
    } else if (record.type == _lastPromptType) {
      if (record.leafUuid case final named? when parents.containsKey(named)) leaf = named;
    }
  }
  if (leaf == null) return null;

  // The walk stops at the root, at a link the file does not resolve, or at a
  // cycle a corrupt file could hold.
  final chain = <String>{};
  String? cursor = leaf;
  while (cursor != null && parents.containsKey(cursor) && chain.add(cursor)) {
    cursor = parents[cursor];
  }
  return (parents: parents, chain: chain, leaf: leaf, reachesRoot: cursor == null);
}

/// The entry `--resume-session-at` keeps when the prompt [messageId] and
/// everything after it are removed: the prompt's own `parentUuid`, so the
/// edited prompt is the next record (verified live on 2.1.221 and 2.1.322).
ClaudeRewindPoint _rewindPointBefore({required List<ClaudeTranscriptRecordDto> records, required String messageId}) {
  final active = _activeChain(records: records);
  final byId = {for (final record in records) ?_chainId(record): record};
  final prompt = byId[messageId];
  if (active == null || prompt == null || !_isPrompt(prompt) || !active.chain.contains(messageId)) {
    return const ClaudeRewindUnavailable(reason: ClaudeRewindRefusal.notOnActiveBranch);
  }
  final entryUuid = trimmedOrNull(value: prompt.parentUuid);
  if (entryUuid == null) return const ClaudeRewindUnavailable(reason: ClaudeRewindRefusal.firstMessage);
  // A parent missing from the file (a truncated transcript) cannot be resumed at.
  if (!active.chain.contains(entryUuid)) {
    return const ClaudeRewindUnavailable(reason: ClaudeRewindRefusal.notOnActiveBranch);
  }
  // The chain from the leaf reaches the prompt, which it holds.
  String? cursor = active.leaf;
  while (cursor != null && cursor != messageId) {
    if (byId[cursor] case final record? when _isCompactBoundary(record)) {
      return const ClaudeRewindUnavailable(reason: ClaudeRewindRefusal.beforeCompaction);
    }
    cursor = active.parents[cursor];
  }
  return ClaudeRewindEntry(entryUuid: entryUuid);
}

/// What a fork keeps, or why it keeps nothing.
sealed class const _ForkPrefix();

final class const _ForkKept({required final List<Map<String, dynamic>> records}) extends _ForkPrefix;

final class const _ForkRefused({required final ClaudeForkRefusal reason}) extends _ForkPrefix;

/// The raw records a fork through the turn whose last shown message is
/// [messageId] keeps: the active branch in file order through that turn's last
/// chain record. That is the record before the chain's next prompt or
/// compaction, which is usually the turn's `turn_duration`, else the leaf, so
/// a turn still running after it stays behind. A later compaction stays
/// behind with the turns after it, so a fork from before one continues from
/// the whole conversation it summarised.
///
/// Records the branch keeps beside the chain, such as parallel tool results,
/// come along. Records without an id carry metadata rather than turns, and stay
/// behind as with the CLI's own fork; the fork's title is the bridge's. Inline
/// sub-agent records stay with the origin, as its sub-agent transcripts do.
_ForkPrefix _forkPrefix({required List<ClaudeTranscriptEntry> entries, required String messageId}) {
  final records = [for (final entry in entries) entry.record];
  final active = _activeChain(records: records);
  if (active == null) return const _ForkRefused(reason: ClaudeForkRefusal.notOnActiveBranch);
  final byId = {for (final record in records) ?_chainId(record): record};
  final chain = [for (final id in active.chain.toList().reversed) ?byId[id]];
  // An assistant message spans several records; its last one is the latest.
  final target = chain.lastIndexWhere((record) => _messageIdOf(record) == messageId);
  if (target == -1) return const _ForkRefused(reason: ClaudeForkRefusal.notOnActiveBranch);
  var last = target;
  while (last + 1 < chain.length && !_startsBranch(chain[last + 1])) {
    last++;
  }
  final boundary = chain[last];
  final branch = Set<ClaudeTranscriptRecordDto>.identity()..addAll(_activeBranch(records: records));
  final end = entries.indexWhere((entry) => identical(entry.record, boundary));
  return _ForkKept(
    records: [
      for (final entry in entries.take(end + 1))
        if (branch.contains(entry.record) && _chainId(entry.record) != null) entry.json,
    ],
  );
}

/// The Sesori message id a record carries, as history maps it.
String? _messageIdOf(ClaudeTranscriptRecordDto record) => switch (_mapTranscriptRecord(record)) {
  ClaudeTranscriptUserRecord(:final id) ||
  ClaudeTranscriptAssistantRecord(:final id) ||
  ClaudeTranscriptApiErrorRecord(:final id) ||
  ClaudeTranscriptQueuedCommandRecord(:final id) => id,
  _ => null,
};

bool _isCompactBoundary(ClaudeTranscriptRecordDto record) =>
    record.type == ClaudeTranscriptContextKind.system.wireType &&
    record.subtype == ClaudeTranscriptCompactBoundaryRecord.subtype;

/// A main-chain record's id; null for sub-agent records and records without
/// one.
String? _chainId(ClaudeTranscriptRecordDto record) =>
    (record.isSidechain ?? false) ? null : trimmedOrNull(value: record.uuid);

/// What a rewound branch starts with: a prompt, or a compaction when the
/// rewind went back to just before it. An active compaction is on the chain,
/// so a boundary off it was always left behind.
bool _startsBranch(ClaudeTranscriptRecordDto record) => _isPrompt(record) || _isCompactBoundary(record);

/// A user record that is not a tool result.
bool _isPrompt(ClaudeTranscriptRecordDto record) =>
    record.type == ClaudeTranscriptUserRecord.wireType && record.sourceToolAssistantUuid == null;

const String _lastPromptType = "last-prompt";

/// Maps the generated API DTO into the closed variants the repository uses.
ClaudeTranscriptRecord _mapTranscriptRecord(ClaudeTranscriptRecordDto dto) {
  final type = dto.type;
  if (type == null) {
    return ClaudeTranscriptUnknownRecord(type: null, sessionId: dto.sessionId);
  }

  if (type == ClaudeTranscriptUserRecord.wireType) {
    final id = trimmedOrNull(value: dto.uuid);
    if (id != null) {
      return ClaudeTranscriptUserRecord(
        id: id,
        content: dto.message?.content,
        isMeta: dto.isMeta ?? false,
        isVisibleInTranscriptOnly: dto.isVisibleInTranscriptOnly ?? false,
        isCompactSummary: dto.isCompactSummary ?? false,
        toolUseResult: dto.toolUseResult,
        originKind: dto.originKind,
        isUnattributedSdkRecord: dto.entrypoint == _sdkEntrypoint && dto.turnAttributionKey == null,
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        agentId: dto.agentId,
        sessionId: dto.sessionId,
      );
    }
    return _unreplayableMessageRecord(dto: dto);
  }

  if (type == ClaudeTranscriptAssistantRecord.wireType) {
    final id = trimmedOrNull(value: dto.message?.id);
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
          sessionId: dto.sessionId,
        );
      }
      return ClaudeTranscriptAssistantRecord(
        id: id,
        model: trimmedOrNull(value: dto.message?.model),
        effort: ClaudeEffortLevel.tryParse(dto.effort),
        content: dto.message?.content,
        cwd: dto.cwd,
        timestamp: dto.timestamp,
        isSidechain: dto.isSidechain,
        agentId: dto.agentId,
        sessionId: dto.sessionId,
      );
    }
    return _unreplayableMessageRecord(dto: dto);
  }

  final attachment = dto.attachment;
  if (type == ClaudeTranscriptContextKind.attachment.wireType &&
      attachment != null &&
      attachment.type == ClaudeTranscriptQueuedCommandRecord.attachmentType) {
    final id = trimmedOrNull(value: attachment.sourceUuid) ?? trimmedOrNull(value: dto.uuid);
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
        sessionId: dto.sessionId,
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
      sessionId: dto.sessionId,
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
      sessionId: dto.sessionId,
    );
  }

  final titleKind = ClaudeTranscriptTitleKind.tryParse(type);
  if (titleKind != null) {
    final title = trimmedOrNull(
      value: switch (titleKind) {
        ClaudeTranscriptTitleKind.custom => dto.customTitle,
        ClaudeTranscriptTitleKind.generated => dto.aiTitle,
      },
    );
    if (title != null) {
      return ClaudeTranscriptTitleRecord(kind: titleKind, title: title, sessionId: dto.sessionId);
    }
  }

  return ClaudeTranscriptUnknownRecord(type: type, sessionId: dto.sessionId);
}

ClaudeTranscriptUnreplayableMessageRecord _unreplayableMessageRecord({required ClaudeTranscriptRecordDto dto}) {
  return ClaudeTranscriptUnreplayableMessageRecord(
    cwd: dto.cwd,
    timestamp: dto.timestamp,
    isSidechain: dto.isSidechain,
    agentId: dto.agentId,
    sessionId: dto.sessionId,
  );
}
