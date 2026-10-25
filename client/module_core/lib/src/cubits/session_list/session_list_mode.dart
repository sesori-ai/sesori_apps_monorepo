import "package:sesori_shared/sesori_shared.dart";

/// Pages own viewing semantics and fetch their inventory. A sidebar's lazy
/// action scope starts from its existing inventory and never claims a view.
sealed class const SessionListMode() {
  const factory view() = SessionListViewMode;
  const factory actions({required List<Session> sessions}) = SessionListActionsMode;
}

final class const SessionListViewMode() extends SessionListMode;
final class const SessionListActionsMode({required final List<Session> sessions}) extends SessionListMode;
