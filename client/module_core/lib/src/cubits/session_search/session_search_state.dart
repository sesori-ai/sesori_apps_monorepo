import "package:sesori_shared/sesori_shared.dart";

/// A session that matches the search, with the project it opens in.
typedef SessionSearchMatch = ({Session session, ProjectSummary project});

final class const SessionSearchState({
  /// Newest first, at most the cubit's limit. The list stays the same
  /// instance while its content is unchanged.
  required final List<SessionSearchMatch> matches,

  /// Whether the bridge's answer for the query is still to come, so an empty
  /// [matches] does not yet mean that nothing matches.
  required final bool isSearching,
});
