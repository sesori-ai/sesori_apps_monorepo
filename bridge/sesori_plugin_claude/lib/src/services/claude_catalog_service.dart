import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/claude_process_purpose.dart";
import "../repositories/claude_backend_catalog_repository.dart";
import "../repositories/claude_session_process_repository.dart";

typedef _CatalogFetch = ({bool refresh, Future<ClaudeBackendCatalog> future});

/// Owns the per-directory catalog probes.
///
/// Claude lists a project's own commands and skills only to a process started
/// in that project, so each directory gets its own probe and cached catalog.
final class ClaudeCatalogService({
  required ClaudeBackendCatalogRepository catalog,
  required final ClaudeSessionProcessRepository _processes,
  required final String Function() _generateProbeSessionId,

  /// Where a request that names no project probes: the user's and Claude's
  /// own entries, without any project's.
  required String discoveryDirectory,
}) {
  final ClaudeBackendCatalogRepository _catalogRepository = catalog;
  final String _discoveryDirectory = normalizeProjectDirectory(directory: discoveryDirectory);
  final Map<String, ClaudeBackendCatalog> _catalogs = {};
  final Map<String, _CatalogFetch> _fetches = {};
  ClaudeBackendCatalog? _latest;

  /// The last catalog discovered in any directory, or null before the first
  /// probe completes. Models come from the account, not the project, so any
  /// directory's catalog maps a live model name.
  ClaudeBackendCatalog? get latest => _latest;

  /// The catalog for [directory], or for the discovery directory when null.
  Future<ClaudeBackendCatalog> getCatalog({required String? directory, required bool refresh}) {
    final key = switch (directory) {
      final directory? => normalizeProjectDirectory(directory: directory),
      null => _discoveryDirectory,
    };
    final cached = _catalogs[key];
    if (!refresh && cached != null) {
      Log.d("[claude] session options cache hit for $key");
      return Future.value(cached);
    }
    final inFlight = _fetches[key];
    if (inFlight != null) {
      if (!refresh || inFlight.refresh) return inFlight.future;
      Log.d("[claude] queued session options refresh for $key");
      final queued = inFlight.future.then(
        (_) => _fetchCatalog(directory: key, refresh: true),
        onError: (Object _, StackTrace _) => _fetchCatalog(directory: key, refresh: true),
      );
      return _trackFetch(directory: key, refresh: true, future: queued);
    }

    return _trackFetch(
      directory: key,
      refresh: refresh,
      future: _fetchCatalog(directory: key, refresh: refresh),
    );
  }

  Future<ClaudeBackendCatalog> _trackFetch({
    required String directory,
    required bool refresh,
    required Future<ClaudeBackendCatalog> future,
  }) {
    _fetches[directory] = (refresh: refresh, future: future);
    return future.whenComplete(() {
      if (identical(_fetches[directory]?.future, future)) _fetches.remove(directory);
    });
  }

  Future<ClaudeBackendCatalog> _fetchCatalog({required String directory, required bool refresh}) async {
    Log.d("[claude] discovering session options in $directory (refresh=$refresh)");
    final probeSessionId = _generateProbeSessionId();
    try {
      await _processes.ensureResident(
        sessionId: probeSessionId,
        directory: directory,
        createNew: true,
        purpose: ClaudeProcessPurpose.catalogProbe,
        model: null,
        effort: null,
        permissionMode: null,
        fastMode: false,
        allowedTools: const [],
      );
      final catalog = await _readCatalog(
        sessionId: probeSessionId,
        refresh: refresh,
        skillNames: await _catalogRepository.readSkillNames(directory: directory),
      );
      _catalogs[directory] = catalog;
      _latest = catalog;
      final modelCount = catalog.providers.providers.fold<int>(0, (count, provider) => count + provider.models.length);
      Log.d(
        "[claude] discovered session options in $directory "
        "(${catalog.agents.length} agents, $modelCount models, ${catalog.commands.length} commands)",
      );
      return catalog;
    } finally {
      // A catalog probe never runs a turn or writes a transcript, so the session
      // service's idle reap does not own it. Reap it with the discovery request.
      await _processes.teardown(sessionId: probeSessionId);
    }
  }

  Future<ClaudeBackendCatalog> _readCatalog({
    required String sessionId,
    required bool refresh,
    required Set<String> skillNames,
  }) async {
    final handshake = _processes.handshake(sessionId: sessionId);
    if (handshake == null) throw StateError("Claude session has no catalog: $sessionId");
    final accountHandshake = await _unmaskFastMode(sessionId: sessionId, handshake: handshake);
    if (!refresh) return _catalogRepository.map(handshake: accountHandshake, skillNames: skillNames);

    final refreshed = await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "list_models",
      params: const {},
    );
    return _catalogRepository.map(handshake: {...accountHandshake, ...refreshed}, skillNames: skillNames);
  }

  /// Opts the probe into fast mode and re-reads the handshake, which then
  /// reports the account's real fast-mode state. The flag is process-scoped
  /// and the probe is torn down afterwards. Only probes feed the catalog,
  /// so a user session's masked handshake never decides availability.
  Future<Map<String, Object?>> _unmaskFastMode({
    required String sessionId,
    required Map<String, Object?> handshake,
  }) async {
    if (!_catalogRepository.fastModeNeedsOptIn(handshake: handshake)) return handshake;
    try {
      await _processes.sendControlRequest(
        sessionId: sessionId,
        subtype: "apply_flag_settings",
        params: const {
          "settings": {"fastMode": true},
        },
      );
      return await _processes.sendControlRequest(sessionId: sessionId, subtype: "initialize", params: const {});
    } on Object catch (error, stack) {
      Log.w("[claude] fast-mode availability unverified; offering it as available", error, stack);
      return handshake;
    }
  }
}
