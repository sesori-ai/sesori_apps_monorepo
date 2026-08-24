import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/pi_rpc_command.dart";
import "models/pi_extension_ui_request.dart";
import "models/pi_rpc_frame.dart";
import "pi_launch_spec.dart";
import "pi_process_factory.dart";

/// A typed Pi RPC transport failure.
sealed class const PiRpcException() implements Exception;

/// Pi rejected a command with untyped prose.
final class const PiRpcCommandFailureException({required final PiRpcCommand command, required final String error})
    extends PiRpcException {
  @override
  String toString() => "PiRpcCommandFailureException(command: ${command.wireValue})";
}

/// A command could not be written to Pi's stdin.
final class const PiRpcWriteException({required final PiRpcCommand command, required final Object cause})
    extends PiRpcException {
  @override
  String toString() => "PiRpcWriteException(command: ${command.wireValue})";
}

/// Pi's stdout stream failed before the process exited.
final class const PiRpcStdoutException({required final Object cause}) extends PiRpcException {
  @override
  String toString() => "PiRpcStdoutException";
}

/// Pi's stdin failed asynchronously after accepting a write.
final class const PiRpcStdinException({required final Object cause}) extends PiRpcException {
  @override
  String toString() => "PiRpcStdinException";
}

/// The Pi process exited.
final class const PiRpcProcessExitException({required final int exitCode}) extends PiRpcException {
  @override
  String toString() => "PiRpcProcessExitException(exitCode: $exitCode)";
}

/// A command was sent before a Pi process was started.
final class const PiRpcNotRunningException({required final PiRpcCommand command}) extends PiRpcException {
  @override
  String toString() => "PiRpcNotRunningException(command: ${command.wireValue})";
}

/// The transport was disposed while work was pending.
final class const PiRpcDisposedException() extends PiRpcException {
  @override
  String toString() => "PiRpcDisposedException";
}

/// What Sesori answers a blocking Pi extension dialog with.
sealed class const PiExtensionUiReply() {
  Map<String, Object?> get fields;
}

/// Answers a `select`, `input`, or `editor` dialog.
final class const PiExtensionUiValueReply({required final String value}) extends PiExtensionUiReply {
  @override
  Map<String, Object?> get fields => {"value": value};
}

/// Answers a `confirm` dialog.
final class const PiExtensionUiConfirmationReply({required final bool confirmed}) extends PiExtensionUiReply {
  @override
  Map<String, Object?> get fields => {"confirmed": confirmed};
}

/// Dismisses any dialog without a value.
final class const PiExtensionUiCancelledReply() extends PiExtensionUiReply {
  @override
  Map<String, Object?> get fields => const {"cancelled": true};
}

/// Speaks Pi's JSONL RPC protocol to exactly one child process.
///
/// One process serves one session. Pi has no handshake and no protocol
/// version, so [start] only spawns and wires the pipes; the caller decides what
/// to ask for.
///
/// Framing is strict: records are separated by LF only, one trailing CR is
/// removed to tolerate CRLF input, and a bare CR, U+2028, or U+2029 inside a
/// JSON string stays part of the record. Splitting on those would corrupt any
/// frame carrying such text.
///
/// Pi applies stdout backpressure to its own agent, so both pipes are drained
/// unconditionally from the moment the process starts, including for frames
/// nothing consumes.
///
/// No prompt, transcript, tool, dialog, or raw frame content is ever logged.
class PiRpcClient({
  required final PiLaunchSpec _launchSpec,
  required final PiProcessFactory _processFactory,
}) {
  static const String noModelsDiagnosticPrefix =
      "No models available. Use /login to log into a provider via OAuth or API key. See:";

  /// How many parsed frames are held while no router has attached yet.
  ///
  /// Pi streams continuously, so an unbounded startup buffer would grow with
  /// the run. The cap is far above the handful of frames a launch produces.
  static const int _startupFrameLimit = 512;

  /// How many redacted stderr lines are retained for failure diagnosis.
  static const int _stderrTailLimit = 20;

  /// Longest retained stderr line. A crashing runtime can emit very long lines.
  static const int _stderrLineLimit = 500;

  PiProcessHandle? _process;
  Future<void>? _starting;
  Future<void>? _disposing;
  _PiTeardownDeadline? _teardownDeadline;
  bool _disposed = false;
  int _nextRequestId = 1;
  int _generation = 0;
  bool _attached = false;
  bool _droppedStartupFrames = false;
  int? _exitCode;

  final Map<String, ({PiRpcCommand command, Completer<PiSuccessResponseFrame> completer})> _pending = {};
  final List<PiRpcFrame> _startupFrames = [];
  final List<String> _stderrTail = [];
  final Completer<int> _exited = Completer<int>();

  late final StreamController<PiRpcFrame> _frames = StreamController<PiRpcFrame>.broadcast(
    onListen: _flushStartupFrames,
  );

  /// Every parsed stdout frame, including unknown ones.
  ///
  /// Frames parsed before the first listener attaches are buffered and replayed
  /// on attachment, so a session started by a launch does not lose the events
  /// Pi emits while the router is still being wired.
  Stream<PiRpcFrame> get frames => _frames.stream;

  /// Completes with the process's exit code.
  Future<int> get processExit => _exited.future;

  bool get isRunning => _process != null && !_disposed && !_exited.isCompleted;

  /// The most recent redacted stderr lines, oldest first.
  ///
  /// Bounded because stderr is diagnostic only: a verbose or crashing Pi must
  /// never let it grow with the run.
  List<String> get stderrDiagnostics => List.unmodifiable(_stderrTail);

  /// Spawns the process and installs the stdout/stderr consumers.
  Future<void> start() async {
    if (_process != null) throw StateError("PiRpcClient already started");
    if (_disposed) throw StateError("PiRpcClient is disposed");

    final starting = _start();
    final settled = starting.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _starting = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_starting, settled)) _starting = null;
      }),
    );
    await starting;
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final process = await _processFactory(spec: _launchSpec);
    if (_disposed || generation != _generation) {
      // Teardown ran while the spawn was in flight and saw no process to reap.
      await _reapLateProcess(process);
      throw StateError(_disposed ? "PiRpcClient disposed during start" : "PiRpcClient reset during start");
    }

    _process = process;

    unawaited(
      process.stdin.done.catchError((Object error, StackTrace stack) {
        if (generation != _generation || _exited.isCompleted) return;
        Log.w("[pi] stdin stream failed", error, stack);
        _failPending(PiRpcStdinException(cause: error), stack);
        try {
          if (!process.kill(signal: io.ProcessSignal.sigkill)) {
            Log.w("[pi] could not terminate Pi after stdin failed");
          }
        } on Object catch (killError, killStack) {
          Log.w("[pi] failed to terminate Pi after stdin failed", killError, killStack);
        }
      }),
    );

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    process.stdout
        // One malformed byte must not tear down the unconditional stdout drain.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(_lfRecords(maxRecordLength: null))
        .listen(
          (record) {
            if (generation == _generation) _handleRecord(record);
          },
          onError: (Object error, StackTrace stack) {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
            if (generation != _generation) return;
            Log.w("[pi] stdout stream failed", error, stack);
            _failPending(
              PiRpcStdoutException(cause: error),
              stack,
            );
          },
          onDone: () {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
          },
          cancelOnError: false,
        );

    process.stderr
        // A crashing child can emit non-UTF-8 bytes, and a strict decoder would
        // take down the diagnostic stream exactly when it matters most.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(_lfRecords(maxRecordLength: _stderrLineLimit))
        .listen(
          (line) {
            if (generation == _generation) _recordStderr(line);
          },
          onError: (Object error, StackTrace stack) {
            if (!stderrDone.isCompleted) stderrDone.complete();
            Log.w("[pi] stderr stream failed", error, stack);
          },
          onDone: () {
            if (!stderrDone.isCompleted) stderrDone.complete();
          },
          cancelOnError: false,
        );

    unawaited(
      process.exitCode.then((code) async {
        await Future.wait([stdoutDone.future, stderrDone.future]);
        _exitCode = code;
        if (!_exited.isCompleted) _exited.complete(code);
        if (generation != _generation) return;
        _failPending(
          PiRpcProcessExitException(exitCode: code),
          StackTrace.current,
        );
      }),
    );
  }

  /// Sends a command and awaits Pi's response.
  ///
  /// Correlation is by request ID alone. `prompt` in particular is answered
  /// from Pi's asynchronous preflight, so its agent events legitimately arrive
  /// before or after this future completes, and a success means accepted or
  /// queued rather than finished.
  ///
  /// Throws [PiRpcException] when Pi answers with a failure, when the frame
  /// cannot be written, or when the process has already exited; and
  /// [TimeoutException] when no response arrives.
  Future<PiSuccessResponseFrame> send({
    required PiRpcCommand command,
    required Map<String, Object?> arguments,
    required Duration timeout,
  }) async {
    final type = command.wireValue;
    final process = _process;
    if (_disposed) throw const PiRpcDisposedException();
    if (process == null) throw PiRpcNotRunningException(command: command);
    // The exit handler deliberately leaves `_process` set, so without this a
    // command issued after the process died would write to a dead pipe and then
    // block for the whole timeout awaiting a reply that can never come.
    if (_exited.isCompleted) {
      throw PiRpcProcessExitException(exitCode: _exitCode ?? -1);
    }

    final requestId = "sesori-${_nextRequestId++}";
    final completer = Completer<PiSuccessResponseFrame>();
    _pending[requestId] = (command: command, completer: completer);

    final writeError = _writeError(process: process, frame: {...arguments, "id": requestId, "type": type});
    if (writeError != null) {
      // The frame never left the bridge, so no reply is coming.
      _pending.remove(requestId);
      throw PiRpcWriteException(command: command, cause: writeError);
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(requestId);
      rethrow;
    }
  }

  /// Answers a blocking [PiExtensionDialogRequest].
  ///
  /// Returns whether the reply was written. Pi resolves select, confirm, and
  /// input dialogs on its own timeout, so a late answer is simply ignored.
  bool sendExtensionUiResponse({required String id, required PiExtensionUiReply reply}) {
    final process = _process;
    if (process == null || _exited.isCompleted) return false;
    return _writeError(
          process: process,
          frame: {...reply.fields, "type": "extension_ui_response", "id": id},
        ) ==
        null;
  }

  /// Terminates the process, fails in-flight requests, and closes the stream.
  Future<void> dispose({Duration gracefulTimeout = const Duration(seconds: 5)}) {
    _teardownDeadline?.tighten(timeout: gracefulTimeout);
    return _disposing ??= _dispose(gracefulTimeout: gracefulTimeout);
  }

  Future<void> _dispose({required Duration gracefulTimeout}) async {
    if (_disposed) return;
    _disposed = true;
    await _teardown(
      gracefulTimeout: gracefulTimeout,
      pendingError: const PiRpcDisposedException(),
    );
    try {
      await _frames.close();
    } on Object catch (error, stack) {
      Log.w("[pi] failed to close the frame stream", error, stack);
    }
  }

  Object? _writeError({required PiProcessHandle process, required Map<String, Object?> frame}) {
    try {
      process.stdin.add(utf8.encode("${jsonEncode(frame)}\n"));
      return null;
    } on Object catch (error, stack) {
      // A broken pipe lands here when the write races the process's exit.
      Log.w("[pi] failed to write a ${frame["type"]} frame", error, stack);
      return error;
    }
  }

  void _handleRecord(String record) {
    if (record.trim().isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(record);
    } on FormatException {
      // The exception's own text embeds a snippet of the frame, and a frame can
      // hold prompt or transcript content, so neither is attached here.
      Log.w("[pi] discarded an undecodable stdout frame of ${record.length} characters");
      return;
    }
    if (decoded is! Map) {
      Log.w("[pi] discarded a non-object stdout frame");
      return;
    }

    final frame = PiRpcFrame.parse(json: decoded.cast<String, Object?>());
    if (frame is PiResponseFrame) _completePending(frame: frame);
    _deliver(frame);
  }

  void _completePending({required PiResponseFrame frame}) {
    final id = frame.id;
    final completer = id == null ? null : _pending.remove(id);
    if (completer == null) {
      // Pi answers its own parse failures without a request ID, and a response
      // can outlive a timed-out request.
      Log.d("[pi] response for uncorrelated request id=$id command=${frame.command?.wireValue ?? "<unknown>"}");
      return;
    }
    switch (frame) {
      case PiSuccessResponseFrame():
        completer.completer.complete(frame);
      case PiFailureResponseFrame(:final error):
        completer.completer.completeError(
          PiRpcCommandFailureException(command: completer.command, error: error ?? "the command failed"),
          StackTrace.current,
        );
    }
  }

  void _deliver(PiRpcFrame frame) {
    if (_frames.isClosed) return;
    if (_attached) {
      _frames.add(frame);
      return;
    }
    if (_startupFrames.length >= _startupFrameLimit) {
      // Dropping the oldest keeps the drain unconditional, which is what stops
      // Pi's own stdout backpressure from stalling the agent.
      _startupFrames.removeAt(0);
      if (!_droppedStartupFrames) {
        _droppedStartupFrames = true;
        Log.w("[pi] dropping startup frames: no router attached after $_startupFrameLimit frames");
      }
    }
    _startupFrames.add(frame);
  }

  void _flushStartupFrames() {
    _attached = true;
    final buffered = List<PiRpcFrame>.from(_startupFrames);
    _startupFrames.clear();
    for (final frame in buffered) {
      if (!_frames.isClosed) _frames.add(frame);
    }
  }

  void _recordStderr(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    final redacted = _redact(trimmed);
    _stderrTail.add(redacted);
    if (_stderrTail.length > _stderrTailLimit) _stderrTail.removeAt(0);
    Log.d("[pi][stderr] $redacted");
  }

  /// Redacts bounded diagnostics without enumerating every provider-specific
  /// spelling or destroying unrelated fields in valid JSON.
  static final RegExp _authorizationHeader = RegExp(
    r'(\bauthorization\s*:\s*[a-z][a-z0-9_-]*\s+).*$',
    caseSensitive: false,
  );
  static final RegExp _diagnosticKey = RegExp(
    r'"?([a-z][a-z0-9_-]*)"?\s*[:=]\s*',
    caseSensitive: false,
  );
  static final RegExp _nonAlphanumeric = RegExp("[^a-z0-9]");

  String _redact(String value) {
    if (value.startsWith(noModelsDiagnosticPrefix)) return noModelsDiagnosticPrefix;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map || decoded is List) return jsonEncode(_redactJson(decoded));
    } on FormatException {
      // Partial and non-JSON diagnostics use the bounded fallback below.
    }

    final authorization = _authorizationHeader.firstMatch(value);
    if (authorization != null) {
      return "${value.substring(0, authorization.start)}${authorization.group(1)}***";
    }
    for (final match in _diagnosticKey.allMatches(value)) {
      if (!_isCredentialKey(match.group(1)!)) continue;
      final quoted = match.end < value.length && value.codeUnitAt(match.end) == 0x22;
      return "${value.substring(0, match.end)}${quoted ? '"***"' : '***'}";
    }
    return value;
  }

  Object? _redactJson(Object? value, {String? key}) {
    if (key != null && _isCredentialKey(key)) return "***";
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): _redactJson(entry.value, key: entry.key.toString()),
      };
    }
    if (value is List) return [for (final entry in value) _redactJson(entry)];
    return value;
  }

  bool _isCredentialKey(String key) {
    final normalized = key.toLowerCase().replaceAll(_nonAlphanumeric, "");
    return normalized == "authorization" ||
        normalized.endsWith("token") ||
        normalized.endsWith("apikey") ||
        normalized.endsWith("secret") ||
        normalized.endsWith("password") ||
        normalized.contains("credential");
  }

  void _failPending(Object error, StackTrace stack) {
    final inflight = _pending.values.map((request) => request.completer).toList();
    _pending.clear();
    for (final completer in inflight) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  }

  Future<void> _teardown({required Duration gracefulTimeout, required Object pendingError}) async {
    // Invalidate the callbacks before the first await so a late frame from this
    // process cannot affect anything established afterwards.
    _generation++;
    final process = _process;
    _process = null;

    _failPending(pendingError, StackTrace.current);

    var stopped = process == null;
    if (process != null) {
      final deadline = _teardownDeadline = _PiTeardownDeadline(timeout: gracefulTimeout);
      try {
        // Closing stdin is Pi's own shutdown signal, so it is tried before
        // signalling. A broken pipe here is expected and already absorbed.
        if (!await deadline.waitFor(process.stdin.close())) {
          throw TimeoutException("Pi stdin did not close before the teardown deadline");
        }
      } on Object catch (error, stack) {
        Log.w("[pi] closing stdin during teardown failed", error, stack);
      }
      stopped = await _stopProcess(process: process, deadline: deadline);
      deadline.dispose();
      _teardownDeadline = null;
    }

    // A confirmed process exit closes both pipes. Let their listeners receive
    // onDone so buffered stdout is handled before processExit settles.
    if (!stopped) Log.w("[pi] retaining pipe drains for a process that did not terminate");
  }

  Future<void> _reapLateProcess(PiProcessHandle process) async {
    try {
      if (!process.kill(signal: io.ProcessSignal.sigkill)) {
        Log.w("[pi] late process rejected forced termination");
        return;
      }
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      Log.w("[pi] late process did not exit after forced termination");
    } on Object catch (error, stack) {
      Log.w("[pi] failed to reap a process spawned during teardown", error, stack);
    }
  }

  Future<bool> _stopProcess({required PiProcessHandle process, required _PiTeardownDeadline deadline}) async {
    final initialSignal = io.Platform.isWindows ? io.ProcessSignal.sigkill : io.ProcessSignal.sigterm;
    if (!_sendSignal(process: process, signal: initialSignal)) return false;
    if (await deadline.waitFor(process.exitCode)) return true;
    if (initialSignal == io.ProcessSignal.sigkill) {
      Log.w("[pi] Pi did not exit after forced termination");
      return false;
    }
    if (!_sendSignal(process: process, signal: io.ProcessSignal.sigkill)) return false;
    if (await deadline.waitFor(process.exitCode)) return true;
    Log.w("[pi] Pi did not exit after SIGKILL");
    return false;
  }

  bool _sendSignal({required PiProcessHandle process, required io.ProcessSignal signal}) {
    try {
      final sent = process.kill(signal: signal);
      if (!sent) Log.w("[pi] process rejected ${signal.toString()} during teardown");
      return sent;
    } on Object catch (error, stack) {
      Log.w("[pi] failed to signal the process during teardown", error, stack);
      return false;
    }
  }
}

final class _PiTeardownDeadline({required final Duration timeout}) {
  this {
    tighten(timeout: timeout);
  }

  final Completer<void> _elapsed = Completer<void>();
  DateTime? _deadline;
  Timer? _timer;

  void tighten({required Duration timeout}) {
    if (_elapsed.isCompleted) return;
    final candidate = DateTime.now().add(timeout);
    final current = _deadline;
    if (current != null && !candidate.isBefore(current)) return;
    _deadline = candidate;
    _timer?.cancel();
    if (timeout <= Duration.zero) {
      _elapsed.complete();
      return;
    }
    _timer = Timer(timeout, _elapsed.complete);
  }

  Future<bool> waitFor<T>(Future<T> operation) => Future.any([
    operation.then((_) => true),
    _elapsed.future.then((_) => false),
  ]);

  void dispose() => _timer?.cancel();
}

/// Splits decoded text into Pi's JSONL records.
///
/// Unlike `LineSplitter` this splits on LF only. Pi separates records with LF
/// and permits a bare CR, U+2028, and U+2029 inside a JSON string, so splitting
/// on those would corrupt any frame carrying such text. One trailing CR is
/// removed so CRLF input still yields a clean record.
///
/// A new transformer is built per stream because the carry-over buffer for a
/// record split across chunks is per-stream state.
StreamTransformer<String, String> _lfRecords({required int? maxRecordLength}) {
  final pending = <String>[];
  var pendingLength = 0;

  void retain(String fragment) {
    final limit = maxRecordLength;
    if (limit == null) {
      pending.add(fragment);
      return;
    }
    final remaining = limit - pendingLength;
    if (remaining <= 0) return;
    final retained = fragment.length <= remaining ? fragment : fragment.substring(0, remaining);
    pending.add(retained);
    pendingLength += retained.length;
  }

  return StreamTransformer<String, String>.fromHandlers(
    handleData: (chunk, sink) {
      var start = 0;
      for (var index = chunk.indexOf("\n"); index >= 0; index = chunk.indexOf("\n", start)) {
        retain(chunk.substring(start, index));
        sink.add(_withoutTrailingCarriageReturn(pending.join()));
        pending.clear();
        pendingLength = 0;
        start = index + 1;
      }
      if (start < chunk.length) retain(chunk.substring(start));
    },
    handleDone: (sink) {
      // Pi terminates every record with LF, so a leftover tail is a truncated
      // frame from a process that died mid-write. Emitting it lets the decoder
      // report and discard it instead of losing it silently.
      if (pending.isNotEmpty) {
        sink.add(_withoutTrailingCarriageReturn(pending.join()));
        pending.clear();
        pendingLength = 0;
      }
      sink.close();
    },
  );
}

String _withoutTrailingCarriageReturn(String record) =>
    record.endsWith("\r") ? record.substring(0, record.length - 1) : record;
