import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("live/replay ACP tool parity", () {
    final toolParityCases = <({String name, List<Map<String, dynamic>> updates})>[
      (
        name: "partial output updates preserve mixed content attachments",
        updates: [
          {
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "status": "in_progress",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "standard output"},
              },
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/output.png",
                },
              },
            ],
          },
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "status": "completed",
          },
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "rawOutput": {"stdout": "final output\n"},
          },
        ],
      ),
      (
        name: "image-only content replaces earlier mixed content",
        updates: [
          {
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "status": "in_progress",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "old output"},
              },
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/old.png",
                },
              },
            ],
          },
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "content": [
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AQ==",
                  "mimeType": "image/png",
                  "uri": "file:///private/new.png",
                },
              },
            ],
          },
        ],
      ),
      (
        name: "a late base call cannot replace a newer attachment",
        updates: [
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "status": "completed",
            "content": [
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/new.png",
                },
              },
            ],
          },
          {
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "title": "Read source.dart",
            "status": "pending",
            "content": [
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AQ==",
                  "mimeType": "image/png",
                  "uri": "file:///private/stale.png",
                },
              },
            ],
          },
        ],
      ),
    ];

    for (final testCase in toolParityCases) {
      test("matches live tool attachment state for ${testCase.name}", () {
        final mapper = AcpEventMapper(
          launchDirectory: "/repo",
          pluginId: "acp",
          configurationTracker: AcpSessionConfigurationTracker(),
          childSessions: AcpChildSessionTracker(),
        );
        final collector = _collector();
        PluginMessagePart? livePart;

        for (final body in testCase.updates) {
          final events = mapper.map(
            AcpNotification(
              method: "session/update",
              params: {"sessionId": "s1", "update": body},
            ),
          );
          livePart = events.whereType<BridgeSseMessagePartUpdated>().single.part;
          collector.consume({"update": body});
        }

        final replayPart = collector.build().single.parts.single;
        expect(replayPart.tool, livePart!.tool);
        expect(replayPart.state, livePart.state);
        expect(replayPart.state.attachments, isNotEmpty);
      });
    }
  });

  group("live ACP tool content", () {
    late AcpEventMapper mapper;

    setUp(() {
      mapper = AcpEventMapper(
        launchDirectory: "/repo",
        pluginId: "acp",
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: AcpChildSessionTracker(),
      );
    });

    AcpNotification update(Map<String, dynamic> body) => AcpNotification(
      method: "session/update",
      params: {"sessionId": "s1", "update": body},
    );

    test("omission and raw output preserve attachments while empty content clears", () {
      final initial = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "read",
          "status": "in_progress",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "standard output"},
            },
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": "file:///private/first.png",
              },
            },
          ],
        }),
      );
      final initialState = _liveState(events: initial);
      expect(initialState.output, "standard output");
      expect(initialState.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(initialState.attachments.single.filename, "first.png");

      final omitted = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
        }),
      );
      expect(_liveState(events: omitted).output, "standard output");
      expect(_liveState(events: omitted).attachments.single.filename, "first.png");

      final rawOutput = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "rawOutput": {"stdout": "fallback output\n"},
        }),
      );
      expect(_liveState(events: rawOutput).output, "fallback output");
      expect(_liveState(events: rawOutput).attachments.single.filename, "first.png");

      final cleared = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "content": const <Object?>[],
        }),
      );
      expect(_liveState(events: cleared).output, isNull);
      expect(_liveState(events: cleared).attachments, isEmpty);
    });

    test("image-only content replaces prior output and attachments", () {
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "read",
          "status": "in_progress",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "old output"},
            },
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": "file:///private/old.png",
              },
            },
          ],
        }),
      );

      final replacement = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "content": [
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AQ==",
                "mimeType": "image/png",
                "uri": "file:///private/new.png",
              },
            },
          ],
        }),
      );

      final state = _liveState(events: replacement);
      expect(state.output, isNull);
      expect(state.attachments, hasLength(1));
      expect(state.attachments.single.filename, "new.png");
    });

    test("diff content replaces attachments and keeps one-shot diff signaling", () {
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "read",
          "status": "in_progress",
          "content": [
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": null,
              },
            },
          ],
        }),
      );

      final replacement = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "content": [
            {
              "type": "diff",
              "path": "/private/source.dart",
              "oldText": "old",
              "newText": "new",
            },
          ],
        }),
      );
      expect(_liveState(events: replacement).output, isNull);
      expect(_liveState(events: replacement).attachments, isEmpty);
      expect(replacement.whereType<BridgeSseSessionDiff>(), isEmpty);

      final completed = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
        }),
      );
      expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("explicit non-terminal diff content waits for completion", () {
      final running = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "in_progress",
          "content": [
            {
              "type": "diff",
              "path": "/private/source.dart",
              "oldText": "old",
              "newText": "new",
            },
          ],
        }),
      );
      expect(running.whereType<BridgeSseSessionDiff>(), isEmpty);

      final completed = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
        }),
      );
      expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("malformed status lets a later tool_call supply live status", () {
      mapper.map(
        update({"sessionUpdate": "tool_call_update", "toolCallId": "t1", "status": 42}),
      );

      final call = mapper.map(
        update({"sessionUpdate": "tool_call", "toolCallId": "t1", "status": "completed"}),
      );

      expect(_liveState(events: call).status, PluginToolStatus.completed);
    });

    test("a late tool_call enriches without clobbering a first-seen update", () {
      final firstSeen = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "new output"},
            },
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": "file:///private/new.png",
              },
            },
            {
              "type": "diff",
              "path": "/private/source.dart",
              "oldText": "old",
              "newText": "new",
            },
          ],
        }),
      );
      expect(firstSeen.whereType<BridgeSseSessionDiff>(), hasLength(1));

      final lateCall = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "edit",
          "title": "Edit source.dart",
          "status": "pending",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "stale output"},
            },
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AQ==",
                "mimeType": "image/png",
                "uri": "file:///private/stale.png",
              },
            },
          ],
        }),
      );

      expect(lateCall.whereType<BridgeSseMessageUpdated>(), isEmpty);
      final state = _liveState(events: lateCall);
      expect(lateCall.whereType<BridgeSseMessagePartUpdated>().single.part.tool, "edit");
      expect(state.title, "Edit source.dart");
      expect(state.status, PluginToolStatus.completed);
      expect(state.output, "new output");
      expect(state.attachments.single.filename, "new.png");
      expect(lateCall.whereType<BridgeSseSessionDiff>(), isEmpty);
    });
  });

  group("replayed ACP tool content", () {
    Map<String, dynamic> update(Map<String, dynamic> body) => {"update": body};

    test("applies the same replacement state with attachments", () {
      final collector = _collector()
        ..consume(
          update({
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "status": "in_progress",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "standard output"},
              },
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/output.png",
                },
              },
            ],
          }),
        );

      var state = _replayState(collector: collector);
      expect(state.output, "standard output");
      expect(state.attachments.single.filename, "output.png");
      expect(state.attachments.single, isA<PluginMessageAttachmentInlineImage>());

      collector.consume(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
        }),
      );
      state = _replayState(collector: collector);
      expect(state.output, "standard output");
      expect(state.attachments.single.filename, "output.png");

      collector.consume(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "rawOutput": {"stdout": "fallback output\n"},
        }),
      );
      state = _replayState(collector: collector);
      expect(state.output, "fallback output");
      expect(state.attachments.single.filename, "output.png");

      collector.consume(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "content": const <Object?>[],
        }),
      );
      expect(_replayState(collector: collector).output, isNull);
      expect(_replayState(collector: collector).attachments, isEmpty);
    });

    test("image-only content replaces prior replay output and attachment", () {
      final collector = _collector()
        ..consume(
          update({
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "status": "in_progress",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "old output"},
              },
            ],
          }),
        )
        ..consume(
          update({
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "content": [
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": null,
                },
              },
            ],
          }),
        );

      final state = _replayState(collector: collector);
      expect(state.output, isNull);
      expect(state.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(
        (state.attachments.single as PluginMessageAttachmentInlineImage).base64,
        "AA==",
      );
    });

    test("malformed status lets a later tool_call supply replay status", () {
      final collector = _collector()
        ..consume(
          update({"sessionUpdate": "tool_call_update", "toolCallId": "t1", "status": 42}),
        )
        ..consume(
          update({"sessionUpdate": "tool_call", "toolCallId": "t1", "status": "completed"}),
        );

      expect(_replayState(collector: collector).status, PluginToolStatus.completed);
    });

    test("a late tool_call enriches without clobbering a first-seen replay update", () {
      final collector = _collector()
        ..consume(
          update({
            "sessionUpdate": "tool_call_update",
            "toolCallId": "t1",
            "status": "completed",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "new output"},
              },
              {
                "type": "content",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/new.png",
                },
              },
            ],
          }),
        )
        ..consume(
          update({
            "sessionUpdate": "tool_call",
            "toolCallId": "t1",
            "kind": "read",
            "title": "Read source.dart",
            "status": "pending",
            "content": [
              {
                "type": "content",
                "content": {"type": "text", "text": "stale output"},
              },
            ],
          }),
        );

      final part = collector.build().single.parts.single;
      expect(part.tool, "read");
      expect(part.state.title, "Read source.dart");
      expect(part.state.status, PluginToolStatus.completed);
      expect(part.state.output, "new output");
      expect(part.state.attachments.single.filename, "new.png");
    });
  });
}

PluginToolState _liveState({required List<BridgeSseEvent> events}) =>
    events.whereType<BridgeSseMessagePartUpdated>().single.part.state;

AcpReplayCollector _collector() => AcpReplayCollector(
  sessionId: "s1",
  agentId: "ACP",
  initialUserMessageId: null,
  messageIdOverride: null,
  messageTimeResolver: null,
  haltClassifier: null,
  toolPartReplacement: null,
);

PluginToolState _replayState({required AcpReplayCollector collector}) => collector.build().single.parts.single.state;
