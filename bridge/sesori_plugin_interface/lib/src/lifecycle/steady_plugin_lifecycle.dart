import "dart:async";

import "package:meta/meta.dart";

import "../log.dart";
import "../process/server_clock.dart";
import "bridge_plugin.dart";
import "plugin_status.dart";
import "plugin_status_controller.dart";

/// Lifecycle implementation for plugins with no managed runtime — direct-CLI
/// and remote-server archetypes whose "lifecycle" is just connectivity.
///
/// Mixing this in implements `status`, `currentStatus`, and `shutdown()`;
/// the plugin only supplies `api`, `describe()`, and (optionally)
/// [onShutdown]:
///
/// ```dart
/// class RemotePlugin with SteadyPluginLifecycle implements BridgePlugin {
///   @override
///   BridgePluginApi get api => _api;
///
///   @override
///   PluginDiagnostics describe() =>
///       PluginDiagnostics(pluginId: api.id, endpoint: _url, details: const {});
///
///   @override
///   Future<void> onShutdown({required Duration? budget}) => _api.dispose();
/// }
/// ```
///
/// Status reporting is **debounced on the degraded side**: a single failed
/// probe does not flip the status — [markDegraded] only surfaces after the
/// degradation persists for [degradedDebounce] without an intervening
/// [markReady]. Recovery is immediate: [markReady] cancels any pending
/// degradation and restores `Ready` at once. This is what makes `status` the
/// debounced lifecycle signal, distinct from the instantaneous
/// `BridgePluginApi.healthCheck` probe.
///
/// All transitions go through the legal-transition machine: after
/// [shutdown] starts, late [markFailed] / [markDegraded] calls are silently
/// dropped (no `Failed` after `Stopping`), and [shutdown] is idempotent.
mixin SteadyPluginLifecycle implements BridgePlugin {
  PluginStatusController? _statusController;
  Future<void>? _shutdownFuture;
  int _degradedGeneration = 0;
  DateTime? _pendingDegradedSince;
  ({bool recoverable, bool requiresUserAction, String? userActionHint})? _pendingDegradedDetails;

  PluginStatusController get _statusMachine =>
      _statusController ??= PluginStatusController(initial: const PluginStarting());

  /// Clock seam for the debounce timing; override in tests (or wire to
  /// `PluginHost.clock`).
  @protected
  ServerClock get statusClock => const ServerClock();

  /// How long a degradation must persist before it is reported.
  @protected
  Duration get degradedDebounce => const Duration(seconds: 5);

  @override
  Stream<PluginStatus> get status => _statusMachine.stream;

  @override
  PluginStatus get currentStatus => _statusMachine.current;

  /// Reports the plugin operational. Cancels any pending degradation and
  /// applies immediately.
  @protected
  void markReady() {
    _cancelPendingDegraded();
    _statusMachine.trySet(const PluginReady());
  }

  /// Reports the plugin impaired. Takes effect only if the degradation
  /// persists for [degradedDebounce] without a [markReady] in between; the
  /// reported `since` is the time of the *first* observation, while the
  /// details (`recoverable`, `requiresUserAction`, `userActionHint`) are the
  /// *latest* reported — an escalation arriving during the debounce window
  /// (e.g. auth expiry detected after a generic probe failure) is not lost.
  /// While already degraded, updates the details immediately (keeping
  /// `since`). A no-op once the plugin is failed or stopping: those states
  /// can never legally reach `Degraded`.
  @protected
  void markDegraded({required bool recoverable, required bool requiresUserAction, required String? userActionHint}) {
    final current = _statusMachine.current;
    if (current is PluginFailed || current is PluginStopping || current is PluginStopped) {
      return;
    }
    if (current is PluginDegraded) {
      _statusMachine.trySet(
        PluginDegraded(
          since: current.since,
          recoverable: recoverable,
          requiresUserAction: requiresUserAction,
          userActionHint: userActionHint,
        ),
      );
      return;
    }
    _pendingDegradedDetails = (
      recoverable: recoverable,
      requiresUserAction: requiresUserAction,
      userActionHint: userActionHint,
    );
    if (_pendingDegradedSince != null) {
      return;
    }
    final since = statusClock.now();
    _pendingDegradedSince = since;
    final generation = _degradedGeneration;
    unawaited(
      statusClock
          .delay(duration: degradedDebounce)
          .then((_) {
            if (generation != _degradedGeneration) {
              return;
            }
            final details = _pendingDegradedDetails;
            _pendingDegradedSince = null;
            _pendingDegradedDetails = null;
            if (details == null) {
              return;
            }
            _statusMachine.trySet(
              PluginDegraded(
                since: since,
                recoverable: details.recoverable,
                requiresUserAction: details.requiresUserAction,
                userActionHint: details.userActionHint,
              ),
            );
          })
          // An unhandled async error here would take down the whole isolate
          // over a status report; log it instead.
          .catchError((Object error, StackTrace stackTrace) {
            Log.w("SteadyPluginLifecycle: degraded debounce failed: $error\n$stackTrace");
          }),
    );
  }

  /// Reports a terminal failure. Dropped silently once [shutdown] has
  /// started (no `Failed` after `Stopping`).
  @protected
  void markFailed(String reason, {required Object? cause}) {
    _cancelPendingDegraded();
    _statusMachine.trySet(PluginFailed(reason: reason, cause: cause));
  }

  /// Releases the plugin's resources. Override point for the mixed-in class;
  /// the default does nothing. Must be safe to run before or after
  /// `BridgePluginApi.dispose()`.
  ///
  /// If this throws, the plugin still reaches `Stopped`, and the same error
  /// is rethrown to *every* `shutdown()` caller — the failure is part of the
  /// memoized teardown, so no caller can mistake a failed teardown for a
  /// clean one.
  @protected
  Future<void> onShutdown({required Duration? budget}) async {}

  @override
  Future<void> shutdown({required Duration? budget}) {
    return _shutdownFuture ??= _runShutdown(budget: budget);
  }

  Future<void> _runShutdown({required Duration? budget}) async {
    _cancelPendingDegraded();
    _statusMachine.trySet(const PluginStopping());
    try {
      await onShutdown(budget: budget);
    } finally {
      _statusMachine.trySet(const PluginStopped());
    }
  }

  void _cancelPendingDegraded() {
    _degradedGeneration++;
    _pendingDegradedSince = null;
    _pendingDegradedDetails = null;
  }
}
