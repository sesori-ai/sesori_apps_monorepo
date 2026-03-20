import "dart:convert";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("SseEventParser", () {
    test("parses session.status with busy status", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.status",
          "properties": {
            "sessionID": "s1",
            "status": {"type": "busy"},
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.directory, equals("/repo"));
      expect(result.rawData, equals(rawData));
      expect(result.event, isA<SseSessionStatus>());

      final event = result.event! as SseSessionStatus;
      expect(event.sessionID, equals("s1"));
      expect(event.status, isA<SessionStatusBusy>());
    });

    test("parses session.created event", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.created",
          "properties": {
            "info": {"id": "s1", "projectID": "p1", "directory": "/repo"},
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.event, isA<SseSessionCreated>());
      final event = result.event! as SseSessionCreated;
      expect(event.info.id, equals("s1"));
      expect(event.info.projectID, equals("p1"));
      expect(event.info.directory, equals("/repo"));
      expect(result.directory, equals("/repo"));
    });

    test("parses server.heartbeat event", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "payload": {"type": "server.heartbeat", "properties": <String, dynamic>{}},
      });

      final result = parser.parse(rawData);

      expect(result.event, isA<SseServerHeartbeat>());
      expect(result.directory, isNull);
      expect(result.rawData, equals(rawData));
    });

    test(
      "unknown event type returns null event with directory and rawData",
      () {
        final parser = SseEventParser();
        final rawData = jsonEncode({
          "directory": "/repo",
          "payload": {
            "type": "unknown.event",
            "properties": <String, dynamic>{"value": 1},
          },
        });

        final result = parser.parse(rawData);

        expect(result.event, isNull);
        expect(result.directory, equals("/repo"));
        expect(result.rawData, equals(rawData));
      },
    );

    test("malformed JSON returns null event and preserved rawData", () {
      final parser = SseEventParser();
      const rawData = "{not-json";

      final result = parser.parse(rawData);

      expect(result.event, isNull);
      expect(result.directory, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("empty string returns null event and preserved rawData", () {
      final parser = SseEventParser();
      const rawData = "";

      final result = parser.parse(rawData);

      expect(result.event, isNull);
      expect(result.directory, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("missing payload returns null event and preserved rawData", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({"directory": "/repo"});

      final result = parser.parse(rawData);

      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.rawData, equals(rawData));
    });

    test("missing payload type returns null event and preserved rawData", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "properties": {"sessionID": "s1"},
        },
      });

      final result = parser.parse(rawData);

      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.rawData, equals(rawData));
    });

    test("rawData is always preserved exactly", () {
      final parser = SseEventParser();
      final rawInputs = <String>[
        "",
        "{not-json",
        '  {"directory":"/repo"}',
        jsonEncode({
          "directory": "/repo",
          "payload": {
            "type": "session.status",
            "properties": {
              "sessionID": "s1",
              "status": {"type": "busy"},
            },
          },
        }),
      ];

      for (final rawData in rawInputs) {
        final result = parser.parse(rawData);
        expect(result.rawData, equals(rawData));
      }
    });
  });
}
