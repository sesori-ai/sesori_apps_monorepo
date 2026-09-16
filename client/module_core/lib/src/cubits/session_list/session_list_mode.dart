import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/session_list_filter.dart";

/// Pages own viewing semantics and fetch their inventory. A sidebar's lazy
/// action scope starts from its existing inventory and never claims a view.
sealed class const SessionListMode() {
  const factory view({required SessionListFilter filter}) = SessionListViewMode;
  const factory actions({required List<Session> sessions}) = SessionListActionsMode;
}

final class const SessionListViewMode({required final SessionListFilter filter}) extends SessionListMode;
final class const SessionListActionsMode({required final List<Session> sessions}) extends SessionListMode;
