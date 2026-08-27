import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "acp_process_factory.dart";

class AcpRpcException({
  required final String method,
  required final int code,
  required final String message,
  final Object? data,
}) implements Exception {
  @override
  String toString() => "AcpRpcException($method, code=$code, $message)";
}

class const AcpNotification({required final String method, required final Map<String, dynamic> params}) {
  @override
  String toString() => "AcpNotification($method)";
}

class const AcpServerRequest({
  required final Object id,
  required final String method,
  required final Map<String, dynamic> params,
});

class AcpStdioClient({
  required final AcpLaunchSpec _launchSpec,
  required final AcpProcessFactory _processFactory,
  final String _logTag = "acp",
}) {
  late final NdjsonProcessClient _transport = NdjsonProcessClient(
    responseCorrelationId: (frame) => frame["method"] == null ? frame["id"] : null,
    exitError: (code) => AcpRpcException(
      method: "<process>",
      code: -32000,
      message: "agent process exited with code $code",
    ),
    malformedFramePolicy: MalformedFramePolicy.discard,
    nonObjectFramePolicy: NonObjectFramePolicy.discard,
    malformedFrameLogPolicy: MalformedFrameLogPolicy.metadataOnly,
    stderrPolicy: StderrPolicy.forwardSanitized,
    sanitizeForLog: (line) => line,
    logTag: _logTag,
    reapTimeout: const Duration(seconds: 5),
  );
  final StreamController<AcpNotification> _notifications = StreamController.broadcast();
  final StreamController<AcpServerRequest> _serverRequests = StreamController.broadcast();
  StreamSubscription<JsonObject>? _frames;
  bool _disposed = false;
  int _nextId = 1;

  String get logTag => _logTag;
  Stream<AcpNotification> get notifications => _notifications.stream;
  Stream<AcpServerRequest> get serverRequests => _serverRequests.stream;
  Future<int> get processExit => _transport.exit;
  bool get isConnected => _transport.isAttached;

  Future<void> connect() async {
    if (_disposed) throw StateError("AcpStdioClient is disposed");
    final token = _transport.beginAttach();
    final process = await _processFactory(_launchSpec);
    await _transport.attach(token: token, process: _AcpProcessHandle(process));
    await _frames?.cancel();
    _frames = _transport.notifications.listen(_handleFrame);
  }

  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final dispatched = await dispatchRequest(method: method, params: params, timeout: timeout);
    return await dispatched.response;
  }

  Future<({Future<dynamic> response})> dispatchRequest({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final id = _nextId++;
    final frame = <String, Object?>{"jsonrpc": "2.0", "id": id, "method": method};
    if (params != null) frame["params"] = params;
    final dispatched = await _transport.dispatch(id: id, frame: frame, timeout: timeout);
    final response = _mapResponse(dispatched.response);
    response.ignore();
    return (response: response);
  }

  Future<dynamic> _mapResponse(Future<JsonObject> response) async {
    final frame = await response;
    if (frame.containsKey("error")) {
      final rawError = frame["error"];
      final error = rawError is Map ? rawError : null;
      final code = error?["code"];
      final message = error?["message"];
      throw AcpRpcException(
        method: "<response>",
        code: code is int ? code : -32603,
        message: message is String ? message : "unknown error",
        data: error?["data"],
      );
    }
    return frame["result"];
  }

  void notify({required String method, Object? params}) {
    final frame = <String, Object?>{"jsonrpc": "2.0", "method": method};
    if (params != null) frame["params"] = params;
    _sendFrame(frame);
  }

  void respondToServerRequest({required Object id, required Object? result}) {
    _sendFrame({"jsonrpc": "2.0", "id": id, "result": result});
  }

  void respondToServerRequestWithError({required Object id, required int code, required String message}) {
    _sendFrame({
      "jsonrpc": "2.0",
      "id": id,
      "error": {"code": code, "message": message},
    });
  }

  void _sendFrame(JsonObject frame) {
    if (!_transport.isAttached) return;
    try {
      _transport.sendFrame(frame: frame);
    } on Object catch (error, stackTrace) {
      Log.w("[$_logTag] failed to write frame", error, stackTrace);
    }
  }

  void _handleFrame(JsonObject frame) {
    final id = frame["id"];
    final method = frame["method"];
    if (method is! String) {
      Log.d("[$_logTag] unrecognised frame");
      return;
    }
    final rawParams = frame["params"];
    final params = rawParams is Map ? Map<String, dynamic>.from(rawParams) : <String, dynamic>{};
    if (id != null) {
      _serverRequests.add(AcpServerRequest(id: id, method: method, params: params));
    } else {
      _notifications.add(AcpNotification(method: method, params: params));
    }
  }

  Future<void> reset({required Duration gracefulTimeout}) async {
    if (_disposed) return;
    await _frames?.cancel();
    _frames = null;
    await _transport.reset(reason: StateError("AcpStdioClient reset"), gracefulTimeout: gracefulTimeout);
  }

  Future<void> dispose({Duration gracefulTimeout = const Duration(seconds: 5)}) async {
    if (_disposed) return;
    _disposed = true;
    await _frames?.cancel();
    _frames = null;
    await _transport.dispose(reason: StateError("AcpStdioClient disposed"), gracefulTimeout: gracefulTimeout);
    await _notifications.close();
    await _serverRequests.close();
  }
}

final class _AcpProcessHandle(final AcpProcessHandle process) implements NdjsonProcessHandle {
  @override
  io.IOSink get stdin => process.stdin;
  @override
  Stream<String> get stdoutLines => process.stdout.transform(utf8.decoder).transform(const LineSplitter());
  @override
  Stream<String> get stderrLines => process.stderr.transform(utf8.decoder).transform(const LineSplitter());
  @override
  Future<int> get done => process.exitCode;
  @override
  Future<void> kill({required bool force}) async {
    process.kill(force ? io.ProcessSignal.sigkill : io.ProcessSignal.sigterm);
  }
}
