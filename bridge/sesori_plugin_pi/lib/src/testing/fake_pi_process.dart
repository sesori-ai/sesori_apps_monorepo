import "dart:async";
import "dart:convert";
import "dart:io";

import "../api/pi_process_factory.dart";

/// In-memory [PiProcessHandle] for Pi transport and plugin tests.
class FakePiProcess({bool stdinCloseCompletes = true, bool stdinWritesFail = false}) implements PiProcessHandle {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  final CapturingIOSink _stdin = CapturingIOSink(closeCompletes: stdinCloseCompletes, writesFail: stdinWritesFail);

  bool _stdoutTapped = false;
  bool _stderrTapped = false;

  /// Signals the fake received a kill, so teardown tests can assert it.
  bool killed = false;

  @override
  Stream<List<int>> get stdout {
    _stdoutTapped = true;
    return _stdout.stream;
  }

  @override
  Stream<List<int>> get stderr {
    _stderrTapped = true;
    return _stderr.stream;
  }

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill({required ProcessSignal signal}) {
    killed = true;
    exit(code: -15);
    return true;
  }

  /// Commands the client wrote to stdin, decoded from JSONL.
  List<Map<String, Object?>> get written => _stdin.frames;

  bool get stdinClosed => _stdin.closed;

  void failStdin({required Object error}) => _stdin.failDone(error: error);

  /// Completes a stdin close that was configured to stall.
  void completeStdinClose() => _stdin.completeClose();

  /// Pushes one stdout frame as a JSONL record.
  void emit({required Map<String, Object?> frame}) {
    if (_stdout.isClosed) return;
    _stdout.add(utf8.encode("${jsonEncode(frame)}\n"));
  }

  /// Pushes raw stdout bytes, for framing and malformed-input tests.
  void emitRaw({required List<int> bytes}) {
    if (_stdout.isClosed) return;
    _stdout.add(bytes);
  }

  /// Pushes raw stderr bytes, including non-UTF-8 output from a crashing child.
  void emitStderrRaw({required List<int> bytes}) {
    if (_stderr.isClosed) return;
    _stderr.add(bytes);
  }

  /// Answers the command with request id [id].
  void emitResponse({
    required String id,
    required String command,
    Map<String, Object?> data = const {},
  }) => emit(frame: {"id": id, "type": "response", "command": command, "success": true, "data": data});

  /// Answers the command with request id [id] with a failure.
  void emitFailure({required String id, required String command, required String error}) =>
      emit(frame: {"id": id, "type": "response", "command": command, "success": false, "error": error});

  /// Completes the process with [code], simulating an exit.
  void exit({required int code}) {
    if (!_exit.isCompleted) _exit.complete(code);
    if (!_stdout.isClosed) unawaited(_stdout.close());
    if (!_stderr.isClosed) unawaited(_stderr.close());
  }

  Future<void> close() async {
    // A single-subscription controller's `close()` future only completes once
    // its stream has been listened to, so drain any never-tapped stream first.
    if (!_stdoutTapped) _stdout.stream.listen(null);
    if (!_stderrTapped) _stderr.stream.listen(null);
    if (!_stdout.isClosed) await _stdout.close();
    if (!_stderr.isClosed) await _stderr.close();
  }
}

/// Minimal [IOSink] capturing `add`-ed bytes and decoding complete JSONL
/// records into [frames]. Only `add` and `close` are exercised by the
/// transport.
class CapturingIOSink({bool closeCompletes = true, final bool _writesFail = false}) implements IOSink {
  final Completer<void>? _closeCompleter = closeCompletes ? null : Completer<void>();
  final Completer<void> _doneCompleter = Completer<void>();
  final List<int> _buffer = [];
  final List<Map<String, Object?>> frames = [];

  /// Whether the transport closed stdin, which is Pi's own shutdown signal.
  bool closed = false;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    // A write to a dead child raises here, which is how a broken pipe reaches
    // the transport synchronously.
    if (_writesFail) throw const SocketException("broken pipe");
    _buffer.addAll(data);
    while (true) {
      final index = _buffer.indexOf(10);
      if (index < 0) break;
      final record = utf8.decode(_buffer.sublist(0, index));
      _buffer.removeRange(0, index + 1);
      if (record.trim().isNotEmpty) {
        frames.add((jsonDecode(record) as Map).cast<String, Object?>());
      }
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() {
    closed = true;
    final closing = _closeCompleter?.future ?? Future<void>.value();
    return closing.whenComplete(() {
      if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    });
  }

  void completeClose() {
    final completer = _closeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void failDone({required Object error}) {
    if (!_doneCompleter.isCompleted) _doneCompleter.completeError(error, StackTrace.current);
  }

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = ""]) {}
}
