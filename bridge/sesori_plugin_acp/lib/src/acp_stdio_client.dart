import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "acp_process_factory.dart";

/// A JSON-RPC error returned by an ACP agent.
class AcpRpcException implements Exception {
  AcpRpcException({
    required this.method,
    required this.code,
    required this.message,
    this.data,
  });

  final String method;
  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => "AcpRpcException($method, code=$code, $message)";
}

/// A server-originated notification (no `id`), e.g. `session/update`.
class AcpNotification {
  const AcpNotification({required this.method, required this.params});

  final String method;
  final Map<String, dynamic> params;

  @override
  String toString() => "AcpNotification($method)";
}

/// A server-originated request that expects a response, e.g.
/// `session/request_permission` or Cursor's `cursor/ask_question`.
class AcpServerRequest {
  const AcpServerRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  /// JSON-RPC `id` — echo this when responding.
  final Object id;
  final String method;
  final Map<String, dynamic> params;
}

/// JSON-RPC 2.0 client for an ACP agent spoken over the agent process's
/// stdin/stdout, framed as newline-delimited JSON (ndjson): one JSON-RPC
/// message per `\n`, no embedded newlines (ACP transport spec).
///
/// Mirrors the public surface of codex's `CodexAppServerClient` (WebSocket)
/// so the event mapper, approval registry and plugin port across with minimal
/// change. The differences are that this client owns a real subprocess: it
/// spawns on [connect], reaps on [dispose], and can send id-less
/// notifications ([notify], e.g. `session/cancel`) which the WebSocket client
/// never needed.
class AcpStdioClient {
  AcpStdioClient({
    required AcpLaunchSpec launchSpec,
    AcpProcessFactory? processFactory,
    String logTag = "acp",
  }) : _launchSpec = launchSpec,
       _processFactory = processFactory ?? defaultAcpProcessFactory,
       _logTag = logTag;

  final AcpLaunchSpec _launchSpec;
  final AcpProcessFactory _processFactory;
  final String _logTag;

  AcpProcessHandle? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _disposed = false;
  int _nextId = 1;

  final Map<Object, Completer<dynamic>> _pending = {};
  final StreamController<AcpNotification> _notifications =
      StreamController.broadcast();
  final StreamController<AcpServerRequest> _serverRequests =
      StreamController.broadcast();
  final Completer<int> _exited = Completer<int>();

  /// Server-originated notifications (broadcast).
  Stream<AcpNotification> get notifications => _notifications.stream;

  /// Server-originated requests that expect a response (broadcast).
  Stream<AcpServerRequest> get serverRequests => _serverRequests.stream;

  /// Completes with the agent process's exit code when it terminates.
  Future<int> get processExit => _exited.future;

  // The exit handler deliberately does not clear _process (see [request]), so
  // _exited must be consulted too — otherwise a dead client still reports live.
  bool get isConnected => _process != null && !_disposed && !_exited.isCompleted;

  /// Spawns the agent process and wires the stdio framing.
  ///
  /// Does NOT perform the ACP `initialize` handshake — that is protocol-level
  /// and carries harness-specific capabilities, so the plugin issues it via
  /// [request] after `connect`. Idempotent only in the failure path.
  Future<void> connect() async {
    if (_process != null) {
      throw StateError("AcpStdioClient already connected");
    }
    if (_disposed) {
      throw StateError("AcpStdioClient is disposed");
    }

    final process = await _processFactory(_launchSpec);
    _process = process;

    // Writes to stdin surface broken-pipe errors asynchronously on `stdin.done`
    // (not synchronously from `add`), so an unexpected agent exit would
    // otherwise raise an unhandled async error. Observe and drop it here — the
    // process exit is already logged via [exitCode] below.
    unawaited(process.stdin.done.catchError((Object _) {}));

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onError: _handleStreamError,
          cancelOnError: false,
        );

    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => Log.d("[$_logTag][stderr] $line"),
          onError: (Object error, StackTrace stack) =>
              Log.w("[$_logTag] stderr stream error: $error", error, stack),
          cancelOnError: false,
        );

    unawaited(
      process.exitCode.then((code) {
        if (!_exited.isCompleted) _exited.complete(code);
        if (!_disposed) {
          Log.w("[$_logTag] agent process exited with code $code");
        }
        _failPending(
          AcpRpcException(
            method: "<process>",
            code: -32000,
            message: "agent process exited with code $code",
          ),
          StackTrace.current,
        );
      }),
    );
  }

  /// Send a JSON-RPC request and await its response.
  ///
  /// Throws [AcpRpcException] on error responses, [TimeoutException] on
  /// timeout, [StateError] if not connected or the agent process has exited.
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final process = _process;
    if (process == null) {
      throw StateError("AcpStdioClient not connected");
    }
    // The exit handler does not clear _process, so without this a request issued
    // after the agent died would write to a dead pipe and then block for the
    // full timeout (up to 30 min for a prompt) waiting for a reply that can
    // never come. Fail fast instead.
    if (_exited.isCompleted) {
      throw StateError("AcpStdioClient agent process has exited");
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
    if (!_writeFrame(process, envelope)) {
      // The frame never left the bridge, so no reply will ever come — fail the
      // request now instead of letting it orphan in _pending until the timeout.
      _pending.remove(id);
      throw StateError("AcpStdioClient failed to write request frame for $method");
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      rethrow;
    }
  }

  /// Send a JSON-RPC notification (no `id`, no response), e.g.
  /// `session/cancel`.
  void notify({required String method, Object? params}) {
    final process = _process;
    if (process == null) return;
    final envelope = <String, dynamic>{"jsonrpc": "2.0", "method": method};
    if (params != null) envelope["params"] = params;
    _writeFrame(process, envelope);
  }

  /// Reply to an [AcpServerRequest] with a result payload.
  void respondToServerRequest({required Object id, required Object? result}) {
    final process = _process;
    if (process == null) return;
    _writeFrame(process, {"jsonrpc": "2.0", "id": id, "result": result});
  }

  /// Reply to an [AcpServerRequest] with a JSON-RPC error.
  void respondToServerRequestWithError({
    required Object id,
    required int code,
    required String message,
  }) {
    final process = _process;
    if (process == null) return;
    _writeFrame(process, {
      "jsonrpc": "2.0",
      "id": id,
      "error": {"code": code, "message": message},
    });
  }

  /// Writes one ndjson frame. Returns whether the write was accepted; callers
  /// awaiting a reply (see [request]) use this to fail fast instead of orphaning
  /// a pending request when the frame could not be sent.
  bool _writeFrame(AcpProcessHandle process, Map<String, dynamic> envelope) {
    try {
      process.stdin.add(utf8.encode("${jsonEncode(envelope)}\n"));
      return true;
    } catch (error, stack) {
      Log.w("[$_logTag] failed to write frame", error, stack);
      return false;
    }
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return;
      final map = decoded.cast<String, dynamic>();
      final id = map["id"];
      final method = map["method"] as String?;

      if (id != null && method == null) {
        // Response to one of our requests.
        final completer = _pending.remove(id);
        if (completer == null) {
          Log.d("[$_logTag] response for unknown id=$id");
          return;
        }
        if (map.containsKey("error")) {
          // Parse defensively: a malformed `error` member (not a map, or a
          // non-int code / non-string message) must still complete the pending
          // completer, or the awaiting request orphans until it times out.
          final rawErr = map["error"];
          final err = rawErr is Map ? rawErr.cast<String, dynamic>() : null;
          final code = err?["code"];
          final message = err?["message"];
          completer.completeError(
            AcpRpcException(
              method: "<response>",
              code: code is int ? code : -32603,
              message: message is String ? message : "unknown error",
              data: err?["data"],
            ),
          );
        } else {
          completer.complete(map["result"]);
        }
        return;
      }

      if (id != null && method != null) {
        // Server-originated request. Guard the cast: a malformed payload or
        // positional (List) params must not throw and drop the whole frame.
        final rawParams = map["params"];
        final params = rawParams is Map ? rawParams.cast<String, dynamic>() : <String, dynamic>{};
        _serverRequests.add(
          AcpServerRequest(id: id as Object, method: method, params: params),
        );
        return;
      }

      if (method != null) {
        // Notification. Same defensive params handling as the request branch.
        final rawParams = map["params"];
        final params = rawParams is Map ? rawParams.cast<String, dynamic>() : <String, dynamic>{};
        _notifications.add(AcpNotification(method: method, params: params));
        return;
      }

      Log.d("[$_logTag] unrecognised frame: $line");
    } catch (error, stack) {
      Log.w("[$_logTag] failed to parse frame: $error\n$stack");
    }
  }

  void _handleStreamError(Object error, StackTrace stack) {
    Log.w("[$_logTag] stdout stream error: $error");
    _failPending(error, stack);
  }

  void _failPending(Object error, StackTrace stack) {
    final inflight = List<Completer<dynamic>>.from(_pending.values);
    _pending.clear();
    for (final completer in inflight) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  }

  /// Kills the agent process, fails in-flight requests, and closes streams.
  Future<void> dispose({
    Duration gracefulTimeout = const Duration(seconds: 5),
  }) async {
    if (_disposed) return;
    _disposed = true;

    final process = _process;
    _process = null;
    if (process != null) {
      try {
        if (io.Platform.isWindows) {
          process.kill(io.ProcessSignal.sigkill);
        } else {
          process.kill(io.ProcessSignal.sigterm);
          try {
            await process.exitCode.timeout(gracefulTimeout);
          } on TimeoutException {
            process.kill(io.ProcessSignal.sigkill);
          }
        }
      } catch (_) {
        // Process may already be dead.
      }
    }

    // Isolate each teardown step so a failure in one does not skip the rest
    // (notably _failPending, which unblocks callers awaiting in-flight
    // requests). dispose() must not throw — log and continue.
    try {
      await _stdoutSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[$_logTag] failed to cancel stdout subscription", e, st);
    }
    try {
      await _stderrSubscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[$_logTag] failed to cancel stderr subscription", e, st);
    }
    _failPending(
      StateError("AcpStdioClient disposed"),
      StackTrace.current,
    );
    try {
      await _notifications.close();
    } on Object catch (e, st) {
      Log.w("[$_logTag] failed to close notifications stream", e, st);
    }
    try {
      await _serverRequests.close();
    } on Object catch (e, st) {
      Log.w("[$_logTag] failed to close server-requests stream", e, st);
    }
  }
}
