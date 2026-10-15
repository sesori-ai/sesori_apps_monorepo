import "models/connection_status.dart";

/// Tells a bridge-scoped cache, from inside its existing connection-status
/// subscription, when the connection moved to a different computer. Statuses
/// without a target (disconnected, or not yet routed) never count as a change.
final class TargetBridgeChangeTracker({required ConnectionStatus initialStatus}) {
  String? _targetBridgeId = initialStatus.targetBridgeId;

  /// Whether [status] targets a different computer than the last status that
  /// named one.
  bool changed({required ConnectionStatus status}) {
    final next = status.targetBridgeId;
    if (next == null) return false;
    final previous = _targetBridgeId;
    _targetBridgeId = next;
    return previous != null && previous != next;
  }
}
