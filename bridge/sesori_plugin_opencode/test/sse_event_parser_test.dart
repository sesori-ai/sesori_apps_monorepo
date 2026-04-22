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

      expect(result.outcome, equals(SseParseOutcome.validKnownEvent));
      expect(result.directory, equals("/repo"));
      expect(result.eventType, equals("session.status"));
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

      expect(result.outcome, equals(SseParseOutcome.validKnownEvent));
      expect(result.event, isA<SseSessionCreated>());
      expect(result.eventType, equals("session.created"));
      final event = result.event! as SseSessionCreated;
      expect(event.info.id, equals("s1"));
      expect(event.info.projectID, equals("p1"));
      expect(event.info.directory, equals("/repo"));
      expect(result.directory, equals("/repo"));
    });

    test("parses command.executed event", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "command.executed",
          "properties": {
            "name": "review",
            "sessionID": "s1",
            "arguments": "lib/main.dart",
            "messageID": "m1",
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.validKnownEvent));
      expect(result.eventType, equals("command.executed"));
      expect(result.directory, equals("/repo"));
      expect(result.event, isA<SseCommandExecuted>());

      final event = result.event! as SseCommandExecuted;
      expect(event.name, equals("review"));
      expect(event.sessionID, equals("s1"));
      expect(event.arguments, equals("lib/main.dart"));
      expect(event.messageID, equals("m1"));
    });

    test("parses server.heartbeat event", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "payload": {"type": "server.heartbeat", "properties": <String, dynamic>{}},
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.validKnownEvent));
      expect(result.event, isA<SseServerHeartbeat>());
      expect(result.eventType, equals("server.heartbeat"));
      expect(result.directory, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("parses 1.4 session.diff payload with patch-based diff array", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.diff",
          "properties": {
            "sessionID": "s1",
            "diff": [
              {
                "file": "lib/main.dart",
                "patch": "@@ -1 +1 @@\n-old\n+new",
                "additions": 1,
                "deletions": 1,
                "status": "modified",
              },
            ],
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.validKnownEvent));
      expect(result.rawData, equals(rawData));
      expect(result.event, isA<SseSessionDiff>());
      expect(result.eventType, equals("session.diff"));

      final event = result.event! as SseSessionDiff;
      expect(event.sessionID, equals("s1"));
      expect(event.diff, hasLength(1));
      expect(event.diff.single.file, equals("lib/main.dart"));
      expect(event.diff.single.patch, contains("+new"));
    });

    test("session.diff without diff array is categorized as malformed known payload", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.diff",
          "properties": {
            "sessionID": "s1",
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedKnownPayload));
      expect(result.event, isNull);
      expect(result.eventType, equals("session.diff"));
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

        expect(result.outcome, equals(SseParseOutcome.unknownEventType));
        expect(result.event, isNull);
        expect(result.directory, equals("/repo"));
        expect(result.eventType, equals("unknown.event"));
        expect(result.rawData, equals(rawData));
      },
    );

    test("sync event is recognized and ignored with preserved metadata", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "sync",
          "name": "message.updated.1",
          "id": "evt-1",
          "seq": 7,
          "aggregateID": "sessionID",
          "data": {
            "sessionID": "s1",
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.ignoredKnownEvent));
      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.eventType, equals("sync"));
      expect(result.rawData, equals(rawData));
    });

    test("malformed JSON returns null event and preserved rawData", () {
      final parser = SseEventParser();
      const rawData = "{not-json";

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedEnvelope));
      expect(result.event, isNull);
      expect(result.directory, isNull);
      expect(result.eventType, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("empty string returns null event and preserved rawData", () {
      final parser = SseEventParser();
      const rawData = "";

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedEnvelope));
      expect(result.event, isNull);
      expect(result.directory, isNull);
      expect(result.eventType, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("missing payload returns null event and preserved rawData", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({"directory": "/repo"});

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedEnvelope));
      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.eventType, isNull);
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

      expect(result.outcome, equals(SseParseOutcome.malformedEnvelope));
      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.eventType, isNull);
      expect(result.rawData, equals(rawData));
    });

    test("known event with malformed payload is categorized separately", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.status",
          "properties": {
            "sessionID": "s1",
            "status": {"unexpected": true},
          },
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedKnownPayload));
      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.eventType, equals("session.status"));
      expect(result.rawData, equals(rawData));
    });

    test("malformed payload envelope is categorized separately", () {
      final parser = SseEventParser();
      final rawData = jsonEncode({
        "directory": "/repo",
        "payload": {
          "type": "session.status",
          "properties": "not-a-map",
        },
      });

      final result = parser.parse(rawData);

      expect(result.outcome, equals(SseParseOutcome.malformedEnvelope));
      expect(result.event, isNull);
      expect(result.directory, equals("/repo"));
      expect(result.eventType, equals("session.status"));
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
