import "dart:convert";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _NormalizedEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final AntigravityProtocolMapper protocolMapper,
}) extends AcpEventMapper {
  int normalizations = 0;
  @override
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) {
    normalizations++;
    return protocolMapper.normalizeSessionUpdate(params: params);
  }
}

_NormalizedEventMapper _mapper() => _NormalizedEventMapper(
  launchDirectory: "/synthetic",
  pluginId: "antigravity",
  configurationTracker: AcpSessionConfigurationTracker(),
  childSessions: AcpChildSessionTracker(),
  protocolMapper: const AntigravityProtocolMapper(),
);

AcpReplayCollector _collector({required AcpEventMapper mapper}) => AcpReplayCollector(
  sessionUpdateNormalizer: mapper.normalizeSessionUpdate,
  sessionId: "s",
  agentId: "antigravity",
  initialUserMessageId: null,
  messageIdOverride: null,
  messageTimeResolver: null,
  haltClassifier: null,
  toolPartReplacement: null,
);

Map<String, dynamic> _envelope({required Map<String, dynamic> update}) => {
  "sessionId": "s",
  "update": {"sessionUpdate": "tool_call", "toolCallId": "t", ...update},
};

PluginToolState _parity({required Map<String, dynamic> params}) {
  final mapper = _mapper();
  final replay = _collector(mapper: mapper);
  final before = jsonEncode(params);
  final live = mapper
      .map(AcpNotification(method: AcpMethods.sessionUpdate, params: params))
      .whereType<BridgeSseMessagePartUpdated>()
      .single
      .part;
  replay.consume(params);
  final recorded = replay.build().single.parts.single;
  expect(recorded.state, live.state);
  expect(recorded.tool, live.tool);
  expect(mapper.normalizations, 2);
  expect(jsonEncode(params), before, reason: "normalization must not mutate raw caller envelopes");
  return live.state;
}

void main() {
  const protocol = AntigravityProtocolMapper();

  test("standard mapper identity and non-tool provider updates remain unchanged", () {
    final mapper = AcpEventMapper(
      launchDirectory: "/synthetic",
      pluginId: "acp",
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
    );
    final params = _envelope(
      update: {
        "rawOutput": {"stdout": "standard"},
        "status": "completed",
      },
    );
    expect(mapper.normalizeSessionUpdate(params: params), same(params));
    final replay = _collector(mapper: mapper)..consume(params);
    final live = mapper
        .map(AcpNotification(method: AcpMethods.sessionUpdate, params: params))
        .whereType<BridgeSseMessagePartUpdated>()
        .single
        .part
        .state;
    expect(replay.build().single.parts.single.state, live);
    final ordinary = {
      "sessionId": "s",
      "update": {
        "sessionUpdate": "agent_message_chunk",
        "content": {"type": "text", "text": "ordinary"},
      },
    };
    expect(protocol.normalizeSessionUpdate(params: ordinary), same(ordinary));
    expect(protocol.normalizeSessionUpdate(params: {"sessionId": "s"}), {"sessionId": "s"});
  });

  test("pinned command and cwd aliases become bounded display-ready canonical fields", () {
    for (final alias in [
      (command: "CommandLine", cwd: "Cwd"),
      (command: "command_line", cwd: "WorkingDirectory"),
      (command: "commandLine", cwd: "working_dir"),
      (command: "command", cwd: "workingDir"),
      (command: "command", cwd: "cwd"),
    ]) {
      final params = _envelope(
        update: {
          "status": "completed",
          "rawInput": {alias.command: "  echo synthetic  ", alias.cwd: "  /synthetic  "},
        },
      );
      final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
      expect(normalized["kind"], "execute");
      expect((normalized["rawInput"] as Map<String, Object?>)["command"], "echo synthetic");
      expect((normalized["rawInput"] as Map<String, Object?>)["cwd"], "/synthetic");
      expect(_parity(params: params).title, "echo synthetic");
    }
    final params = _envelope(
      update: {
        "rawOutput": {"command_line": "fallback", "working_dir": "/fallback"},
      },
    );
    final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
    expect(normalized["title"], "fallback");
    expect((normalized["rawInput"] as Map<String, Object?>)["cwd"], "/fallback");
  });

  for (final fixture in [
    (
      name: "nonzero stdout",
      text: "synthetic output",
      exit: 7,
      status: "completed",
      expected: PluginToolStatus.completed,
    ),
    (name: "nonzero empty output", text: "", exit: 2, status: "completed", expected: PluginToolStatus.completed),
    (name: "success", text: "successful output", exit: 0, status: "completed", expected: PluginToolStatus.completed),
    (name: "tool failure", text: "tool failure output", exit: 0, status: "failed", expected: PluginToolStatus.error),
  ]) {
    for (final withContent in [false, true]) {
      test("${fixture.name} stays equal live/replayed with content=$withContent", () {
        final params = _envelope(
          update: {
            "status": fixture.status,
            "rawInput": {"CommandLine": "synthetic"},
            "rawOutput": {"combined_output": fixture.text, "exit_code": fixture.exit},
            if (withContent)
              "content": [
                {
                  "type": "content",
                  "content": {"type": "text", "text": fixture.text},
                },
              ],
          },
        );
        final expected = fixture.exit == 0 ? fixture.text : "${fixture.text}\n[Process exit code: ${fixture.exit}]";
        final state = _parity(params: params);
        expect(state.output, expected);
        expect(state.status, fixture.expected);
        expect(state.error, fixture.expected == PluginToolStatus.error ? expected : isNull);
        final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
        expect((normalized["rawOutput"] as Map<String, Object?>)["exitCode"], fixture.exit);
      });
    }
  }

  test("content-only nonzero output and partial updates use the same normalization", () {
    final params = _envelope(
      update: {
        "sessionUpdate": "tool_call_update",
        "status": "completed",
        "rawOutput": {"exitCode": 5},
        "content": [
          {
            "type": "content",
            "content": {"type": "text", "text": "content output"},
          },
        ],
      },
    );
    expect(_parity(params: params).output, "content output\n[Process exit code: 5]");
  });

  test("bounded output reserves the exit note and retains the tail", () {
    final params = _envelope(
      update: {
        "status": "completed",
        "rawInput": {"commandLine": "c" * 20000},
        "rawOutput": {"combinedOutput": "${"x" * 20000}TAIL", "exitCode": 17},
      },
    );
    final state = _parity(params: params);
    expect(state.output!.length, maxToolOutputLength);
    expect(state.output, startsWith("[Earlier output truncated]"));
    expect(state.output, endsWith("TAIL\n[Process exit code: 17]"));
    expect(state.title!.length, AntigravityProtocolMapper.toolTextLimit);
    final contentOnly = _parity(
      params: _envelope(
        update: {
          "rawOutput": {"exitCode": 17},
          "content": [
            for (var i = 0; i < 3; i++)
              {
                "type": "content",
                "content": {"type": "text", "text": "${"x" * 20000}TAIL"},
              },
          ],
        },
      ),
    );
    expect(contentOnly.output!.length, maxToolOutputLength);
    expect(contentOnly.output, endsWith("TAIL\n[Process exit code: 17]"));
  });

  test("standard images survive while redundant raw image bytes and formatted output are removed", () {
    const image = {
      "type": "content",
      "content": {"type": "image", "mimeType": "image/png", "data": "AA==", "uri": "file:///synthetic/image.png"},
    };
    final params = _envelope(
      update: {
        "status": "completed",
        "content": [image],
        "rawOutput": {
          "combinedOutput": "image output",
          "formatted_output": "image output",
          "exit_code": 3,
          "imagePath": "/synthetic/image.png",
          "image": {
            "type": "image",
            "data": "SECRET_BYTES",
            "mimeType": "image/png",
            "uri": "file:///synthetic/image.png",
          },
        },
        "rawInput": {"embedded": "DATA:IMAGE/png;base64,SECRET_BYTES"},
        "_meta": {
          "preview": {"mimeType": "image/png", "blob": "SECRET_BYTES", "filename": "image.png"},
        },
      },
    );
    final normalized = protocol.normalizeSessionUpdate(params: params);
    expect(jsonEncode(normalized), isNot(contains("SECRET_BYTES")));
    final update = normalized["update"] as Map;
    expect((update["content"] as List).last, same(image));
    expect((update["rawOutput"] as Map<String, Object?>)["imagePath"], "/synthetic/image.png");
    expect((update["rawOutput"] as Map).containsKey("formatted_output"), isFalse);
    expect(((update["_meta"] as Map<String, Object?>)["preview"]! as Map)["filename"], "image.png");
    final state = _parity(params: params);
    expect(state.output, "image output\n[Process exit code: 3]");
    expect(state.attachments.single.filename, "image.png");
    expect(state.attachments.single, isA<PluginMessageAttachmentInlineImage>());
    final dataUri = protocol.normalizeSessionUpdate(
      params: _envelope(update: {"rawOutput": "data:image/png;base64,BYTES"}),
    );
    expect((dataUri["update"] as Map).containsKey("rawOutput"), isFalse);
  });

  test("raw payload depth, aggregate text and node budgets bound retained metadata", () {
    Object nested = "deep";
    for (var i = 0; i < 20; i++) {
      nested = {"nested": nested};
    }
    final params = _envelope(
      update: {
        "_meta": {"deep": nested, "entries": List.filled(10000, 1)},
        "rawInput": {for (var i = 0; i < 100; i++) "$i": "x" * 8000},
      },
    );
    final update = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
    expect(jsonEncode(update["_meta"]), isNot(contains(':"deep"')));
    expect(((update["_meta"] as Map<String, Object?>)["entries"]! as List).length, lessThan(512));
    final retainedText = (update["rawInput"] as Map).values.cast<String>().fold<int>(0, (n, s) => n + s.length);
    expect(retainedText, lessThanOrEqualTo(64000));
  });

  test("image and raw-only projections retain stderr without duplicating it", () {
    for (final withImage in [false, true]) {
      for (final stdout in [null, "stdout"]) {
        final state = _parity(
          params: _envelope(
            update: {
              "status": "completed",
              "rawOutput": {"stdout": ?stdout, "stderr": "stderr", "exit_code": 3},
              if (withImage)
                "content": [
                  {"type": "image", "mimeType": "image/png", "data": "AA=="},
                ],
            },
          ),
        );
        expect(state.output, "${stdout == null ? '' : 'stdout\n'}stderr\n[Process exit code: 3]");
        expect(state.attachments, hasLength(withImage ? 1 : 0));
      }
    }
  });

  test("exit-only terminal updates retain earlier output in live and replay state", () {
    for (final key in ["exit_code", "exitCode"]) {
      for (final code in [0, 7]) {
        final mapper = _mapper();
        final replay = _collector(mapper: mapper);
        final initial = _envelope(
          update: {
            "status": "in_progress",
            "rawOutput": {"stdout": "earlier output"},
          },
        );
        mapper.map(AcpNotification(method: AcpMethods.sessionUpdate, params: initial)).toList();
        replay.consume(initial);
        final terminal = _envelope(
          update: {
            "sessionUpdate": "tool_call_update",
            "status": "completed",
            "rawOutput": {key: code},
          },
        );
        final live = mapper
            .map(AcpNotification(method: AcpMethods.sessionUpdate, params: terminal))
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part
            .state;
        replay.consume(terminal);
        expect(live.output, "earlier output");
        expect(live.status, PluginToolStatus.completed);
        expect(replay.build().single.parts.single.state, live);
      }
    }
  });

  test("formatted-only native output reaches canonical stdout and live/replay display", () {
    final params = _envelope(
      update: {
        "status": "completed",
        "rawOutput": {"formatted_output": "formatted"},
      },
    );
    final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
    expect((normalized["rawOutput"] as Map)["stdout"], "formatted");
    expect((normalized["rawOutput"] as Map).containsKey("formatted_output"), isFalse);
    expect(_parity(params: params).output, "formatted");
  });

  test("only exact standard text duplicates are removed, including split text", () {
    for (final texts in [
      <String>["native"],
      ["na", "tive"],
      ["detail"],
      ["native", "detail"],
    ]) {
      final params = _envelope(
        update: {
          "status": "completed",
          "rawOutput": {"combinedOutput": "native", "exit_code": 3},
          "content": [
            for (final text in texts)
              {
                "type": "content",
                "content": {"type": "text", "text": text},
              },
          ],
        },
      );
      final expected = texts.contains("detail") ? "native\ndetail" : "native";
      expect(_parity(params: params).output, "$expected\n[Process exit code: 3]");
    }
    final direct = _envelope(
      update: {
        "rawOutput": {"combinedOutput": "native"},
        "content": {"type": "text", "text": "direct detail"},
      },
    );
    expect(_parity(params: direct).output, "native\ndirect detail");
  });

  test("differing long sources each retain a tail within the display and exit-note bound", () {
    final params = _envelope(
      update: {
        "rawOutput": {"combinedOutput": "${"n" * 2000}NATIVE", "exit_code": 8},
        "content": {"type": "text", "text": "${"s" * 2000}STANDARD"},
      },
    );
    final output = _parity(params: params).output!;
    expect(output.length, maxToolOutputLength);
    expect(output, contains("NATIVE\n"));
    expect(output, endsWith("STANDARD\n[Process exit code: 8]"));
  });

  test("malformed known blocks retain original entries for bounded ACP degradation", () {
    for (final bad in <Map<String, dynamic>>[
      {"type": "content"},
      {"type": "text", "text": 7},
      {"type": "content", "content": "not a map"},
    ]) {
      final params = _envelope(
        update: {
          "status": "completed",
          "rawOutput": {"combinedOutput": "kept"},
          "content": [bad],
        },
      );
      final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
      expect((normalized["content"] as List).last, same(bad));
      // ACP's legacy fallback recovers a plain string nested under content.
      expect(_parity(params: params).output, bad["content"] == "not a map" ? "keptnot a map" : "kept");
    }
  });

  test("direct image maps survive native output and nonzero-exit normalization", () {
    const image = {"type": "image", "mimeType": "image/png", "data": "AA==", "uri": "file:///synthetic/direct.png"};
    for (final content in [
      image,
      {"type": "content", "content": image},
    ]) {
      final params = _envelope(
        update: {
          "status": "completed",
          "rawOutput": {"combinedOutput": "image", "exit_code": 4},
          "content": content,
        },
      );
      final normalized = protocol.normalizeSessionUpdate(params: params)["update"] as Map;
      expect((normalized["content"] as List).last, same(content));
      final state = _parity(params: params);
      expect(state.output, "image\n[Process exit code: 4]");
      expect(state.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(state.attachments.single.filename, "direct.png");
    }
  });

  test("malformed generated update envelopes fall back to existing ACP handling", () {
    final params = _envelope(
      update: {
        "kind": 7,
        "title": "Fallback",
        "status": "completed",
        "rawOutput": {"stdout": "standard output"},
      },
    );
    expect(protocol.normalizeSessionUpdate(params: params), same(params));
    final state = _parity(params: params);
    expect(state.title, "Fallback");
    expect(state.output, "standard output");
    expect(state.status, PluginToolStatus.completed);
  });

  test("malformed native aliases degrade observably without fabricating command policy", () {
    final params = _envelope(
      update: {
        "kind": "read",
        "status": "completed",
        "rawInput": {"command": 7},
        "rawOutput": {"combinedOutput": "retained output"},
      },
    );
    final state = _parity(params: params);
    expect(state.output, "retained output");
    expect(state.status, PluginToolStatus.completed);
    expect(state.title, isNull);
  });
}
