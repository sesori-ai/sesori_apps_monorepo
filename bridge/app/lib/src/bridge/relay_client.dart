import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";
import "package:web_socket_channel/io.dart";

const String _bridgeRole = "bridge";

class RelayClientMessage {
  final bool isText;
  final Uint8List data;

  const RelayClientMessage({required this.isText, required this.data});
}

class RelayClient {
  final String _relayURL;
  String _accessToken;
  final Duration _pingInterval;
  final Duration _connectTimeout;
  IOWebSocketChannel? _channel;

  RelayClient(
    String relayURL,
    String accessToken, {
    Duration pingInterval = const Duration(seconds: 15),
    Duration connectTimeout = const Duration(seconds: 15),
  }) : _relayURL = relayURL,
       _accessToken = accessToken,
       _pingInterval = pingInterval,
       _connectTimeout = connectTimeout;

  Future<void> connect() async {
    final wsURL = _buildWebSocketURL(_relayURL);
    final channel = IOWebSocketChannel.connect(
      wsURL,
      pingInterval: _pingInterval,
    );

    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (e) {
      // Clean up the channel if connection fails or times out to prevent
      // zombie WebSocket connections from lingering.
      try {
        await channel.sink.close().timeout(const Duration(seconds: 1));
      } catch (closeError) {
        Log.w("Failed to clean up WebSocket channel: $closeError");
      }
      rethrow;
    }

    _channel = channel;

    if (_accessToken.isNotEmpty) {
      final authMessage = RelayMessage.auth(
        token: _accessToken,
        role: _bridgeRole,
      );
      channel.sink.add(jsonEncode(authMessage.toJson()));
    }
  }

  Future<void> reconnect() async {
    try {
      await close();
    } catch (_) {}
    await connect();
  }

  Stream<RelayClientMessage> read() {
    final channel = _channel;
    if (channel == null) {
      throw StateError("WebSocket connection is not established");
    }

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

  void send(int connID, List<int> payload) {
    if (connID < 0 || connID > 0xFFFF) {
      throw RangeError.range(connID, 0, 0xFFFF, "connID");
    }

    final channel = _channel;
    if (channel == null) {
      throw StateError("WebSocket connection is not established");
    }

    final framed = Uint8List(2 + payload.length);
    final byteData = ByteData.sublistView(framed);
    byteData.setUint16(0, connID, Endian.big);
    framed.setRange(2, framed.length, payload);

    channel.sink.add(framed);
  }

  void setAccessToken(String token) {
    _accessToken = token;
  }

  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) {
      return;
    }
    try {
      await channel.sink.close().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      Log.w("WebSocket close handshake timed out — connection abandoned");
    } catch (e) {
      Log.w("WebSocket close failed: $e — connection abandoned");
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
