import "dart:async";

import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class FakeControlChannelClient() implements ControlChannelClient {
  this {
    addTearDown(dispose);
  }

  final StreamController<String> _inbound = StreamController<String>.broadcast();
  final StreamController<ControlChannelConnectionState> _connectionState =
      StreamController<ControlChannelConnectionState>.broadcast();
  final List<String> sentFrames = [];
  bool throwOnSend = false;
  Object? sendError;
  bool _disposed = false;

  List<ControlMessage> get sentMessages =>
      sentFrames.map((frame) => ControlMessage.fromJson(jsonDecodeMap(frame))).toList();

  void emit(String frame) => _inbound.add(frame);

  void emitConnectionState(ControlChannelConnectionState state) => _connectionState.add(state);

  @override
  Stream<String> get inbound => _inbound.stream;

  @override
  Stream<ControlChannelConnectionState> get connectionState => _connectionState.stream;

  @override
  void send(String frame) {
    if (throwOnSend) {
      throw const ControlChannelNotConnectedException("Control channel is not connected");
    }
    final error = sendError;
    if (error != null) throw error;
    sentFrames.add(frame);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inbound.close();
    await _connectionState.close();
  }
}
