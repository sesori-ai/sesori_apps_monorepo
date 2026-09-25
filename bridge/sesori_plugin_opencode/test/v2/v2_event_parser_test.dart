import "package:opencode_plugin/src/v2/models/v2_decode_exception.dart";
import "package:opencode_plugin/src/v2/models/v2_event.g.dart";
import "package:opencode_plugin/src/v2/sse/v2_event_parser.dart";
import "package:test/test.dart";

void main() {
  const parser = V2EventParser();

  test("decodes global event envelopes without requiring a location", () {
    final event = parser.parse(rawData: '{"id":"event-1","created":1,"type":"server.connected","data":{}}')!;
    expect(event.id, "event-1");
    expect(event.created, 1);
    expect(event.location, isNull);
    expect(event.data, isA<V2ServerConnected>());
  });

  test("uses the outer event type and retains location and session identity", () {
    final event = parser.parse(
      rawData: '''
    {
      "id":"event-2","created":2,"type":"session.text.delta",
      "location":{"directory":"/fixture/project"},
      "data":{"type":"server.connected","sessionID":"s","assistantMessageID":"m","ordinal":0,"delta":"Hi"}
    }''',
    )!;
    expect(event.location!.directory, "/fixture/project");
    final delta = event.data as V2SessionTextDelta;
    expect(delta.sessionID, "s");
    expect(delta.delta, "Hi");
  });

  test("drops malformed and unknown frames, then accepts later valid frames", () {
    for (final raw in <String>[
      "not JSON",
      "[]",
      '{"id":"event-3","created":3,"type":"future.event","data":{}}',
      '{"id":"event-4","created":4,"type":"session.text.delta","data":{}}',
      '{"id":"event-5","type":"server.connected","data":{}}',
    ]) {
      expect(parser.parse(rawData: raw), isNull);
    }
    expect(parser.parse(rawData: '{"id":"event-6","created":6,"type":"server.connected","data":{}}'), isNotNull);
  });

  test("retains the exact cause but omits format source and message from logs", () {
    const cause = FormatException("private fixture message", "private fixture source", 4);
    const failure = V2DecodeException(operation: "SSE event", innerError: cause);
    expect(failure.innerError, same(cause));
    expect(failure.toString(), contains("offset 4"));
    expect(failure.toString(), isNot(contains("private fixture")));
  });
}
