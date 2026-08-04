import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

void main() {
  group("CursorEventMapper", () {
    final mapper = CursorEventMapper(
      launchDirectory: "/repo",
      pluginId: CursorPlugin.pluginId,
      configurationTracker: AcpSessionConfigurationTracker(),
      contentMapper: const AcpContentMapper(),
    );

    test("cursor/update_todos maps to a todo update", () {
      final events = mapper.map(
        const AcpNotification(
          method: "cursor/update_todos",
          params: {"sessionId": "s1", "todos": <Object?>[]},
        ),
      );
      expect(events.single, isA<BridgeSseTodoUpdated>());
      expect((events.single as BridgeSseTodoUpdated).sessionID, "s1");
    });

    test("other cursor extensions are dropped", () {
      expect(
        mapper.map(const AcpNotification(method: "cursor/task", params: {})),
        isEmpty,
      );
    });

    test("standard session/update still works via the base mapper", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s1",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "hi"},
            },
          },
        ),
      );
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "hi");
    });

    test("cursor/generate_image maps to a standard inline file part", () async {
      mapper.beginTurn("s-image");
      final file = File("${Directory.systemTemp.path}/cursor-event-mapper-${DateTime.now().microsecondsSinceEpoch}.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      expect(
        mapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"sessionId": "s-image", "filePath": file.path},
          ),
        ).whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.file,
      );
    });

    test("cursor/generate_image accepts legacy path params", () async {
      mapper.beginTurn("s-image-legacy");
      final file = File("${Directory.systemTemp.path}/legacy-output.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      expect(
        mapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"sessionId": "s-image-legacy", "path": file.path},
          ),
        ).whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.file,
      );
    });

    test("cursor/generate_image resolves sessionId from active turn", () async {
      final resolverMapper = CursorEventMapper(
        launchDirectory: "/repo",
        pluginId: CursorPlugin.pluginId,
        configurationTracker: AcpSessionConfigurationTracker(),
        contentMapper: const AcpContentMapper(),
        activeSessionResolver: () => "s-active",
      );
      resolverMapper.beginTurn("s-active");
      final file = File("${Directory.systemTemp.path}/cursor-active-turn-image.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      expect(
        resolverMapper
            .map(
              AcpNotification(
                method: "cursor/generate_image",
                params: {"filePath": file.path, "description": "test"},
              ),
            )
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part
            .type,
        PluginMessagePartType.file,
      );
    });

    test("cursor/generate_image resolves sessionId from toolCallId", () async {
      mapper.beginTurn("s1");
      final file = File("${Directory.systemTemp.path}/cursor-toolcall-image.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s1",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "img-tool-1",
              "title": "Generate Image: test",
              "status": "completed",
            },
          },
        ),
      );

      expect(
        mapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {
              "toolCallId": "img-tool-1",
              "filePath": file.path,
              "description": "test",
            },
          ),
        ).whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.file,
      );
    });

    test("standard ACP images still work alongside cursor generate_image", () {
      mapper.beginTurn("s-image");
      final standard = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s-image",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": null,
              },
            },
          },
        ),
      );
      expect(
        standard.whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.file,
      );
    });

    test("an account/plan gate notice becomes an error message, not assistant text", () {
      mapper.beginTurn("sg");
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "sg",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              // Exact wire capture from cursor-agent when a gated model is used.
              "content": {"type": "text", "text": "\n\nCheck your settings to continue"},
            },
          },
        ),
      );
      final message = shared.Message.fromJson(
        events.whereType<BridgeSseMessageUpdated>().single.info,
      );
      expect(message, isA<shared.MessageError>());
      expect(
        (message as shared.MessageError).errorMessage,
        "Check your settings to continue",
      );
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("gate matching tolerates case and surrounding decoration", () {
      expect(mapper.classifyHaltNotice(text: "  CHECK YOUR SETTINGS TO CONTINUE.  "), isNotNull);
      expect(mapper.classifyHaltNotice(text: "⚠️ Check your settings to continue"), isNotNull);
    });

    test("non-ASCII letters are content, not strippable decoration", () {
      // Letters (any script) adjacent to the phrase mean the message is more
      // than the gate notice; only punctuation/symbol/emoji decoration is
      // stripped before the exact match.
      expect(mapper.classifyHaltNotice(text: "É Check your settings to continue"), isNull);
    });

    test("ordinary prose that merely contains the phrase is not a gate", () {
      expect(
        mapper.classifyHaltNotice(
          text: "Sure — check your settings to continue setting up the project, then rerun.",
        ),
        isNull,
      );
    });
  });
}
