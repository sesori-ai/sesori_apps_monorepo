import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/pi_rpc_command.dart";
import "models/pi_extension_ui_request.dart";
import "models/pi_rpc_frame.dart";
import "pi_launch_spec.dart";
import "pi_process_factory.dart";

/// A Pi RPC command that failed, or that could not be delivered at all.
///
/// [error] is Pi's own untyped prose. It is kept for local diagnosis; mapping
/// it to a user-facing failure belongs to the repository layer.
class PiRpcException implements Exception {
  PiRpcException({required this.command, required this.error, required this.cause});

  /// The command that failed, or a `<...>` marker when the failure happened
  /// before Pi could answer.
  final String command;

  final String error;

  /// The local transport failure translated by this exception, when one exists.
  final Object? cause;

  @override
  String toString() => "PiRpcException(command: $command)";
}

/// What Sesori answers a blocking Pi extension dialog with.
sealed class PiExtensionUiReply {
  const PiExtensionUiReply();

  Map<String, Object?> get fields;
}

/// Answers a `select`, `input`, or `editor` dialog.
final class PiExtensionUiValueReply extends PiExtensionUiReply {
  const PiExtensionUiValueReply({required this.value});

  final String value;

  @override
  Map<String, Object?> get fields => {"value": value};
}

/// Answers a `confirm` dialog.
final class PiExtensionUiConfirmationReply extends PiExtensionUiReply {
  const PiExtensionUiConfirmationReply({required this.confirmed});

  final bool confirmed;

  @override
  Map<String, Object?> get fields => {"confirmed": confirmed};
}

/// Dismisses any dialog without a value.
final class PiExtensionUiCancelledReply extends PiExtensionUiReply {
  const PiExtensionUiCancelledReply();

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
class PiRpcClient {
  PiRpcClient({
    required PiLaunchSpec launchSpec,
    required PiProcessFactory processFactory,
  }) : _launchSpec = launchSpec,
       _processFactory = processFactory;

  /// How many parsed frames are held while no router has attached yet.
  ///
  /// Pi streams continuously, so an unbounded startup buffer would grow with
  /// the run. The cap is far above the handful of frames a launch produces.
  static const int _startupFrameLimit = 512;

  /// How many redacted stderr lines are retained for failure diagnosis.
  static const int _stderrTailLimit = 20;

  /// Longest retained stderr line. A crashing runtime can emit very long lines.
  static const int _stderrLineLimit = 500;

  final PiLaunchSpec _launchSpec;
  final PiProcessFactory _processFactory;

  PiProcessHandle? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _disposed = false;
  int _nextRequestId = 1;
  int _generation = 0;
  bool _attached = false;
  bool _droppedStartupFrames = false;

  final Map<String, ({PiRpcCommand command, Completer<PiSuccessResponseFrame> completer})> _pending = {};
  final List<PiRpcFrame> _startupFrames = [];
  final List<String> _stderrTail = [];
  Completer<int> _exited = Completer<int>();

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

    final generation = ++_generation;
    final process = await _processFactory(spec: _launchSpec);
    if (_disposed || generation != _generation) {
      // Teardown ran while the spawn was in flight and saw no process to reap.
      try {
        process.kill(signal: io.ProcessSignal.sigkill);
      } on Object catch (error, stack) {
        Log.w("[pi] failed to reap a process spawned during teardown", error, stack);
      }
      throw StateError(_disposed ? "PiRpcClient disposed during start" : "PiRpcClient reset during start");
    }

    final exited = Completer<int>();
    _exited = exited;
    _process = process;

    // A broken pipe surfaces asynchronously on `stdin.done` rather than from
    // `add`, so an unexpected exit would otherwise raise an unhandled async
    // error. The exit itself is reported below.
    unawaited(process.stdin.done.catchError((Object _) {}));

    _stdoutSubscription = process.stdout
        // One malformed byte must not tear down the unconditional stdout drain.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(_lfRecords())
        .listen(
          (record) {
            if (generation == _generation) _handleRecord(record);
          },
          onError: (Object error, StackTrace stack) {
            if (generation != _generation) return;
            Log.w("[pi] stdout stream failed", error, stack);
            _failPending(
              PiRpcException(command: "<stdout>", error: "pi stdout stream failed", cause: error),
              stack,
            );
          },
          cancelOnError: false,
        );

    _stderrSubscription = process.stderr
        // A crashing child can emit non-UTF-8 bytes, and a strict decoder would
        // take down the diagnostic stream exactly when it matters most.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(_lfRecords())
        .listen(
          (line) {
            if (generation == _generation) _recordStderr(line);
          },
          onError: (Object error, StackTrace stack) => Log.w("[pi] stderr stream failed", error, stack),
          cancelOnError: false,
        );

    unawaited(
      process.exitCode.then((code) {
        if (!exited.isCompleted) exited.complete(code);
        if (generation != _generation) return;
        if (!_disposed) Log.w("[pi] process exited with code $code");
        _failPending(
          PiRpcException(command: "<process>", error: "pi process exited with code $code", cause: null),
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
    if (process == null) {
      throw PiRpcException(command: type, error: "pi process is not running", cause: null);
    }
    // The exit handler deliberately leaves `_process` set, so without this a
    // command issued after the process died would write to a dead pipe and then
    // block for the whole timeout awaiting a reply that can never come.
    if (_exited.isCompleted) {
      throw PiRpcException(command: type, error: "pi process has exited", cause: null);
    }

    final requestId = "sesori-${_nextRequestId++}";
    final completer = Completer<PiSuccessResponseFrame>();
    _pending[requestId] = (command: command, completer: completer);

    final writeError = _writeError(process: process, frame: {...arguments, "id": requestId, "type": type});
    if (writeError != null) {
      // The frame never left the bridge, so no reply is coming.
      _pending.remove(requestId);
      throw PiRpcException(command: type, error: "failed to write the $type command", cause: writeError);
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
  Future<void> dispose({Duration gracefulTimeout = const Duration(seconds: 5)}) async {
    if (_disposed) return;
    _disposed = true;
    await _teardown(
      gracefulTimeout: gracefulTimeout,
      pendingError: PiRpcException(command: "<teardown>", error: "pi transport was disposed", cause: null),
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
          PiRpcException(
            command: completer.command.wireValue,
            error: error ?? "the command failed",
            cause: null,
          ),
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
    final bounded = trimmed.length > _stderrLineLimit ? trimmed.substring(0, _stderrLineLimit) : trimmed;
    final redacted = _redact(bounded);
    _stderrTail.add(redacted);
    if (_stderrTail.length > _stderrTailLimit) _stderrTail.removeAt(0);
    Log.d("[pi][stderr] $redacted");
  }

  /// Masks credential-shaped values before a diagnostic string is retained or
  /// logged. A string scrub rather than a JSON re-encode, so partial and
  /// non-JSON output is redacted too.
  static final RegExp _secretJsonValue = RegExp(
    r'("(?:token|authorization|api[_-]?key|secret|password|bearer)"\s*:\s*)"(?:\\.|[^"\\])*"',
    caseSensitive: false,
  );
  static final RegExp _authorizationBearer = RegExp(
    r'(\bauthorization\s*:\s*bearer\s+)[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _secretScalarValue = RegExp(
    r'((?:token|api[_-]?key|secret|password|bearer)\s*[:=]\s*)[^\s,;]+',
    caseSensitive: false,
  );

  String _redact(String value) => value
      .replaceAllMapped(_secretJsonValue, (match) => '${match.group(1)}"***"')
      .replaceAllMapped(_authorizationBearer, (match) => "${match.group(1)}***")
      .replaceAllMapped(_secretScalarValue, (match) => "${match.group(1)}***");

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

    if (process != null) {
      try {
        // Closing stdin is Pi's own shutdown signal, so it is tried before
        // signalling. A broken pipe here is expected and already absorbed.
        await process.stdin.close().timeout(gracefulTimeout);
      } on Object catch (error, stack) {
        Log.w("[pi] closing stdin during teardown failed", error, stack);
      }
      try {
        if (io.Platform.isWindows) {
          process.kill(signal: io.ProcessSignal.sigkill);
        } else {
          process.kill(signal: io.ProcessSignal.sigterm);
          try {
            await process.exitCode.timeout(gracefulTimeout);
          } on TimeoutException {
            process.kill(signal: io.ProcessSignal.sigkill);
          }
        }
      } on Object catch (error, stack) {
        Log.w("[pi] failed to stop the process during teardown", error, stack);
      }
    }

    Future<void>? stdoutCancellation;
    try {
      stdoutCancellation = _stdoutSubscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("[pi] failed to cancel the stdout subscription", error, stack);
    }
    _stdoutSubscription = null;

    Future<void>? stderrCancellation;
    try {
      stderrCancellation = _stderrSubscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("[pi] failed to cancel the stderr subscription", error, stack);
    }
    _stderrSubscription = null;

    // Isolate each step so one failure does not skip the rest.
    try {
      await stdoutCancellation;
    } on Object catch (error, stack) {
      Log.w("[pi] failed to cancel the stdout subscription", error, stack);
    }
    try {
      await stderrCancellation;
    } on Object catch (error, stack) {
      Log.w("[pi] failed to cancel the stderr subscription", error, stack);
    }
  }
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
StreamTransformer<String, String> _lfRecords() {
  final pending = <String>[];
  return StreamTransformer<String, String>.fromHandlers(
    handleData: (chunk, sink) {
      var start = 0;
      for (var index = chunk.indexOf("\n"); index >= 0; index = chunk.indexOf("\n", start)) {
        pending.add(chunk.substring(start, index));
        sink.add(_withoutTrailingCarriageReturn(pending.join()));
        pending.clear();
        start = index + 1;
      }
      if (start < chunk.length) pending.add(chunk.substring(start));
    },
    handleDone: (sink) {
      // Pi terminates every record with LF, so a leftover tail is a truncated
      // frame from a process that died mid-write. Emitting it lets the decoder
      // report and discard it instead of losing it silently.
      if (pending.isNotEmpty) {
        sink.add(_withoutTrailingCarriageReturn(pending.join()));
        pending.clear();
      }
      sink.close();
    },
  );
}

String _withoutTrailingCarriageReturn(String record) =>
    record.endsWith("\r") ? record.substring(0, record.length - 1) : record;
