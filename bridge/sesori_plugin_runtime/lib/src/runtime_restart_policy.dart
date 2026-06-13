/// How the supervisor responds when a managed runtime exits unexpectedly
/// while it is meant to be running.
///
/// The legacy behavior is [RuntimeRestartPolicy.disabled] — an unexpected exit
/// is terminal. The hardened bounded-restart pacing
/// ([RuntimeRestartPolicy.bounded]) becomes available only when the real
/// descriptor opts in at the flip; until then the monitor is simply never
/// armed, so production behavior is unchanged.
sealed class RuntimeRestartPolicy {
  const RuntimeRestartPolicy();

  /// Legacy: an unexpected exit is terminal and surfaces as `PluginFailed`.
  const factory RuntimeRestartPolicy.disabled() = DisabledRestartPolicy;

  /// Hardened: up to [maxAttempts] restarts within a single failure episode,
  /// each preceded by an exponential backoff and a bounded wait for the
  /// address-frozen port to free. Exhausting the attempts surfaces as
  /// `PluginFailed`.
  factory RuntimeRestartPolicy.bounded({
    required int maxAttempts,
    required Duration initialBackoff,
    required Duration maxBackoff,
    required Duration portReleaseTimeout,
    required Duration portReleasePollInterval,
    double backoffMultiplier,
  }) = BoundedRestartPolicy;
}

/// Restarts are off: the supervisor never relaunches a runtime that exits.
class DisabledRestartPolicy extends RuntimeRestartPolicy {
  const DisabledRestartPolicy();
}

/// Bounded restart-with-backoff, pinned to the runtime's original port.
class BoundedRestartPolicy extends RuntimeRestartPolicy {
  // Not const: the parameter guards compare Durations, which is not a
  // constant-evaluable operation. Built at runtime anyway (at the flip).
  BoundedRestartPolicy({
    required this.maxAttempts,
    required this.initialBackoff,
    required this.maxBackoff,
    required this.portReleaseTimeout,
    required this.portReleasePollInterval,
    this.backoffMultiplier = 2.0,
  }) : assert(maxAttempts > 0, "maxAttempts must be positive"),
       assert(!initialBackoff.isNegative, "initialBackoff must be non-negative"),
       assert(backoffMultiplier >= 1.0, "backoffMultiplier must be at least 1.0"),
       assert(maxBackoff >= initialBackoff, "maxBackoff must be at least initialBackoff"),
       assert(!portReleaseTimeout.isNegative, "portReleaseTimeout must be non-negative"),
       assert(portReleasePollInterval > Duration.zero, "portReleasePollInterval must be positive");

  /// Maximum restarts attempted within one failure episode. A restart that
  /// reaches `Ready` ends the episode; a later exit starts a fresh one.
  final int maxAttempts;

  /// Backoff before the first restart attempt.
  final Duration initialBackoff;

  /// Upper bound on the (geometrically growing) backoff.
  final Duration maxBackoff;

  /// How long to wait for the pinned port to become bindable again before a
  /// restart attempt gives up (the previous child is releasing the address).
  final Duration portReleaseTimeout;

  /// How often to re-probe the pinned port while waiting for it to free.
  final Duration portReleasePollInterval;

  /// Multiplier applied to the backoff between successive attempts.
  final double backoffMultiplier;

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
