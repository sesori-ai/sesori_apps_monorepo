import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "codex_app_server_client.dart";

/// JSONL transport for a short-lived `codex app-server` stdio connection.
class CodexStdioAppServerClient({
  required final HostProcessService _processes,
  required final String _executable,
  required Map<String, String> environment,
  required final Duration _shutdownTimeout,
}) implements CodexAppServerTransport {
  final Map<String, String> _environment = Map<String, String>.unmodifiable(environment);
  late final NdjsonProcessClient _transport = NdjsonProcessClient(
    responseCorrelationId: (frame) => frame["method"] == null ? frame["id"] : null,
    exitError: (_) => StateError("Codex App Server process exited before replying"),
    malformedFramePolicy: MalformedFramePolicy.failPending,
    nonObjectFramePolicy: NonObjectFramePolicy.discard,
    malformedFrameLogPolicy: MalformedFrameLogPolicy.metadataOnly,
    stderrPolicy: StderrPolicy.discard,
    sanitizeForLog: (_) => "<redacted>",
    logTag: "codex][stdio",
    reapTimeout: _shutdownTimeout,
  );
  final StreamController<CodexServerNotification> _notifications = StreamController.broadcast();
  final StreamController<CodexServerRequest> _serverRequests = StreamController.broadcast();
  StreamSubscription<Map<String, dynamic>>? _frames;
  int _nextId = 1;
  bool _disposed = false;

  @override
  Stream<CodexServerNotification> get notifications => _notifications.stream;
  Stream<CodexServerRequest> get serverRequests => _serverRequests.stream;
  Future<int> get processExit => _transport.exit;

  Future<CodexInitializeResult> connect({
    required String clientName,
    required String clientVersion,
    required Duration timeout,
  }) async {
    if (_disposed) throw StateError("CodexStdioAppServerClient is disposed");
    final token = _transport.beginAttach();
    final process = await _processes.spawn(
      executable: _executable,
      arguments: const ["app-server", "--listen", "stdio://"],
      environment: _environment,
      workingDirectory: null,
      runInShell: io.Platform.isWindows,
    );
    await _transport.attach(
      token: token,
      process: _CodexProcessHandle(process: process, processes: _processes),
    );
    await _frames?.cancel();
    _frames = _transport.notifications.listen(_handleFrame);
    try {
      final raw = await request(
        method: "initialize",
        params: {
          "clientInfo": {"name": clientName, "title": "Sesori Bridge", "version": clientVersion},
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
      final result = CodexInitializeResult.fromJson(raw.cast<String, dynamic>());
      _notify(method: "initialized");
      return result;
    } on Object {
      await _transport.reset(
        reason: StateError("Codex stdio initialization failed"),
        gracefulTimeout: _shutdownTimeout,
      );
      rethrow;
    }
  }

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final id = _nextId++;
    final frame = <String, dynamic>{"id": id, "method": method};
    if (params != null) frame["params"] = params;
    final response = await _transport.request(id: id, frame: frame, timeout: timeout);
    if (response.containsKey("error")) {
      final rawError = response["error"];
      final error = rawError is Map ? rawError.cast<String, dynamic>() : null;
      final code = error?["code"];
      final message = error?["message"];
      throw CodexRpcException(
        method: method,
        code: code is int ? code : -32603,
        message: message is String ? message : "unknown error",
      );
    }
    return response["result"];
  }

  void _notify({required String method, Object? params}) {
    final frame = <String, dynamic>{"method": method};
    if (params != null) frame["params"] = params;
    _transport.sendFrame(frame: frame);
  }

  void _handleFrame(Map<String, dynamic> frame) {
    final method = frame["method"];
    if (method is! String) {
      Log.d("[codex][stdio] ignored unrecognized stdout frame");
      return;
    }
    final rawParams = frame["params"];
    final params = rawParams is Map ? rawParams.cast<String, dynamic>() : <String, dynamic>{};
    final id = frame["id"];
    if (id != null) {
      _serverRequests.add(CodexServerRequest(id: id as Object, method: method, params: params));
    } else {
      _notifications.add(CodexServerNotification(method: method, params: params));
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _transport.dispose(
      reason: StateError("CodexStdioAppServerClient disposed"),
      gracefulTimeout: _shutdownTimeout,
    );
    await _frames?.cancel();
    await _notifications.close();
    await _serverRequests.close();
  }
}

final class _CodexProcessHandle({required final SpawnedProcess process, required final HostProcessService processes})
    implements NdjsonProcessHandle {
  @override
  io.IOSink get stdin => process.stdin;
  @override
  Stream<String> get stdoutLines => process.stdout.transform(utf8.decoder).transform(const LineSplitter());
  @override
  Stream<String> get stderrLines => process.stderr.transform(const Utf8Decoder(allowMalformed: true));
  @override
  Future<int> get done => process.exitCode;
  @override
  Future<void> kill({required bool force}) =>
      force ? processes.signalForce(pid: process.pid) : processes.signalGraceful(pid: process.pid);
}
