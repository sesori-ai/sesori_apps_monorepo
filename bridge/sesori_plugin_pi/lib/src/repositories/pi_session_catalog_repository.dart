import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession, PluginSessionTime;

import "../api/pi_session_storage_api.dart";

final class PiSessionCatalogRepository({required final PiSessionStorageApi _storageApi}) {
  final Map<String, ({String directory, String? parentId})> _primedSessions = {};
  final Map<String, PluginSession> _snapshotById = {};
  final Set<String> _knownDirectories = {};

  Map<String, PluginSession> get sessionSnapshot => Map.unmodifiable(_snapshotById);

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

  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) =>
      _readSessions(knownDirectories: knownDirectories);

  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = (await _readSessions(knownDirectories: {target}))
        .where((session) => session.directory == target)
        .toList(growable: false);
    return _page(sessions: sessions, start: start, limit: limit);
  }

  Future<List<PluginSession>> getChildSessions({required String sessionId}) async => [
    for (final session in await _readSessions(knownDirectories: const {}))
      if (session.parentID == sessionId) session,
  ];

  Future<PluginSession?> findSessionById({required String sessionId}) async {
    for (final session in await _readSessions(knownDirectories: const {})) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  Future<({String displaySessionId, String projectId})?> resolveDisplayScope({required String sessionId}) async {
    final sessions = await _readSessions(knownDirectories: const {});
    final byId = {for (final session in sessions) session.id: session};
    final owner = byId[sessionId];
    if (owner == null) return null;
    var display = owner;
    final visited = {owner.id};
    while (true) {
      final parentId = display.parentID;
      if (parentId == null || !visited.add(parentId)) break;
      final parent = byId[parentId];
      if (parent == null) break;
      display = parent;
    }
    return (displaySessionId: display.id, projectId: owner.projectID);
  }

  Future<List<PluginSession>> _readSessions({required Set<String> knownDirectories}) async {
    _knownDirectories.addAll({
      for (final directory in knownDirectories)
        if (directory.trim().isNotEmpty) normalizeProjectDirectory(directory: directory),
    });
    final scanDirectories = {..._knownDirectories, ..._primedSessions.values.map((session) => session.directory)};
    final metadata = await _storageApi.listSessionMetadata(knownDirectories: scanDirectories);
    final observedIds = metadata.map((session) => session.id).toSet();
    _primedSessions.removeWhere((sessionId, _) => observedIds.contains(sessionId));
    final sessions = <PluginSession>[
      for (final session in metadata) _toPluginSession(session),
      for (final entry in _primedSessions.entries)
        PluginSession(
          id: entry.key,
          projectID: entry.value.directory,
          directory: entry.value.directory,
          parentID: entry.value.parentId,
          title: null,
          time: null,
        ),
    ];
    _snapshotById
      ..clear()
      ..addEntries(sessions.map((session) => MapEntry(session.id, session)));
    sessions.sort((left, right) {
      final leftUpdated = left.time?.updated;
      final rightUpdated = right.time?.updated;
      if (leftUpdated == null && rightUpdated == null) return left.id.compareTo(right.id);
      if (leftUpdated == null) return 1;
      if (rightUpdated == null) return -1;
      final timeOrder = rightUpdated.compareTo(leftUpdated);
      return timeOrder == 0 ? left.id.compareTo(right.id) : timeOrder;
    });
    return List.unmodifiable(sessions);
  }

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
