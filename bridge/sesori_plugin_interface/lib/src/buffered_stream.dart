import "dart:async";

class BufferedUntilFirstListener<T> {
  final List<_BufferedEvent<T>> _buffer = [];
  late final StreamController<T> _controller;
  bool _hasListener = false;
  bool _isClosed = false;

  BufferedUntilFirstListener() {
    _controller = StreamController<T>(
      onListen: () {
        if (_hasListener) {
          throw StateError("This stream supports only one listener.");
        }
        _hasListener = true;
        for (final event in _buffer) {
          event.dispatch(_controller);
        }
        _buffer.clear();
      },
    );
  }

  Stream<T> get stream => _controller.stream;

  void add(T value) {
    _ensureOpen();
    if (_hasListener) {
      _controller.add(value);
    } else {
      _buffer.add(_DataEvent(value));
    }
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _ensureOpen();
    if (_hasListener) {
      _controller.addError(error, stackTrace);
    } else {
      _buffer.add(_ErrorEvent(error, stackTrace));
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    if (_hasListener) {
      await _controller.close();
    } else {
      _buffer.add(_DoneEvent());
    }
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError("Cannot add event after close.");
    }
  }
}

sealed class _BufferedEvent<T> {
  void dispatch(StreamController<T> controller);
}

class _DataEvent<T> implements _BufferedEvent<T> {
  final T value;
  _DataEvent(this.value);

  @override
  void dispatch(StreamController<T> controller) => controller.add(value);
}

class _ErrorEvent<T> implements _BufferedEvent<T> {
  final Object error;
  final StackTrace? stackTrace;
  _ErrorEvent(this.error, this.stackTrace);

  @override
  void dispatch(StreamController<T> controller) => controller.addError(error, stackTrace);
}

class _DoneEvent<T> implements _BufferedEvent<T> {
  @override
  void dispatch(StreamController<T> controller) => controller.close();
}
