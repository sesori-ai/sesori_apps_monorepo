import "dart:async";
import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/control_channel_server.dart";
import "../trackers/bridge_prompt_tracker.dart";
import "../trackers/bridge_status_tracker.dart";

/// Single inbound consumer of helper→GUI control messages.
///
/// Decodes each frame once and writes strictly DOWNWARD: token requests are
/// answered from the auth seam, status/registered land in the status tracker,
/// prompts land in the prompt tracker. It never touches cubits or UI — those
/// read the same trackers.
@lazySingleton
class ControlMessageDispatcher {
  ControlMessageDispatcher({
    required ControlChannelServer server,
    required AuthTokenProvider tokenProvider,
    required BridgeStatusTracker statusTracker,
    required BridgePromptTracker promptTracker,
  }) : _server = server,
       _tokenProvider = tokenProvider,
       _statusTracker = statusTracker,
       _promptTracker = promptTracker;

  final ControlChannelServer _server;
  final AuthTokenProvider _tokenProvider;
  final BridgeStatusTracker _statusTracker;
  final BridgePromptTracker _promptTracker;

  StreamSubscription<ControlChannelEvent>? _eventSubscription;

  /// Bumped on every connect/disconnect: an async token reply is bound to the
  /// connection its request arrived on and dropped when that changes.
  int _connectionEpoch = 0;

  void start() {
    if (_eventSubscription != null) {
      throw StateError("ControlMessageDispatcher is already started");
    }
    // ONE ordered stream for lifecycle + frames: a status frame can never be
    // processed on the wrong side of the connect/disconnect it belongs to.
    _eventSubscription = _server.events.listen(_onEvent);
  }

  void _onEvent(ControlChannelEvent event) {
    switch (event) {
      case ControlChannelConnected():
        _connectionEpoch++;
        _statusTracker.markHelperConnected();
      case ControlChannelDisconnected():
        _connectionEpoch++;
        _statusTracker.markHelperDisconnected();
        // Prompts are per-connection: a dropped helper resolves its own
        // pending asks as unanswerable, so ours are stale.
        _promptTracker.clear();
      case ControlChannelFrame(:final text):
        _onFrame(text);
    }
  }

  void _onFrame(String frame) {
    final ControlMessage message;
    try {
      message = ControlMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error, stackTrace) {
      // Forward compat: a newer helper's frame must not kill the pipeline.
      logw("Dropping an undecodable control frame", error, stackTrace);
      return;
    }

    switch (message) {
      case ControlTokenRequest():
        unawaited(_respondToken(request: message));
      case ControlStatus():
        _statusTracker.applyStatus(status: message);
      case ControlRegistered(:final bridgeId):
        _statusTracker.handleRegistered(bridgeId: bridgeId);
      case ControlPromptRequest():
        _promptTracker.addPrompt(prompt: message);
      case ControlProvisionProgressMessage():
        // Provisioning progress feeds the first-run UI slice; until that
        // lands, dropping a progress frame only skips a UI update.
        logd("Ignoring provision progress (no consumer yet)");
      case ControlRestart():
        // Advisory heads-up only — the exit-code sentinel is authoritative
        // for the supervisor's respawn decision.
        logd("Helper announced an intentional restart");
      case ControlTokenResponse() || ControlTokenUpdate() || ControlPromptResponse() || ControlUnregisterAndExit():
        // GUI→helper-direction variants are never inbound commands.
        logd("Ignoring a GUI-direction control message arriving inbound");
    }
  }

  Future<void> _respondToken({required ControlTokenRequest request}) async {
    final int epoch = _connectionEpoch;
    String? accessToken;
    try {
      accessToken = await _tokenProvider.getFreshAccessToken(forceRefresh: request.forceRefresh);
    } on Object catch (error, stackTrace) {
      // Answer signed-out rather than leaving the helper's pull hanging on
      // its timeout; the helper surfaces its typed token-unavailable path.
      logw("Token refresh for the helper failed; answering signed-out", error, stackTrace);
      accessToken = null;
    }
    if (_eventSubscription == null || epoch != _connectionEpoch) {
      // The requesting connection is gone (helper dropped/respawned, or the
      // dispatcher was disposed). Token ids are process-local on the helper
      // side, so a stale bearer reply must never cross onto a different
      // connection; the new helper simply re-pulls.
      logd("Dropping a token response for a connection that no longer exists");
      return;
    }
    _send(message: ControlMessage.tokenResponse(id: request.id, accessToken: accessToken));
  }

  void _send({required ControlMessage message}) {
    final String encoded = jsonEncode(message.toJson());
    try {
      _server.send(encoded);
    } on Object catch (error, stackTrace) {
      // Best-effort: the helper may have dropped mid-round-trip; it re-pulls
      // after reconnecting.
      logw("Failed to send a control message to the helper", error, stackTrace);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
