import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/control_channel_client.dart";
import "../services/control_channel_token_service.dart";
import "../services/control_prompt_service.dart";

/// The single inbound subscriber/decoder for GUI→helper control messages in
/// supervised mode: it owns the one subscription to
/// [ControlChannelClient.inbound], decodes each frame into a [ControlMessage]
/// exactly once, and routes it to the owning service through typed delegate
/// calls. The services keep their own correlation state and outbound send
/// paths — this class sends nothing.
///
/// An undecodable frame (malformed, or a forward-compat message type a newer
/// GUI added) is logged and skipped so it can never stall the channel. Variants
/// this bridge does not consume inbound are ignored: `restart` is helper→GUI
/// only and is never an inbound command (the GUI restarts the helper by
/// kill+respawn, not by message), and helper→GUI variants echoed back have no
/// inbound meaning.
class BridgeControlMessageDispatcher {
  final ControlChannelClient _client;
  final ControlChannelTokenService _tokenService;
  final ControlPromptService _promptService;

  StreamSubscription<String>? _subscription;

  BridgeControlMessageDispatcher({
    required ControlChannelClient client,
    required ControlChannelTokenService tokenService,
    required ControlPromptService promptService,
  })  : _client = client,
        _tokenService = tokenService,
        _promptService = promptService;

  /// Subscribes to the client's inbound stream. Idempotent — a second call
  /// while already started does nothing.
  void start() {
    _subscription ??= _client.inbound.listen(_handleFrame);
  }

  Future<void> dispose() async {
    // Isolate the cancel so a failure still lets teardown finish.
    try {
      await _subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[control][dispatcher] failed to cancel inbound subscription", error, stackTrace);
    }
    _subscription = null;
  }

  void _handleFrame(String frame) {
    final ControlMessage message;
    try {
      message = ControlMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error, stackTrace) {
      Log.w("[control][dispatcher] ignoring undecodable control frame", error, stackTrace);
      return;
    }
    switch (message) {
      case ControlTokenResponse(:final id, :final accessToken):
        _tokenService.handleTokenResponse(id: id, accessToken: accessToken);
      case ControlTokenUpdate(:final accessToken):
        _tokenService.handleTokenUpdate(accessToken: accessToken);
      case ControlPromptResponse(:final id, :final accepted):
        _promptService.handlePromptResponse(id: id, accepted: accepted);
      case ControlTokenRequest():
      case ControlStatus():
      case ControlPromptRequest():
      case ControlRestart():
      case ControlUnregisterAndExit():
      case ControlRegistered():
      case ControlProvisionProgressMessage():
        // Not consumed inbound (yet): helper→GUI variants have no inbound
        // meaning, `restart` is never an inbound command, and
        // `unregister_and_exit` gains its route when the unregister flow lands.
        Log.d("[control][dispatcher] ignoring inbound ${message.runtimeType}");
    }
  }
}
