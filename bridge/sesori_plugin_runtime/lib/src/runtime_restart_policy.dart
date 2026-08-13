/// How the supervisor responds when a managed runtime exits unexpectedly
/// while it is meant to be running.
///
/// The legacy behavior is [RuntimeRestartPolicy.disabled] — an unexpected exit
/// is terminal. The hardened bounded-restart pacing
/// ([RuntimeRestartPolicy.bounded]) becomes available only when the real
/// descriptor opts in at the flip; until then the monitor is simply never
/// armed, so production behavior is unchanged.
sealed class const RuntimeRestartPolicy() {
  /// Legacy: an unexpected exit is terminal and surfaces as `PluginFailed`.
  const factory disabled() = DisabledRestartPolicy;

  /// Hardened: up to [maxAttempts] restarts within a single failure episode,
  /// each preceded by an exponential backoff and a bounded wait for the
  /// address-frozen port to free. Exhausting the attempts surfaces as
  /// `PluginFailed`.
  factory bounded({
    required int maxAttempts,
    required Duration initialBackoff,
    required Duration maxBackoff,
    required Duration portReleaseTimeout,
    required Duration portReleasePollInterval,
    double backoffMultiplier,
  }) = BoundedRestartPolicy;
}

/// Restarts are off: the supervisor never relaunches a runtime that exits.
class const DisabledRestartPolicy() extends RuntimeRestartPolicy;

/// Bounded restart-with-backoff, pinned to the runtime's original port.
class BoundedRestartPolicy({
  /// Maximum restarts attempted within one failure episode. A restart that
  /// reaches `Ready` ends the episode; a later exit starts a fresh one.
  required final int maxAttempts,

  /// Backoff before the first restart attempt.
  required final Duration initialBackoff,

  /// Upper bound on the (geometrically growing) backoff.
  required final Duration maxBackoff,

  /// How long to wait for the pinned port to become bindable again before a
  /// restart attempt gives up (the previous child is releasing the address).
  required final Duration portReleaseTimeout,

  /// How often to re-probe the pinned port while waiting for it to free.
  required final Duration portReleasePollInterval,

  /// Multiplier applied to the backoff between successive attempts.
  final double backoffMultiplier = 2.0,
}) extends RuntimeRestartPolicy {
  // Not const: the parameter guards compare Durations, which is not a
  // constant-evaluable operation. Built at runtime anyway (at the flip).
  this
    : assert(maxAttempts > 0, "maxAttempts must be positive"),
      assert(!initialBackoff.isNegative, "initialBackoff must be non-negative"),
      assert(backoffMultiplier >= 1.0, "backoffMultiplier must be at least 1.0"),
      assert(maxBackoff >= initialBackoff, "maxBackoff must be at least initialBackoff"),
      assert(!portReleaseTimeout.isNegative, "portReleaseTimeout must be non-negative"),
      assert(portReleasePollInterval > Duration.zero, "portReleasePollInterval must be positive");

  /// Backoff before the 1-based [attempt] restart, capped at [maxBackoff].
  Duration backoffFor(int attempt) {
    assert(attempt >= 1, "attempt is 1-based: the first restart is attempt 1");
    var value = initialBackoff;
    for (var i = 1; i < attempt && value < maxBackoff; i += 1) {
      final next = value * backoffMultiplier;
      value = next < maxBackoff ? next : maxBackoff;
    }
    return value < maxBackoff ? value : maxBackoff;
  }
}
