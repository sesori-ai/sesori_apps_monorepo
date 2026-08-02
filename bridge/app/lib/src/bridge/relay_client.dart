import "dart:async";
import "dart:convert";
import "dart:io" show HttpClient;
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";
import "package:web_socket_channel/io.dart";

import "../auth/access_token_provider.dart";
import "../auth/bridge_id_provider.dart";

const String _bridgeRole = "bridge";

class RelayClientMessage {
  final bool isText;
  final Uint8List data;

  const RelayClientMessage({required this.isText, required this.data});
}

/// Opaque handle for one exact relay WebSocket generation.
///
/// Callers can retain and pass the handle back to [RelayClient], but cannot
/// inspect the underlying socket.
final class RelayConnection {
  RelayConnection._({required IOWebSocketChannel channel}) : _channel = channel;

  final IOWebSocketChannel _channel;
  String? _lastAuthedToken;
}

enum RelaySendOutcome { sent, stale }

enum RelayCloseOutcome { closed, stale }

/// Live connection state of the relay WebSocket, emitted on
/// [RelayClient.connectionState].
///
/// This is internal lifecycle state, NOT a wire-protocol type. A remote drop
/// carries the WebSocket [RelayDisconnected.closeCode] so observers can key on
/// close semantics (e.g. revoked/replaced) without racing the reconnect loop's
/// own connection-scoped close-code read.
sealed class RelayConnectionState {
  const RelayConnectionState();
}

/// A connect attempt is in flight (initial connect or a reconnect).
final class RelayConnecting extends RelayConnectionState {
  const RelayConnecting();
}

/// The relay socket is open and the auth message (if any) has been sent.
final class RelayConnected extends RelayConnectionState {
  const RelayConnected();
}

/// The relay socket dropped or a connect attempt failed.
///
/// [closeCode] is the WebSocket close code of the dropped connection, or
/// `null` when none is available (e.g. a failed connect attempt).
/// [closeReason] is the paired close reason string, needed to detect a
/// bridge-replaced close during the relay-deploy rollout window (the relay
/// sends `1000 + "replaced"` until it emits the dedicated code); it is fragile
/// and only consulted for that fallback — the close code is authoritative.
final class RelayDisconnected extends RelayConnectionState {
  final int? closeCode;
  final String? closeReason;

  const RelayDisconnected({required this.closeCode, required this.closeReason});
}

class RelayClient {
  final String _relayURL;
  final AccessTokenProvider _accessTokenProvider;
  final BridgeIdProvider _bridgeIdProvider;
  final Duration _pingInterval;
  final Duration _connectTimeout;
  final StreamController<RelayConnectionState> _connectionState = StreamController<RelayConnectionState>.broadcast();
  _RelayConnectionAttempt? _pendingConnection;
  RelayConnection? _connection;

  RelayClient({
    required String relayURL,
    required AccessTokenProvider accessTokenProvider,
    required BridgeIdProvider bridgeIdProvider,
    Duration pingInterval = const Duration(seconds: 15),
    Duration connectTimeout = const Duration(seconds: 15),
  }) : _relayURL = relayURL,
       _accessTokenProvider = accessTokenProvider,
       _bridgeIdProvider = bridgeIdProvider,
       _pingInterval = pingInterval,
       _connectTimeout = connectTimeout;

  /// The WebSocket close code of [connection], available once it has closed.
  int? closeCode({required RelayConnection connection}) => connection._channel.closeCode;

  /// The WebSocket close reason of [connection], paired with
  /// [closeCode]. Only meaningful for the bridge-replaced rollout fallback
  /// (`1000 + "replaced"`); close reason strings are fragile, so close-code
  /// semantics are authoritative everywhere else.
  String? closeReason({required RelayConnection connection}) => connection._channel.closeReason;

  /// The access token sent in [connection]'s auth message, or `null` if that
  /// connect sent no auth (empty token). Lets a live re-auth
  /// trigger compare a freshly emitted token against the one this socket is
  /// actually authenticated with, so it re-auths only on a real change.
  String? lastAuthedToken({required RelayConnection connection}) => connection._lastAuthedToken;

  /// Live connection-state transitions of the relay socket.
  ///
  /// A connect attempt emits [RelayConnecting] then [RelayConnected] on
  /// success or [RelayDisconnected] on failure; a remote drop emits
  /// [RelayDisconnected] with the socket's close code. A deliberate
  /// [closeIfCurrent] emits nothing — a clean shutdown is not an outage (same
  /// contract as the control channel's connection-state stream).
  ///
  /// Remote-drop detection rides on the socket's close handshake, which
  /// `dart:io` only processes while the inbound message stream is being
  /// consumed — true whenever the orchestrator's relay loop is running
  /// (it always drains [read] on a live connection).
  Stream<RelayConnectionState> get connectionState => _connectionState.stream;

  Future<RelayConnection> connect() async {
    // Build (and thereby validate) the URL before announcing the attempt: a
    // throwing parse must not leave observers stuck on a connecting state
    // that never resolves to a terminal one.
    final wsURL = _buildWebSocketURL(_relayURL);
    if (_pendingConnection != null || _connection != null) {
      throw StateError("Relay connection already exists or is in progress");
    }
    _connectionState.add(const RelayConnecting());
    final httpClient = HttpClient();
    final channel = IOWebSocketChannel.connect(
      wsURL,
      pingInterval: _pingInterval,
      customClient: httpClient,
    );
    final attempt = _RelayConnectionAttempt(channel: channel, httpClient: httpClient);
    _pendingConnection = attempt;

    try {
      await channel.ready.timeout(_connectTimeout);
    } on Object catch (error, stackTrace) {
      // A detached attempt belongs to deliberate cancellation; only a
      // still-owned failure reports disconnected and cleans up here.
      if (identical(_pendingConnection, attempt)) {
        _pendingConnection = null;
        _connectionState.add(const RelayDisconnected(closeCode: null, closeReason: null));
        httpClient.close(force: true);
        await _closeChannel(
          channel: channel,
          timeout: const Duration(seconds: 1),
          timeoutMessage: "WebSocket cleanup timed out after connect failure",
          failureMessage: "Failed to clean up WebSocket channel after connect failure",
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (!identical(_pendingConnection, attempt)) {
      throw StateError("Relay connect was cancelled");
    }
    _pendingConnection = null;
    httpClient.close();
    final connection = RelayConnection._(channel: channel);
    _connection = connection;
    _watchConnectionDone(connection);
    _connectionState.add(const RelayConnected());

    try {
      if (_accessTokenProvider.accessToken case final String token when token.isNotEmpty) {
        final authMessage = RelayMessage.auth(
          token: token,
          role: _bridgeRole,
          bridgeId: _bridgeIdProvider.bridgeId,
        );
        channel.sink.add(jsonEncode(authMessage.toJson()));
        connection._lastAuthedToken = token;
      } else {
        connection._lastAuthedToken = null;
      }
    } on Object catch (error, stackTrace) {
      await closeIfCurrent(connection: connection);
      Error.throwWithStackTrace(error, stackTrace);
    }
    return connection;
  }

  /// Emits [RelayDisconnected] when [connection]'s socket closes while it is
  /// still current. A deliberate close detaches the handle before the
  /// sink-done future settles, so this watcher stays silent for intentional
  /// teardown and only surfaces genuine drops.
  void _watchConnectionDone(RelayConnection connection) {
    unawaited(
      connection._channel.sink.done.then<void>(
        (_) => _handleConnectionDone(connection),
        onError: (Object error) {
          Log.w("relay socket closed with error", error);
          _handleConnectionDone(connection);
        },
      ),
    );
  }

  void _handleConnectionDone(RelayConnection connection) {
    if (!identical(_connection, connection)) return;
    _connectionState.add(
      RelayDisconnected(
        closeCode: connection._channel.closeCode,
        closeReason: connection._channel.closeReason,
      ),
    );
  }

  Future<RelayConnection> reconnect({required RelayConnection connection}) async {
    try {
      await closeIfCurrent(connection: connection);
    } on Object catch (error, stackTrace) {
      Log.w("reconnect: close failed; continuing with a fresh connection", error, stackTrace);
    }
    return connect();
  }

  Stream<RelayClientMessage> read({required RelayConnection connection}) {
    final channel = connection._channel;

    return channel.stream.map((dynamic message) {
      if (message is String) {
        return RelayClientMessage(
          isText: true,
          data: Uint8List.fromList(utf8.encode(message)),
        );
      }

      if (message is Uint8List) {
        return RelayClientMessage(isText: false, data: message);
      }

      if (message is List<int>) {
        return RelayClientMessage(
          isText: false,
          data: Uint8List.fromList(message),
        );
      }

      if (message is ByteBuffer) {
        return RelayClientMessage(isText: false, data: message.asUint8List());
      }

      throw StateError(
        "Unsupported WebSocket frame type: ${message.runtimeType}",
      );
    });
  }

  RelaySendOutcome sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required List<int> payload,
  }) {
    if (connID < 0 || connID > 0xFFFF) {
      throw RangeError.range(connID, 0, 0xFFFF, "connID");
    }

    final current = _connection;
    if (!identical(current, connection)) return RelaySendOutcome.stale;

    final framed = Uint8List(2 + payload.length);
    final byteData = ByteData.sublistView(framed);
    byteData.setUint16(0, connID, Endian.big);
    framed.setRange(2, framed.length, payload);

    try {
      current!._channel.sink.add(framed);
    } on Object {
      // This call claims the exact handle before returning its close future.
      // An obsolete send can therefore never close a successor connection.
      unawaited(closeIfCurrent(connection: connection));
      rethrow;
    }
    return RelaySendOutcome.sent;
  }

  /// Closes a pending handshake that has not produced a [RelayConnection].
  ///
  /// Detachment is synchronous so a cancelled attempt cannot be promoted by a
  /// later `ready` completion.
  Future<void> cancelPendingConnection() {
    final pendingConnection = _pendingConnection;
    _pendingConnection = null;
    pendingConnection?.httpClient.close(force: true);
    if (pendingConnection == null) return Future<void>.value();
    return _closeChannel(
      channel: pendingConnection.channel,
      timeout: const Duration(seconds: 3),
      timeoutMessage: "Pending WebSocket close timed out — connection abandoned",
      failureMessage: "Pending WebSocket close failed — connection abandoned",
    );
  }

  /// Claims and detaches [connection] synchronously, then closes its socket.
  ///
  /// A stale handle is a typed no-op and can never close the current socket.
  Future<RelayCloseOutcome> closeIfCurrent({required RelayConnection connection}) {
    final current = _connection;
    if (!identical(current, connection)) {
      return Future<RelayCloseOutcome>.value(RelayCloseOutcome.stale);
    }
    _connection = null;
    return _closeClaimedConnection(current!);
  }

  Future<RelayCloseOutcome> _closeClaimedConnection(RelayConnection connection) async {
    await _closeChannel(
      channel: connection._channel,
      timeout: const Duration(seconds: 3),
      timeoutMessage: "WebSocket close handshake timed out — connection abandoned",
      failureMessage: "WebSocket close failed — connection abandoned",
    );
    return RelayCloseOutcome.closed;
  }

  Future<void> _closeChannel({
    required IOWebSocketChannel channel,
    required Duration timeout,
    required String timeoutMessage,
    required String failureMessage,
  }) async {
    try {
      await channel.ready.timeout(timeout);
    } on TimeoutException catch (error, stackTrace) {
      Log.w(timeoutMessage, error, stackTrace);
      return;
    } on Object {
      // web_socket_channel never attaches its outbound sink when the upgrade
      // fails, so sink.close() cannot complete. The failed ready future is the
      // terminal signal; pending attempts have also force-closed HttpClient.
      return;
    }

    try {
      await channel.sink.close().timeout(timeout);
    } on TimeoutException catch (error, stackTrace) {
      Log.w(timeoutMessage, error, stackTrace);
    } on Object catch (error, stackTrace) {
      Log.w(failureMessage, error, stackTrace);
    }
  }

  String _buildWebSocketURL(String relayURL) {
    final relayURI = Uri.parse(relayURL);
    final trimmedPath = relayURI.path.endsWith("/")
        ? relayURI.path.substring(0, relayURI.path.length - 1)
        : relayURI.path;
    final wsPath = trimmedPath.isEmpty ? "/ws" : "$trimmedPath/ws";
    return relayURI.replace(path: wsPath).toString();
  }
}

final class _RelayConnectionAttempt {
  const _RelayConnectionAttempt({required this.channel, required this.httpClient});

  final IOWebSocketChannel channel;
  final HttpClient httpClient;
}
