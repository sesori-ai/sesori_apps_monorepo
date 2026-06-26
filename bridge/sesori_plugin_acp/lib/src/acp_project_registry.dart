import "dart:convert";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Persistent registry of the directories an ACP agent has been pointed at as
/// projects.
///
/// ACP agents (Cursor, Codex, …) are single-process and have no notion of a
/// "project list": each `session/new`/`session/load` merely carries a `cwd`.
/// To let the app open several directories as projects — the way OpenCode's
/// server tracks every project you have worked in — the plugin keeps the list
/// here instead.
///
/// The launch [cwd] is always present (the implicit default project, so the
/// list is never empty on a fresh install). Opening a directory ([register])
/// adds it. Entries other than the implicit default persist across bridge
/// restarts via the host [store] (a single JSON file in the plugin's private
/// state directory), so a discovered project survives a restart rather than
/// vanishing — matching the durability of OpenCode's server-tracked list.
///
/// All ids are canonical absolute paths ([p.normalize]d), so the same directory
/// reached two ways (trailing slash, `.` segment) is one project.
class AcpProjectRegistry {
  AcpProjectRegistry({
    required String cwd,
    HostJsonStore? store,
    String fileName = defaultFileName,
    int Function()? nowMs,
  })  : _cwd = _normalize(cwd),
        _store = store,
        _fileName = fileName,
        _now = nowMs ?? _wallClockMs;

  /// File name used inside the plugin's state directory.
  static const String defaultFileName = "acp-projects.json";
  static const int _schemaVersion = 1;

  final String _cwd;
  final HostJsonStore? _store;
  final String _fileName;
  final int Function() _now;

  /// Canonical-id -> entry, in insertion order. Always contains the cwd seed
  /// after [ensureLoaded].
  final Map<String, _ProjectEntry> _entries = {};
  Future<void>? _loading;

  /// The launch CWD's canonical id (the implicit default project).
  String get cwd => _cwd;

  /// Loads the persisted registry once. Idempotent and safe to call from every
  /// accessor — the read happens at most once per instance.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    // Seed the implicit default first so it is present even when the persisted
    // file is missing or corrupt. createdAt = load time so freshly opened
    // projects (registered later) sort above it, newest-first.
    _entries[_cwd] = _ProjectEntry(id: _cwd, createdAt: _now(), persisted: false);

    final store = _store;
    if (store == null) return;

    String? raw;
    try {
      raw = await store.read(name: _fileName);
    } catch (error, stack) {
      // Unreadable store: serve the cwd seed only. Log so a persistent hydration
      // failure (e.g. a permissions problem) is diagnosable rather than silent.
      Log.w("[acp] project registry read failed; serving cwd seed only", error, stack);
      return;
    }
    if (raw == null || raw.trim().isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error, stack) {
      // Corrupt JSON: move it aside so a clean file can be written, keep seed.
      Log.w("[acp] project registry JSON is corrupt; quarantining", error, stack);
      // Awaited (not fire-and-forget) so the quarantine completes before any
      // later _persist() write — otherwise the rename can race ahead and move
      // aside the freshly written clean file.
      await _quarantine();
      return;
    }
    if (decoded is! Map) return;
    final list = decoded["projects"];
    if (list is! List) return;
    for (final item in list) {
      if (item is! Map) continue;
      final rawId = item["id"];
      if (rawId is! String || rawId.trim().isEmpty) continue;
      final id = _normalize(rawId);
      final createdAtRaw = item["createdAt"];
      final createdAt = createdAtRaw is int
          ? createdAtRaw
          : (createdAtRaw is num ? createdAtRaw.round() : _now());
      final nameRaw = item["name"];
      final name = nameRaw is String && nameRaw.trim().isNotEmpty ? nameRaw.trim() : null;
      _entries[id] = _ProjectEntry(
        id: id,
        createdAt: createdAt,
        name: name,
        persisted: true,
      );
    }
  }

  /// Registers [path] as a known project, persisting it. Returns the canonical
  /// id. Idempotent: an already-known project is left untouched (no rewrite).
  /// An empty/invalid path falls back to the cwd default.
  Future<String> register(String path) async {
    await ensureLoaded();
    final id = _normalize(path);
    if (id.isEmpty) return _cwd;
    final existing = _entries[id];
    if (existing != null && existing.persisted) return id;
    _entries[id] = _ProjectEntry(
      id: id,
      createdAt: existing?.createdAt ?? _now(),
      name: existing?.name,
      persisted: true,
    );
    await _persist();
    return id;
  }

  /// Sets a display [name] for [path] (the project's name otherwise derives from
  /// the directory's basename), persisting it. Registers the project if unknown.
  Future<void> rename({required String path, required String name}) async {
    await ensureLoaded();
    final id = _normalize(path);
    if (id.isEmpty) return;
    final existing = _entries[id];
    final trimmed = name.trim();
    _entries[id] = _ProjectEntry(
      id: id,
      createdAt: existing?.createdAt ?? _now(),
      name: trimmed.isEmpty ? null : trimmed,
      persisted: true,
    );
    await _persist();
  }

  /// All known projects, most-recently-registered first (the implicit default
  /// cwd sorts oldest unless it was explicitly opened).
  List<PluginProject> list() {
    final entries = _entries.values.toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return [for (final e in entries) e.toProject()];
  }

  /// The project for [path] — the registered entry, or a synthesized one for an
  /// unknown path (without registering it; [register] does that).
  PluginProject projectFor(String path) {
    final id = _normalize(path);
    final entry = _entries[id];
    if (entry != null) return entry.toProject();
    final fallbackId = id.isEmpty ? _cwd : id;
    return _ProjectEntry(id: fallbackId, createdAt: _now(), persisted: false).toProject();
  }

  /// Serializes persistence so concurrent register/rename calls cannot interleave
  /// or complete out of order and drop entries. Each link snapshots [_entries]
  /// when it runs, so the final write reflects the latest state.
  Future<void> _writeChain = Future.value();

  Future<void> _persist() {
    final next = _writeChain.then((_) => _write());
    // Keep the chain alive even if a write fails so the next link still runs.
    _writeChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write() async {
    final store = _store;
    if (store == null) return;
    final payload = jsonEncode({
      "version": _schemaVersion,
      "projects": [
        // The implicit cwd default (persisted == false) is re-seeded on load,
        // so it is never written — only explicitly opened/renamed projects are.
        for (final e in _entries.values)
          if (e.persisted)
            {
              "id": e.id,
              "createdAt": e.createdAt,
              if (e.name != null) "name": e.name,
            },
      ],
    });
    try {
      await store.write(name: _fileName, contents: payload);
    } catch (_) {
      // Best-effort: the in-memory list still serves this run.
    }
  }

  Future<void> _quarantine() async {
    try {
      await _store?.quarantine(
        name: _fileName,
        quarantinedName: "$_fileName.corrupt",
      );
    } catch (_) {
      // Best-effort.
    }
  }

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  static String _normalize(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return "";
    return p.normalize(trimmed);
  }
}

class _ProjectEntry {
  _ProjectEntry({
    required this.id,
    required this.createdAt,
    this.name,
    required this.persisted,
  });

  final String id;
  final int createdAt;
  final String? name;

  /// Whether this entry is written to disk. The implicit cwd default is not
  /// (it is re-seeded each load); explicitly opened/renamed projects are.
  final bool persisted;

  PluginProject toProject() {
    final display = name ?? _basename(id);
    return PluginProject(
      id: id,
      name: display,
      time: PluginProjectTime(created: createdAt, updated: createdAt),
    );
  }

  static String _basename(String id) {
    final base = p.basename(id);
    return base.isEmpty ? id : base;
  }
}
