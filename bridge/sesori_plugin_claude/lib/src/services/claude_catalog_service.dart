import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/claude_agent_selection.dart";
import "../repositories/claude_backend_catalog_repository.dart";
import "../repositories/claude_session_process_repository.dart";

typedef _CatalogFetch = ({bool refresh, Future<ClaudeBackendCatalog> future});

/// Owns the global catalog probe and live-session selection controls.
final class ClaudeCatalogService({
  required ClaudeBackendCatalogRepository catalog,
  required final ClaudeSessionProcessRepository _processes,
  required final String _probeSessionId,
  required final String _discoveryDirectory,
}) {
  final ClaudeBackendCatalogRepository _catalogRepository = catalog;
  ClaudeBackendCatalog? _catalog;
  _CatalogFetch? _fetch;

  Future<ClaudeBackendCatalog> getCatalog({required bool refresh}) {
    final cached = _catalog;
    if (!refresh && cached != null) {
      Log.d("[claude] global session options cache hit");
      return Future.value(cached);
    }
    final inFlight = _fetch;
    if (inFlight != null) {
      if (!refresh || inFlight.refresh) return inFlight.future;
      Log.d("[claude] queued global session options refresh");
      final queued = inFlight.future.then(
        (_) => _fetchCatalog(refresh: true),
        onError: (Object _, StackTrace _) => _fetchCatalog(refresh: true),
      );
      return _trackFetch(refresh: true, future: queued);
    }

    return _trackFetch(
      refresh: refresh,
      future: _fetchCatalog(refresh: refresh),
    );
  }

  Future<ClaudeBackendCatalog> _trackFetch({
    required bool refresh,
    required Future<ClaudeBackendCatalog> future,
  }) {
    _fetch = (refresh: refresh, future: future);
    return future.whenComplete(() {
      if (identical(_fetch?.future, future)) _fetch = null;
    });
  }

  Future<ClaudeBackendCatalog> _fetchCatalog({required bool refresh}) async {
    Log.d("[claude] discovering global session options in $_discoveryDirectory (refresh=$refresh)");
    try {
      await _processes.ensureResident(
        sessionId: _probeSessionId,
        directory: _discoveryDirectory,
        createNew: true,
        model: null,
        effort: null,
        permissionMode: null,
        allowedTools: const [],
        provisionAgentTools: false,
      );
      final catalog = await _readCatalog(sessionId: _probeSessionId, refresh: refresh);
      _catalog = catalog;
      final modelCount = catalog.providers.providers.fold<int>(0, (count, provider) => count + provider.models.length);
      Log.d(
        "[claude] discovered global session options in $_discoveryDirectory "
        "(${catalog.agents.length} agents, $modelCount models, ${catalog.commands.length} commands)",
      );
      return catalog;
    } finally {
      // A catalog probe never runs a turn or writes a transcript, so the session
      // service's idle reap does not own it. Reap it with the discovery request.
      await _processes.teardown(sessionId: _probeSessionId);
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
    await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "set_model",
      params: {"model": modelId},
    );
    final applied = _processes.appliedSelection(sessionId: sessionId);
    _processes.recordAppliedSelection(
      sessionId: sessionId,
      model: modelId,
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
