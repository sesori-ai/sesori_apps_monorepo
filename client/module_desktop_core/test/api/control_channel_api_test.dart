import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("serializes a typed control message for the foundation server", () {
    final _FakeControlChannelServer server = _FakeControlChannelServer();
    final ControlChannelApi api = ControlChannelApi(server: server);

    api.send(
      message: const ControlMessage.promptResponse(id: "replace-1", accepted: true),
    );

    expect(server.sentFrames, hasLength(1));
    expect(
      ControlMessage.fromJson(jsonDecodeMap(server.sentFrames.single)),
      const ControlMessage.promptResponse(id: "replace-1", accepted: true),
    );
  });

  test("preserves the foundation transport failure", () {
    final _FakeControlChannelServer server = _FakeControlChannelServer();
    final ControlChannelApi api = ControlChannelApi(server: server);
    final StateError failure = StateError("helper disconnected");
    server.sendError = failure;

    expect(
      () => api.send(message: const ControlMessage.shutdown()),
      throwsA(same(failure)),
    );
  });
}

class _FakeControlChannelServer() implements ControlChannelServer {
  final List<String> sentFrames = <String>[];
  Object? sendError;

  @override
  void send(String text) {
    final Object? failure = sendError;
    if (failure != null) {
      throw failure;
    }
    sentFrames.add(text);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
