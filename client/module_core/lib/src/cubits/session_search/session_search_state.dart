import "package:sesori_shared/sesori_shared.dart";

/// What a prompt to a running session does, as its plugin declares it.
enum RunningTarget() {
  /// The prompt stops the running turn, then starts.
  stopsTurn,

  /// The running turn takes the prompt in, or the plugin does not say.
  keepsTurn,
}

/// A session that matches the search, with the project it opens in, and
/// what a prompt to it does while it runs: null when it is idle.
typedef SessionSearchMatch = ({Session session, ProjectSummary project, RunningTarget? running});

final class const SessionSearchState({
  /// Newest first, at most the cubit's limit. The list stays the same
  /// instance while its content is unchanged.
  required final List<SessionSearchMatch> matches,

  /// Whether the bridge's answer for the query is still to come, so an empty
  /// [matches] does not yet mean that nothing matches.
  required final bool isSearching,
});
