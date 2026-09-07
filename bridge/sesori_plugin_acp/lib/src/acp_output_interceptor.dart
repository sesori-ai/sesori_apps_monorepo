import "dart:async";
import "dart:typed_data";

/// Consumes complete raw lines before UTF-8/NDJSON decoding or diagnostic logs.
/// Lines retain their LF/CRLF terminator; the final unterminated line is offered
/// at EOF. Returning false preserves every byte. Callbacks must never log input
/// or include it in errors; provider parsing belongs to the owning repository.
class const AcpOutputInterceptor({
  required final int maxLineBytes,
  required final bool Function({required List<int> line}) consumeLine,
}) {
  Stream<List<int>> intercept({required Stream<List<int>> bytes}) => Stream.eventTransformed(
    bytes,
    (sink) => _AcpOutputSink(sink: sink, interceptor: this),
  );
}

/// Each subscription owns its partial line. Unlike an async generator waiting
/// for another chunk, this transformer forwards cancellation immediately.
class _AcpOutputSink({required final EventSink<List<int>> sink, required final AcpOutputInterceptor interceptor})
    implements EventSink<List<int>> {
  final BytesBuilder _pending = BytesBuilder(copy: false);
  bool _failed = false;

  @override
  void add(List<int> chunk) {
    if (_failed) return;
    try {
      var start = 0;
      for (var index = 0; index < chunk.length; index++) {
        if (chunk[index] != 10) continue;
        _append(chunk: chunk, start: start, end: index + 1);
        _emit();
        start = index + 1;
      }
      _append(chunk: chunk, start: start, end: chunk.length);
    } on Object catch (error, stackTrace) {
      _failed = true;
      _pending.clear();
      sink.addError(error, stackTrace);
    }
  }

  void _append({required List<int> chunk, required int start, required int end}) {
    if (_pending.length + end - start > interceptor.maxLineBytes) {
      throw const AcpOutputInterceptionException(cause: null);
    }
    if (end > start) _pending.add(chunk.sublist(start, end));
  }

  void _emit() {
    final line = _pending.takeBytes();
    final bool consumed;
    try {
      consumed = interceptor.consumeLine(line: List<int>.unmodifiable(line));
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(AcpOutputInterceptionException(cause: error), stackTrace);
    }
    if (!consumed) sink.add(line);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => sink.addError(error, stackTrace);

  @override
  void close() {
    try {
      if (!_failed && _pending.isNotEmpty) _emit();
    } on Object catch (error, stackTrace) {
      sink.addError(error, stackTrace);
    } finally {
      sink.close();
    }
  }
}

/// Presentation never echoes process output, including a parser's original
/// error. The typed cause remains available to the repository for mapping.
class const AcpOutputInterceptionException({required final Object? cause}) implements Exception {
  @override
  String toString() => "ACP output interception failed (line limit or callback failure)";
}
