import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:cursor_plugin/src/repositories/cursor_generated_image_reader.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

void main() {
  group("CursorEventMapper", () {
    CursorEventMapper buildMapper({String? Function()? activeSessionResolver}) {
      return CursorEventMapper(
        launchDirectory: "/repo",
        pluginId: CursorPlugin.pluginId,
        configurationTracker: AcpSessionConfigurationTracker(),
        generatedImageReader: const CursorGeneratedImageReader(),
        activeSessionResolver: activeSessionResolver ?? () => null,
      );
    }

    final mapper = buildMapper();

    // Microsecond-stamped names: parallel worktrees run this suite against the
    // same systemTemp concurrently, so fixed names can race.
    File writeTempPng(String prefix) {
      final file = File(
        "${Directory.systemTemp.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.png",
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );
      return file;
    }

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
      mapper.beginTurn(sessionId: "s1", messageId: null);
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
      mapper.beginTurn(sessionId: "s-image", messageId: null);
      final file = writeTempPng("cursor-event-mapper");

      final part = mapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {"sessionId": "s-image", "filePath": file.path},
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "s-image");
    });

    test("cursor/generate_image finalizes active reasoning before the image", () async {
      final imageMapper = buildMapper();
      imageMapper.beginTurn(sessionId: "s-thinking-image", messageId: null);
      imageMapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s-thinking-image",
            "update": {
              "sessionUpdate": "agent_thought_chunk",
              "content": {"type": "text", "text": "Designing the image"},
            },
          },
        ),
      );
      final file = writeTempPng("cursor-reasoning-image");

      final events = imageMapper.map(
        AcpNotification(
          method: "cursor/generate_image",
          params: {"sessionId": "s-thinking-image", "filePath": file.path},
        ),
      );

      final parts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
      expect(parts, hasLength(2));
      expect(parts.first.type, PluginMessagePartType.reasoning);
      expect((parts.first as PluginMessagePartReasoning).text, "Designing the image");
      expect(parts.last.type, PluginMessagePartType.file);
    });

    test("cursor/generate_image accepts legacy path params", () async {
      mapper.beginTurn(sessionId: "s-image-legacy", messageId: null);
      final file = writeTempPng("cursor-event-mapper-legacy");

      expect(
        mapper
            .map(
              AcpNotification(
                method: "cursor/generate_image",
                params: {"sessionId": "s-image-legacy", "path": file.path},
              ),
            )
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part
            .type,
        PluginMessagePartType.file,
      );
    });

    test("cursor/generate_image resolves sessionId from the plugin's active turn", () async {
      // No sessionId and no toolCallId in the payload: attribution comes from
      // the plugin-supplied resolver, not any mapper-side turn tracking.
      final turnMapper = buildMapper(activeSessionResolver: () => "s-active");
      final file = writeTempPng("cursor-active-turn-image");

      final part = turnMapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {"filePath": file.path, "description": "test"},
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "s-active");
    });

    test("cursor/generate_image prefers the originating toolCallId over the active turn", () async {
      // The resolver answers a different session than the one owning the tool
      // call, so this fails if the toolCallId chain is broken or deleted.
      final chainMapper = buildMapper(activeSessionResolver: () => "s-other");
      final file = writeTempPng("cursor-toolcall-image");

      chainMapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "sA",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "img-tool-1",
              "title": "Generate Image: test",
              "status": "completed",
            },
          },
        ),
      );

      final part = chainMapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {
                "toolCallId": "img-tool-1",
                "filePath": file.path,
                "description": "test",
              },
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "sA");
    });

    test("cursor/generate_image rejects a relative source path, even one that exists", () {
      // A relative path resolves against the bridge process CWD, not the
      // session's project — it must be rejected at the boundary, never read.
      final name = "cursor-relative-image-${DateTime.now().microsecondsSinceEpoch}.png";
      final file = File(name);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      final relativeMapper = buildMapper(activeSessionResolver: () => "s-rel");
      expect(
        relativeMapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"sessionId": "s-rel", "filePath": name},
          ),
        ),
        isEmpty,
      );
    });

    test("cursor/generate_image with no resolvable session drops the payload", () async {
      // No sessionId, no toolCallId, resolver answers null: the payload must be
      // dropped — an event stamped with "" would be discarded by the client.
      final orphanMapper = buildMapper();
      final file = writeTempPng("cursor-orphan-image");

      expect(
        orphanMapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"filePath": file.path, "description": "test"},
          ),
        ),
        isEmpty,
      );
    });

    test("generate_image lands as an ordered part inside the live assistant message", () {
      // The whole point of routing through appendAssistantImageBlocks is that
      // the image joins the in-progress assistant message in stream order,
      // instead of being emitted as a standalone sidecar message.
      final orderedMapper = buildMapper();
      orderedMapper.beginTurn(sessionId: "s1", messageId: null);
      final file = writeTempPng("cursor-ordered-image");
      const messageId = "s1-t1-assistant-a0";

      AcpNotification textChunk(String text) => AcpNotification(
        method: "session/update",
        params: {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": text},
          },
        },
      );

      final first = orderedMapper.map(textChunk("Here it is:"));
      final image = orderedMapper.map(
        AcpNotification(
          method: "cursor/generate_image",
          params: {"sessionId": "s1", "filePath": file.path},
        ),
      );
      final second = orderedMapper.map(textChunk("Done."));

      expect(first.whereType<BridgeSseMessagePartDelta>().single.partID, "$messageId-text");

      final imagePart = image.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(imagePart.id, "$messageId-image-1");
      expect(imagePart.messageID, messageId);
      expect(
        image.whereType<BridgeSseMessageUpdated>(),
        isEmpty,
        reason: "the image must join the live message, not open a new envelope",
      );

      expect(second.whereType<BridgeSseMessagePartDelta>().single.partID, "$messageId-text-1");
      expect(second.whereType<BridgeSseMessageUpdated>(), isEmpty);
    });

    test("standard ACP images still work alongside cursor generate_image", () {
      mapper.beginTurn(sessionId: "s-image", messageId: null);
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
      mapper.beginTurn(sessionId: "sg", messageId: null);
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
        "\n\nCheck your settings to continue",
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
