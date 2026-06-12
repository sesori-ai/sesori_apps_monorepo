import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Structured outcome of a single runtime health probe.
///
/// Plugins return this from [ManagedRuntimeSpec.probeHealth]. The supervisor
/// only looks at [healthy] to decide whether the runtime is up; [version] and
/// [detail] are surfaced through the resulting [ManagedRuntimeHandle] for
/// diagnostics, and [error] carries the failure cause when a probe reports
/// unhealthy (so a start failure can name why).
class RuntimeHealthProbe {
  const RuntimeHealthProbe({required this.healthy, this.version, this.detail, this.error});

  /// A probe that failed, carrying its [error] cause.
  const RuntimeHealthProbe.unhealthy({Object? error}) : this(healthy: false, error: error);

  final bool healthy;
  final String? version;
  final String? detail;
  final Object? error;
}

/// Facts the supervisor hands a plugin's record factory after a successful
/// spawn, so it can build its concrete (byte-frozen) ownership record.
///
/// The supervisor stays generic over the record type `R`; the plugin's
/// [ManagedRuntimeSpec.buildRecord] maps these facts — plus its own knowledge
/// of the command line it spawned — into `R` at the "starting" status.
class RuntimeRecordDraft {
  const RuntimeRecordDraft({
    required this.ownerSessionId,
    required this.runtimeIdentity,
    required this.port,
    required this.bridgeIdentity,
    required this.startedAt,
  });

  /// Stable identifier of the bridge run that owns the runtime.
  final String ownerSessionId;

  /// Identity of the freshly spawned runtime process, as captured by the
  /// spawn seam. May be partial (no start marker) on Windows or when the
  /// child raced the post-spawn inspection.
  final ProcessIdentity runtimeIdentity;

  /// The port the runtime was started on.
  final int port;

  /// Identity of the hosting bridge process.
  final ProcessIdentity bridgeIdentity;

  /// When the runtime was started (host clock).
  final DateTime startedAt;
}

/// How the supervisor paces health confirmation after a spawn.
///
/// The legacy spec is [RuntimeHealthPolicy.attemptCount]; the hardened
/// deadline-based pacing ([RuntimeHealthPolicy.deadline]) becomes the default
/// only when the real descriptor opts in at the flip. The legacy test suite
/// hard-asserts exact delay sequences, so pacing must be configurable rather
/// than replaced.
sealed class RuntimeHealthPolicy {
  const RuntimeHealthPolicy();

  /// Legacy pacing: up to [attempts] probes, each preceded by [delay].
  const factory RuntimeHealthPolicy.attemptCount({
    required int attempts,
    required Duration delay,
  }) = HealthAttemptCountPolicy;

  /// Deadline pacing: probe every [pollInterval] until healthy or until
  /// [deadline] elapses (host clock).
  factory RuntimeHealthPolicy.deadline({
    required Duration deadline,
    required Duration pollInterval,
  }) = HealthDeadlinePolicy;
}

class HealthAttemptCountPolicy extends RuntimeHealthPolicy {
  const HealthAttemptCountPolicy({required this.attempts, required this.delay})
    : assert(attempts > 0, "attempts must be positive"),
      super();

  final int attempts;
  final Duration delay;
}

class HealthDeadlinePolicy extends RuntimeHealthPolicy {
  // Not const: the parameter guards below compare Durations, which is not a
  // constant-evaluable operation. The policy is built at runtime anyway.
  HealthDeadlinePolicy({required this.deadline, required this.pollInterval})
    : assert(!deadline.isNegative, "deadline must be non-negative"),
      assert(pollInterval > Duration.zero, "pollInterval must be positive"),
      super();

  final Duration deadline;
  final Duration pollInterval;
}

/// When the supervisor writes the ownership record relative to spawn.
enum RuntimeRecordTiming {
  /// Legacy: the record is written only after spawn, once a real pid exists.
  /// The frozen schema's runtime pid is required non-null, so there is no
  /// representable pre-spawn state in the ownership file itself.
  afterSpawn,

  /// Hardened: an intent record is written to a bridge-private side file
  /// before spawn and resolved after. Activated in a later migration step;
  /// the supervisor rejects it until then.
  intentSideFile,
}

/// Where the supervisor obtains the listening port for a start.
sealed class RuntimePortPolicy {
  const RuntimePortPolicy();

  /// A single, caller-chosen port.
  const factory RuntimePortPolicy.explicit({
    required int port,
    bool preProbeBindable,
  }) = ExplicitPortPolicy;

  /// Dynamic discovery across [candidates]: probe each for bindability and
  /// start on the first that works, up to [maxAttempts] examined candidates.
  const factory RuntimePortPolicy.dynamic({
    required Iterable<int> candidates,
    required int maxAttempts,
    required int reservedPort,
    required int minPort,
    required int maxPort,
    bool failFastOnSpawnError,
  }) = DynamicPortPolicy;
}

class ExplicitPortPolicy extends RuntimePortPolicy {
  const ExplicitPortPolicy({required this.port, this.preProbeBindable = false}) : super();

  final int port;

  /// Hardened (default off): probe bindability before spawning and fail with
  /// a diagnosed error when the port is already held. Off reproduces the
  /// legacy behavior of spawning straight onto the explicit port.
  final bool preProbeBindable;
}

class DynamicPortPolicy extends RuntimePortPolicy {
  const DynamicPortPolicy({
    required this.candidates,
    required this.maxAttempts,
    required this.reservedPort,
    required this.minPort,
    required this.maxPort,
    this.failFastOnSpawnError = false,
  }) : assert(maxAttempts > 0, "maxAttempts must be positive"),
       super();

  /// Candidate ports to consider, in order. May be a lazy or unbounded
  /// generator (e.g. a random source): the supervisor pulls at most
  /// [maxAttempts] values from it and counts every value examined against that
  /// cap — including ones skipped for being [reservedPort] or outside
  /// [[minPort], [maxPort]] — so even an all-invalid infinite source still
  /// terminates rather than spinning under the startup mutex.
  final Iterable<int> candidates;

  /// Maximum number of candidates examined (whether skipped, unbindable, or
  /// attempted) before giving up — bounds discovery the way the legacy
  /// five-candidate cap does, and guarantees termination for lazy [candidates].
  final int maxAttempts;

  /// The reserved default port, excluded from dynamic discovery.
  final int reservedPort;

  /// Inclusive bounds of the dynamic range.
  final int minPort;
  final int maxPort;

  /// Hardened (default off): treat a spawn error as fatal and stop instead of
  /// retrying the next candidate. Off reproduces the legacy behavior of
  /// retrying on any start error (e.g. a bind race).
  final bool failFastOnSpawnError;
}

/// Everything a [ManagedProcessService] needs to start (or attach to) one
/// managed runtime, expressed as seams so the same supervisor serves the
/// legacy in-place wrapper, the eventual host-backed plugin, and tests.
///
/// The seams ([spawn], [probeHealth], [probePortBindable]) are supplied as
/// functions rather than service objects so a plugin (or a legacy adapter)
/// owns exactly how a runtime is launched and inspected. The supervisor
/// trusts the identity its [spawn] seam returns and never re-inspects it.
class ManagedRuntimeSpec<R> {
  const ManagedRuntimeSpec({
    required this.spawn,
    required this.probeHealth,
    required this.probePortBindable,
    required this.buildRecord,
    required this.portPolicy,
    required this.healthPolicy,
    this.recordTiming = RuntimeRecordTiming.afterSpawn,
    this.validateRuntime,
    this.failOnEarlyChildExit = false,
  });

  /// Launches the runtime on [port] and returns the spawned process with its
  /// captured identity. Contract: the returned [SpawnedProcess.identity] is
  /// authoritative — the supervisor does not re-inspect it.
  final Future<SpawnedProcess> Function({required int port}) spawn;

  /// Probes the runtime's health on [port]. Should report unhealthy rather
  /// than throw, but the supervisor tolerates a thrown probe (treated as
  /// unhealthy) so a transient connection error simply retries.
  final Future<RuntimeHealthProbe> Function({required int port}) probeHealth;

  /// Whether [port] can currently be bound (used for dynamic discovery and
  /// the optional explicit pre-probe).
  final Future<bool> Function({required int port}) probePortBindable;

  /// Maps the post-spawn facts into the plugin's concrete ownership record at
  /// the "starting" status.
  final R Function(RuntimeRecordDraft draft) buildRecord;

  final RuntimePortPolicy portPolicy;
  final RuntimeHealthPolicy healthPolicy;
  final RuntimeRecordTiming recordTiming;

  /// Optional post-health validation, run after the first healthy probe and
  /// before the record flips to "ready". A throw fails the start (with
  /// rollback). Null reproduces the legacy behavior of no extra validation.
  final Future<void> Function({required int port})? validateRuntime;

  /// Hardened (default off): if the spawned child exits before the first
  /// healthy probe, fail the start regardless of probe success — a healthy
  /// response after our child died means an unrelated process holds the port.
  final bool failOnEarlyChildExit;
}

/// The outcome of a successful [ManagedProcessService.start] or
/// [ManagedProcessService.attach].
///
/// A started runtime is owned ([process], [identity] and [record] are
/// populated); an attached runtime is not ([isOwned] is false and those
/// fields are null — the bridge never kills or records a server it merely
/// connected to).
class ManagedRuntimeHandle<R> {
  const ManagedRuntimeHandle({
    required this.port,
    required this.record,
    required this.process,
    required this.identity,
    required this.health,
  });

  final int port;
  final R? record;
  final SpawnedProcess? process;
  final ProcessIdentity? identity;
  final RuntimeHealthProbe health;

  bool get isOwned => process != null;
}
