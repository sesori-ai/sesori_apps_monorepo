import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:web_socket_channel/io.dart";

/// Live connection state of the loopback control channel.
///
/// This is internal lifecycle state, NOT a wire-protocol type — the
/// control-protocol DTOs live in `sesori_shared` (added in a later PR).
enum ControlChannelConnectionState { connected, disconnected }

/// Layer-0 transport for the GUI-hosted loopback control channel used in
/// supervised mode. It is a dumb duplex WebSocket pipe: it connects,
/// auto-reconnects with backoff while it is alive, surfaces inbound text
/// frames, and sends outbound text frames. It performs NO message parsing or
/// routing — higher layers interpret the frames.
///
/// The per-spawn secret authenticates the bridge to the GUI's control server.
/// It travels as an `Authorization: Bearer` header on the WebSocket upgrade
/// request — never on argv (ADR A8) and never as an application message.
///
/// Reconnect ownership differs from [RelayClient] (whose backoff loop lives in
/// the orchestrator): the GUI may come and go while the bridge stays up, so the
/// control client owns its own reconnect loop. The decision to give up after a
/// sustained outage is NOT made here — it belongs to a separate lifecycle
/// policy (`ControlChannelLossListener`, ADR A9) that observes
/// [connectionState].
class ControlChannelClient {
  final Uri _url;
  final String _secret;
  final Duration _connectTimeout;
  final Duration _initialReconnectDelay;
  final Duration _maxReconnectDelay;

  final StreamController<String> _inbound = StreamController<String>.broadcast();
  final StreamController<ControlChannelConnectionState> _connectionState =
      StreamController<ControlChannelConnectionState>.broadcast();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _active = false;
  int _generation = 0;

  ControlChannelClient({
    required Uri url,
    required String secret,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration initialReconnectDelay = const Duration(seconds: 1),
    Duration maxReconnectDelay = const Duration(seconds: 30),
  }) : _url = url,
       _secret = secret,
       _connectTimeout = connectTimeout,
       _initialReconnectDelay = initialReconnectDelay,
       _maxReconnectDelay = maxReconnectDelay;

  /// Raw inbound text frames from the control server. No parsing is performed.
  Stream<String> get inbound => _inbound.stream;

  /// Live connection-state transitions (connected / disconnected). A real drop
  /// emits [ControlChannelConnectionState.disconnected]; an intentional
  /// [dispose] closes this stream (done) WITHOUT emitting `disconnected`, so a
  /// loss policy can distinguish an outage from a clean shutdown.
  Stream<ControlChannelConnectionState> get connectionState => _connectionState.stream;

  /// Opens the initial connection. Throws if the first attempt fails (the GUI
  /// control server is not listening, or the handshake times out), mirroring
  /// [RelayClient.connect]. Once connected, subsequent drops are recovered in
  /// the background with exponential backoff until [dispose].
  Future<void> connect() async {
    if (_active) return;
    _active = true;
    _generation++;
    try {
      await _openChannel(_generation);
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  /// Sends a raw text frame. Throws [StateError] if not currently connected.
  void send(String frame) {
    final channel = _channel;
    if (channel == null) {
      throw StateError("Control channel is not connected");
    }
    channel.sink.add(frame);
  }

  Future<void> dispose() async {
    _active = false;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Isolate every teardown step: a failure in one must not skip the rest.
    try {
      await _socketSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[control][ws] failed to cancel subscription during dispose", error, stackTrace);
    }
    _socketSubscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        Log.w("[control][ws] close handshake timed out — connection abandoned");
      } on Object catch (error, stackTrace) {
        Log.w("[control][ws] close failed — connection abandoned", error, stackTrace);
      }
    }
    try {
      await _inbound.close();
    } on Object catch (error, stackTrace) {
      Log.w("[control][ws] failed to close inbound stream", error, stackTrace);
    }
    try {
      await _connectionState.close();
    } on Object catch (error, stackTrace) {
      Log.w("[control][ws] failed to close connectionState stream", error, stackTrace);
    }
  }

  Future<void> _openChannel(int generation) async {
    final channel = IOWebSocketChannel.connect(
      _url,
      headers: <String, dynamic>{"Authorization": "Bearer $_secret"},
    );
    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (_) {
      // Clean up the half-open channel so a failed/timed-out attempt never
      // leaves a zombie connection lingering.
      await _closeChannelQuietly(channel, "after a failed connect");
      rethrow;
    }

    // Liveness guard: dispose() or a newer connect generation may have run while
    // we awaited the handshake. Never install a socket on a disposed/superseded
    // client — that would leak a live WebSocket past dispose.
    if (!_active || generation != _generation) {
      await _closeChannelQuietly(channel, "on a superseded connect");
      return;
    }

    _channel = channel;
    _emitConnectionState(ControlChannelConnectionState.connected);
    _socketSubscription = channel.stream.listen(
      _handleFrame,
      onError: (Object error, StackTrace stackTrace) {
        Log.w("[control][ws] socket error", error, stackTrace);
        _handleDisconnect(channel);
      },
      onDone: () => _handleDisconnect(channel),
      cancelOnError: false,
    );
  }

  Future<void> _closeChannelQuietly(IOWebSocketChannel channel, String context) async {
    try {
      await channel.sink.close().timeout(const Duration(seconds: 1));
    } catch (error, stackTrace) {
      Log.w("[control][ws] failed to close channel $context", error, stackTrace);
    }
  }

  void _handleFrame(dynamic frame) {
    if (frame is String) {
      _inbound.add(frame);
      return;
    }
    if (frame is List<int>) {
      _inbound.add(utf8.decode(frame));
      return;
    }
    Log.w("[control][ws] ignoring unsupported frame type: ${frame.runtimeType}");
  }

  void _handleDisconnect(IOWebSocketChannel channel) {
    // Ignore drops once disposed, and stale callbacks from a channel that has
    // already been replaced by a reconnect (onError can be followed by onDone
    // for the same socket — only the current channel may drive a reconnect).
    if (!_active || !identical(_channel, channel)) return;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    _channel = null;
    if (subscription != null) {
      // unawaited alone does not consume errors; a throwing cancel would
      // surface as an uncaught async error. Future.sync also catches a
      // synchronous throw from cancel().
      unawaited(
        Future.sync(subscription.cancel).catchError((Object error, StackTrace stackTrace) {
          Log.w("[control][ws] failed to cancel subscription on disconnect", error, stackTrace);
        }),
      );
    }
    _emitConnectionState(ControlChannelConnectionState.disconnected);
    _scheduleReconnect(_initialReconnectDelay, _generation);
  }

  void _scheduleReconnect(Duration delay, int generation) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_active || generation != _generation) return;
      try {
        await _openChannel(generation);
      } catch (error, stackTrace) {
        if (!_active || generation != _generation) return;
        Log.w("[control][ws] reconnect attempt failed; backing off", error, stackTrace);
        _scheduleReconnect(_nextBackoff(delay), generation);
      }
    });
  }

  Duration _nextBackoff(Duration delay) {
    final doubled = delay * 2;
    return doubled > _maxReconnectDelay ? _maxReconnectDelay : doubled;
  }

  void _emitConnectionState(ControlChannelConnectionState state) {
    if (_connectionState.isClosed) return;
    _connectionState.add(state);
  }
}
