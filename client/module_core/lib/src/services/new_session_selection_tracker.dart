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
/// app run and are cleared when the backend changes. They belong to the
/// harness, not the project: a project that does not offer a pick falls back
/// to its own default, and the pick returns with a project that does, unless
/// the user has picked another value for it in the meantime.
@lazySingleton
class NewSessionSelectionTracker() {
  final Map<String, _RevisionedSelection> _selections = {};
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

  NewSessionSelectionIntent? read({required String pluginId}) => _selections[pluginId]?.selection;

  int? currentRevision({required String pluginId}) => _selections[pluginId]?.revision;

  void recordAgent({required String pluginId, required String agentName}) {
    final current = read(pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: agentName,
        model: current.model,
        variant: current.variant,
        fastMode: current.fastMode,
      ),
    );
  }

  void recordModel({required String pluginId, required String providerId, required String modelId}) {
    final current = read(pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: current.agentName,
        model: NewSessionModelIntent(providerId: providerId, modelId: modelId),
        variant: current.variant,
        fastMode: current.fastMode,
      ),
    );
  }

  void recordVariant({required String pluginId, required NewSessionVariantIntent variant}) {
    final current = read(pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
      pluginId: pluginId,
      selection: NewSessionSelectionIntent(
        agentName: current.agentName,
        model: current.model,
        variant: variant,
        fastMode: current.fastMode,
      ),
    );
  }

  void recordFastMode({required String pluginId, required bool fastMode}) {
    final current = read(pluginId: pluginId) ?? const NewSessionSelectionIntent.empty();
    _write(
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
  void write({required String pluginId, required NewSessionSelectionIntent selection}) {
    _write(pluginId: pluginId, selection: selection);
  }

  void _write({required String pluginId, required NewSessionSelectionIntent selection}) {
    _selections[pluginId] = (selection: selection, revision: ++_nextRevision);
  }

  void clearIfRevision({required String pluginId, required int? revision}) {
    if (_selections[pluginId]?.revision == revision) {
      _selections.remove(pluginId);
    }
  }
}
