import "package:sesori_shared/sesori_shared.dart";

/// What the composer offers for the session's permission approval.
sealed class const SessionApprovalControl() {
  /// Resolves the control from the bridge's YOLO setting and the session's
  /// own override.
  factory resolve({required YoloSettingsResponse bridge, required SessionApprovalMode? sessionOverride}) {
    if (!bridge.supportsSessionOverride) {
      return bridge.enabled ? const SessionApprovalBridgeWideYolo() : const SessionApprovalHidden();
    }
    final bridgeDefault = bridge.enabled ? SessionApprovalMode.yolo : SessionApprovalMode.ask;
    return SessionApprovalPerSession(effective: sessionOverride ?? bridgeDefault, bridgeDefault: bridgeDefault);
  }
}

/// An older bridge with YOLO off: nothing to show.
final class const SessionApprovalHidden() extends SessionApprovalControl;

/// An older bridge with YOLO on for every session: a read-only notice.
final class const SessionApprovalBridgeWideYolo() extends SessionApprovalControl;

/// The session picks its own mode; [bridgeDefault] is what it follows without
/// an override.
final class const SessionApprovalPerSession({
  required final SessionApprovalMode effective,
  required final SessionApprovalMode bridgeDefault,
}) extends SessionApprovalControl {
  /// The override that picks [mode]: null for the bridge default, so the
  /// session follows the bridge setting again when it changes.
  SessionApprovalMode? overrideFor({required SessionApprovalMode mode}) => mode == bridgeDefault ? null : mode;
}
