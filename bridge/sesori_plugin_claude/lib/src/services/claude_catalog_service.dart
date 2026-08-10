import "../models/claude_agent_selection.dart";
import "../repositories/claude_backend_catalog_repository.dart";
import "../repositories/claude_session_process_repository.dart";

/// Composes the retained process handshake with catalog and selection controls.
final class ClaudeCatalogService {
  ClaudeCatalogService({
    required ClaudeBackendCatalogRepository catalog,
    required ClaudeSessionProcessRepository processes,
  }) : _catalog = catalog,
       _processes = processes;

  final ClaudeBackendCatalogRepository _catalog;
  final ClaudeSessionProcessRepository _processes;

  Future<ClaudeBackendCatalog> getCatalog({required String sessionId, required bool refresh}) async {
    final handshake = _processes.handshake(sessionId: sessionId);
    if (handshake == null) throw StateError("Claude session has no catalog: $sessionId");
    if (!refresh) return _catalog.map(handshake: handshake);

    final refreshed = await _processes.sendControlRequest(
      sessionId: sessionId,
      subtype: "list_models",
      params: const {},
    );
    return _catalog.map(handshake: {...handshake, ...refreshed});
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
