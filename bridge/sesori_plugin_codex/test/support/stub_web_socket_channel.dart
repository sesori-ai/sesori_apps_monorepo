import "dart:async";

import "package:web_socket_channel/web_socket_channel.dart";

/// An in-memory [WebSocketChannel] over a fixed stream and sink.
class StubWebSocketChannel({
  @override required final Stream<dynamic> stream,
  @override required final WebSocketSink sink,
}) implements WebSocketChannel {
  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  // The StreamChannelMixin helpers are not exercised by the tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [WebSocketSink] that forwards everything into a [StreamController].
class ControllerWebSocketSink({required final StreamController<Object?> _controller}) implements WebSocketSink {
  @override
  void add(Object? data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) => stream.forEach(_controller.add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> get done => _controller.done;
}
