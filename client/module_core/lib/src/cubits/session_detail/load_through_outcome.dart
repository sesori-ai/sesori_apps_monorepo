/// What a load-through to a prompt came back with.
sealed class const LoadThroughOutcome();

/// The target message is in the transcript, loaded now or before.
final class const LoadThroughLoaded() extends LoadThroughOutcome;

/// The load landed without the target message: history changed since the
/// caller learned its `seq`.
final class const LoadThroughTargetMissing() extends LoadThroughOutcome;

/// The request failed; already logged. Asking again may succeed.
final class const LoadThroughFailed() extends LoadThroughOutcome;

/// The transcript was replaced while the load ran, so it was dropped.
final class const LoadThroughSuperseded() extends LoadThroughOutcome;

/// The bridge predates the load-through route and must be updated.
final class const LoadThroughUnsupported() extends LoadThroughOutcome;
