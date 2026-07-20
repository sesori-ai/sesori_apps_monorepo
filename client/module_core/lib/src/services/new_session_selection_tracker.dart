import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A snapshot of the new-session composer's agent / model / variant selection.
typedef NewSessionSelection = ({String? agent, AgentModel? agentModel});
typedef _RevisionedSelection = ({NewSessionSelection selection, int revision});

/// Tracks the new-session composer's deliberately chosen agent / model /
/// variant (reasoning effort) per project and plugin, exposing the latest snapshot.
///
/// The selection counterpart of the unsent prompt *text* draft: it lets a model
/// or effort the user picked survive navigating away from the new-session
/// screen and back, where the `NewSessionCubit` is disposed and recreated and
/// its state would otherwise reset to the computed default.
///
/// Only the user's explicit choices are written here — never the auto-computed
/// default — so a stale entry can never shadow a future default. The cubit
/// validates a restored selection against freshly loaded providers/agents, so
/// a now-unavailable model or variant falls back to the default.
///
/// Intentionally lightweight: selections live only for the current app run and
/// are cleared once the session is created (mirroring how a sent prompt clears
/// its draft).
@lazySingleton
class NewSessionSelectionTracker {
  final Map<({String projectId, String pluginId}), _RevisionedSelection> _selections =
      <({String projectId, String pluginId}), _RevisionedSelection>{};
  int _nextRevision = 0;

  /// The saved selection for [projectId] and [pluginId], or `null` if none.
  NewSessionSelection? read({required String projectId, required String pluginId}) =>
      _selections[(projectId: projectId, pluginId: pluginId)]?.selection;

  /// The revision of the latest write for [projectId] and [pluginId].
  int? currentRevision({required String projectId, required String pluginId}) =>
      _selections[(projectId: projectId, pluginId: pluginId)]?.revision;

  /// Saves the composer [agent]/[agentModel] selection for [projectId] and [pluginId].
  void write({
    required String projectId,
    required String pluginId,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    _selections[(projectId: projectId, pluginId: pluginId)] = (
      selection: (agent: agent, agentModel: agentModel),
      revision: ++_nextRevision,
    );
  }

  /// Drops the saved selection only when it is still the write at [revision].
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

  /// Drops the saved selection for [projectId] and [pluginId].
  void clear({required String projectId, required String pluginId}) =>
      _selections.remove((projectId: projectId, pluginId: pluginId));
}
