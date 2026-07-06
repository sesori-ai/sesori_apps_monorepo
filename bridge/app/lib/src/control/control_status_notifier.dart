import "dart:convert";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/relay_client.dart";
import "../foundation/control_channel_client.dart";

/// Owns ALL outbound status-class control sends in supervised mode: it
/// observes the bridge's live state streams and pushes `status` /
/// `registered` control messages to the GUI over the injected
/// [ControlChannelClient]. Higher layers (the Orchestrator) never call
/// `ControlChannelClient.send` directly.
///
/// Observed triggers — all push-based, no timers:
/// - plugin health: the replay-latest `BridgePlugin.status` lifecycle stream;
/// - relay connection state: [RelayClient.connectionState];
/// - registration success: the auth-subsystem `registrations` stream, mapped
///   to a `registered{bridgeId}` push so the GUI can persist a readable copy
///   of the id before any crash/stop (offline-unregister fallback);
/// - active-session summary: fed by the Orchestrator's SSE pipeline through
///   [handleProjectsSummary] (the same already-built summary event phones
///   receive), so no second derivation path into the plugin exists;
/// - the control channel's own connection state: after a reconnect the GUI
///   may have missed edge-triggered pushes, so the current snapshot (and the
///   `registered` event) is re-sent to converge.
///
/// Sends are best-effort and never throw to callers: status is informational,
/// and a frame lost to a channel blip is repaired by the reconnect re-sync.
/// Consecutive identical status frames are deduped so live state changes are
/// pushed exactly once (no periodic spam).
class ControlStatusNotifier {
  final ControlChannelClient _client;
  final Stream<PluginStatus> _pluginStatus;
  final Stream<RelayConnectionState> _relayConnectionState;
  final Stream<String> _registrations;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  // The relay is genuinely not connected before the orchestrator's first
  // connect attempt; the plugin's health is unknown until its replay-latest
  // status stream delivers the current value (immediately on subscribe).
  ControlRelayConnectionState _relay = ControlRelayConnectionState.disconnected;
  ControlPluginHealthState _plugin = ControlPluginHealthState.unknown;
  int _activeSessionCount = 0;
  ControlStatus? _lastSentStatus;
  String? _bridgeId;
  bool _started = false;

  ControlStatusNotifier({
    required ControlChannelClient client,
    required Stream<PluginStatus> pluginStatus,
    required Stream<RelayConnectionState> relayConnectionState,
    required Stream<String> registrations,
  }) : _client = client,
       _pluginStatus = pluginStatus,
       _relayConnectionState = relayConnectionState,
       _registrations = registrations;

  /// Subscribes to the observed streams. Idempotent — a second call while
  /// already started does nothing.
  void start() {
    if (_started) return;
    _started = true;
    _pluginStatus.listen(_handlePluginStatus).addTo(_subscriptions);
    _relayConnectionState.listen(_handleRelayConnectionState).addTo(_subscriptions);
    _registrations.listen(_handleRegistered).addTo(_subscriptions);
    _client.connectionState.listen(_handleControlChannelState).addTo(_subscriptions);
  }

  Future<void> dispose() async {
    // Isolate the cancel so a failure still lets teardown finish.
    try {
      await _subscriptions.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[control][status] failed to cancel subscriptions", error, stackTrace);
    }
  }

  /// Typed delegate fed by the Orchestrator's SSE pipeline with the
  /// already-built projects-summary event (the same one phones receive), on
  /// startup and whenever the plugin reports project activity changes.
  void handleProjectsSummary({required SesoriProjectsSummary summary}) {
    final count = summary.projects.fold<int>(
      0,
      (total, project) => total + project.activeSessions.length,
    );
    if (count == _activeSessionCount) return;
    _activeSessionCount = count;
    _pushStatus();
  }

  void _handlePluginStatus(PluginStatus status) {
    final mapped = _mapPluginStatus(status);
    if (mapped == _plugin) return;
    _plugin = mapped;
    _pushStatus();
  }

  void _handleRelayConnectionState(RelayConnectionState state) {
    final mapped = _mapRelayState(state);
    if (mapped == _relay) return;
    _relay = mapped;
    _pushStatus();
  }

  void _handleRegistered(String bridgeId) {
    _bridgeId = bridgeId;
    _send(ControlMessage.registered(bridgeId: bridgeId));
  }

  /// After a control-channel blip the GUI may have missed edge-triggered
  /// pushes (sends throw while the channel is down), so a reconnect re-sends
  /// the `registered` event and the current status snapshot, bypassing the
  /// dedupe. A clean client dispose closes the state stream without emitting,
  /// so shutdown never triggers a re-sync.
  void _handleControlChannelState(ControlChannelConnectionState state) {
    if (state != ControlChannelConnectionState.connected) return;
    final bridgeId = _bridgeId;
    if (bridgeId != null) {
      _send(ControlMessage.registered(bridgeId: bridgeId));
    }
    _pushStatus(force: true);
  }

  void _pushStatus({bool force = false}) {
    final status = ControlStatus(
      relay: _relay,
      plugin: _plugin,
      activeSessionCount: _activeSessionCount,
    );
    if (!force && status == _lastSentStatus) return;
    _lastSentStatus = status;
    _send(status);
  }

  /// Best-effort send: status pushes are informational and must never throw
  /// into an observed stream's callback or block the caller.
  void _send(ControlMessage message) {
    try {
      _client.send(jsonEncode(message.toJson()));
    } on ControlChannelNotConnectedException {
      // Expected while the GUI is briefly away; the reconnect re-sync in
      // _handleControlChannelState converges the missed state.
      Log.d("[control][status] channel down — dropping ${message.runtimeType}");
    } on Object catch (error, stackTrace) {
      Log.w("[control][status] failed to send ${message.runtimeType}", error, stackTrace);
    }
  }

  ControlPluginHealthState _mapPluginStatus(PluginStatus status) {
    return switch (status) {
      // Health is not yet determined while start() is still in flight.
      PluginStarting() => ControlPluginHealthState.unknown,
      PluginReady() => ControlPluginHealthState.healthy,
      PluginDegraded() => ControlPluginHealthState.degraded,
      PluginRestarting() => ControlPluginHealthState.degraded,
      PluginFailed() => ControlPluginHealthState.unavailable,
      PluginStopping() => ControlPluginHealthState.unavailable,
      PluginStopped() => ControlPluginHealthState.unavailable,
    };
  }

  ControlRelayConnectionState _mapRelayState(RelayConnectionState state) {
    return switch (state) {
      RelayConnecting() => ControlRelayConnectionState.connecting,
      RelayConnected() => ControlRelayConnectionState.connected,
      RelayDisconnected() => ControlRelayConnectionState.disconnected,
    };
  }
}
