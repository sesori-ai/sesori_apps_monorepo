import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:web_socket_channel/web_socket_channel.dart";

class FakeRealtimeVoiceTokenProvider({required final String? token}) implements AuthTokenProvider {
  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async => token;
}

class FakeRealtimeVoiceChannel() extends Mock implements WebSocketChannel {
  final StreamController<Object?> inbound = StreamController<Object?>();
  final Completer<void> upgrade = Completer<void>();
  final List<Object?> outbound = [];

  /// Sees each send as it happens, for a test that cares about the moment.
  void Function({required Object? data})? onOutbound;

  final Completer<void> _sinkDone = Completer<void>();
  int? sinkCloseCode;
  int? serverCloseCode;

  @override
  Future<void> get ready => upgrade.future;

  @override
  Stream<Object?> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _FakeSink(channel: this);

  @override
  int? get closeCode => serverCloseCode;

  @override
  String? get closeReason => null;
}

class _FakeSink({required final FakeRealtimeVoiceChannel channel}) implements WebSocketSink {
  @override
  void add(Object? data) {
    channel.outbound.add(data);
    channel.onOutbound?.call(data: data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => throw UnimplementedError();

  @override
  Future<void> addStream(Stream<Object?> stream) => throw UnimplementedError();

  @override
  Future<void> get done => channel._sinkDone.future;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    channel.sinkCloseCode = closeCode;
    if (!channel._sinkDone.isCompleted) channel._sinkDone.complete();
  }
}
