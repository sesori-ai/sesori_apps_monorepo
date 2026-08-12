import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "codex_app_server_client.dart";

final class const _PendingRequest({required this.method, required this.completer}) {
  final String method;
  final Completer<dynamic> completer;
}

/// JSONL transport for a short-lived `codex app-server` stdio connection.
class CodexStdioAppServerClient({
    required HostProcessService processes,
    required String executable,
    required Map<String, String> environment,
    required Duration shutdownTimeout,
  }) implements CodexAppServerTransport {
  this : _processes = processes,
       _executable = executable,
       _environment = Map<String, String>.unmodifiable(environment),
       _shutdownTimeout = shutdownTimeout;

  final HostProcessService _processes;
  final String _executable;
  final Map<String, String> _environment;
  final Duration _shutdownTimeout;

  SpawnedProcess? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  Completer<int> _exited = Completer<int>();
  final Map<Object, _PendingRequest> _pending = <Object, _PendingRequest>{};
  final StreamController<CodexServerNotification> _notifications = StreamController.broadcast();
  final StreamController<CodexServerRequest> _serverRequests = StreamController.broadcast();
  int _nextId = 1;
  int _connectionGeneration = 0;
  bool _disposed = false;

  @override
  Stream<CodexServerNotification> get notifications => _notifications.stream;

  Stream<CodexServerRequest> get serverRequests => _serverRequests.stream;

  Future<int> get processExit => _exited.future;

  Future<CodexInitializeResult> connect({
    required String clientName,
    required String clientVersion,
    required Duration timeout,
  }) async {
    if (_process != null) {
      throw StateError("CodexStdioAppServerClient already connected");
    }
    if (_disposed) {
      throw StateError("CodexStdioAppServerClient is disposed");
    }

    final generation = ++_connectionGeneration;
    final process = await _processes.spawn(
      executable: _executable,
      arguments: const ["app-server", "--listen", "stdio://"],
      environment: _environment,
      workingDirectory: null,
      runInShell: io.Platform.isWindows,
    );
    if (_disposed || generation != _connectionGeneration) {
      await _reapLateProcess(process);
      throw StateError("CodexStdioAppServerClient disposed during connect");
    }

    _process = process;
    _exited = Completer<int>();
    unawaited(process.stdin.done.catchError((Object _) {}));
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (generation == _connectionGeneration) _handleLine(line);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (generation == _connectionGeneration) {
              Log.w("[codex][stdio] stdout stream failed", error, stackTrace);
              _failPending(error, stackTrace);
            }
          },
          cancelOnError: false,
        );
    // Stderr can include upstream account diagnostics. Drain it without
    // retaining or logging its contents.
    _stderrSubscription = process.stderr.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) => Log.w("[codex][stdio] stderr stream failed", error, stackTrace),
      cancelOnError: false,
    );
    unawaited(
      process.exitCode.then(
        (code) => _handleExit(generation: generation, code: code),
        onError: (Object error, StackTrace stackTrace) {
          if (generation != _connectionGeneration) return;
          if (!_exited.isCompleted) _exited.completeError(error, stackTrace);
          _failPending(error, stackTrace);
        },
      ),
    );

    try {
      final raw = await request(
        method: "initialize",
        params: {
          "clientInfo": {
            "name": clientName,
            "title": "Sesori Bridge",
            "version": clientVersion,
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
      final result = CodexInitializeResult.fromJson(
        raw.cast<String, dynamic>(),
      );
      _notify(method: "initialized");
      return result;
    } on Object {
      await _teardownConnection(
        pendingError: StateError("Codex stdio initialization failed"),
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
    final process = _process;
    if (process == null || _exited.isCompleted) {
      throw StateError("CodexStdioAppServerClient is not connected");
    }
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = _PendingRequest(method: method, completer: completer);
    final envelope = <String, dynamic>{"id": id, "method": method};
    if (params != null) envelope["params"] = params;
    if (!_writeFrame(process: process, envelope: envelope)) {
      _pending.remove(id);
      throw StateError("CodexStdioAppServerClient failed to write $method request");
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      rethrow;
    }
  }

  void _notify({required String method, Object? params}) {
    final process = _process;
    if (process == null || _exited.isCompleted) return;
    final envelope = <String, dynamic>{"method": method};
    if (params != null) envelope["params"] = params;
    _writeFrame(process: process, envelope: envelope);
  }

  bool _writeFrame({
    required SpawnedProcess process,
    required Map<String, dynamic> envelope,
  }) {
    try {
      process.stdin.add(utf8.encode("${jsonEncode(envelope)}\n"));
      return true;
    } on Object catch (error, stackTrace) {
      Log.w("[codex][stdio] failed to write protocol frame", error, stackTrace);
      return false;
    }
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on Object {
      final error = StateError("Codex App Server returned malformed JSON");
      Log.w("[codex][stdio] ignored malformed stdout frame");
      _failPending(error, StackTrace.current);
      return;
    }
    if (decoded is! Map) {
      Log.w("[codex][stdio] ignored non-object stdout frame");
      return;
    }
    final map = decoded.cast<String, dynamic>();
    final id = map["id"];
    final method = map["method"];
    if (id != null && method == null) {
      final pending = _pending.remove(id);
      if (pending == null) {
        Log.d("[codex][stdio] ignored response for unknown request id");
        return;
      }
      final rawError = map["error"];
      if (map.containsKey("error")) {
        final error = rawError is Map ? rawError.cast<String, dynamic>() : null;
        final code = error?["code"];
        final message = error?["message"];
        pending.completer.completeError(
          CodexRpcException(
            method: pending.method,
            code: code is int ? code : -32603,
            message: message is String ? message : "unknown error",
          ),
        );
      } else {
        final Object? result = map["result"];
        pending.completer.complete(result);
      }
      return;
    }
    if (method is! String) {
      Log.d("[codex][stdio] ignored unrecognized stdout frame");
      return;
    }
    final rawParams = map["params"];
    final params = rawParams is Map ? rawParams.cast<String, dynamic>() : <String, dynamic>{};
    if (id != null) {
      _serverRequests.add(
        CodexServerRequest(id: id as Object, method: method, params: params),
      );
    } else {
      _notifications.add(
        CodexServerNotification(method: method, params: params),
      );
    }
  }

  void _handleExit({required int generation, required int code}) {
    if (generation != _connectionGeneration) return;
    if (!_exited.isCompleted) _exited.complete(code);
    _failPending(
      StateError("Codex App Server process exited before replying"),
      StackTrace.current,
    );
    if (!_disposed) {
      Log.w("[codex][stdio] app-server process exited with code $code");
    }
  }

  void _failPending(Object error, StackTrace stackTrace) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final request in pending) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(error, stackTrace);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardownConnection(
      pendingError: StateError("CodexStdioAppServerClient disposed"),
    );
    try {
      await _notifications.close();
    } on Object catch (error, stackTrace) {
      Log.w("[codex][stdio] failed to close notifications", error, stackTrace);
    }
    try {
      await _serverRequests.close();
    } on Object catch (error, stackTrace) {
      Log.w("[codex][stdio] failed to close server requests", error, stackTrace);
    }
  }

  Future<void> _teardownConnection({required Object pendingError}) async {
    _connectionGeneration++;
    final process = _process;
    _process = null;
    _failPending(pendingError, StackTrace.current);

    if (process != null) {
      try {
        await process.stdin.close().timeout(_shutdownTimeout);
      } on Object catch (error, stackTrace) {
        Log.w("[codex][stdio] failed to close app-server stdin", error, stackTrace);
      }
      if (!await _waitForExit(process)) {
        try {
          await _processes.signalGraceful(pid: process.pid);
        } on Object catch (error, stackTrace) {
          Log.w("[codex][stdio] failed to stop app-server gracefully", error, stackTrace);
        }
        if (!await _waitForExit(process)) {
          try {
            await _processes.signalForce(pid: process.pid);
          } on Object catch (error, stackTrace) {
            Log.w("[codex][stdio] failed to force-stop app-server", error, stackTrace);
          }
          await _waitForExit(process);
        }
      }
    }

    try {
      await _stdoutSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex][stdio] failed to cancel stdout subscription",
        error,
        stackTrace,
      );
    }
    _stdoutSubscription = null;
    try {
      await _stderrSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex][stdio] failed to cancel stderr subscription",
        error,
        stackTrace,
      );
    }
    _stderrSubscription = null;
  }

  Future<bool> _waitForExit(SpawnedProcess process) async {
    try {
      await process.exitCode.timeout(_shutdownTimeout);
      return true;
    } on TimeoutException {
      return false;
    } on Object catch (error, stackTrace) {
      Log.w("[codex][stdio] failed while awaiting app-server exit", error, stackTrace);
      return true;
    }
  }

  Future<void> _reapLateProcess(SpawnedProcess process) async {
    try {
      await _processes.signalForce(pid: process.pid);
      await process.exitCode.timeout(_shutdownTimeout);
    } on Object catch (error, stackTrace) {
      Log.w("[codex][stdio] failed to reap process spawned during teardown", error, stackTrace);
    }
  }
}
