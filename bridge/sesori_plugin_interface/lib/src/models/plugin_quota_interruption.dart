/// Whether a plugin can report terminal quota interruptions from live turns.
enum PluginQuotaReportingSupport() {
  unavailable,

  /// Reporting depends on the provider and error shape. A reported interruption
  /// may still have no usable reset time.
  conditional,
}

/// Named-session admission evidence, including native retries and input waits.
enum PluginQuotaContinuationReadiness { idle, busy, retrying, queued, awaitingInput, unavailable, unknown }

/// The reset information attached to one terminal quota error.
sealed class const PluginQuotaReset();

final class const PluginQuotaResetUnknown() extends PluginQuotaReset;

/// An absolute UTC reset later than the interruption's original observation.
final class const PluginQuotaResetKnown({required final DateTime resetAt}) extends PluginQuotaReset;

/// Plugin-owned interpretation of a terminal quota error from the current turn.
///
/// The error identity must match the plugin's live and historical error message.
/// History replay, warnings and intermediate native retries must not emit this.
final class const PluginQuotaInterruption({
  required final String errorMessageId,
  required final DateTime observedAt,
  required final PluginQuotaReset reset,
});
