import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("defaults dedicated command event support for the public v1.6.0 app", () {
    final message = RelayMessage.fromJson({
      "type": "sse_subscribe",
      "path": "/global/event",
    });

    expect(message, isA<RelaySseSubscribe>());
    expect((message as RelaySseSubscribe).supportsSessionCommandsUpdated, isFalse);
  });

  test("round-trips dedicated command event support", () {
    const message = RelayMessage.sseSubscribe(
      path: "/global/event",
      supportsSessionCommandsUpdated: true,
    );

    expect(RelayMessage.fromJson(message.toJson()), message);
  });
}
