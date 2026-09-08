import "dart:async";
import "dart:typed_data";

/// Composition supplies a fresh pair for each live/replay process when callbacks
/// carry state. Null leaves that stream's existing transport behavior unchanged.
typedef AcpOutputInterceptors = ({AcpOutputInterceptor? stdout, AcpOutputInterceptor? stderr});

/// Consumes complete raw lines before UTF-8/NDJSON decoding or diagnostic logs.
/// Lines retain their LF/CRLF terminator; the final unterminated line is offered
/// at EOF. Returning false preserves every byte. Callbacks must never log input
/// or include it in errors; provider parsing belongs to the owning repository.
class const AcpOutputInterceptor({
  required final int maxLineBytes,
  final AcpOutputPrefix? prefix,
  required final bool Function({required List<int> line}) consumeLine,
}) {
  this : assert(prefix == null || (prefix.length > 0 && prefix.length <= maxLineBytes));

  Stream<List<int>> intercept({required Stream<List<int>> bytes}) => Stream.eventTransformed(
    bytes,
    (sink) => _AcpOutputSink(sink: sink, interceptor: this),
  );
}

/// Opt-in classification before whole-line buffering. Nonmatching lines stream
/// through unchanged; only matching lines are subject to [AcpOutputInterceptor.maxLineBytes].
/// The caller owns matching policy. The prefix must fit inside the line budget.
class const AcpOutputPrefix({
  required final int length,
  required final bool Function({required List<int> prefix}) matches,
});

enum _AcpOutputLineState() {
  classifying,
  intercepting,
  forwarding,
}

/// Each subscription owns its partial line. Unlike an async generator waiting
/// for another chunk, this transformer forwards cancellation immediately.
class _AcpOutputSink({required final EventSink<List<int>> sink, required final AcpOutputInterceptor interceptor})
    implements EventSink<List<int>> {
  final BytesBuilder _pending = BytesBuilder(copy: false);
  bool _failed = false;
  _AcpOutputLineState _lineState = interceptor.prefix == null
      ? _AcpOutputLineState.intercepting
      : _AcpOutputLineState.classifying;

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
    var offset = start;
    final prefix = interceptor.prefix;
    if (prefix != null && _lineState == _AcpOutputLineState.classifying) {
      final prefixEnd = offset + (prefix.length - _pending.length);
      final takeUntil = prefixEnd < end ? prefixEnd : end;
      if (takeUntil > offset) _pending.add(chunk.sublist(offset, takeUntil));
      offset = takeUntil;
      if (_pending.length < prefix.length) return;
      try {
        _lineState = prefix.matches(prefix: _pending.toBytes().asUnmodifiableView())
            ? _AcpOutputLineState.intercepting
            : _AcpOutputLineState.forwarding;
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(AcpOutputInterceptionException(cause: error), stackTrace);
      }
      if (_lineState == _AcpOutputLineState.forwarding) sink.add(_pending.takeBytes());
    }
    if (_lineState == _AcpOutputLineState.forwarding) {
      if (end > offset) sink.add(offset == 0 && end == chunk.length ? chunk : chunk.sublist(offset, end));
      return;
    }
    if (_pending.length + end - offset > interceptor.maxLineBytes) {
      throw const AcpOutputInterceptionException(cause: null);
    }
    if (end > offset) _pending.add(chunk.sublist(offset, end));
  }

  void _emit() {
    final line = _pending.takeBytes();
    final passthrough = _lineState != _AcpOutputLineState.intercepting;
    _lineState = interceptor.prefix == null ? _AcpOutputLineState.intercepting : _AcpOutputLineState.classifying;
    if (passthrough) {
      if (line.isNotEmpty) sink.add(line);
      return;
    }
    final bool consumed;
    try {
      consumed = interceptor.consumeLine(line: line.asUnmodifiableView());
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
