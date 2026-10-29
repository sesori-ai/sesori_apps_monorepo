import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSession, PluginSessionTime;

import "../api/pi_session_storage_api.dart";

final class PiSessionCatalogRepository({required final PiSessionStorageApi _storageApi}) {
  final Map<String, ({String directory, String? parentId})> _primedSessions = {};
  final Set<String> _knownDirectories = {};

  /// Every candidate session file of the last scan by path, with the stamp it
  /// was read at, so a rescan only reads new or changed files.
  final Map<String, PiScannedSessionFile> _files = {};

  /// Parents outside the scanned roots, from the last scan.
  List<PiSessionFile> _externalParents = const [];

  /// Persisted sessions by id, linked from [_files] and [_externalParents].
  Map<String, PiResolvedSession> _resolvedById = const {};

  /// Persisted and primed sessions, newest first.
  List<PluginSession> _sessions = const [];
  Map<String, PluginSession> _snapshotById = const {};

  Map<String, PluginSession> get sessionSnapshot => _snapshotById;

  void primeSessionDirectory({required String sessionId, required String directory}) {
    recordPendingSession(
      sessionId: sessionId,
      directory: directory,
      parentSessionId: _primedSessions[sessionId]?.parentId,
    );
  }

  void recordPendingSession({
    required String sessionId,
    required String directory,
    required String? parentSessionId,
  }) {
    if (sessionId.isEmpty || directory.trim().isEmpty) return;
    final normalized = normalizeProjectDirectory(directory: directory);
    _primedSessions[sessionId] = (directory: normalized, parentId: parentSessionId);
    _knownDirectories.add(normalized);
  }

  void forgetSession({required String sessionId}) => _primedSessions.remove(sessionId);

  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    _addKnownDirectories(knownDirectories);
    await _rescan();
    return _sessions;
  }

  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = (await listAllSessions(knownDirectories: {target}))
        .where((session) => session.directory == target)
        .toList(growable: false);
    return _page(sessions: sessions, start: start, limit: limit);
  }

  /// Direct children from the last scan, unless the parent is not in it, plus
  /// children recorded as pending since.
  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    if (!_resolvedById.containsKey(sessionId)) await _rescan();
    return [
      for (final session in _sessions)
        if (session.parentID == sessionId) session,
      for (final MapEntry(key: id, value: primed) in _primedSessions.entries)
        if (primed.parentId == sessionId && !_snapshotById.containsKey(id))
          _primedSession(sessionId: id, primed: primed),
    ];
  }

  /// Puts a successful rename into the cached file, which the next scan
  /// re-reads anyway because the rename changed its stamp.
  void recordRename({required String sessionId, required String title}) {
    final path = _resolvedById[sessionId]?.path;
    final file = _files[path];
    final session = file?.session;
    if (path == null || file == null || session == null) return;
    _files[path] = PiScannedSessionFile(
      stamp: file.stamp,
      session: PiSessionFile(
        path: session.path,
        id: session.id,
        cwd: session.cwd,
        parentPath: session.parentPath,
        title: title,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      ),
    );
    _link();
  }

  /// A persisted or primed session from the last scan, or from one rescan on
  /// a miss.
  Future<PluginSession?> findSessionById({required String sessionId}) async {
    if (!_resolvedById.containsKey(sessionId)) await _rescan();
    return _snapshotById[sessionId];
  }

  /// A persisted session and its file from the last scan, or from one rescan
  /// on a miss. [knownDirectories] widens that rescan to the roots those
  /// directories configure.
  Future<PiResolvedSession?> resolveSession({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    if (!_resolvedById.containsKey(sessionId)) {
      _addKnownDirectories(knownDirectories);
      await _rescan();
    }
    return _resolvedById[sessionId];
  }

  Future<bool> hasPersistedSession({required String sessionId}) async =>
      await resolveSession(sessionId: sessionId, knownDirectories: const {}) != null;

  Future<({String displaySessionId, String projectId})?> resolveDisplayScope({required String sessionId}) async {
    final owner = await findSessionById(sessionId: sessionId);
    if (owner == null) return null;
    var display = owner;
    final visited = {owner.id};
    while (true) {
      final parentId = display.parentID;
      if (parentId == null || !visited.add(parentId)) break;
      final parent = _snapshotById[parentId];
      if (parent == null) break;
      display = parent;
    }
    return (displaySessionId: display.id, projectId: owner.projectID);
  }

  /// Deletes a persisted session's file and the session's pending markers.
  Future<void> deleteSession({required String sessionId, required String? directory}) async {
    final directories = {
      if (directory != null && directory.trim().isNotEmpty) directory,
    };
    final resolved = await resolveSession(sessionId: sessionId, knownDirectories: directories);
    if (resolved != null) {
      _storageApi.deleteSessionFile(path: resolved.path);
      _files.remove(resolved.path);
      _externalParents = [
        for (final parent in _externalParents)
          if (parent.path != resolved.path) parent,
      ];
      _deletedDuringScan.add(resolved.path);
      _link();
    }
    await _storageApi.clearPendingNewSession(
      sessionId: sessionId,
      knownDirectories: {...directories, ?resolved?.metadata.cwd},
    );
  }

  void _addKnownDirectories(Set<String> directories) {
    _knownDirectories.addAll({
      for (final directory in directories)
        if (directory.trim().isNotEmpty) normalizeProjectDirectory(directory: directory),
    });
  }

  /// Scans run one at a time so an older scan never merges over a newer one.
  Future<void>? _scanInFlight;

  /// The one scan queued behind [_scanInFlight], shared by every caller that
  /// arrives meanwhile, so each of them sees the disk as of after its call.
  Future<void>? _queuedScan;

  /// Paths deleted while the current scan runs; its merge must not re-add
  /// them.
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

  Future<void> _scan() async {
    _deletedDuringScan.clear();
    final known = <String, PiKnownSessionFile>{
      for (final MapEntry(key: path, value: file) in _files.entries)
        path: (stamp: file.stamp, parentPath: file.session?.parentPath),
    };
    final scan = await _storageApi.scanSessionFiles(
      knownDirectories: {..._knownDirectories, ..._primedSessions.values.map((session) => session.directory)},
      known: known,
    );
    _files.removeWhere((path, _) => !scan.present.contains(path));
    for (final MapEntry(key: path, value: file) in scan.parsed.entries) {
      if (_deletedDuringScan.contains(path)) continue;
      // An unreadable file stays uncached so the next scan reads it again.
      if (file.session == null) {
        _files.remove(path);
      } else {
        _files[path] = file;
      }
    }
    _externalParents = [
      for (final parent in scan.externalParents)
        if (!_deletedDuringScan.contains(parent.path)) parent,
    ];
    _link();
    Log.d("[pi] session catalog scan: files=${scan.present.length}, parsed=${scan.parsed.length}");
  }

  /// Rebuilds the sessions from the cached files and the primed sessions not
  /// yet persisted.
  void _link() {
    final resolved = _storageApi.linkSessionFiles(
      files: [
        for (final file in _files.values) ?file.session,
        ..._externalParents,
      ],
    );
    _resolvedById = {for (final session in resolved) session.metadata.id: session};
    _primedSessions.removeWhere((sessionId, _) => _resolvedById.containsKey(sessionId));
    final primedIds = _primedSessions.keys.toList()..sort();
    _sessions = List.unmodifiable([
      for (final session in resolved) _toPluginSession(session.metadata),
      for (final sessionId in primedIds)
        if (_primedSessions[sessionId] case final primed?) _primedSession(sessionId: sessionId, primed: primed),
    ]);
    _snapshotById = Map.unmodifiable({for (final session in _sessions) session.id: session});
  }

  PluginSession _primedSession({required String sessionId, required ({String directory, String? parentId}) primed}) =>
      PluginSession(
        id: sessionId,
        projectID: primed.directory,
        directory: primed.directory,
        parentID: primed.parentId,
        title: null,
        time: null,
      );

  PluginSession _toPluginSession(PiSessionMetadata metadata) {
    final directory = normalizeProjectDirectory(directory: metadata.cwd);
    final updated = metadata.updatedAt.millisecondsSinceEpoch;
    return PluginSession(
      id: metadata.id,
      projectID: directory,
      directory: directory,
      parentID: metadata.parentId,
      title: metadata.title,
      time: PluginSessionTime(
        created: metadata.createdAt?.millisecondsSinceEpoch ?? updated,
        updated: updated,
        archived: null,
      ),
    );
  }

  List<PluginSession> _page({required List<PluginSession> sessions, required int? start, required int? limit}) {
    final from = (start ?? 0).clamp(0, sessions.length);
    if (from >= sessions.length) return const [];
    final pageSize = limit?.clamp(0, sessions.length);
    final until = pageSize == null ? sessions.length : (from + pageSize).clamp(from, sessions.length);
    return sessions.sublist(from, until);
  }
}
