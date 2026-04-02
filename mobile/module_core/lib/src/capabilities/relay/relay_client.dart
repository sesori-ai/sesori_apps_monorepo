import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../../logging/logging.dart";
import "room_key_storage.dart";

enum RelayClientConnectionState { disconnected, connecting, connected, disconnecting }

/// Represents whether the bridge (desktop process) is reachable via the relay.
enum BridgeStatus { online, offline }

class RelayClient {
  final String relayHost;
  final String? authToken;

  final RelayCryptoService _cryptoService;
  final RoomKeyStorage _roomKeyStorage;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _channelSubscription;
  SessionEncryptor? _sessionEncryptor;

  final Map<String, Completer<RelayResponse>> _pendingRequests = {};
  StreamController<RelaySseEvent>? _sseController;
  Completer<Uint8List>? _firstBinaryMessage;

  final StreamController<BridgeStatus> _bridgeStatusController = StreamController<BridgeStatus>.broadcast();

  RelayClientConnectionState _connectionState = RelayClientConnectionState.disconnected;
  bool _disposed = false;

  static const int _messageVersion = 0x01;
  static const Duration _handshakeTimeout = Duration(seconds: 15);
  static const Duration _requestTimeout = Duration(seconds: 30);
  int? _lastCloseCode;
  int? get lastCloseCode => _lastCloseCode;

  RelayClient({
    required this.relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    this.authToken,
  }) : _cryptoService = cryptoService,
       _roomKeyStorage = roomKeyStorage;

  RelayClientConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == RelayClientConnectionState.connected;

  /// Stream of bridge online/offline events sent as text control frames by the relay.
  Stream<BridgeStatus> get bridgeStatus => _bridgeStatusController.stream;

  Future<void> connect() async {
    if (_disposed) {
      throw StateError("RelayClient is disposed");
    }
    if (_connectionState == RelayClientConnectionState.connected) {
      return;
    }
    if (_connectionState == RelayClientConnectionState.connecting) {
      throw StateError("RelayClient is already connecting");
    }

    _connectionState = RelayClientConnectionState.connecting;
    _lastCloseCode = null;
    final uri = Uri.parse("wss://$relayHost/ws");

    try {
      _channel = WebSocketChannel.connect(uri);
      final channel = _channel;
      if (channel == null) {
        throw StateError("Failed to create relay WebSocket channel");
      }
      unawaited(
        channel.sink.done.catchError((Object error) {
          logw("WebSocket sink closed with error (suppressed): ${error.toString()}");
        }),
      );
      _firstBinaryMessage = Completer<Uint8List>();

      _channelSubscription = channel.stream.listen(
        (Object? message) {
          unawaited(_onSocketMessage(message));
        },
        onError: (Object error, StackTrace stackTrace) {
          loge("Relay socket stream error", error, stackTrace);
          final firstBinaryMessage = _firstBinaryMessage;
          if (firstBinaryMessage != null && !firstBinaryMessage.isCompleted) {
            firstBinaryMessage.completeError(error, stackTrace);
          }
          _completeAllPendingWithError(StateError("Relay socket stream error: ${error.toString()}"));
        },
        onDone: _onSocketDone,
      );

      // Auth token is sent before E2EE is established. This is intentional:
      // the relay requires a valid JWT to authenticate the WebSocket connection
      // and route it to the correct account group. Transport-level encryption
      // is provided by WSS (TLS). The relay cannot read E2EE application data.
      final token = authToken;
      if (token != null && token.isNotEmpty) {
        final authMessage = RelayMessage.auth(token: token, role: RelayProtocol.rolePhone);
        channel.sink.add(jsonEncode(authMessage.toJson()));
        logd("Relay auth message sent");
      }

      // Attempt resume with a stored room key before falling back to full DH exchange.
      final storedRoomKeyBytes = await _roomKeyStorage.getRoomKey();
      if (storedRoomKeyBytes != null) {
        final resumed = await _tryResume(storedRoomKeyBytes);
        if (resumed) {
          if (_disposed) return;
          _connectionState = RelayClientConnectionState.connected;
          logd("Relay resumed with stored room key");
          return;
        }
        // Resume failed (rekey_required or decryption error); room key was cleared.
        // Reset the completer so the DH flow can capture the bridge's response.
        _firstBinaryMessage = Completer<Uint8List>();
      }

      // Fresh DH key exchange to obtain the room key from the bridge.
      await _performKeyExchange();

      if (_disposed) {
        return;
      }

      _connectionState = RelayClientConnectionState.connected;
      logd("Relay key exchange complete, room key persisted");
    } catch (error, stackTrace) {
      loge("Failed to connect relay client", error, stackTrace);
      await _teardownChannelOnly();
      _connectionState = RelayClientConnectionState.disconnected;
      rethrow;
    }
  }

  /// Tries to resume the session using [storedRoomKeyBytes].
  /// Returns true if the bridge acknowledged the resume.
  /// Returns false and clears the stored key if a fresh key exchange is required.
  Future<bool> _tryResume(Uint8List storedRoomKeyBytes) async {
    try {
      final roomKeySecret = SecretKey(storedRoomKeyBytes.toList());
      final resumeEncryptor = _cryptoService.createSessionEncryptor(roomKeySecret);

      // Send encrypted resume message — binary frame, relay forwards to bridge.
      await _sendEncryptedMessageWithEncryptor(const RelayMessage.resume(), resumeEncryptor);

      final firstBinaryMessage = _firstBinaryMessage;
      if (firstBinaryMessage == null) {
        throw StateError("Binary message completer is null before resume");
      }
      final responseBytes = await firstBinaryMessage.future.timeout(
        _handshakeTimeout,
        onTimeout: () {
          throw TimeoutException("Timed out waiting for relay resume response", _handshakeTimeout);
        },
      );

      if (responseBytes.isEmpty) {
        throw const FormatException("Empty resume response from relay");
      }

      if (responseBytes.first == _messageVersion) {
        // Encrypted response — decrypt with room key and expect resume_ack.
        final responseMsg = await _decryptRelayMessage(responseBytes, resumeEncryptor);
        if (responseMsg is RelayResumeAck) {
          _sessionEncryptor = resumeEncryptor;
          return true;
        }
        throw StateError("Expected resume_ack, got ${responseMsg.runtimeType.toString()}");
      }

      if (responseBytes.first == RelayProtocol.jsonStartByte) {
        // Plaintext JSON from bridge — expect rekey_required.
        final decoded = jsonDecodeMap(utf8.decode(responseBytes));
        final msg = RelayMessage.fromJson(decoded);
        if (msg is RelayRekeyRequired) {
          logd("Relay rekey_required received, clearing stored room key");
          await _roomKeyStorage.clearRoomKey();
          return false;
        }
        throw StateError("Unexpected plaintext message during resume: ${msg.runtimeType.toString()}");
      }

      throw FormatException(
        "Unexpected first byte in resume response: 0x${responseBytes.first.toRadixString(16)}",
      );
    } catch (error, stackTrace) {
      loge("Resume failed, clearing room key and falling back to DH key exchange", error, stackTrace);
      await _roomKeyStorage.clearRoomKey();
      return false;
    }
  }

  /// Performs the initial DH key exchange with the bridge to receive the room key.
  Future<void> _performKeyExchange() async {
    final channel = _channel;
    if (channel == null) {
      throw StateError("WebSocket channel is null — connection was lost before key exchange");
    }
    final completer = _firstBinaryMessage;
    if (completer == null) {
      throw StateError("Binary message completer is null — connection was lost before key exchange");
    }

    final localKeyPair = await _cryptoService.generateKeyPair();
    final localPublicKey = await localKeyPair.extractPublicKey();
    final encodedPublicKey = await _cryptoService.encodePublicKey(localPublicKey);

    // Key exchange is sent as a binary frame (UTF-8 JSON bytes).
    // Text frames from phones are silently dropped by the relay phone handler.
    final keyExchange = RelayMessage.keyExchange(publicKey: encodedPublicKey);
    channel.sink.add(utf8.encode(jsonEncode(keyExchange.toJson())));

    final firstEncryptedMessage = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        "Bridge did not respond to key exchange within 15 seconds",
      ),
    );

    const x25519KeyLength = 32;
    if (firstEncryptedMessage.length < x25519KeyLength + 2) {
      throw FormatException(
        "Key exchange response too short: ${firstEncryptedMessage.length} bytes",
      );
    }
    final bridgePublicKeyBytes = firstEncryptedMessage.sublist(0, x25519KeyLength);
    final encryptedFrame = firstEncryptedMessage.sublist(x25519KeyLength);

    final peerPublicKey = _cryptoService.decodePublicKeyFromBytes(bridgePublicKeyBytes);
    final sharedSecret = await _cryptoService.deriveSharedSecret(localKeyPair, peerPublicKey: peerPublicKey);
    final encryptionKey = await _cryptoService.deriveEncryptionKey(sharedSecret);
    final ephemeralEncryptor = _cryptoService.createSessionEncryptor(encryptionKey);

    final readyMessage = await _decryptRelayMessage(encryptedFrame, ephemeralEncryptor);
    if (readyMessage is! RelayReady) {
      throw StateError("Expected ready message after key exchange, got ${readyMessage.runtimeType.toString()}");
    }

    // The ready message delivers the bridge's public key (confirmation) and the
    // shared room key. All subsequent sessions use the room key — the ephemeral
    // DH key is discarded after this point.
    final roomKeyBytes = base64Url.decode(base64Url.normalize(readyMessage.roomKey));
    if (roomKeyBytes.length != 32) {
      throw FormatException(
        "Invalid room key length: expected 32 bytes, got ${roomKeyBytes.length}",
      );
    }

    final roomKeyUint8 = Uint8List.fromList(roomKeyBytes);
    await _roomKeyStorage.saveRoomKey(roomKeyUint8);

    // Switch to room key for all subsequent messages.
    final roomKeySecret = SecretKey(roomKeyBytes);
    _sessionEncryptor = _cryptoService.createSessionEncryptor(roomKeySecret);
  }

  Future<RelayResponse> sendRequest(RelayRequest request) async {
    if (!isConnected || _sessionEncryptor == null || _channel == null) {
      throw StateError("RelayClient is not connected");
    }

    final completer = Completer<RelayResponse>();
    _pendingRequests[request.id] = completer;

    try {
      await _sendEncryptedMessage(request);

      return completer.future.timeout(
        _requestTimeout,
        onTimeout: () {
          _pendingRequests.remove(request.id);
          throw TimeoutException(
            "Relay request timed out: ${request.method} ${request.path}",
            _requestTimeout,
          );
        },
      );
    } catch (error, stackTrace) {
      _pendingRequests.remove(request.id);
      loge("Failed to send relay request ${request.id}", error, stackTrace);
      rethrow;
    }
  }

  Stream<RelaySseEvent> subscribeSse(String path) {
    if (!isConnected || _sessionEncryptor == null) {
      throw StateError("RelayClient is not connected");
    }

    final previousController = _sseController;
    if (previousController != null && !previousController.isClosed) {
      unawaited(_sendEncryptedMessage(const RelayMessage.sseUnsubscribe()));
      unawaited(previousController.close());
    }

    final controller = StreamController<RelaySseEvent>.broadcast();
    _sseController = controller;
    unawaited(_sendEncryptedMessage(RelayMessage.sseSubscribe(path: path)));
    return controller.stream;
  }

  Future<void> disconnect() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _connectionState = RelayClientConnectionState.disconnecting;

    try {
      final sseController = _sseController;
      if (_sessionEncryptor != null && sseController != null && !sseController.isClosed) {
        await _sendEncryptedMessage(const RelayMessage.sseUnsubscribe());
      }
    } catch (error, stackTrace) {
      loge("Failed to send relay SSE unsubscribe", error, stackTrace);
    }

    await _teardownChannelOnly();
    await _closeSseController();
    await _closeBridgeStatusController();
    _completeAllPendingWithError(StateError("Relay disconnected"));
    _sessionEncryptor = null;
    _connectionState = RelayClientConnectionState.disconnected;
  }

  Future<void> _onSocketMessage(Object? message) async {
    if (_disposed) {
      return;
    }

    if (message is String) {
      _onTextFrame(message);
      return;
    }

    final bytes = _toBytes(message);
    if (bytes == null) {
      logw("Unsupported relay frame type: ${message.runtimeType.toString()}");
      return;
    }

    final encryptor = _sessionEncryptor;
    if (encryptor == null) {
      if (_firstBinaryMessage case final completer? when !completer.isCompleted) {
        completer.complete(bytes);
      } else {
        logw("Received extra binary frame before relay key exchange completion");
      }
      return;
    }

    try {
      final relayMessage = await _decryptRelayMessage(bytes, encryptor);
      if (_disposed) return;

      if (relayMessage case final RelayResponse response) {
        final completer = _pendingRequests.remove(response.id);
        if (completer == null) {
          logw("No pending request for relay response id=${response.id}");
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(response);
        }
        return;
      }

      if (relayMessage case final RelaySseEvent sseEvent) {
        final controller = _sseController;
        if (controller == null || controller.isClosed) {
          logw("Received relay SSE event without an active subscription");
          return;
        }
        controller.add(sseEvent);
        return;
      }

      logw("Unhandled relay message type: ${relayMessage.runtimeType.toString()}");
    } catch (error, stackTrace) {
      loge("Failed to route incoming relay message", error, stackTrace);
    }
  }

  void _onSocketDone() {
    final closeCode = _channel?.closeCode;
    _lastCloseCode = closeCode;

    final firstBinaryMessage = _firstBinaryMessage;
    if (firstBinaryMessage != null && !firstBinaryMessage.isCompleted) {
      firstBinaryMessage.completeError(
        StateError("Relay socket closed before key exchange (code=$closeCode)"),
      );
    }

    _sessionEncryptor = null;
    _connectionState = RelayClientConnectionState.disconnected;
    _completeAllPendingWithError(StateError("Relay socket closed (code=$closeCode)"));
    unawaited(_teardownChannelOnly());
    unawaited(_closeSseController());

    if (RelayCloseCodes.shouldReconnect(closeCode)) {
      logd("Relay socket closed (closeCode=$closeCode), reconnection handled by ConnectionService");
    } else {
      logw("Relay socket closed with terminal closeCode=$closeCode");
    }
  }

  Future<void> _sendEncryptedMessage(RelayMessage message) async {
    final channel = _channel;
    final encryptor = _sessionEncryptor;
    if (_disposed || channel == null || encryptor == null) {
      throw StateError("RelayClient is not ready for encrypted messages");
    }

    final jsonBytes = utf8.encode(jsonEncode(message.toJson()));
    final encryptedBytes = await encryptor.encrypt(jsonBytes);
    final payload = Uint8List.fromList([_messageVersion, ...encryptedBytes]);
    channel.sink.add(payload);
  }

  /// Sends an encrypted message using the provided [encryptor] instead of
  /// [_sessionEncryptor]. Used during handshake before the session is established.
  // ignore: no_slop_linter/prefer_required_named_parameters, private handshake helper mirrors call sites
  Future<void> _sendEncryptedMessageWithEncryptor(
    RelayMessage message,
    SessionEncryptor encryptor,
  ) async {
    final channel = _channel;
    if (_disposed || channel == null) {
      throw StateError("RelayClient is not ready for encrypted messages");
    }

    final jsonBytes = utf8.encode(jsonEncode(message.toJson()));
    final encryptedBytes = await encryptor.encrypt(jsonBytes);
    final payload = Uint8List.fromList([_messageVersion, ...encryptedBytes]);
    channel.sink.add(payload);
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, private decrypt helper mirrors call sites
  Future<RelayMessage> _decryptRelayMessage(Uint8List message, SessionEncryptor encryptor) async {
    if (message.isEmpty) {
      throw const FormatException("Relay message is empty");
    }

    final version = message.first;
    if (version != _messageVersion) {
      throw FormatException("Unsupported relay message version: $version");
    }

    final encryptedPayload = message.sublist(1);
    final decryptedBytes = await encryptor.decrypt(encryptedPayload);

    final decoded = jsonDecodeMap(utf8.decode(decryptedBytes));
    return RelayMessage.fromJson(decoded);
  }

  Uint8List? _toBytes(Object? message) {
    if (message is Uint8List) {
      return message;
    }
    if (message is List<int>) {
      return Uint8List.fromList(message);
    }
    if (message is ByteBuffer) {
      return message.asUint8List();
    }
    return null;
  }

  Future<void> _teardownChannelOnly() async {
    try {
      await _channelSubscription?.cancel();
    } catch (error, stackTrace) {
      loge("Failed to cancel relay socket subscription", error, stackTrace);
    }
    _channelSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (error, stackTrace) {
      loge("Failed to close relay socket channel", error, stackTrace);
    }
    _channel = null;
    _firstBinaryMessage = null;
  }

  Future<void> _closeSseController() async {
    final controller = _sseController;
    _sseController = null;
    if (controller == null || controller.isClosed) {
      return;
    }

    try {
      await controller.close();
    } catch (error, stackTrace) {
      loge("Failed to close relay SSE stream controller", error, stackTrace);
    }
  }

  Future<void> _closeBridgeStatusController() async {
    if (_bridgeStatusController.isClosed) return;
    try {
      await _bridgeStatusController.close();
    } catch (error, stackTrace) {
      loge("Failed to close relay bridge status controller", error, stackTrace);
    }
  }

  /// Handles text frames from the relay. These are plaintext JSON control messages
  /// (not E2EE) sent by the relay itself, e.g. bridge_connected / bridge_disconnected.
  void _onTextFrame(String message) {
    try {
      final decoded = jsonDecodeMap(message);
      final typeValue = decoded["type"];
      final type = typeValue is String ? typeValue : null;
      switch (type) {
        case RelayProtocol.typeBridgeConnected:
          logd("Relay: bridge came online");
          _bridgeStatusController.add(BridgeStatus.online);
        case RelayProtocol.typeBridgeDisconnected:
          logd("Relay: bridge went offline");
          final firstBinaryMessage = _firstBinaryMessage;
          if (firstBinaryMessage != null && !firstBinaryMessage.isCompleted) {
            firstBinaryMessage.completeError(
              StateError("Bridge is offline - cannot complete key exchange"),
            );
          }
          _bridgeStatusController.add(BridgeStatus.offline);
        default:
          logw("Relay: unknown text frame type: ${type.toString()}");
      }
    } catch (error, stackTrace) {
      loge("Failed to parse relay text frame", error, stackTrace);
    }
  }

  void _completeAllPendingWithError(Object error) {
    final pending = Map<String, Completer<RelayResponse>>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final entry in pending.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(error);
      }
    }
  }
}
