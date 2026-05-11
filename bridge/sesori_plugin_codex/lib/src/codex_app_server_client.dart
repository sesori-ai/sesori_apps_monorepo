import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:web_socket_channel/web_socket_channel.dart";

/// Result of a successful `initialize` handshake against codex app-server.
///
/// Fields mirror codex's `InitializeResponse` shape (see codex's
/// `app-server generate-json-schema` output for the source of truth).
class CodexInitializeResult {
  const CodexInitializeResult({
    required this.userAgent,
    required this.codexHome,
    required this.platformOs,
    required this.platformFamily,
  });

  final String userAgent;
  final String codexHome;
  final String platformOs;
  final String platformFamily;

  factory CodexInitializeResult.fromJson(Map<String, dynamic> json) {
    return CodexInitializeResult(
      userAgent: (json["userAgent"] ?? "") as String,
      codexHome: (json["codexHome"] ?? "") as String,
      platformOs: (json["platformOs"] ?? "") as String,
      platformFamily: (json["platformFamily"] ?? "") as String,
    );
  }
}

/// A JSON-RPC error returned by codex app-server.
class CodexRpcException implements Exception {
  CodexRpcException({
    required this.method,
    required this.code,
    required this.message,
  });

  final String method;
  final int code;
  final String message;

  @override
  String toString() => "CodexRpcException($method, code=$code, $message)";
}

/// A server-originated notification on the JSON-RPC connection.
///
/// Codex's `ServerNotification` is a tagged union: every notification has
/// a `method` (e.g. `"thread/started"`, `"item/agentMessage/delta"`) and
/// a free-form `params` object. We keep the raw map here and let upper
/// layers (event mapper in later phases) decode it.
class CodexServerNotification {
  const CodexServerNotification({required this.method, required this.params});

  final String method;
  final Map<String, dynamic> params;

  @override
  String toString() => "CodexServerNotification($method)";
}

/// A server-originated request that expects a response (approval prompts,
/// elicitations, user-input requests). Phase 2 records and logs these but
/// does not yet route them; later phases will turn them into
/// [PluginPendingQuestion]s on the bridge stream.
class CodexServerRequest {
  const CodexServerRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  /// JSON-RPC `id` — caller must use this when sending a response.
  final Object id;
  final String method;
  final Map<String, dynamic> params;
}

/// Factory used by the WebSocket client to open the underlying channel.
/// Injected for tests so we can swap in an in-memory transport.
typedef CodexWebSocketChannelFactory = WebSocketChannel Function(Uri uri);

WebSocketChannel _defaultConnect(Uri uri) => WebSocketChannel.connect(uri);

/// JSON-RPC 2.0 client for `codex app-server` over WebSocket.
///
/// Lifecycle:
///   1. Construct with the `ws://` URL discovered from
///      `startCodexAppServer`.
///   2. Call [connect]. This opens the socket and performs the
///      `initialize` handshake — the future resolves with the
///      [CodexInitializeResult] codex returns, or rejects on failure.
///   3. Send requests with [request]. Concurrent requests are demultiplexed
///      by JSON-RPC `id`.
///   4. Listen on [notifications] and [serverRequests] for streaming events.
///   5. Call [dispose] to close the socket and fail any in-flight requests.
class CodexAppServerClient {
  CodexAppServerClient({
    required String serverUrl,
    String? capabilityToken,
    CodexWebSocketChannelFactory? channelFactory,
  }) : _serverUrl = serverUrl,
       _capabilityToken = capabilityToken,
       _channelFactory = channelFactory ?? _defaultConnect;

  final String _serverUrl;
  // Currently unused — codex's `--ws-auth` is documented as required only
  // for non-loopback listeners. Kept for non-loopback support.
  // ignore: unused_field
  final String? _capabilityToken;
  final CodexWebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;
  int _nextId = 1;

  final Map<Object, Completer<dynamic>> _pending = {};
  final StreamController<CodexServerNotification> _notifications =
      StreamController.broadcast();
  final StreamController<CodexServerRequest> _serverRequests =
      StreamController.broadcast();

  /// Server-originated notifications (broadcast).
  Stream<CodexServerNotification> get notifications => _notifications.stream;

  /// Server-originated requests that expect a response (broadcast).
  Stream<CodexServerRequest> get serverRequests => _serverRequests.stream;

  /// Opens the socket and performs the `initialize` handshake.
  ///
  /// Idempotent only in the failure path — once `connect` succeeds, calling
  /// it again throws [StateError]. Re-connecting after a drop is a job for
  /// the caller (mirrors how the opencode SSE client externalises retry).
  Future<CodexInitializeResult> connect({
    String clientName = "sesori-bridge",
    String clientVersion = "0.0.0",
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_channel != null) {
      throw StateError("CodexAppServerClient already connected");
    }
    if (_disposed) {
      throw StateError("CodexAppServerClient is disposed");
    }

    final uri = Uri.parse(_serverUrl);
    final channel = _channelFactory(uri);
    _channel = channel;

    _subscription = channel.stream.listen(
      _handleIncoming,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
      cancelOnError: false,
    );

    final raw = await request(
      method: "initialize",
      params: {
        "clientInfo": {
          "name": clientName,
          "title": null,
          "version": clientVersion,
        },
        "capabilities": {
          "experimentalApi": false,
          "optOutNotificationMethods": null,
        },
      },
      timeout: timeout,
    );

    if (raw is! Map) {
      throw CodexRpcException(
        method: "initialize",
        code: -32603,
        message: "expected object result, got ${raw.runtimeType}",
      );
    }
    return CodexInitializeResult.fromJson(raw.cast<String, dynamic>());
  }

  /// Send a JSON-RPC request and wait for its response.
  ///
  /// Throws [CodexRpcException] on error responses, [TimeoutException] on
  /// timeout, [StateError] if the socket isn't open.
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError("CodexAppServerClient not connected");
    }
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;

    final envelope = <String, dynamic>{
      "jsonrpc": "2.0",
      "id": id,
      "method": method,
    };
    if (params != null) envelope["params"] = params;
    channel.sink.add(jsonEncode(envelope));

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      rethrow;
    }
  }

  /// Reply to a [CodexServerRequest] with a result payload.
  void respondToServerRequest({required Object id, required Object? result}) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode({"jsonrpc": "2.0", "id": id, "result": result}));
  }

  /// Reply to a [CodexServerRequest] with a JSON-RPC error.
  void respondToServerRequestWithError({
    required Object id,
    required int code,
    required String message,
  }) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": code, "message": message},
      }),
    );
  }

  void _handleIncoming(dynamic raw) {
    if (raw is! String) {
      Log.w("[codex][ws] non-string frame received: ${raw.runtimeType}");
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = decoded.cast<String, dynamic>();
      final id = map["id"];
      final method = map["method"] as String?;

      if (id != null && method == null) {
        // Response to one of our requests.
        final completer = _pending.remove(id);
        if (completer == null) {
          Log.d("[codex][ws] response for unknown id=$id");
          return;
        }
        if (map.containsKey("error")) {
          final err = (map["error"] as Map).cast<String, dynamic>();
          completer.completeError(
            CodexRpcException(
              method: "<response>",
              code: (err["code"] ?? -32603) as int,
              message: (err["message"] ?? "unknown error") as String,
            ),
          );
        } else {
          completer.complete(map["result"]);
        }
        return;
      }

      if (id != null && method != null) {
        // Server-originated request.
        final params = (map["params"] as Map?)?.cast<String, dynamic>() ?? {};
        _serverRequests.add(
          CodexServerRequest(id: id as Object, method: method, params: params),
        );
        return;
      }

      if (method != null) {
        // Notification.
        final params = (map["params"] as Map?)?.cast<String, dynamic>() ?? {};
        _notifications.add(
          CodexServerNotification(method: method, params: params),
        );
        return;
      }

      Log.d("[codex][ws] unrecognised frame: $raw");
    } catch (error, stack) {
      Log.w("[codex][ws] failed to parse frame: $error\n$stack");
    }
  }

  void _handleSocketError(Object error, StackTrace stack) {
    Log.w("[codex][ws] socket error: $error");
    _failPending(error, stack);
  }

  void _handleSocketDone() {
    Log.d("[codex][ws] socket closed");
    _failPending(
      StateError("codex app-server WebSocket closed before reply"),
      StackTrace.current,
    );
  }

  void _failPending(Object error, StackTrace stack) {
    final inflight = List<Completer<dynamic>>.from(_pending.values);
    _pending.clear();
    for (final completer in inflight) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  }

  /// Closes the socket and fails any in-flight requests.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {
        // best-effort close
      }
    }
    _failPending(
      StateError("CodexAppServerClient disposed"),
      StackTrace.current,
    );
    await _notifications.close();
    await _serverRequests.close();
  }
}
