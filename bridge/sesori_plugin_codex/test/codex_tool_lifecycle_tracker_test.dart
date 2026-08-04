import "package:codex_plugin/src/api/models/codex_image_bearing_item_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_tool_lifecycle_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = CodexRolloutToolMapper(
    imageAttachmentMapper: CodexImageAttachmentMapper(),
  );

  CodexToolLifecycleTracker tracker() => CodexToolLifecycleTracker(
    rolloutToolMapper: mapper,
  );

  test("correlates app-server command ids with rollout calls in turn order", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-2", turnId: "turn-1"),
      );

    final firstStarted = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final firstCompleted = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
      ),
    );
    final secondStarted = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-2",
        turnId: "turn-1",
      ),
    );

    expect(firstStarted?.canonicalId, "call-1");
    expect(firstCompleted?.canonicalId, "call-1");
    expect(firstCompleted?.status, PluginToolStatus.completed);
    expect(secondStarted?.canonicalId, "call-2");

    target.clearThread(threadId: "thread-1");
    expect(
      target.observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/completed",
          itemId: "exec-2",
          turnId: "turn-1",
        ),
      ),
      isNull,
    );
  });

  test("leaves commands native when rollout turn metadata is unavailable", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _shellCall(callId: "call-1", turnId: null),
    );

    expect(
      target.observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      ),
      isNull,
    );
  });

  test("task_started turn identity is inherited by metadata-less calls", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: null),
      );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-1",
              turnId: "turn-1",
            ),
          )
          ?.canonicalId,
      "call-1",
    );
  });

  test("user_message retains the active task turn for command correlation", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _userMessageEvent(message: "run it"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: null),
      );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-1",
              turnId: "turn-1",
            ),
          )
          ?.canonicalId,
      "call-1",
    );
  });

  test("excludes raw-only custom exec calls from command correlation", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-raw", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: "turn-1"),
      );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-1",
              turnId: "turn-1",
            ),
          )
          ?.canonicalId,
      "call-1",
    );
  });

  test("correlates a lone code-mode command with its app-server item", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _rawExecCall(callId: "call-raw", turnId: "turn-1"),
    );

    final started = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    final completed = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
      ),
    );

    expect(started?.canonicalId, "call-raw");
    expect(completed?.canonicalId, "call-raw");
    expect(completed?.status, PluginToolStatus.completed);
  });

  test("correlates code-mode commands containing invocation-like text", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _codeModeExecCall(
        callId: "call-raw",
        turnId: "turn-1",
        input: "await tools.exec_command({cmd: \"echo 'tools.exec_command('\"});",
      ),
    );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-1",
              turnId: "turn-1",
            ),
          )
          ?.canonicalId,
      "call-raw",
    );
  });

  test("correlates code-mode commands with invocation whitespace", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _codeModeExecCall(
        callId: "call-raw",
        turnId: "turn-1",
        input: "await tools.exec_command ({cmd: 'pwd'});",
      ),
    );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-1",
              turnId: "turn-1",
            ),
          )
          ?.canonicalId,
      "call-raw",
    );
  });

  test("does not correlate invocation text inside a string", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _codeModeExecCall(
        callId: "call-raw",
        turnId: "turn-1",
        input: "console.log('tools.exec_command(');",
      ),
    );

    expect(
      target.observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      ),
      isNull,
    );
  });

  test("suppresses only complete generated image wrapper invocations", () {
    final target = tracker();
    final wrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-image-wrapper",
        "name": "exec",
        "input": "await tools.image_gen__generate({prompt: 'private'});",
      },
    });
    final literalSearch = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-search",
        "name": "exec",
        "input": "console.log('tools.image_gen__generate')",
      },
    });
    final forwardedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-forwarded-image-wrapper",
        "name": "exec",
        "input": "const result = await tools.image_gen__generate({prompt: 'private'}); generatedImage(result);",
      },
    });
    final directedForwardedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-directed-image-wrapper",
        "name": "exec",
        "input":
            "// @exec: {\"yield_time_ms\": 120000}\nconst r = await tools.image_gen__imagegen({prompt: 'private'}); generatedImage(r);",
      },
    });
    final contentForwardedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-content-forwarded-image-wrapper",
        "name": "exec",
        "input":
            '// @exec: {"yield_time_ms": 120000, "max_output_tokens": 2000}\n'
            "const r = await tools.image_gen__imagegen({prompt: 'private'});\n"
            "for (const c of (r?.content ?? [])) {\n"
            '  if (c.type === "image") image(c);\n'
            '  else if (c.type === "text") text(c.text);\n'
            "}\n"
            "if (r?.image_url) generatedImage(r);\n"
            "text(JSON.stringify({structuredContent:r?.structuredContent,_meta:r?._meta}));\n",
      },
    });
    final previewForwardedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-preview-forwarded-image-wrapper",
        "name": "exec",
        "input":
            '// @exec: {"yield_time_ms": 120000, "max_output_tokens": 2000}\n'
            "const r = await tools.image_gen__imagegen({prompt: 'private'});\n"
            "for (const c of (r?.content ?? [])) {\n"
            '  if (c.type === "image") image(c);\n'
            '  else if (c.type === "text") text(c.text);\n'
            "}\n"
            "if (r?.image_url) generatedImage(r);\n",
      },
    });
    final imageWrapperWithAnotherTool = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-image-wrapper-with-another-tool",
        "name": "exec",
        "input":
            "const r = await tools.image_gen__imagegen({prompt: 'private'});\n"
            "await tools.exec_command({cmd: 'pwd'});\n"
            "for (const c of (r?.content ?? [])) {\n"
            '  if (c.type === "image") image(c);\n'
            '  else if (c.type === "text") text(c.text);\n'
            "}\n"
            "if (r?.image_url) generatedImage(r);\n"
            "text(JSON.stringify({structuredContent:r?.structuredContent,_meta:r?._meta}));\n",
      },
    });
    final wrapperWithShadowedResultVariable = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-image-wrapper-with-shadowed-result",
        "name": "exec",
        "input":
            "const r = await tools.image_gen__imagegen({prompt: 'private'});\n"
            "for (const r of (r?.content ?? [])) {\n"
            '  if (r.type === "image") image(r);\n'
            '  else if (r.type === "text") text(r.text);\n'
            "}\n"
            "if (r?.image_url) generatedImage(r);\n",
      },
    });
    final malformedDirectedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-malformed-directed-image-wrapper",
        "name": "exec",
        "input":
            "// @exec: {invalid}\nconst r = await tools.image_gen__imagegen({prompt: 'private'}); generatedImage(r);",
      },
    });
    final multilineDirectedMarker = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-multiline-directed-marker",
        "name": "exec",
        "input": "//\n@exec: {\"yield_time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: 'private'});",
      },
    });
    final mixedDirectedWrapper = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-mixed-directed-image-wrapper",
        "name": "exec",
        "input":
            "// @exec: {\"yield_time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: 'private'}); await tools.exec_command({cmd: 'keep visible'});",
      },
    });
    final directedWrapperWithTrailingCode = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-directed-image-wrapper-with-trailing-code",
        "name": "exec",
        "input":
            "// @exec: {\"yield-time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: 'private'}); console.log('keep visible');",
      },
    });
    final directedWrapperWithCallLikePrompt = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-directed-image-wrapper-with-call-like-prompt",
        "name": "exec",
        "input": "// @exec: {\"yield_time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: 'draw cat(s)'});",
      },
    });
    final directedWrapperWithParenthesizedTrailingCode = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-directed-image-wrapper-with-parenthesized-trailing-code",
        "name": "exec",
        "input":
            "// @exec: {\"yield_time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: 'private'}); process.exitCode = (1);",
      },
    });
    final directedWrapperWithNestedToolCall = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-directed-image-wrapper-with-nested-tool",
        "name": "exec",
        "input":
            "// @exec: {\"yield_time_ms\": 120000}\nawait tools.image_gen__imagegen({prompt: (await tools.exec_command({cmd: 'keep visible'}), 'cat')});",
      },
    });
    final unrelatedForwarding = CodexRolloutLineDto.fromJson({
      "type": "response_item",
      "payload": {
        "type": "custom_tool_call",
        "call_id": "call-unrelated-forwarding",
        "name": "exec",
        "input": "const result = await tools.image_gen__generate({prompt: 'private'}); generatedImage(other);",
      },
    });

    expect(
      target.observeRolloutLine(threadId: "thread-1", line: wrapper),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(threadId: "thread-1", line: literalSearch),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: forwardedWrapper,
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: directedForwardedWrapper,
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: contentForwardedWrapper,
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: malformedDirectedWrapper,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: multilineDirectedMarker,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: mixedDirectedWrapper,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: directedWrapperWithTrailingCode,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: directedWrapperWithCallLikePrompt,
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: previewForwardedWrapper,
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: directedWrapperWithParenthesizedTrailingCode,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: imageWrapperWithAnotherTool,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: wrapperWithShadowedResultVariable,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: directedWrapperWithNestedToolCall,
      ),
      hasLength(1),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: unrelatedForwarding,
      ),
      hasLength(1),
    );
  });

  test("claims app-server images before durable rollout evidence", () {
    final target = tracker();
    final appServer = target.observeAppServerTool(
      notification: const CodexServerNotification(
        method: "item/completed",
        params: {
          "threadId": "thread-image",
          "item": {
            "type": "imageGeneration",
            "id": "image-1",
          },
        },
      ),
      imageGeneration: const CodexImageGenerationItemDto(
        id: "image-1",
        status: CodexImageGenerationStatus.completed,
        revisedPrompt: null,
        result: "AA==",
        savedPath: null,
      ),
    );

    expect(appServer?.canonicalId, "image-1");
    expect(appServer?.attachments, hasLength(1));

    final durable = target.observeRolloutLine(
      threadId: "thread-image",
      line: CodexRolloutLineDto.fromJson({
        "type": "event_msg",
        "payload": {
          "type": "image_generation_end",
          "call_id": "image-1",
          "status": "completed",
          "revised_prompt": null,
          "result": "AA==",
          "saved_path": "/private/final.png",
        },
      }),
    );
    final attachment = durable.single.attachments.single as PluginMessageAttachmentInlineImage;
    expect(attachment.filename, "final.png");
  });

  test("suppresses wait calls and projects their result onto the shell call", () {
    final target = tracker();
    expect(
      target
          .observeRolloutLine(
            threadId: "thread-1",
            line: _shellCall(callId: "call-shell", turnId: "turn-1"),
          )
          .single
          .canonicalId,
      "call-shell",
    );
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _toolOutput(
        callId: "call-shell",
        output: "Script running with cell ID 7\nOutput:\n",
      ),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: "turn-1",
          cellId: "7",
        ),
      ),
      isEmpty,
    );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait",
            output: "aborted by user after 1.0s",
          ),
        )
        .single;
    expect(completed.canonicalId, "call-shell");
    expect(completed.status, PluginToolStatus.error);
  });

  test("correlates waits chronologically without turn metadata", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-shell", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-shell",
          output: "Script running with cell ID 7\nOutput:\nearly output\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: null,
          cellId: "7",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait",
            output: "Script completed with exit code 0\nFinal output:\nlate output\n",
          ),
        )
        .single;
    expect(completed.canonicalId, "call-shell");
    expect(completed.status, PluginToolStatus.completed);
    expect(completed.output, contains("early output"));
    expect(completed.output, contains("late output"));
  });

  test("retires a waited cell when a chained wait replaces it", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-7",
          turnId: "turn-1",
          cellId: "7",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-wait-7",
          output: "Script running with cell ID 8\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-8",
          turnId: "turn-1",
          cellId: "8",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait-8",
            output: "Script completed with exit code 0\nFinal output:\ndone\n",
          ),
        )
        .single;
    expect(completed.status, PluginToolStatus.completed);
  });

  test("canonical terminal output clears its own running cells", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-exec",
            output: "Script completed with exit code 0\nFinal output:\ndone\n",
          ),
        )
        .single;
    expect(completed.status, PluginToolStatus.completed);
  });

  test("correlates every running cell from a composed exec", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolContentOutput(
          callId: "call-exec",
          outputs: const [
            "Script running with cell ID 7\nOutput:\nfirst\n",
            "Script running with cell ID 8\nOutput:\nsecond\n",
          ],
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait-8",
          turnId: "turn-1",
          cellId: "8",
        ),
      );

    final stillRunning = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait-8",
            output: "Script completed with exit code 0\nFinal output:\ndone\n",
          ),
        )
        .single;
    expect(stillRunning.status, PluginToolStatus.running);

    target.observeRolloutLine(
      threadId: "thread-1",
      line: _waitCall(
        callId: "call-wait-7",
        turnId: "turn-1",
        cellId: "7",
      ),
    );
    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait-7",
            output: "Script completed with exit code 0\nFinal output:\ndone\n",
          ),
        )
        .single;
    expect(completed.status, PluginToolStatus.completed);
  });

  test("merged output reserves space for the current terminal result", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n${"x" * maxToolOutputLength}",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: "turn-1",
          cellId: "7",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-wait",
            output: "terminal-result",
          ),
        )
        .single;
    expect(completed.output?.runes, hasLength(maxToolOutputLength));
    expect(completed.output, endsWith("terminal-result"));
  });

  test("merged composed results preserve sticky error precedence", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-failed",
          turnId: "turn-1",
          cellId: "7",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-failed",
          output: "Process exited with code 1\nFinal output:\nfailed-output",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-success",
          turnId: "turn-1",
          cellId: "7",
        ),
      );

    final merged = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolOutput(
            callId: "call-success",
            output: "Script completed with exit code 0\nFinal output:\nsuccess-output",
          ),
        )
        .single;
    expect(merged.status, PluginToolStatus.error);
    expect(merged.output, contains("failed-output"));
    expect(merged.output, contains("success-output"));
  });

  test("successful first child followed by a failed child is an error", () {
    final result = mapper.mapResult(
      (_toolContentOutput(
                callId: "call-exec",
                outputs: const [
                  "Script completed with exit code 0\nFinal output:\nfirst\n",
                  "Process exited with code 1\nFinal output:\nfailed\n",
                ],
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(result, isA<CodexRolloutToolErrorResult>());
  });

  test("successful first child followed by a leading abort is an error", () {
    final result = mapper.mapResult(
      (_toolContentOutput(
                callId: "call-exec",
                outputs: const [
                  "Script completed with exit code 0\nFinal output:\nfirst\n",
                  "aborted by user after 1.0s",
                ],
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(result, isA<CodexRolloutToolErrorResult>());
  });

  test("executor marker text later in ordinary stdout does not fail", () {
    final result = mapper.mapResult(
      (_toolOutput(
                callId: "call-exec",
                output:
                    "Script completed with exit code 0\n"
                    "Final output:\n"
                    "ordinary stdout\n"
                    "Process exited with code 1\n"
                    "aborted by user after 1.0s\n",
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(result, isA<CodexRolloutToolCompletedResult>());
  });

  test("truncated executor metadata still preserves a non-zero exit", () {
    final result = mapper.mapResult(
      (_toolOutput(
                callId: "call-exec",
                output:
                    "Chunk ID: failed\n"
                    "Wall time: 0.01 seconds\n"
                    "Process exited with code 7\n",
              )
              as CodexRolloutResponseItemLineDto)
          .payload,
    );

    expect(result, isA<CodexRolloutToolErrorResult>());
  });

  test("attachments accumulate in encounter order with exact deduplication", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolContentItems(
          callId: "call-exec",
          items: const [
            {
              "type": "output_text",
              "text": "Script running with cell ID 7\nOutput:\n",
            },
            {"type": "input_image", "image_url": "data:image/png;base64,AA=="},
          ],
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-wait",
          turnId: "turn-1",
          cellId: "7",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _toolContentItems(
            callId: "call-wait",
            items: const [
              {
                "type": "output_text",
                "text": "Script completed with exit code 0\nFinal output:\ndone\n",
              },
              {"type": "input_image", "image_url": "data:image/png;base64,AQ=="},
              {"type": "input_image", "image_url": "data:image/png;base64,AA=="},
            ],
          ),
        )
        .single;

    expect(completed.attachments, hasLength(2));
    expect(
      completed.attachments.map((attachment) => (attachment as PluginMessageAttachmentInlineImage).base64),
      ["AA==", "AQ=="],
    );
  });

  test("metadata-less running result completes from chronological terminal evidence", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    final completed = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _taskEvent(type: "task_complete", turnId: "turn-1"),
        )
        .single;
    expect(completed.canonicalId, "call-exec");
    expect(completed.status, PluginToolStatus.completed);
  });

  test("metadata-less running result errors from chronological abort evidence", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    final aborted = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _taskEvent(type: "turn_aborted", turnId: "turn-1"),
        )
        .single;
    expect(aborted.canonicalId, "call-exec");
    expect(aborted.status, PluginToolStatus.error);
  });

  test("late app-server completion retains the aborted canonical identity", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      );
    final started = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/started",
        itemId: "exec-1",
        turnId: "turn-1",
      ),
    );
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _toolOutput(
        callId: "call-exec",
        output:
            "Script running with cell ID 7\n"
            "Output:\n"
            "early output\n"
            "Output:\n"
            "literal output",
      ),
    );
    final aborted = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _taskEvent(type: "turn_aborted", turnId: "turn-1"),
        )
        .single;
    target.observeTerminalNotification(
      notification: _terminalNotification(method: "error"),
    );

    final lateCompletion = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
        output:
            "early output\n"
            "Output:\n"
            "literal output\n"
            "late command output",
      ),
    );

    expect(started?.canonicalId, "call-exec");
    expect(aborted.status, PluginToolStatus.error);
    expect(lateCompletion?.canonicalId, "call-exec");
    expect(lateCompletion?.status, PluginToolStatus.error);
    expect(lateCompletion?.output, contains("late command output"));
    expect(
      RegExp("early output").allMatches(lateCompletion?.output ?? ""),
      hasLength(1),
    );
    expect(
      RegExp("literal output").allMatches(lateCompletion?.output ?? ""),
      hasLength(1),
    );

    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-exec",
          output: "stale output",
        ),
      ),
      isEmpty,
    );
  });

  test("failed turn completion without rollout abort keeps late completion failed", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-exec", turnId: "turn-1"),
      )
      ..observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      )
      ..observeTerminalNotification(
        notification: _terminalNotification(
          method: "turn/completed",
          turnStatus: "failed",
        ),
      );

    final lateCompletion = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
      ),
    );

    expect(lateCompletion?.canonicalId, "call-exec");
    expect(lateCompletion?.status, PluginToolStatus.error);
  });

  test("late completion preserves a newer active turn", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-old", turnId: "turn-1"),
      )
      ..observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-old",
          turnId: "turn-1",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-old",
          output: "Script running with cell ID 7\nOutput:\nearly output",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "turn_aborted", turnId: "turn-1"),
      )
      ..observeTerminalNotification(
        notification: _terminalNotification(method: "error"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-2"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-new", turnId: "turn-2"),
      );

    final lateCompletion = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-old",
        turnId: null,
        status: "completed",
        exitCode: 0,
        output: "late old output",
      ),
    );

    expect(lateCompletion?.output, contains("late old output"));
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-old",
          output: "stale old output",
        ),
      ),
      isEmpty,
    );
    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-new",
              turnId: "turn-2",
            ),
          )
          ?.canonicalId,
      "call-new",
    );
  });

  test("late completion preserves externally started turn correlation", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-old", turnId: "turn-1"),
      )
      ..observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-old",
          turnId: "turn-1",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "turn_aborted", turnId: "turn-1"),
      )
      ..observeTerminalNotification(
        notification: _terminalNotification(method: "error"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-external", turnId: "turn-2"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-external",
          output: "already completed",
        ),
      )
      ..observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/completed",
          itemId: "exec-old",
          turnId: "turn-1",
          status: "completed",
          exitCode: 0,
        ),
      );

    expect(
      target
          .observeAppServerTool(
            imageGeneration: null,
            notification: _commandNotification(
              method: "item/started",
              itemId: "exec-external",
              turnId: "turn-2",
            ),
          )
          ?.canonicalId,
      "call-external",
    );
  });

  test("a later turn cannot complete a stale metadata-less call", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-stale", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-stale",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    final closedSegment = target
        .observeRolloutLine(
          threadId: "thread-1",
          line: _userMessageEvent(message: "next turn"),
        )
        .single;
    expect(closedSegment.canonicalId, "call-stale");
    expect(closedSegment.status, PluginToolStatus.error);

    target.observeRolloutLine(
      threadId: "thread-1",
      line: _taskEvent(type: "task_started", turnId: "turn-later"),
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_complete", turnId: "turn-later"),
      ),
      isEmpty,
    );
  });

  test("a delayed terminal cannot close the active newer turn", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_started", turnId: "turn-new"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _userMessageEvent(message: "new turn"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-new", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-new",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      );

    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_complete", turnId: "turn-old"),
      ),
      isEmpty,
    );
    expect(
      target
          .observeRolloutLine(
            threadId: "thread-1",
            line: _taskEvent(type: "task_complete", turnId: "turn-new"),
          )
          .single
          .status,
      PluginToolStatus.completed,
    );
  });

  test("a later turn cannot reuse a prior turn cell alias", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _rawExecCall(callId: "call-stale", turnId: null),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-stale",
          output: "Script running with cell ID 7\nOutput:\n",
        ),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_complete", turnId: "turn-1"),
      );

    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _waitCall(
          callId: "call-later-wait",
          turnId: "turn-2",
          cellId: "7",
        ),
      ),
      isEmpty,
    );
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-later-wait",
          output: "Script completed with exit code 0\nFinal output:\nlate\n",
        ),
      ),
      isEmpty,
    );
  });

  test("app-server terminal evidence overrides running rollout evidence", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-shell", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "call-shell",
          output: "Script running with cell ID 7\nOutput:\nearly output",
        ),
      );

    final completed = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
        output: "smaller output",
      ),
    );
    expect(completed?.status, PluginToolStatus.completed);
    expect(completed?.output, contains("early output"));
    expect(completed?.output, isNot("smaller output"));
  });

  test("turn completion does not replace app-server terminal evidence", () {
    final target = tracker();
    target.observeRolloutLine(
      threadId: "thread-1",
      line: _shellCall(callId: "call-shell", turnId: "turn-1"),
    );
    final completed = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 0,
      ),
    );

    expect(completed?.status, PluginToolStatus.completed);
    expect(
      target.observeRolloutLine(
        threadId: "thread-1",
        line: _taskEvent(type: "task_complete", turnId: "turn-1"),
      ),
      isEmpty,
    );
  });

  test("app-server non-zero exit upgrades a completed rollout result to error", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-shell", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(callId: "call-shell", output: "opaque output"),
      );

    final failed = target.observeAppServerTool(
      imageGeneration: null,
      notification: _commandNotification(
        method: "item/completed",
        itemId: "exec-1",
        turnId: "turn-1",
        status: "completed",
        exitCode: 1,
      ),
    );
    expect(failed?.status, PluginToolStatus.error);
    expect(failed?.output, "opaque output");
  });

  test("dynamic tool failure preserves richer rollout evidence", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _dynamicCall(callId: "dynamic-1", turnId: "turn-1"),
      )
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _toolOutput(
          callId: "dynamic-1",
          output: "opaque persisted output",
        ),
      );

    final failed = target.observeAppServerTool(
      imageGeneration: null,
      notification: const CodexServerNotification(
        method: "item/completed",
        params: {
          "threadId": "thread-1",
          "turnId": "turn-1",
          "item": {
            "type": "dynamicToolCall",
            "id": "dynamic-1",
            "status": "failed",
          },
        },
      ),
    );

    expect(failed?.status, PluginToolStatus.error);
    expect(failed?.output, "opaque persisted output");
  });

  test("clear removes all lifecycle and alias state", () {
    final target = tracker();
    target
      ..observeRolloutLine(
        threadId: "thread-1",
        line: _shellCall(callId: "call-1", turnId: "turn-1"),
      )
      ..observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/started",
          itemId: "exec-1",
          turnId: "turn-1",
        ),
      )
      ..observeTerminalNotification(
        notification: _terminalNotification(method: "error"),
      );
    target.clear();

    expect(
      target.observeAppServerTool(
        imageGeneration: null,
        notification: _commandNotification(
          method: "item/completed",
          itemId: "exec-1",
          turnId: "turn-1",
          status: "completed",
          exitCode: 0,
        ),
      ),
      isNull,
    );
  });
}

CodexRolloutLineDto _shellCall({
  required String callId,
  required String? turnId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call",
      "call_id": callId,
      "name": "exec_command",
      "arguments": '{"cmd":"pwd"}',
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _rawExecCall({
  required String callId,
  required String? turnId,
}) {
  return _codeModeExecCall(
    callId: callId,
    turnId: turnId,
    input: "await tools.exec_command({cmd: 'pwd'});",
  );
}

CodexRolloutLineDto _codeModeExecCall({
  required String callId,
  required String? turnId,
  required String input,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "custom_tool_call",
      "call_id": callId,
      "name": "exec",
      "input": input,
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _dynamicCall({
  required String callId,
  required String? turnId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "custom_tool_call",
      "call_id": callId,
      "name": "custom_tool",
      "input": "{}",
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _waitCall({
  required String callId,
  required String? turnId,
  required String cellId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call",
      "call_id": callId,
      "name": "wait",
      "arguments": '{"cell_id":"$cellId"}',
      if (turnId != null)
        "internal_chat_message_metadata_passthrough": {
          "turn_id": turnId,
        },
    },
  });
}

CodexRolloutLineDto _toolOutput({
  required String callId,
  required String output,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "function_call_output",
      "call_id": callId,
      "output": output,
    },
  });
}

CodexRolloutLineDto _toolContentOutput({
  required String callId,
  required List<String> outputs,
}) {
  return _toolContentItems(
    callId: callId,
    items: [
      for (final output in outputs)
        {
          "type": "output_text",
          "text": output,
        },
    ],
  );
}

CodexRolloutLineDto _toolContentItems({
  required String callId,
  required List<Map<String, Object?>> items,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "response_item",
    "payload": {
      "type": "custom_tool_call_output",
      "call_id": callId,
      "output": items,
    },
  });
}

CodexRolloutLineDto _taskEvent({
  required String type,
  required String turnId,
}) {
  return CodexRolloutLineDto.fromJson({
    "type": "event_msg",
    "payload": {
      "type": type,
      "turn_id": turnId,
    },
  });
}

CodexRolloutLineDto _userMessageEvent({required String message}) {
  return CodexRolloutLineDto.fromJson({
    "type": "event_msg",
    "payload": {
      "type": "user_message",
      "message": message,
    },
  });
}

CodexServerNotification _commandNotification({
  required String method,
  required String itemId,
  required String? turnId,
  String? status,
  int? exitCode,
  String? output,
}) {
  return CodexServerNotification(
    method: method,
    params: {
      "threadId": "thread-1",
      "turnId": ?turnId,
      "item": {
        "type": "commandExecution",
        "id": itemId,
        "command": "/bin/zsh -lc pwd",
        "status": ?status,
        "exitCode": ?exitCode,
        "aggregatedOutput": ?output,
      },
    },
  );
}

CodexServerNotification _terminalNotification({
  required String method,
  String? turnStatus,
}) {
  return CodexServerNotification(
    method: method,
    params: {
      "threadId": "thread-1",
      if (turnStatus != null) "turn": {"status": turnStatus},
    },
  );
}
