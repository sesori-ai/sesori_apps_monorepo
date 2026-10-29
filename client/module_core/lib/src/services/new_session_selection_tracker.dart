import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "models/new_session_backend_scope.dart";
import "models/new_session_selection_intent.dart";

typedef _RevisionedSelection = ({NewSessionSelectionIntent selection, int revision});

/// Tracks only deliberate new-session harness, agent, model, variant, and
/// fast-mode choices.
///
/// Each dimension is independent so a user choosing one value never persists a
/// service-computed default for another. Selections live only for the current
/// app run and are cleared when the backend changes. The harness choice is
/// shared by every project, so changing the project keeps it.
@lazySingleton
class NewSessionSelectionTracker() {
  final Map<({String projectId, String pluginId}), _RevisionedSelection> _selections = {};
  int _nextRevision = 0;
  String? _selectedPluginId;
  NewSessionBackendScope _backendScope = const NewSessionBackendScope.unverified(
    lastIdentifiedBridgeId: null,
  );

  NewSessionBackendScope get backendScope => _backendScope;

  /// The harness the user last picked on the new-session screen, if any.
  String? get selectedPluginId => _selectedPluginId;

  /// Applies the same backend-scope transition used to decide whether cached
  /// options can survive discovery.
  void applyBackendScopeTransition({required NewSessionBackendScopeTransition transition}) {
    if (!transition.retainsBackendState) {
      _selections.clear();
      _selectedPluginId = null;
    }
    _backendScope = transition.scope;
  }

  void recordPlugin({required String pluginId}) => _selectedPluginId = pluginId;

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
        fastMode: current.fastMode,
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
        fastMode: current.fastMode,
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
        fastMode: current.fastMode,
      ),
    );
  }

  void recordFastMode({required String projectId, required String pluginId, required bool fastMode}) {
    final current = read(projectId: projectId, pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      projectId: projectId,
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: current.agentName,
        model: current.model,
        variant: current.variant,
        fastMode: fastMode,
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
