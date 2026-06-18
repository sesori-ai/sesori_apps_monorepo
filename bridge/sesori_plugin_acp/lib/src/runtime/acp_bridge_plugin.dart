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
/// child's exit, and owns the ordered, idempotent [shutdown].
class AcpBridgePlugin with SteadyPluginLifecycle implements BridgePlugin {
  AcpBridgePlugin({
    required AcpPlugin plugin,
    required ServerClock clock,
    String? endpoint,
  }) : _plugin = plugin,
       _clock = clock,
       _endpoint = endpoint;

  final AcpPlugin _plugin;
  final ServerClock _clock;
  final String? _endpoint;

  StreamSubscription<int>? _exitSubscription;
  var _stopping = false;

  @override
  BridgePluginApi get api => _plugin;

  @override
  ServerClock get statusClock => _clock;

  @override
  PluginDiagnostics describe() {
    return PluginDiagnostics(
      pluginId: _plugin.id,
      endpoint: _endpoint,
      details: {
        "transport": "acp-stdio",
        "agent": _plugin.agentDisplayName,
      },
    );
  }

  /// Eagerly establishes the ACP connection within [budget] so the agent is
  /// spawned and the `initialize` handshake done before the first mobile
  /// request, and the reported status reflects reality.
  ///
  /// A failure or timeout leaves the plugin [PluginDegraded] (recoverable: a
  /// later request re-drives [AcpPlugin.ensureConnected]) rather than failing
  /// the whole bridge — the descriptor's `checkAvailability` already verified
  /// the binary, so an agent that does not answer the handshake right now is a
  /// transient condition, not a fatal one. Never throws.
  Future<void> connect({
    required Duration budget,
    required StartAbortSignal startAborted,
  }) async {
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
    // An abort observed here is handled by the caller (descriptor), which rolls
    // back via shutdown() and throws PluginStartAbortedException.
    if (startAborted.isAborted) {
      return;
    }
    if (connected) {
      _armExitWatch();
      markReady();
    } else {
      markDegraded(recoverable: true, requiresUserAction: false, userActionHint: null);
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
    _exitSubscription = exit.asStream().listen((code) {
      if (_stopping) {
        return;
      }
      Log.w("[${_plugin.id}] agent process exited (code $code); marking degraded");
      markDegraded(recoverable: true, requiresUserAction: false, userActionHint: null);
    });
  }

  @override
  Future<void> onShutdown({required Duration? budget}) async {
    _stopping = true;
    await _exitSubscription?.cancel();
    _exitSubscription = null;
    // AcpPlugin.dispose() reaps the agent subprocess (SIGTERM, wait, SIGKILL),
    // cancels the notification subscription, and closes the event channel.
    await _plugin.dispose();
  }
}
