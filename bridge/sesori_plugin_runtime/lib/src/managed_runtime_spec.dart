import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Structured outcome of a single runtime health probe.
///
/// Plugins return this from [ManagedRuntimeSpec.probeHealth]. The supervisor
/// only looks at [healthy] to decide whether the runtime is up; [version] and
/// [detail] are surfaced through the resulting [ManagedRuntimeHandle] for
/// diagnostics, and [error] carries the failure cause when a probe reports
/// unhealthy (so a start failure can name why).
class const RuntimeHealthProbe({required final bool healthy, final String? version, final String? detail, final Object? error}) {
  /// A probe that failed, carrying its [error] cause.
  const new unhealthy({Object? error}) : this(healthy: false, error: error);

}

/// Facts the supervisor hands a plugin's record factory after a successful
/// spawn, so it can build its concrete (byte-frozen) ownership record.
///
/// The supervisor stays generic over the record type `R`; the plugin's
/// [ManagedRuntimeSpec.buildRecord] maps these facts — plus its own knowledge
/// of the command line it spawned — into `R` at the "starting" status.
class const RuntimeRecordDraft({
    /// Stable identifier of the bridge run that owns the runtime.
  required final String ownerSessionId,
    /// Identity of the freshly spawned runtime process, as captured by the
  /// spawn seam. May be partial (no start marker) on Windows or when the
  /// child raced the post-spawn inspection.
  required final ProcessIdentity runtimeIdentity,
    /// The port the runtime was started on.
  required final int port,
    /// Identity of the hosting bridge process.
  required final ProcessIdentity bridgeIdentity,
    /// When the runtime was started (host clock).
  required final DateTime startedAt,
  });

/// How the supervisor paces health confirmation after a spawn: probe every
/// [pollInterval] until healthy or until [deadline] elapses (host clock).
class RuntimeHealthPolicy({required final Duration deadline, required final Duration pollInterval}) {
  // Not const: the parameter guards below compare Durations, which is not a
  // constant-evaluable operation. The policy is built at runtime anyway.
  this
    : assert(!deadline.isNegative, "deadline must be non-negative"),
      assert(pollInterval > Duration.zero, "pollInterval must be positive");

}

/// Where the supervisor obtains the listening port for a start.
sealed class const RuntimePortPolicy() {
  /// A single, caller-chosen port.
  const factory explicit({required int port}) = ExplicitPortPolicy;

  /// Dynamic discovery across [candidates]: probe each for bindability and
  /// start on the first that works, up to [maxAttempts] examined candidates.
  const factory dynamic({
    required Iterable<int> candidates,
    required int maxAttempts,
    required int reservedPort,
    required int minPort,
    required int maxPort,
  }) = DynamicPortPolicy;
}

class const ExplicitPortPolicy({required final int port}) extends RuntimePortPolicy {
  this : super();

}

class const DynamicPortPolicy({
    /// Candidate ports to consider, in order. May be a lazy or unbounded
  /// generator (e.g. a random source): the supervisor pulls at most
  /// [maxAttempts] values from it and counts every value examined against that
  /// cap — including ones skipped for being [reservedPort] or outside
  /// [[minPort], [maxPort]] — so even an all-invalid infinite source still
  /// terminates rather than spinning under the startup mutex.
  required final Iterable<int> candidates,
    /// Maximum number of candidates examined (whether skipped, unbindable, or
  /// attempted) before giving up — bounds discovery the way the legacy
  /// five-candidate cap does, and guarantees termination for lazy [candidates].
  required final int maxAttempts,
    /// The reserved default port, excluded from dynamic discovery.
  required final int reservedPort,
    /// Inclusive bounds of the dynamic range.
  required final int minPort,
    required final int maxPort,
  }) extends RuntimePortPolicy {
  this : assert(maxAttempts > 0, "maxAttempts must be positive"),
       super();

}

/// Everything a [ManagedProcessService] needs to start (or attach to) one
/// managed runtime, expressed as seams so one supervisor serves every plugin
/// that owns a runtime process, plus tests.
///
/// The seams ([spawn], [probeHealth], [probePortBindable]) are supplied as
/// functions rather than service objects so a plugin (or a legacy adapter)
/// owns exactly how a runtime is launched and inspected. The supervisor
/// trusts the identity its [spawn] seam returns and never re-inspects it.
class const ManagedRuntimeSpec<R>({
    /// Launches the runtime on [port] and returns the spawned process with its
  /// captured identity. Contract: the returned [SpawnedProcess.identity] is
  /// authoritative — the supervisor does not re-inspect it.
  required final Future<SpawnedProcess> Function({required int port}) spawn,
    /// Probes the runtime's health on [port]. Should report unhealthy rather
  /// than throw, but the supervisor tolerates a thrown probe (treated as
  /// unhealthy) so a transient connection error simply retries.
  required final Future<RuntimeHealthProbe> Function({required int port}) probeHealth,
    /// Whether [port] can currently be bound — used for dynamic discovery and
  /// for the pre-spawn probe on an explicit port.
  required final Future<bool> Function({required int port}) probePortBindable,
    /// Maps the post-spawn facts into the plugin's concrete ownership record at
  /// the "starting" status.
  required final R Function(RuntimeRecordDraft draft) buildRecord,
    required final RuntimePortPolicy portPolicy,
    required final RuntimeHealthPolicy healthPolicy,
  });

/// The outcome of a successful [ManagedProcessService.start] or
/// [ManagedProcessService.attach].
///
/// A started runtime is owned ([process], [identity] and [record] are
/// populated); an attached runtime is not ([isOwned] is false and those
/// fields are null — the bridge never kills or records a server it merely
/// connected to).
class const ManagedRuntimeHandle<R>({
    required final int port,
    required final R? record,
    required final SpawnedProcess? process,
    required final ProcessIdentity? identity,
    required final RuntimeHealthProbe health,
  }) {
  bool get isOwned => process != null;
}
