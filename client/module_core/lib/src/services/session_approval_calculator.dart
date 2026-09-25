import "package:sesori_shared/sesori_shared.dart";

/// What the composer offers for the session's permission approval.
sealed class const SessionApprovalControl();

/// An older bridge with YOLO off: nothing to show.
final class const SessionApprovalHidden() extends SessionApprovalControl;

/// An older bridge with YOLO on for every session: a read-only notice.
final class const SessionApprovalBridgeWideYolo() extends SessionApprovalControl;

/// The session picks its own mode; [bridgeDefault] is what it follows without
/// an override.
final class const SessionApprovalPerSession({
  required final SessionApprovalMode effective,
  required final SessionApprovalMode bridgeDefault,
}) extends SessionApprovalControl;

/// Decides what the composer offers for a session's permission approval and
/// what a pick stores on the bridge. Owns no state.
class const SessionApprovalCalculator() {
  /// The control for [session] under the bridge's YOLO setting.
  SessionApprovalControl control({required YoloSettingsResponse bridge, required Session session}) {
    if (!bridge.supportsSessionOverride) {
      return bridge.enabled ? const SessionApprovalBridgeWideYolo() : const SessionApprovalHidden();
    }
    final bridgeDefault = bridge.enabled ? SessionApprovalMode.yolo : SessionApprovalMode.ask;
    return SessionApprovalPerSession(
      effective: session.approvalOverride ?? bridgeDefault,
      bridgeDefault: bridgeDefault,
    );
  }

  /// The override to store when the user picks [mode], or null when the
  /// session already stores it and nothing needs sending.
  ///
  /// A top-level session picking the bridge default clears its override, so it
  /// follows the bridge setting when that changes. A child may inherit an
  /// ancestor's override the client cannot see, so its pick is always explicit.
  ({SessionApprovalMode? approvalOverride})? change({
    required Session session,
    required SessionApprovalPerSession control,
    required SessionApprovalMode mode,
  }) {
    final approvalOverride = session.parentID == null && mode == control.bridgeDefault ? null : mode;
    if (approvalOverride == session.approvalOverride) return null;
    return (approvalOverride: approvalOverride);
  }
}
