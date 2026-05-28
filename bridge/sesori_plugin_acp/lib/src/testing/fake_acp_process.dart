import "dart:async";
import "dart:convert";
import "dart:io";

import "../acp_process_factory.dart";

/// In-memory [AcpProcessHandle] for transport/plugin tests — the stdio
/// analogue of codex's injected fake WebSocket channel. Shared across ACP
/// harness packages via `package:acp_plugin/acp_testing.dart`.
class FakeAcpProcess implements AcpProcessHandle {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  final CapturingIOSink _stdin = CapturingIOSink();

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }

  /// Frames the client wrote to stdin, decoded from ndjson.
  List<Map<String, dynamic>> get written => _stdin.frames;

  /// Pushes a server->client JSON-RPC message as one ndjson line.
  void emit(Map<String, dynamic> message) {
    _stdout.add(utf8.encode("${jsonEncode(message)}\n"));
  }

  /// Completes the process with [code], simulating an early exit.
  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  Future<void> close() async {
    await _stdout.close();
    await _stderr.close();
  }
}

/// Minimal [IOSink] that captures `add`-ed bytes and decodes complete ndjson
/// lines into [frames]. Only [add] is exercised by the transport.
class CapturingIOSink implements IOSink {
  final List<int> _buffer = [];
  final List<Map<String, dynamic>> frames = [];

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _buffer.addAll(data);
    while (true) {
      final idx = _buffer.indexOf(10);
      if (idx < 0) break;
      final line = utf8.decode(_buffer.sublist(0, idx));
      _buffer.removeRange(0, idx + 1);
      if (line.trim().isNotEmpty) {
        frames.add((jsonDecode(line) as Map).cast<String, dynamic>());
      }
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() async {}

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
