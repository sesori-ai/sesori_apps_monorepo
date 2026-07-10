import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Thrown by [ControlChannelServer.send] when no helper is connected.
class ControlHelperNotConnectedException implements Exception {
  const ControlHelperNotConnectedException();

  @override
  String toString() => "ControlHelperNotConnectedException: no helper is connected to the control channel";
}

/// Ordered transport events from the control channel.
///
/// Connection lifecycle and frames are delivered on ONE stream, in the exact
/// order the socket produced them — so a consumer can never observe a frame
/// and a connection change out of order (e.g. a status frame after the
/// disconnect it preceded).
sealed class ControlChannelEvent {
  const ControlChannelEvent();
}

/// An authenticated helper attached to the control channel.
final class ControlChannelConnected extends ControlChannelEvent {
  const ControlChannelConnected();
}

/// The helper's socket dropped (or the server stopped).
final class ControlChannelDisconnected extends ControlChannelEvent {
  const ControlChannelDisconnected();
}

/// A text frame from the authenticated helper.
final class ControlChannelFrame extends ControlChannelEvent {
  const ControlChannelFrame({required this.text});

  final String text;
}

/// GUI-hosted loopback WebSocket control host for the supervised bridge
/// helper (transport only — message semantics live in the dispatcher).
///
/// - Binds `127.0.0.1` on an ephemeral port; [start] mints a FRESH per-spawn
///   secret, which the spawner delivers to the helper off-argv (first stdin
///   line — argv is world-readable and this channel issues bearer tokens).
/// - The helper authenticates by presenting the secret as an
///   `Authorization: Bearer` header on the WS upgrade; anything else is
///   rejected 401. Exactly one authenticated helper at a time (a concurrent
///   second connection is rejected 409), but a dropped socket is cleared so
///   the helper's auto-reconnect is accepted.
@lazySingleton
class ControlChannelServer {
  HttpServer? _server;
  WebSocket? _socket;
  String? _secret;
  bool _startPending = false;

  /// Bumped by every [stop]: an in-flight `start()` bind or WS upgrade from a
  /// previous generation detects it was superseded and discards its result.
  int _generation = 0;
  final StreamController<ControlChannelEvent> _events = StreamController<ControlChannelEvent>.broadcast();
  final BehaviorSubject<bool> _helperConnected = BehaviorSubject.seeded(false);

  /// Connection lifecycle + frames, in true socket order.
  Stream<ControlChannelEvent> get events => _events.stream;

  /// True while an authenticated helper socket is attached (snapshot
  /// convenience derived from [events]).
  ValueStream<bool> get helperConnectionStream => _helperConnected.stream;

  /// The `ws://127.0.0.1:<port>` URL to pass to the helper as `--control-url`.
  Uri get url {
    final HttpServer? server = _server;
    if (server == null) {
      throw StateError("Control channel server is not running");
    }
    return Uri.parse("ws://127.0.0.1:${server.port}");
  }

  /// The per-spawn secret the helper must present on the WS upgrade.
  String get secret {
    final String? secret = _secret;
    if (secret == null) {
      throw StateError("Control channel server is not running");
    }
    return secret;
  }

  /// Mints a fresh secret and starts listening on an ephemeral loopback port.
  Future<void> start() async {
    if (_server != null || _startPending) {
      throw StateError("Control channel server is already running");
    }
    _startPending = true;
    final int generation = _generation;
    _secret = _generateSecret();
    try {
      final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (generation != _generation) {
        // stop()/dispose() superseded this start while the bind was pending.
        await server.close(force: true);
        return;
      }
      _server = server;
      server.listen(
        (request) => unawaited(_handleUpgradeRequest(request)),
        onError: (Object error, StackTrace stackTrace) => logw("Control channel server error", error, stackTrace),
      );
    } finally {
      _startPending = false;
    }
  }

  /// Sends a text frame to the connected helper.
  ///
  /// Throws [ControlHelperNotConnectedException] when no helper is attached —
  /// callers decide whether that is an error or a best-effort drop.
  void send(String text) {
    final WebSocket? socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw const ControlHelperNotConnectedException();
    }
    try {
      socket.add(text);
    } on Object {
      // A concurrently-closing socket surfaces here; map it to the documented
      // contract so callers handle a single exception type.
      throw const ControlHelperNotConnectedException();
    }
  }

  /// Stops the server and drops the helper socket + secret.
  Future<void> stop() async {
    // Invalidate any in-flight start bind or WS upgrade first, then null the
    // secret — combined with the null-secret rejection in the upgrade
    // handler, nothing can authenticate during or after teardown.
    _generation++;
    final WebSocket? socket = _socket;
    _socket = null;
    final HttpServer? server = _server;
    _server = null;
    _secret = null;

    // Report the disconnect before the async closes so consumers can never
    // act on a "connected" snapshot of a server that is already gone; frames
    // from the dropped socket are discarded by the identity check in its
    // listener.
    if (!_helperConnected.isClosed && _helperConnected.value) {
      _helperConnected.add(false);
      _events.add(const ControlChannelDisconnected());
    }

    try {
      await socket?.close();
    } on Object catch (error, stackTrace) {
      // Best-effort teardown: the socket may already be dead.
      logw("Error closing the helper control socket", error, stackTrace);
    }
    try {
      await server?.close(force: true);
    } on Object catch (error, stackTrace) {
      // Best-effort teardown: the listener may already be gone.
      logw("Error closing the control channel server", error, stackTrace);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _helperConnected.close();
  }

  Future<void> _handleUpgradeRequest(HttpRequest request) async {
    // Isolate each request: a mid-handshake disconnect or a bad client must
    // never crash the host server.
    try {
      // The null check matters: during teardown `_secret` is null, and
      // interpolation would otherwise turn the expected header into the
      // guessable literal "Bearer null".
      final String? secret = _secret;
      final String? authorization = request.headers.value(HttpHeaders.authorizationHeader);
      if (secret == null || authorization != "Bearer $secret") {
        logw("Rejecting control upgrade: bad or missing Authorization header");
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      if (_socket != null) {
        // One authenticated helper per spawn.
        logw("Rejecting control upgrade: a helper is already connected");
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
        return;
      }

      final int generation = _generation;
      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      // Revalidate after the await: the server may have stopped meanwhile
      // (generation bumped), or a concurrent upgrade may have won the single
      // helper slot — in both cases this socket must not be installed.
      if (generation != _generation || _socket != null) {
        logw("Discarding a control upgrade that lost the helper slot");
        await socket.close(WebSocketStatus.policyViolation, "superseded");
        return;
      }
      _socket = socket;
      _helperConnected.add(true);
      _events.add(const ControlChannelConnected());
      socket.listen(
        (Object? data) {
          if (!identical(_socket, socket)) {
            // Buffered frames from a socket that is no longer the active
            // helper (dropped/superseded) must not leak into the pipeline.
            return;
          }
          if (data is String) {
            _events.add(ControlChannelFrame(text: data));
          } else {
            logw("Ignoring a non-text control frame from the helper");
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          logw("Helper control socket error", error, stackTrace);
          _clearSocket(socket);
        },
        onDone: () => _clearSocket(socket),
        cancelOnError: false,
      );
    } on Object catch (error, stackTrace) {
      logw("Error handling a control-channel upgrade request", error, stackTrace);
    }
  }

  /// Clears the active socket when it disconnects (only if it is still the
  /// one we hold), so the helper's reconnect is accepted instead of 409'd.
  void _clearSocket(WebSocket socket) {
    if (!identical(_socket, socket)) {
      return;
    }
    _socket = null;
    if (!_helperConnected.isClosed) {
      _helperConnected.add(false);
      _events.add(const ControlChannelDisconnected());
    }
  }

  static String _generateSecret() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
