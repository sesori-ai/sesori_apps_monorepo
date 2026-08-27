import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_plugin.dart";

/// Live-plugin wrapper for an stdio ACP backend.
///
/// ACP agents have no managed runtime in the `sesori_plugin_runtime` sense:
/// there is no listening port to reclaim, no ownership file, no cross-restart
/// resident server — just one long-lived child whose stdin/stdout *is* the
/// transport. So this uses the [SteadyPluginLifecycle] archetype (the one the
/// interface docs call out for "direct-CLI / remote-server / ACP" plugins)
/// rather than the managed-process supervisor OpenCode needs.
///
/// The wrapped [AcpPlugin] is the stable [api] object for the plugin's whole
/// lifetime; it owns the agent subprocess (spawned lazily, or eagerly via
/// [connect]) and reaps it on [dispose]. This wrapper adds the lifecycle
/// surface: it drives the status state machine off the ACP connection and the
/// child's exit, and owns the ordered, idempotent [shutdown]. Descriptors
/// obtain a connected instance through [start].
class AcpBridgePlugin({
  required final AcpPlugin _plugin,
  required final ServerClock _clock,
}) with SteadyPluginLifecycle implements BridgePlugin {
  /// Wraps [plugin], eagerly connects it within [connectBudget] (a timeout or
  /// failure leaves it degraded, not failed — see [connect]), and honours an
  /// abort that arrived while connecting by rolling the agent back and throwing
  /// [PluginStartAbortedException] instead of returning a live plugin. This is
  /// the one place the "start an ACP agent under the bridge lifecycle" sequence
  /// lives, so every ACP descriptor's `start` reduces to building its plugin.
  static Future<AcpBridgePlugin> start({
    required AcpPlugin plugin,
    required PluginHost host,
    required Duration connectBudget,
  }) async {
    final wrapper = AcpBridgePlugin(plugin: plugin, clock: host.clock);
    // Race the eager connect against the abort signal: an abort that lands
    // while the handshake hangs must start the rollback now, not after the
    // whole connect budget — the bridge's startup mutex is held meanwhile.
    // connect() never throws, and once aborted it returns without marking
    // status, so the rollback below disposes a plugin whose connect is either
    // settled or failing fast against the disposed client.
    await Future.any<void>([
      wrapper.connect(budget: connectBudget, startAborted: host.startAborted),
      host.startAborted.whenAborted,
    ]);
    if (!host.startAborted.isAborted) return wrapper;
    try {
      await wrapper.shutdown(budget: null);
    } on Object catch (error, stackTrace) {
      Log.e("[${plugin.id}] rollback after aborted start failed", error, stackTrace);
    }
    throw const PluginStartAbortedException();
  }

  StreamSubscription<int>? _exitSubscription;
  StreamSubscription<void>? _connectedSubscription;
  var _stopping = false;

  @override
  BridgePluginApi get api => _plugin;

  @override
  Stream<PluginWorkState> get workState => _plugin.workState;

  @override
  PluginWorkState get currentWorkState => _plugin.currentWorkState;

  @override
  ServerClock get statusClock => _clock;

  @override
  PluginDiagnostics describe() {
    return PluginDiagnostics(
      pluginId: _plugin.id,
      // The agent executable is the "endpoint" of a stdio transport. Only the
      // command: launch arguments can carry operator-supplied values (Cursor's
      // `-e <endpoint>` URL) that must not land in the startup console line.
      endpoint: _plugin.launchSpec.command,
      details: {
        "transport": "acp-stdio",
        "agent": _plugin.agentDisplayName,
      },
    );
  }

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return _plugin.interruptActiveWork(budget: budget);
  }

  /// Eagerly establishes the ACP connection within [budget] so the agent is
  /// spawned and the `initialize` handshake done before the first mobile
  /// request, and the reported status reflects reality.
  ///
  /// A failure or timeout leaves the plugin [PluginDegraded] (recoverable: a
  /// later request re-drives [AcpPlugin.ensureConnected]) rather than failing
  /// the whole bridge — setup inspection already verified the binary, so an
  /// agent that does not answer the handshake right now is a
  /// transient condition, not a fatal one. Never throws.
  Future<void> connect({
    required Duration budget,
    required StartAbortSignal startAborted,
  }) async {
    // Subscribe BEFORE connecting. If the eager connect times out here, the
    // underlying ensureConnected() keeps running and emits onConnected when it
    // finally completes; a later request then reuses that cached success
    // without re-emitting. Subscribing first guarantees that emit isn't lost in
    // the window between a timeout and the listener install — otherwise the
    // plugin would stay degraded forever. Recovers to ready on every later
    // (re)connect too (a lazy reconnect after a crash+reset). markReady and
    // _armExitWatch are idempotent, so the connected branch below double-firing
    // with this listener is harmless.
    _connectedSubscription ??= _plugin.onConnected.listen((_) {
      if (_stopping) {
        return;
      }
      _armExitWatch();
      markReady();
    });

    bool connected;
    try {
      connected = await _plugin.ensureConnected().timeout(
        budget,
        onTimeout: () => false,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[${_plugin.id}] eager connect failed; starting degraded", error, stackTrace);
      connected = false;
    }
    // An abort observed here is handled by the caller ([start]), which rolls
    // back via shutdown() and throws PluginStartAbortedException.
    if (startAborted.isAborted) {
      return;
    }
    if (connected) {
      _armExitWatch();
      markReady();
    } else {
      final authenticationHint = _plugin.authenticationFailureActionHint;
      markDegraded(
        recoverable: true,
        requiresUserAction: authenticationHint != null,
        userActionHint: authenticationHint,
      );
    }
  }

  /// Surfaces an unexpected agent exit as [PluginDegraded] (recoverable: the
  /// next request re-spawns via [AcpPlugin.ensureConnected]). A deliberate exit
  /// during [shutdown] is suppressed via [_stopping] so it never reports a
  /// crash over a clean stop.
  void _armExitWatch() {
    final exit = _plugin.client?.processExit;
    if (exit == null) {
      return;
    }
    // Drop any prior watch (e.g. from the previous, now-exited client) before
    // arming on the current client, so reconnects do not leak subscriptions.
    unawaited(
      _exitSubscription?.cancel().catchError((Object e, StackTrace st) {
        Log.w("[${_plugin.id}] failed to cancel prior exit subscription", e, st);
      }),
    );
    _exitSubscription = exit.asStream().listen((code) {
      if (_stopping) {
        return;
      }
      Log.w("[${_plugin.id}] agent process exited (code $code); resetting connection and marking degraded");
      // Drop the cached client/connection so the next request re-spawns a fresh
      // agent instead of writing to the dead process. resetConnectionAfterExit()
      // clears the cached state synchronously before its first await and never
      // throws, so the degraded path is genuinely recoverable.
      unawaited(_plugin.resetConnectionAfterExit());
      markDegraded(recoverable: true, requiresUserAction: false, userActionHint: null);
    });
  }

  @override
  Future<void> onShutdown({required Duration? budget}) async {
    _stopping = true;
    // Isolated so a failed cancel cannot skip the dispose() below.
    try {
      await _connectedSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[${_plugin.id}] failed to cancel connected subscription", e, st);
    } finally {
      _connectedSubscription = null;
    }
    try {
      await _exitSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[${_plugin.id}] failed to cancel exit subscription", e, st);
    } finally {
      _exitSubscription = null;
    }
    // AcpPlugin.dispose() reaps the agent subprocess (SIGTERM, wait, SIGKILL),
    // cancels the notification subscription, and closes the event channel.
    // It isolates and swallows its own teardown failures, so it never throws.
    await _plugin.dispose();
  }
}
