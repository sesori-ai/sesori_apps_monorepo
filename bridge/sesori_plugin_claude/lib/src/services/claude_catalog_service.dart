import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/claude_agent_selection.dart";
import "../repositories/claude_backend_catalog_repository.dart";
import "../repositories/claude_session_process_repository.dart";

typedef ClaudeCatalogSessionIdGenerator = String Function();
typedef _CatalogFetch = ({bool refresh, Future<ClaudeBackendCatalog> future});

/// Owns project-scoped catalog discovery and live-session selection controls.
final class ClaudeCatalogService {
  ClaudeCatalogService({
    required ClaudeBackendCatalogRepository catalog,
    required ClaudeSessionProcessRepository processes,
    required ClaudeCatalogSessionIdGenerator generateSessionId,
  }) : _catalogRepository = catalog,
       _processes = processes,
       _generateSessionId = generateSessionId;

  final ClaudeBackendCatalogRepository _catalogRepository;
  final ClaudeSessionProcessRepository _processes;
  final ClaudeCatalogSessionIdGenerator _generateSessionId;
  final Map<String, ClaudeBackendCatalog> _catalogs = {};
  final Map<String, _CatalogFetch> _fetches = {};
  final Map<String, String> _probeSessionIds = {};

  Future<ClaudeBackendCatalog> getCatalog({required String directory, required bool refresh}) {
    final normalized = normalizeProjectDirectory(directory: directory);
    final cached = _catalogs[normalized];
    if (!refresh && cached != null) {
      Log.d("[claude] session options cache hit for $normalized");
      return Future.value(cached);
    }
    final inFlight = _fetches[normalized];
    if (inFlight != null) {
      if (!refresh || inFlight.refresh) return inFlight.future;
      Log.d("[claude] queued session options refresh for $normalized");
      final sessionId = _probeSessionIds[normalized]!;
      final queued = inFlight.future.then(
        (_) => _fetchCatalog(directory: normalized, sessionId: sessionId, refresh: true),
        onError: (Object _, StackTrace __) => _fetchCatalog(directory: normalized, sessionId: sessionId, refresh: true),
      );
      return _trackFetch(directory: normalized, refresh: true, future: queued);
    }

    final sessionId = _probeSessionIds.putIfAbsent(normalized, _generateSessionId);
    final fetch = _fetchCatalog(
      directory: normalized,
      sessionId: sessionId,
      refresh: refresh,
    );
    return _trackFetch(directory: normalized, refresh: refresh, future: fetch);
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

  Future<ClaudeBackendCatalog> _fetchCatalog({
    required String directory,
    required String sessionId,
    required bool refresh,
  }) async {
    Log.d("[claude] discovering session options in $directory (refresh=$refresh)");
    try {
      await _processes.ensureResident(
        sessionId: sessionId,
        directory: directory,
        createNew: true,
        model: null,
        effort: null,
        permissionMode: null,
        allowedTools: const [],
      );
      final catalog = await _readCatalog(sessionId: sessionId, refresh: refresh);
      _catalogs[directory] = catalog;
      final modelCount = catalog.providers.providers.fold<int>(0, (count, provider) => count + provider.models.length);
      Log.d(
        "[claude] discovered session options in $directory "
        "(${catalog.agents.length} agents, $modelCount models, ${catalog.commands.length} commands)",
      );
      return catalog;
    } finally {
      // A catalog probe never runs a turn, so the session service's idle reap
      // does not own it. Reap it as part of the same project-scoped operation.
      await _processes.teardown(sessionId: sessionId);
    }
  }

  Future<ClaudeBackendCatalog> _readCatalog({required String sessionId, required bool refresh}) async {
    final handshake = _processes.handshake(sessionId: sessionId);
    if (handshake == null) throw StateError("Claude session has no catalog: $sessionId");
    if (!refresh) return _catalogRepository.map(handshake: handshake);

    final refreshed = await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "list_models",
      params: const {},
    );
    return _catalogRepository.map(handshake: {...handshake, ...refreshed});
  }

  Future<void> selectModel({
    required String sessionId,
    required String modelId,
  }) async {
    final isDefault = modelId == "default";
    await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "set_model",
      params: {"model": isDefault ? null : modelId},
    );
    final applied = _processes.appliedSelection(sessionId: sessionId);
    _processes.recordAppliedSelection(
      sessionId: sessionId,
      model: isDefault ? null : modelId,
      effort: applied?.effort,
      permissionMode: applied?.permissionMode,
    );
  }

  Future<void> selectAgent({required String sessionId, required String agent}) async {
    final selection = ClaudeAgentSelection.tryParse(agent);
    if (selection == null) throw ArgumentError.value(agent, "agent", "Unknown Claude agent");
    await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "set_permission_mode",
      params: {"mode": selection.permissionMode.controlValue},
    );
    final applied = _processes.appliedSelection(sessionId: sessionId);
    _processes.recordAppliedSelection(
      sessionId: sessionId,
      model: applied?.model,
      effort: applied?.effort,
      permissionMode: selection.permissionMode,
    );
  }
}
