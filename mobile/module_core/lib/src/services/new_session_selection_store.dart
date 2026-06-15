import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A snapshot of the new-session composer's agent / model / variant selection.
typedef NewSessionSelection = ({String? agent, AgentModel? agentModel});

/// In-memory store for the new-session composer's deliberately chosen agent /
/// model / variant (reasoning effort), keyed by project id.
///
/// The sibling of [DraftStore] for the unsent prompt *text*: it lets a model
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
class NewSessionSelectionStore {
  final Map<String, NewSessionSelection> _selections = <String, NewSessionSelection>{};

  /// The saved selection for [projectId], or `null` if none.
  NewSessionSelection? read(String projectId) => _selections[projectId];

  /// Saves the composer [agent]/[agentModel] selection for [projectId].
  void write(String projectId, {required String? agent, required AgentModel? agentModel}) {
    _selections[projectId] = (agent: agent, agentModel: agentModel);
  }

  /// Drops any saved selection for [projectId] (e.g. after the session is created).
  void clear(String projectId) => _selections.remove(projectId);
}
