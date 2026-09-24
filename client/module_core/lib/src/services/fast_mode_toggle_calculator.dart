import "package:sesori_shared/sesori_shared.dart";

/// How the composer presents the fast-mode control for the selected model.
enum FastModeControl() {
  /// The model has no fast mode this build knows about, so there is no control.
  hidden,

  /// The model has fast mode, but the account cannot use it right now.
  unavailable,
  off,
  on,
}

/// What tapping the fast-mode control should do.
sealed class const FastModeToggleDecision();

/// The account cannot use fast mode; tell the user why instead of switching.
final class const FastModeToggleUnavailable({required final FastModeUnavailableReason reason})
    extends FastModeToggleDecision;

/// The backend's prompt cache is still warm, so switching drops it. Ask before
/// switching fast mode to [fastMode].
final class const FastModeToggleConfirmCacheReset({required final bool fastMode}) extends FastModeToggleDecision;

/// Switch fast mode to [fastMode] right away.
final class const FastModeToggleApply({required final bool fastMode}) extends FastModeToggleDecision;

/// Decides how the composer's fast-mode control looks and what a tap on it
/// does. Pure: callers pass the clock reading in, so the rule is decided at tap
/// time without timers.
class const FastModeToggleCalculator() {
  FastModeControl control({required FastModeSupport? support, required bool fastMode}) => switch (support) {
    null || FastModeSupportUnknown() => FastModeControl.hidden,
    FastModeUnavailable() => FastModeControl.unavailable,
    FastModeAvailable() => fastMode ? FastModeControl.on : FastModeControl.off,
  };

  /// Switching fast mode drops the backend's prompt cache. That costs a full
  /// re-read only while the cache is still warm: the session has history and
  /// the model was last active less than the cache lifetime ago. Turning fast
  /// mode off confirms too, because it drops the cache all the same.
  FastModeToggleDecision decide({
    required FastModeSupport? support,
    required bool fastMode,
    required bool hasHistory,
    required DateTime? lastModelActivity,
    required DateTime now,
  }) {
    switch (support) {
      case FastModeAvailable(:final promptCacheTtlSeconds):
        final target = !fastMode;
        final cacheIsWarm =
            hasHistory &&
            lastModelActivity != null &&
            now.difference(lastModelActivity) < Duration(seconds: promptCacheTtlSeconds);
        return cacheIsWarm ? FastModeToggleConfirmCacheReset(fastMode: target) : FastModeToggleApply(fastMode: target);
      case FastModeUnavailable(:final reason):
        return FastModeToggleUnavailable(reason: reason);
      // No control is shown for these, so nothing taps it.
      case null || FastModeSupportUnknown():
        return const FastModeToggleUnavailable(reason: FastModeUnavailableReason.unknown);
    }
  }
}
