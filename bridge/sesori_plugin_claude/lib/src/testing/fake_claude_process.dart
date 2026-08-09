import "dart:async";
import "dart:convert";
import "dart:io";

import "../api/claude_process_factory.dart";

/// In-memory [ClaudeProcessHandle] for transport and plugin tests.
class FakeClaudeProcess implements ClaudeProcessHandle {
  FakeClaudeProcess({bool stdinCloseCompletes = true}) : _stdin = CapturingIOSink(closeCompletes: stdinCloseCompletes);

  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  final CapturingIOSink _stdin;

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
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }

  /// Frames the client wrote to stdin, decoded from ndjson.
  List<Map<String, Object?>> get written => _stdin.frames;

  /// Pushes one stdout frame as an ndjson line.
  void emit(Map<String, Object?> message) {
    if (_stdout.isClosed) return;
    _stdout.add(utf8.encode("${jsonEncode(message)}\n"));
  }

  /// Pushes raw stdout bytes, for framing and malformed-input tests.
  void emitRaw(List<int> bytes) {
    if (_stdout.isClosed) return;
    _stdout.add(bytes);
  }

  /// Pushes raw stderr bytes. Used to prove a crashing child's non-UTF-8 output
  /// does not take down the diagnostic stream.
  void emitStderrRaw(List<int> bytes) {
    if (_stderr.isClosed) return;
    _stderr.add(bytes);
  }

  /// Answers the pending control request with `request_id` [requestId].
  void emitControlResponse({required String requestId, required Map<String, Object?> payload}) {
    emit({
      "type": "control_response",
      "response": {"subtype": "success", "request_id": requestId, "response": payload},
    });
  }

  /// Answers a control request with a failure.
  void emitControlError({required String requestId, required String error}) {
    emit({
      "type": "control_response",
      "response": {"subtype": "error", "request_id": requestId, "error": error},
    });
  }

  /// Completes the process with [code], simulating an exit.
  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  Future<void> close() async {
    // A single-subscription controller's `close()` future only completes once
    // its stream has been listened to, so drain any never-tapped stream first.
    if (!_stdoutTapped) _stdout.stream.listen(null);
    if (!_stderrTapped) _stderr.stream.listen(null);
    await _stdout.close();
    await _stderr.close();
  }
}

/// Minimal [IOSink] capturing `add`-ed bytes and decoding complete ndjson lines
/// into [frames]. Only [add] and [close] are exercised by the transport.
class CapturingIOSink implements IOSink {
  CapturingIOSink({bool closeCompletes = true}) : _closeCompleter = closeCompletes ? null : Completer<void>();

  final Completer<void>? _closeCompleter;
  final List<int> _buffer = [];
  final List<Map<String, Object?>> frames = [];

  /// Whether the transport closed stdin, which is the protocol's own shutdown
  /// signal.
  bool closed = false;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _buffer.addAll(data);
    while (true) {
      final index = _buffer.indexOf(10);
      if (index < 0) break;
      final line = utf8.decode(_buffer.sublist(0, index));
      _buffer.removeRange(0, index + 1);
      if (line.trim().isNotEmpty) {
        frames.add((jsonDecode(line) as Map).cast<String, Object?>());
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
    return _closeCompleter?.future ?? Future<void>.value();
  }

  @override
  Future<void> get done => Future<void>.value();

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
