import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Exercises [AcpReplayCollector] — the `session/load` history reconstruction
/// that the bridge serves to the mobile chat screen.
void main() {
  group("AcpReplayCollector", () {
    Map<String, dynamic> upd(Map<String, dynamic> body) => {"update": body};

    final assistantParityCases = <({String name, List<Map<String, dynamic>> updates})>[
      (
        name: "mixed content in one chunk",
        updates: [
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "mixed",
            "content": [
              {"type": "text", "text": "before"},
              {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": "file:///private/output.png",
              },
              {"type": "text", "text": "after"},
            ],
          },
        ],
      ),
      (
        name: "inline and metadata images across chunks",
        updates: [
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "chunked",
            "content": {"type": "text", "text": "one "},
          },
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "chunked",
            "content": {"type": "text", "text": "two"},
          },
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "chunked",
            "content": {
              "type": "image",
              "data": "AA==",
              "mimeType": "image/svg+xml",
              "uri": "https://private.example/unsupported.svg",
            },
          },
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "chunked",
            "content": {
              "type": "image",
              "data": "AQ==",
              "mimeType": "image/png",
              "uri": null,
            },
          },
          {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "chunked",
            "content": {"type": "text", "text": "last"},
          },
        ],
      ),
    ];

    for (final testCase in assistantParityCases) {
      test("matches live assistant image parts for ${testCase.name}", () {
        final configurationTracker = AcpSessionConfigurationTracker();
        final mapper = AcpEventMapper(
          launchDirectory: "/repo",
          pluginId: "acp",
          configurationTracker: configurationTracker,
          childSessions: AcpChildSessionTracker(),
        )..beginTurn(sessionId: "s1", messageId: null);
        final collector = AcpReplayCollector(
          sessionId: "s1",
          agentId: "ACP",
          initialUserMessageId: null,
          messageIdOverride: null,
          messageTimeResolver: null,
          haltClassifier: null,
        );
        final liveEvents = <BridgeSseEvent>[];

        for (final body in testCase.updates) {
          collector.consume(upd(body));
          liveEvents.addAll(
            mapper.map(
              AcpNotification(
                method: "session/update",
                params: {"sessionId": "s1", "update": body},
              ),
            ),
          );
        }

        final replayParts = collector.build().single.parts;
        expect(replayParts, _materializedLiveParts(events: liveEvents));
        expect(
          replayParts.where((part) => part.type == PluginMessagePartType.file),
          isNotEmpty,
        );
      });
    }

    for (final content in [
      const [
        {"type": "text", "text": "before"},
        {"type": "image", "data": "AA==", "mimeType": "image/png", "uri": "file:///private/image.png"},
        {"type": "text", "text": "after"},
      ],
      const [
        {"type": "image", "data": "AA==", "mimeType": "image/png", "uri": "file:///private/image.png"},
      ],
    ]) {
      test(
        "replays ${content.length == 1 ? "attachment-only" : "mixed"} user content with stable initial identity",
        () {
          final collector =
              AcpReplayCollector(
                  sessionId: "s1",
                  agentId: "Cursor",
                  initialUserMessageId: "s1-initial-user",
                  messageIdOverride: null,
                  messageTimeResolver: null,
                  haltClassifier: null,
                )
                ..consume(
                  upd({
                    "sessionUpdate": "user_message_chunk",
                    "content": content,
                  }),
                )
                ..consume(
                  upd({
                    "sessionUpdate": "agent_message_chunk",
                    "content": {"type": "text", "text": "Hi"},
                  }),
                );

          final messages = collector.build();
          final initial = messages.first;
          expect(initial.info.id, "s1-initial-user");
          expect(initial.parts.map((part) => part.type), [
            if (content.length > 1) PluginMessagePartType.text,
            PluginMessagePartType.file,
            if (content.length > 1) PluginMessagePartType.text,
          ]);
          expect(initial.parts.first.id, content.length == 1 ? "s1-initial-user-image-1" : "s1-initial-user-text");
          expect(initial.parts.every((part) => part.messageID == initial.info.id), isTrue);
          final attachment = initial.parts.where((part) => part.type == PluginMessagePartType.file).single.attachment;
          expect(attachment, isA<PluginMessageAttachmentInlineImage>());
          expect((attachment as PluginMessageAttachmentInlineImage).base64, "AA==");
          expect(attachment.filename, isNull);
          expect(initial.parts.toString(), isNot(contains("/private/image.png")));
          expect(messages.last.info.id, "s1-h1-assistant");
        },
      );
    }

    test("reconstructs a user/tool/assistant exchange in order", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "user_message_chunk",
                "content": {"type": "text", "text": "list md files"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "execute",
                "title": "find . -name '*.md'",
                "status": "pending",
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call_update",
                "toolCallId": "t1",
                "status": "completed",
                "rawOutput": {"exitCode": 0, "stdout": "README.md\n", "stderr": ""},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "There is 1 file."},
              }),
            );

      final messages = collector.buildWithAssistantSelection(
        modelId: "gpt-5.5",
        providerId: "cursor",
        variant: null,
      );
      expect(messages, hasLength(3));

      final user = messages.first;
      expect(user.info, isA<PluginMessageUser>());
      expect(user.parts.single.text, "list md files");

      final toolMessage = messages[1];
      expect(toolMessage.info, isA<PluginMessageAssistant>());
      final toolPart = toolMessage.parts.single;
      expect(toolPart.state.status, PluginToolStatus.completed);
      expect(toolPart.state.output, "README.md");
      expect(messages.last.parts.single.text, "There is 1 file.");
    });

    test("replays standard tool content text without materializing other variants", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: null,
          )..consume(
            upd({
              "sessionUpdate": "tool_call",
              "toolCallId": "t1",
              "kind": "read",
              "status": "completed",
              "content": [
                {
                  "type": "content",
                  "content": {"type": "text", "text": "replayed output"},
                },
                {
                  "type": "diff",
                  "path": "/private/source.dart",
                  "oldText": "old",
                  "newText": "new",
                },
                {"type": "terminal", "terminalId": "private-terminal"},
              ],
            }),
          );

      final tool = collector.build().single.parts.single;
      expect(tool.state.output, "replayed output");
      expect(tool.state.attachments, isEmpty);
    });

    test("id-less text after a tool stays chronologically after the tool", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "Before"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "read",
                "status": "completed",
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "After"},
              }),
            );

      final messages = collector.build();
      expect(messages, hasLength(3));
      expect(messages[0].parts.single.text, "Before");
      expect(messages[1].parts.single.type, PluginMessagePartType.tool);
      expect(messages[2].parts.single.text, "After");
    });

    test("a partial (output-only) update does not reset a completed tool to pending", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "execute",
                "status": "pending",
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call_update",
                "toolCallId": "t1",
                "status": "completed",
                "rawOutput": {"stdout": "done"},
              }),
            )
            // An output-only update with NO status must keep the completed state.
            ..consume(
              upd({
                "sessionUpdate": "tool_call_update",
                "toolCallId": "t1",
                "rawOutput": {"stdout": "done (final)"},
              }),
            );

      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(
        toolPart.state.status,
        PluginToolStatus.completed,
        reason: "status-less update must not reset to pending",
      );
      expect(toolPart.state.output, "done (final)");
    });

    test("a title-only tool_call_update merges onto an existing draft (matches live)", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "edit",
                "status": "pending",
              }),
            )
            // A separate title-only update after the tool_call: replay must apply it
            // (the live mapper does), not silently drop it.
            ..consume(
              upd({
                "sessionUpdate": "tool_call_update",
                "toolCallId": "t1",
                "title": "Edit main.dart",
                "status": "in_progress",
              }),
            );
      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.tool, "edit");
      expect(toolPart.state.title, "Edit main.dart");
    });

    test("a non-string tool title does not throw mid-replay", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: null,
          )..consume(
            upd({
              "sessionUpdate": "tool_call",
              "toolCallId": "t1",
              "kind": "read",
              "title": {"unexpected": "object"},
              "status": "completed",
              "rawOutput": {"stdout": "x"},
            }),
          );
      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.tool, "read");
      expect(toolPart.state.title, isNull);
    });

    test("stamps replayed assistant messages with the loaded session selection", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: null,
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "hi"},
            }),
          );
      final assistant =
          collector
                  .buildWithAssistantSelection(
                    modelId: "claude-opus-4-8",
                    providerId: "cursor",
                    variant: "high",
                  )
                  .single
                  .info
              as PluginMessageAssistant;
      expect(assistant.modelID, "claude-opus-4-8");
      expect(assistant.providerID, "cursor");
      expect(assistant.variant, "high");
    });

    test("a messageId change splits consecutive same-role chunks into two messages", () {
      // ACP v1: chunks of one message share a messageId; a change starts a new
      // message. Without honouring it, distinct same-role messages collapse.
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m1",
                "content": {"type": "text", "text": "first"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m1",
                "content": {"type": "text", "text": " message"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m2",
                "content": {"type": "text", "text": "second message"},
              }),
            );

      final messages = collector.build();
      expect(messages, hasLength(2));
      expect(messages[0].parts.single.text, "first message");
      expect(messages[1].parts.single.text, "second message");
      expect(messages[0].info.id, isNot(messages[1].info.id));
    });

    test("chunks without a messageId keep the role-grouping behaviour", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "one"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": " flow"},
              }),
            );
      expect(collector.build().single.parts.single.text, "one flow");
    });

    test("unrenderable assistant chunks do not create empty replay messages", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": ""},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "audio", "data": "private", "mimeType": "audio/wav"},
              }),
            );

      expect(collector.build(), isEmpty);
    });

    test("a non-string session update discriminator is ignored", () {
      final collector = AcpReplayCollector(
        sessionId: "s1",
        agentId: "Cursor",
        initialUserMessageId: null,
        messageIdOverride: null,
        messageTimeResolver: null,
        haltClassifier: null,
      );

      expect(
        () => collector.consume(upd({"sessionUpdate": 42})),
        returnsNormally,
      );
      expect(collector.build(), isEmpty);
    });

    test("malformed replay chunks share warning state without creating a message", () {
      final collector = AcpReplayCollector(
        sessionId: "s1",
        agentId: "Cursor",
        initialUserMessageId: null,
        messageIdOverride: null,
        messageTimeResolver: null,
        haltClassifier: null,
      );
      final output = _captureWarnings(() {
        for (var index = 0; index < 2; index++) {
          collector.consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "messageId": "m1",
              "content": {"type": "text", "text": 42, "private": "secret"},
            }),
          );
        }
      });

      expect("malformed content block".allMatches(output), hasLength(1));
      expect(output, isNot(contains("secret")));
      expect(collector.build(), isEmpty);
    });

    test("replay materializes mixed assistant images in order", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "mixed",
                "content": {"type": "text", "text": "before"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "mixed",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": "file:///private/output.png",
                },
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "mixed",
                "content": {"type": "text", "text": "after"},
              }),
            );

      final message = collector.build().single;
      expect(message.parts, hasLength(3));
      expect(
        message.parts.map((part) => part.id),
        [
          "s1-mmixed-assistant-text",
          "s1-mmixed-assistant-image-1",
          "s1-mmixed-assistant-text-1",
        ],
      );
      expect(message.parts.map((part) => part.type), [
        PluginMessagePartType.text,
        PluginMessagePartType.file,
        PluginMessagePartType.text,
      ]);
      expect(
        message.parts.map(
          (part) => switch (part) {
            PluginMessagePartText(:final text) => text,
            PluginMessagePartFile() => null,
            _ => throw StateError("Unexpected mixed assistant part: ${part.type.name}"),
          },
        ),
        ["before", null, "after"],
      );
      final attachment = message.parts[1].attachment as PluginMessageAttachmentInlineImage;
      expect(attachment.base64, "AA==");
      expect(attachment.filename, "output.png");
    });

    final stampedAssistantChronologyCases = [
      (
        name: "text/tool/image",
        beforeTool: <String, dynamic>{"type": "text", "text": "before"},
        afterTool: <String, dynamic>{
          "type": "image",
          "data": "AA==",
          "mimeType": "image/png",
          "uri": null,
        },
        expectedTypes: <PluginMessagePartType>[
          PluginMessagePartType.text,
          PluginMessagePartType.tool,
          PluginMessagePartType.file,
        ],
      ),
      (
        name: "image/tool/text",
        beforeTool: <String, dynamic>{
          "type": "image",
          "data": "AA==",
          "mimeType": "image/png",
          "uri": null,
        },
        afterTool: <String, dynamic>{"type": "text", "text": "after"},
        expectedTypes: <PluginMessagePartType>[
          PluginMessagePartType.file,
          PluginMessagePartType.tool,
          PluginMessagePartType.text,
        ],
      ),
      (
        name: "text/tool/text",
        beforeTool: <String, dynamic>{"type": "text", "text": "before"},
        afterTool: <String, dynamic>{"type": "text", "text": "after"},
        expectedTypes: <PluginMessagePartType>[
          PluginMessagePartType.text,
          PluginMessagePartType.tool,
          PluginMessagePartType.text,
        ],
      ),
    ];

    for (final testCase in stampedAssistantChronologyCases) {
      test("preserves ${testCase.name} chronology in one stamped assistant draft", () {
        final collector =
            AcpReplayCollector(
                sessionId: "s1",
                agentId: "Cursor",
                initialUserMessageId: null,
                messageIdOverride: null,
                messageTimeResolver: null,
                haltClassifier: null,
              )
              ..consume(
                upd({
                  "sessionUpdate": "agent_message_chunk",
                  "messageId": "m1",
                  "content": testCase.beforeTool,
                }),
              )
              ..consume(
                upd({
                  "sessionUpdate": "tool_call_update",
                  "toolCallId": "t1",
                  "status": "completed",
                  "rawOutput": {"stdout": "done"},
                }),
              )
              ..consume(
                upd({
                  "sessionUpdate": "agent_message_chunk",
                  "messageId": "m1",
                  "content": testCase.afterTool,
                }),
              )
              ..consume(
                upd({
                  "sessionUpdate": "tool_call",
                  "toolCallId": "t1",
                  "kind": "read",
                  "title": "Read source.dart",
                }),
              );

        final message = collector.build().single;
        expect(message.info.id, "s1-mm1-assistant");
        expect(message.parts.map((part) => part.type), testCase.expectedTypes);
        expect(message.parts.map((part) => part.id).toSet(), hasLength(message.parts.length));
        final tool = message.parts.singleWhere((part) => part.type == PluginMessagePartType.tool);
        expect(tool.tool, "read");
        expect(tool.state.status, PluginToolStatus.completed);
        expect(tool.state.title, "Read source.dart");
        expect(tool.state.output, "done");
      });
    }

    test("an id-less image closes its replay draft before a following tool", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": null,
                },
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "read",
                "status": "completed",
              }),
            );

      final messages = collector.build();
      expect(messages, hasLength(2));
      expect(messages.first.parts.single.type, PluginMessagePartType.file);
      expect(
        messages.first.parts.single.attachment,
        isA<PluginMessageAttachmentInlineImage>(),
      );
      expect(messages.last.parts.single.type, PluginMessagePartType.tool);
    });

    test("an explicit messageId after id-less text starts a new message", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "id-less draft"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m2",
                "content": {"type": "text", "text": "identified message"},
              }),
            );

      final messages = collector.build();
      expect(messages, hasLength(2));
      expect(messages[0].parts.single.text, "id-less draft");
      expect(messages[1].parts.single.text, "identified message");
    });

    test("id-less text after an explicit messageId starts a new message", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m1",
                "content": {"type": "text", "text": "identified message"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "id-less message"},
              }),
            );

      final messages = collector.build();
      expect(messages, hasLength(2));
      expect(messages[0].parts.single.text, "identified message");
      expect(messages[1].parts.single.text, "id-less message");
    });

    test("a same-message thought and text share the message; tools attach without an id", () {
      final collector =
          AcpReplayCollector(
              sessionId: "s1",
              agentId: "Cursor",
              initialUserMessageId: null,
              messageIdOverride: null,
              messageTimeResolver: null,
              haltClassifier: null,
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_thought_chunk",
                "messageId": "m1",
                "content": {"type": "text", "text": "thinking"},
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "tool_call",
                "toolCallId": "t1",
                "kind": "read",
                "status": "completed",
              }),
            )
            ..consume(
              upd({
                "sessionUpdate": "agent_message_chunk",
                "messageId": "m1",
                "content": {"type": "text", "text": "answer"},
              }),
            );

      final message = collector.build().single;
      expect(
        message.parts.map((p) => p.type),
        containsAll(<PluginMessagePartType>[
          PluginMessagePartType.reasoning,
          PluginMessagePartType.text,
          PluginMessagePartType.tool,
        ]),
      );
    });

    test("a halt notice replays as an error message with no text part", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: ({required text}) =>
                text.trim() == "Check your settings to continue" ? const AcpHaltNotice(errorName: "cursor_gate") : null,
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "\n\nCheck your settings to continue"},
            }),
          );

      final message = collector
          .buildWithAssistantSelection(
            modelId: "claude-fable-5",
            providerId: "cursor",
            variant: null,
          )
          .single;
      expect(message.info, isA<PluginMessageError>());
      expect((message.info as PluginMessageError).errorMessage, "\n\nCheck your settings to continue");
      expect(message.parts, isEmpty);
    });

    test("an identified halt-like message remains assistant content", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: ({required text}) => const AcpHaltNotice(errorName: "cursor_gate"),
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "messageId": "m1",
              "content": {"type": "text", "text": "Check your settings to continue"},
            }),
          );

      expect(collector.build().single.info, isA<PluginMessageAssistant>());
    });

    test("an image-bearing halt-like message remains an assistant message", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: ({required text}) => const AcpHaltNotice(errorName: "cursor_gate"),
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "content": [
                {
                  "type": "image",
                  "data": "AA==",
                  "mimeType": "image/png",
                  "uri": null,
                },
                {"type": "text", "text": "Check your settings to continue"},
              ],
            }),
          );

      final message = collector.build().single;
      expect(message.info, isA<PluginMessageAssistant>());
      expect(message.parts.map((part) => part.type), [
        PluginMessagePartType.file,
        PluginMessagePartType.text,
      ]);
      expect(message.parts.last.text, "Check your settings to continue");
    });

    test("unsupported content keeps halt-like replay text as an assistant message", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: ({required text}) => const AcpHaltNotice(errorName: "cursor_gate"),
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "content": [
                {"type": "text", "text": "Check your settings to continue"},
                {"type": "audio", "data": "private", "mimeType": "audio/wav"},
              ],
            }),
          );

      final message = collector.build().single;
      expect(message.info, isA<PluginMessageAssistant>());
      expect(message.parts.single.text, "Check your settings to continue");
    });

    test("without a halt classifier the same chunk stays assistant text", () {
      final collector =
          AcpReplayCollector(
            sessionId: "s1",
            agentId: "Cursor",
            initialUserMessageId: null,
            messageIdOverride: null,
            messageTimeResolver: null,
            haltClassifier: null,
          )..consume(
            upd({
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "Check your settings to continue"},
            }),
          );
      final message = collector.build().single;
      expect(message.info, isA<PluginMessageAssistant>());
      expect(message.parts, isNotEmpty);
    });
  });
}

List<PluginMessagePart> _materializedLiveParts({
  required List<BridgeSseEvent> events,
}) {
  final parts = <String, PluginMessagePart>{};
  for (final event in events) {
    if (event case BridgeSseMessagePartUpdated(:final part)) {
      parts[part.id] = part;
    } else if (event case BridgeSseMessagePartDelta(
      :final partID,
      field: "text",
      :final delta,
    )) {
      final prior = parts[partID]!;
      parts[partID] = switch (prior) {
        PluginMessagePartText(:final text) => prior.copyWith(text: "$text$delta"),
        PluginMessagePartReasoning(:final text) => prior.copyWith(text: "$text$delta"),
        _ => throw StateError("Cannot apply text delta to ${prior.type.name}"),
      };
    }
  }
  return parts.values.toList(growable: false);
}

String _captureWarnings(void Function() action) {
  final previousLevel = Log.level;
  final stderr = BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}
