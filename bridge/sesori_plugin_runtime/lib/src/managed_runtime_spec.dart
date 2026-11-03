import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "draining_spawned_process.dart";

/// Structured outcome of a single runtime health probe.
///
/// Plugins return this from [ManagedRuntimeSpec.probeHealth]. The supervisor
/// only looks at [healthy] to decide whether the runtime is up; [error]
/// carries the failure cause when a probe reports unhealthy (so a start
/// failure can name why).
class const RuntimeHealthProbe({required final bool healthy, final Object? error}) {
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
}) {
  /// The command [runtimeIdentity]'s command line runs [args] with, or null
  /// when that line does not end with [args] (Windows reports only the image
  /// name).
  ///
  /// Usually the executable, but `ps` reports an interpreter shim such as a
  /// `#!/usr/bin/env node` script as `node /path/to/shim`. Stop and stale
  /// cleanup match a record against the live command line, so the record must
  /// keep that whole prefix, not only the executable.
  String? runtimeCommandFor({required List<String> args}) {
    final argsSuffix = " ${args.join(" ")}";
    final commandLine = runtimeIdentity.commandLine;
    if (!commandLine.endsWith(argsSuffix)) {
      return null;
    }
    return commandLine.substring(0, commandLine.length - argsSuffix.length);
  }
}

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
sealed class const RuntimePortPolicy();

/// A single, caller-chosen port.
class const ExplicitPortPolicy({required final int port}) extends RuntimePortPolicy;

/// Dynamic discovery: probe each of [candidates] for bindability and start on
/// the first that works.
class const DynamicPortPolicy({
  /// Ports to try, in order. Must be finite and already exclude reserved and
  /// out-of-range ports; build it with `dynamicPortCandidates`.
  required final Iterable<int> candidates,
}) extends RuntimePortPolicy;

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
  /// authoritative — the supervisor does not re-inspect it — and the process
  /// drains its own stdout and stderr (wrap it in [DrainingSpawnedProcess]);
  /// the supervisor only listens to stderr for logging.
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

/// The outcome of a successful [ManagedProcessService.start],
/// [ManagedProcessService.restartOnPort] or [ManagedProcessService.attach].
sealed class const ManagedRuntimeHandle<R>({required final int port});

/// A runtime this bridge spawned and recorded, so it may stop or restart it.
final class const OwnedRuntimeHandle<R>({
  required super.port,
  required final R record,
  required final SpawnedProcess process,
}) extends ManagedRuntimeHandle<R>;

/// A runtime the bridge only connected to: it never kills, records or restarts it.
final class const AttachedRuntimeHandle<R>({required super.port}) extends ManagedRuntimeHandle<R>;
