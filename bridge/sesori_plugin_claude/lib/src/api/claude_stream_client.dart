import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "claude_launch_spec.dart";
import "claude_process_factory.dart";
import "models/claude_stream_message.dart";

/// A control request that the CLI answered with a failure, or that could not be
/// delivered at all.
class ClaudeControlException implements Exception {
  ClaudeControlException({required this.subtype, required this.message});

  final String subtype;
  final String message;

  @override
  String toString() => "ClaudeControlException($subtype, $message)";
}

/// Speaks the stream-json protocol to exactly one `claude` process.
///
/// One process serves one session. The process stays alive only while its stdin
/// stays open, so this client owns that pipe for the session's whole residency
/// and closing it is what ends the process.
///
/// The transport mechanics — line framing, connection-generation fencing across
/// teardown, broken-pipe absorption, failing pending requests on exit, and
/// SIGTERM-then-SIGKILL termination — are ported from `AcpStdioClient`, where
/// they are load-bearing.
class ClaudeStreamClient {
  ClaudeStreamClient({
    required ClaudeLaunchSpec launchSpec,
    required ClaudeProcessFactory processFactory,
    Duration controlTimeout = const Duration(seconds: 60),
    String logTag = "claude",
  }) : _launchSpec = launchSpec,
       _processFactory = processFactory,
       _controlTimeout = controlTimeout,
       _logTag = logTag;

  final ClaudeLaunchSpec _launchSpec;
  final ClaudeProcessFactory _processFactory;
  final Duration _controlTimeout;
  final String _logTag;

  ClaudeProcessHandle? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _disposed = false;
  int _nextRequestId = 1;
  int _connectionGeneration = 0;

  final Map<String, Completer<Map<String, Object?>>> _pending = {};
  final StreamController<ClaudeStreamMessage> _messages = StreamController.broadcast();
  Completer<int> _exited = Completer<int>();
  ClaudeInitMessage? _init;
  Map<String, Object?>? _handshake;

  /// Every parsed stdout frame, including unknown ones (broadcast).
  Stream<ClaudeStreamMessage> get messages => _messages.stream;

  /// The `system`/`init` frame, once seen.
  ///
  /// Null until the session's first turn: the CLI emits this frame when a turn
  /// starts, not when the process spawns. Nothing in the connect path may
  /// require it, and capability detection through [ClaudeInitMessage.supports]
  /// is unavailable until a turn has run.
  ClaudeInitMessage? get init => _init;

  /// The `initialize` control response: the command, agent, model, and account
  /// catalog in one payload. Null until [connect] completes.
  Map<String, Object?>? get handshake => _handshake;

  /// Completes with the process's exit code.
  Future<int> get processExit => _exited.future;

  bool get isConnected => _process != null && !_disposed && !_exited.isCompleted;

  /// Spawns the process, wires the framing, and performs the `initialize`
  /// handshake.
  ///
  /// A failed handshake tears the connection down and rethrows rather than
  /// returning a half-live client: the handshake is the only source of the
  /// session's catalog, and continuing without it would surface an empty model
  /// and command list as if the backend genuinely had none.
  Future<void> connect() async {
    if (_process != null) throw StateError("ClaudeStreamClient already connected");
    if (_disposed) throw StateError("ClaudeStreamClient is disposed");

    final generation = ++_connectionGeneration;
    final process = await _processFactory(_launchSpec);
    if (_disposed || generation != _connectionGeneration) {
      // Teardown ran while the spawn was in flight and saw no process to reap.
      // Kill it here rather than leaking it past teardown.
      try {
        process.kill(io.ProcessSignal.sigkill);
      } on Object catch (error, stack) {
        Log.w("[$_logTag] failed to reap process spawned during teardown", error, stack);
      }
      throw StateError(
        _disposed ? "ClaudeStreamClient disposed during connect" : "ClaudeStreamClient reset during connect",
      );
    }
    final exited = Completer<int>();
    _exited = exited;
    _process = process;

    // Broken pipes surface asynchronously on `stdin.done` rather than from
    // `add`, so an unexpected exit would otherwise raise an unhandled async
    // error. The exit itself is logged below.
    unawaited(process.stdin.done.catchError((Object _) {}));

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (generation == _connectionGeneration) _handleLine(line);
          },
          onError: (Object error, StackTrace stack) {
            if (generation != _connectionGeneration) return;
            Log.w("[$_logTag] stdout stream error: ${_redactForLog("$error")}");
            _failPending(error, stack);
          },
          cancelOnError: false,
        );

    _stderrSubscription = process.stderr
        // A crashing child can emit non-UTF-8 bytes on stderr, and a decoder
        // that throws there would take out the diagnostic stream exactly when
        // it matters most.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) => Log.d("[$_logTag][stderr] ${_redactForLog(line)}"),
          onError: (Object error, StackTrace stack) => Log.w("[$_logTag] stderr stream error", error, stack),
          cancelOnError: false,
        );

    unawaited(
      process.exitCode.then((code) {
        if (!exited.isCompleted) exited.complete(code);
        if (generation != _connectionGeneration) return;
        if (!_disposed) Log.w("[$_logTag] process exited with code $code");
        _failPending(
          ClaudeControlException(subtype: "<process>", message: "claude process exited with code $code"),
          StackTrace.current,
        );
      }),
    );

    try {
      _handshake = await sendControlRequest(subtype: "initialize");
    } on Object catch (error, stack) {
      Log.e("[$_logTag] initialize handshake failed", error, stack);
      await _teardownConnection(
        gracefulTimeout: const Duration(seconds: 5),
        pendingError: StateError("ClaudeStreamClient handshake failed"),
      );
      rethrow;
    }
  }

  /// Sends a user turn. Content blocks are built by the caller.
  ///
  /// Throws [ClaudeControlException] when the process has already exited or the
  /// frame cannot be written. Calls after explicit teardown remain a no-op so a
  /// late UI callback cannot revive a disposed session.
  void sendUserMessage({required List<Map<String, Object?>> content}) {
    final process = _process;
    if (process == null) return;
    if (_exited.isCompleted) {
      throw ClaudeControlException(
        subtype: "<user>",
        message: "claude process has exited",
      );
    }
    if (!_writeFrame(process, {
      "type": "user",
      "message": {"role": "user", "content": content},
      "session_id": _launchSpec.launch.sessionId,
    })) {
      throw ClaudeControlException(
        subtype: "<user>",
        message: "failed to write user turn",
      );
    }
  }

  /// Sends a control request and awaits its response payload.
  ///
  /// Throws [ClaudeControlException] when the CLI answers with a failure, when
  /// the frame cannot be written, or when the process has already exited;
  /// [TimeoutException] when no reply arrives.
  Future<Map<String, Object?>> sendControlRequest({
    required String subtype,
    Map<String, Object?> params = const {},
  }) async {
    final process = _process;
    if (process == null) {
      throw ClaudeControlException(subtype: subtype, message: "not connected");
    }
    // The exit handler deliberately leaves _process set, so without this a
    // request issued after the process died would write to a dead pipe and then
    // block for the full timeout awaiting a reply that can never come.
    if (_exited.isCompleted) {
      throw ClaudeControlException(subtype: subtype, message: "claude process has exited");
    }

    final requestId = "sesori-${_nextRequestId++}";
    final completer = Completer<Map<String, Object?>>();
    _pending[requestId] = completer;

    if (!_writeFrame(process, {
      "type": "control_request",
      "request_id": requestId,
      "request": {...params, "subtype": subtype},
    })) {
      // The frame never left the bridge, so no reply is coming. Fail now rather
      // than orphaning the request until it times out.
      _pending.remove(requestId);
      throw ClaudeControlException(subtype: subtype, message: "failed to write control request");
    }

    try {
      return await completer.future.timeout(_controlTimeout);
    } on TimeoutException {
      _pending.remove(requestId);
      rethrow;
    }
  }

  /// Answers a CLI-originated control request, e.g. a `can_use_tool` ask.
  bool sendControlResponse({required String requestId, required Map<String, Object?> payload}) {
    final process = _process;
    if (process == null || _exited.isCompleted) return false;
    return _writeFrame(process, {
      "type": "control_response",
      "response": {"subtype": "success", "request_id": requestId, "response": payload},
    });
  }

  /// Answers a CLI-originated control request with a failure.
  bool sendControlResponseError({required String requestId, required String message}) {
    final process = _process;
    if (process == null || _exited.isCompleted) return false;
    return _writeFrame(process, {
      "type": "control_response",
      "response": {"subtype": "error", "request_id": requestId, "error": message},
    });
  }

  bool _writeFrame(ClaudeProcessHandle process, Map<String, Object?> envelope) {
    try {
      process.stdin.add(utf8.encode("${jsonEncode(envelope)}\n"));
      return true;
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to write frame", error, stack);
      return false;
    }
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on Object catch (error) {
      // A FormatException can embed a snippet of the offending frame.
      Log.w("[$_logTag] failed to parse frame: ${_redactForLog("$error")}");
      return;
    }
    if (decoded is! Map) {
      Log.d("[$_logTag] non-object frame: ${_redactForLog(line)}");
      return;
    }

    final message = ClaudeStreamMessage.parse(decoded.cast<String, Object?>());
    switch (message) {
      case ClaudeInitMessage():
        _init = message;
      case ClaudeControlResponseMessage(:final requestId):
        final completer = requestId == null ? null : _pending.remove(requestId);
        if (completer == null) {
          Log.d("[$_logTag] control response for unknown request_id=$requestId");
        } else if (message.isSuccess) {
          completer.complete(message.payload);
        } else {
          completer.completeError(
            ClaudeControlException(
              subtype: "<response>",
              message: message.error ?? "control request failed",
            ),
          );
        }
      case ClaudeUnknownMessage(:final type, :final subtype):
        // Debug, never a warning per line: the protocol adds message types
        // frequently and a warning would drown the log on a routine upgrade.
        Log.d("[$_logTag] unmodelled frame type=$type subtype=$subtype");
      case ClaudeStatusMessage():
      case ClaudeApiRetryMessage():
      case ClaudeAssistantMessage():
      case ClaudeUserMessage():
      case ClaudeStreamEventMessage():
      case ClaudeResultMessage():
      case ClaudeControlRequestMessage():
      case ClaudeRateLimitMessage():
        break;
    }

    if (!_messages.isClosed) _messages.add(message);
  }

  /// Masks JSON-style secret values before logging a frame. A best-effort
  /// string scrub rather than a JSON re-encode, so a partial or non-JSON frame
  /// is still redacted.
  static final RegExp _secretKeyValue = RegExp(
    r'("(?:token|authorization|api[_-]?key|secret|password|bearer)"\s*:\s*)"(?:\\.|[^"\\])*"',
    caseSensitive: false,
  );

  String _redactForLog(String frame) => frame.replaceAllMapped(_secretKeyValue, (m) => '${m.group(1)}"***"');

  void _failPending(Object error, StackTrace stack) {
    final inflight = List<Completer<Map<String, Object?>>>.from(_pending.values);
    _pending.clear();
    for (final completer in inflight) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  }

  /// Terminates the process, fails in-flight requests, and closes the stream.
  Future<void> dispose({Duration gracefulTimeout = const Duration(seconds: 5)}) async {
    if (_disposed) return;
    _disposed = true;
    await _teardownConnection(
      gracefulTimeout: gracefulTimeout,
      pendingError: StateError("ClaudeStreamClient disposed"),
    );
    try {
      await _messages.close();
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to close message stream", error, stack);
    }
  }

  Future<void> _teardownConnection({
    required Duration gracefulTimeout,
    required Object pendingError,
  }) async {
    // Invalidate callbacks before the first await so a late frame from this
    // process cannot affect a connection established afterwards.
    _connectionGeneration++;
    final process = _process;
    _process = null;

    Future<void>? stdoutCancellation;
    try {
      stdoutCancellation = _stdoutSubscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to cancel stdout subscription", error, stack);
    }
    _stdoutSubscription = null;

    Future<void>? stderrCancellation;
    try {
      stderrCancellation = _stderrSubscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to cancel stderr subscription", error, stack);
    }
    _stderrSubscription = null;

    _failPending(pendingError, StackTrace.current);

    if (process != null) {
      try {
        // Closing stdin is the protocol's own shutdown signal, so try it before
        // signalling. A broken pipe here is expected and already absorbed.
        await process.stdin.close().timeout(gracefulTimeout);
      } on Object catch (error, stack) {
        Log.w("[$_logTag] closing stdin during teardown failed", error, stack);
      }
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
      } on Object catch (error, stack) {
        Log.w("[$_logTag] failed to stop process during teardown", error, stack);
      }
    }

    // Isolate each step so one failure does not skip the rest.
    try {
      await stdoutCancellation;
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to cancel stdout subscription", error, stack);
    }
    try {
      await stderrCancellation;
    } on Object catch (error, stack) {
      Log.w("[$_logTag] failed to cancel stderr subscription", error, stack);
    }
  }
}
