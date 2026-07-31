import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "models/new_session_selection_intent.dart";

typedef _RevisionedSelection = ({NewSessionSelectionIntent selection, int revision});

/// Tracks only deliberate new-session agent, model, and variant choices.
///
/// Each dimension is independent so a user choosing one value never persists a
/// service-computed default for another. Selections live only for the current
/// app run and are cleared after successful session creation.
@lazySingleton
class NewSessionSelectionTracker {
  final Map<({String projectId, String pluginId}), _RevisionedSelection> _selections = {};
  int _nextRevision = 0;
  bool _hasBridgeScope = false;
  String? _bridgeId;

  /// Clears backend-local intent when the active connection moves to another
  /// identified bridge or when bridge identity is unavailable. Re-establishing
  /// the same identified scope preserves intent across New Session screen
  /// recreation within the current app run.
  void establishBridgeScope({required String? bridgeId}) {
    if (_hasBridgeScope && (bridgeId == null || _bridgeId != bridgeId)) {
      _selections.clear();
    }
    _hasBridgeScope = true;
    _bridgeId = bridgeId;
  }

  NewSessionSelectionIntent? read({required String projectId, required String pluginId}) =>
      _selections[(projectId: projectId, pluginId: pluginId)]?.selection;

  int? currentRevision({required String projectId, required String pluginId}) =>
      _selections[(projectId: projectId, pluginId: pluginId)]?.revision;

  void recordAgent({required String projectId, required String pluginId, required String agentName}) {
    final current = read(projectId: projectId, pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      projectId: projectId,
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: agentName,
        model: current.model,
        variant: current.variant,
      ),
    );
  }

  void recordModel({
    required String projectId,
    required String pluginId,
    required String providerId,
    required String modelId,
  }) {
    final current = read(projectId: projectId, pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      projectId: projectId,
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: current.agentName,
        model: NewSessionModelIntent(providerId: providerId, modelId: modelId),
        variant: current.variant,
      ),
    );
  }

  void recordVariant({
    required String projectId,
    required String pluginId,
    required NewSessionVariantIntent variant,
  }) {
    final current = read(projectId: projectId, pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      projectId: projectId,
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: current.agentName,
        model: current.model,
        variant: variant,
      ),
    );
  }

  @visibleForTesting
  void write({
    required String projectId,
    required String pluginId,
    required NewSessionSelectionIntent selection,
  }) {
    _write(projectId: projectId, pluginId: pluginId, selection: selection);
  }

  void _write({
    required String projectId,
    required String pluginId,
    required NewSessionSelectionIntent selection,
  }) {
    _selections[(projectId: projectId, pluginId: pluginId)] = (
      selection: selection,
      revision: ++_nextRevision,
    );
  }

  void clearIfRevision({
    required String projectId,
    required String pluginId,
    required int? revision,
  }) {
    final key = (projectId: projectId, pluginId: pluginId);
    if (_selections[key]?.revision == revision) {
      _selections.remove(key);
    }
  }

  void clear({required String projectId, required String pluginId}) =>
      _selections.remove((projectId: projectId, pluginId: pluginId));
}
