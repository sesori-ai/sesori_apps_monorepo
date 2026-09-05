import "dart:convert";
import "dart:io";

import "package:deepseek_plugin/src/api/deepseek_acp_api.dart";
import "package:deepseek_plugin/src/api/models/deepseek_protocol_dto.dart";
import "package:deepseek_plugin/src/deepseek_identity.dart";
import "package:test/test.dart";

void main() {
  const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);

  for (final protocolVersion in const [1, 2]) {
    final fixtureDirectory = Directory("test/fixtures/protocol/v$protocolVersion");
    test("protocol v$protocolVersion consumed valid fixtures decode and encode through typed DTOs", () async {
      final corpus = jsonDecode(await File("${fixtureDirectory.path}/valid.json").readAsString()) as List;
      final expectedDefinitions = _definitionsFor(protocolVersion: protocolVersion);
      final definitions = <String>{};
      for (final fixture in corpus.cast<Map<String, dynamic>>()) {
        final definition = fixture["definition"] as String;
        // The complete source corpus also pins contracts whose consumer lands in a later PR.
        if (!expectedDefinitions.contains(definition)) continue;
        final value = (fixture["value"] as Map).cast<String, dynamic>();
        definitions.add(definition);
        expect(
          _decode(api: api, definition: definition, value: value),
          isA<Map<String, dynamic>>(),
          reason: definition,
        );
      }
      expect(definitions, expectedDefinitions);
    });

    test("protocol v$protocolVersion consumed invalid fixtures are rejected", () async {
      final corpus = jsonDecode(await File("${fixtureDirectory.path}/invalid.json").readAsString()) as List;
      final expectedDefinitions = _definitionsFor(protocolVersion: protocolVersion);
      for (final fixture in corpus.cast<Map<String, dynamic>>()) {
        final definition = fixture["definition"] as String;
        if (!expectedDefinitions.contains(definition)) continue;
        final value = (fixture["value"] as Map).cast<String, dynamic>();
        expect(
          () => _decode(api: api, definition: definition, value: value),
          throwsA(anything),
          reason: definition,
        );
      }
    });
  }

  test("catalog rejects bounded collection and entry violations", () async {
    final corpus = jsonDecode(await File("test/fixtures/protocol/v2/valid.json").readAsString()) as List;
    Map<String, dynamic> fixture(String definition) =>
        (corpus.cast<Map<String, dynamic>>().firstWhere(
                  (fixture) => fixture["definition"] == definition,
                )["value"]
                as Map)
            .cast<String, dynamic>();
    final valid = fixture("catalogResponse");
    Map<String, dynamic> copy() => (jsonDecode(jsonEncode(valid)) as Map).cast<String, dynamic>();
    Map<String, dynamic> mutate(void Function(Map<String, dynamic>) change) {
      final value = copy();
      change(value);
      return value;
    }

    final provider = (valid["providers"] as List).single;
    final model = ((provider as Map)["models"] as List).single;
    final malformed = [
      mutate((value) => value["providers"] = List.filled(65, provider)),
      mutate((value) => ((value["providers"] as List).single as Map)["models"] = List.filled(257, model)),
      mutate(
        (value) => value["commands"] = [
          {"name": "", "description": "invalid"},
        ],
      ),
      mutate((value) => value["commands"] = List.filled(129, {"name": "valid", "description": "valid"})),
      mutate(
        (value) => value["failures"] = [
          {"providerId": "provider", "category": "catalog", "message": "x".padRight(513, "x")},
        ],
      ),
      mutate(
        (value) => value["failures"] = List.filled(65, {
          "providerId": "provider",
          "category": "catalog",
          "message": "failed",
        }),
      ),
    ];
    for (final catalog in malformed) {
      expect(() => api.parseCatalogResponse(catalog), throwsFormatException);
    }
    final history = fixture("historyResponse");
    ((history["updates"] as List).first as Map)["sessionId"] = "another-session";
    expect(() => api.parseHistoryResponse(history, sessionId: "session-1"), throwsFormatException);
    final questions = fixture("askUserQuestionRequest");
    (questions["questions"] as List).add((questions["questions"] as List).first);
    expect(() => api.parseQuestionRequest(questions), throwsFormatException);
  });

  test("initialization requires protocol v2", () {
    Map<String, dynamic> metadata({required int version}) => {
      "extensionProtocolVersion": version,
      "adapterVersion": "0.1.3",
      "harnessVersion": "0.1.1-rc.2",
      "persistenceOwner": "sesori",
    };

    expect(() => api.parseInitializeMetadata(metadata(version: 1)), throwsFormatException);
    expect(api.parseInitializeMetadata(metadata(version: 2)).extensionProtocolVersion, 2);
    expect(() => api.parseInitializeMetadata(metadata(version: 3)), throwsFormatException);
  });

  test("history preserves additive metadata while parsing typed DeepSeek fields", () {
    final metadata = {
      "shared/future": {"retained": true},
      DeepSeekAcpApi.initializeMetadataKey: {
        "messageCreatedAt": 1,
        "futureField": "retained",
        "subagent": {
          "label": "Child",
          "prompt": "Inspect",
          "mode": "background",
          "childSessionId": "child",
        },
      },
    };
    final response = api.parseHistoryResponse({
      "updates": [
        {
          "sessionId": "root",
          "update": {"sessionUpdate": "tool_call", "toolCallId": "call"},
          "_meta": metadata,
        },
      ],
      "hasMore": false,
    }, sessionId: "root");

    final encodedUpdate = (response.toJson()["updates"] as List).single as Map<String, dynamic>;
    expect(encodedUpdate["_meta"], metadata);
    expect(response.updates.single.metadata?.deepSeek?.subagent?.childSessionId, "child");
  });

  test("history validates typed DeepSeek metadata before repositories consume it", () {
    expect(
      () => api.parseHistoryResponse({
        "updates": [
          {
            "sessionId": "root",
            "update": {"sessionUpdate": "tool_call", "toolCallId": "call"},
            "_meta": {
              DeepSeekAcpApi.initializeMetadataKey: {
                "subagent": {"label": "Child", "prompt": "Inspect", "mode": "detached"},
              },
            },
          },
        ],
        "hasMore": false,
      }, sessionId: "root"),
      throwsFormatException,
    );
  });

  test("sub-agent optional fields reject explicit null", () {
    final invalidEnd = {
      "kind": "ended",
      "sessionId": "root",
      "childSessionId": "child",
      "stopReason": "completed",
      "summary": null,
    };
    expect(() => api.parseSubagentNotification(invalidEnd), throwsFormatException);
    expect(() => DeepSeekSubagentNotificationDto.fromJson(invalidEnd), throwsFormatException);
    expect(() => DeepSeekSubagentEndedDto.fromJson(invalidEnd), throwsFormatException);
    expect(
      () => api.parseSubagentReplay({
        "label": "Child",
        "prompt": "Inspect",
        "mode": "background",
        "childSessionId": null,
      }),
      throwsFormatException,
    );
    expect(
      () => api.parseSubagentReplay({
        "label": "Child",
        "prompt": "Inspect",
        "mode": "background",
        "ended": {"stopReason": "completed", "summary": null},
      }),
      throwsFormatException,
    );
    for (final subagent in [
      {"label": "Child", "prompt": "Inspect", "mode": "background", "childSessionId": null},
      {
        "label": "Child",
        "prompt": "Inspect",
        "mode": "background",
        "ended": {"stopReason": "completed", "summary": null},
      },
    ]) {
      expect(
        () => api.parseHistoryResponse({
          "updates": [
            {
              "sessionId": "root",
              "update": {"sessionUpdate": "tool_call", "toolCallId": "call"},
              "_meta": {
                DeepSeekAcpApi.initializeMetadataKey: {"subagent": subagent},
              },
            },
          ],
          "hasMore": false,
        }, sessionId: "root"),
        throwsFormatException,
      );
    }
  });

  test("sub-agent presentation fields validate Unicode scalar structure and bounds", () {
    Map<String, dynamic> started({required String prompt, String label = "Child"}) => {
      "kind": "started",
      "sessionId": "root",
      "childSessionId": "child",
      "toolCallId": "call",
      "label": label,
      "prompt": prompt,
      "mode": "foreground",
    };
    Map<String, dynamic> ended(String summary) => {
      "kind": "ended",
      "sessionId": "root",
      "childSessionId": "child",
      "stopReason": "completed",
      "summary": summary,
    };

    expect(
      api.parseSubagentNotification(started(prompt: List.filled(32768, "😀").join())),
      isA<DeepSeekSubagentStartedDto>(),
    );
    expect(
      api.parseSubagentNotification(started(prompt: "valid", label: List.filled(256, "😀").join())),
      isA<DeepSeekSubagentStartedDto>(),
    );
    expect(
      api.parseSubagentNotification(ended(List.filled(512, "😀").join())),
      isA<DeepSeekSubagentEndedDto>(),
    );
    expect(
      () => api.parseSubagentNotification(started(prompt: List.filled(32769, "😀").join())),
      throwsFormatException,
    );
    expect(
      () => api.parseSubagentNotification(started(prompt: "valid", label: List.filled(257, "😀").join())),
      throwsFormatException,
    );
    expect(() => api.parseSubagentNotification(ended(List.filled(513, "😀").join())), throwsFormatException);
    expect(() => api.parseSubagentNotification(ended("valid\uD800")), throwsFormatException);
    expect(
      () => api.parseSubagentReplay({
        "label": "Child",
        "prompt": "Inspect",
        "mode": "background",
        "ended": {"stopReason": "completed", "summary": "valid\uD800"},
      }),
      throwsFormatException,
    );
    expect(() => api.parseSubagentNotification(started(prompt: "valid\uD800")), throwsFormatException);
    expect(() => api.parseSubagentNotification(started(prompt: " padded ")), throwsFormatException);
  });
}

Set<String> _definitionsFor({required int protocolVersion}) => {
  if (protocolVersion == 2) "initializeMetadata",
  "promptMetadata",
  "catalogRequest",
  "catalogResponse",
  "historyRequest",
  "historyResponse",
  "renameRequest",
  "renameResponse",
  "askUserQuestionRequest",
  "askUserQuestionResponse",
  "sessionStatusNotification",
  if (protocolVersion == 2) "subagentNotification",
};

Map<String, dynamic> _decode({
  required DeepSeekAcpApi api,
  required String definition,
  required Map<String, dynamic> value,
}) => switch (definition) {
  "initializeMetadata" => api.parseInitializeMetadata(value).toJson(),
  "promptMetadata" => api.parsePromptMetadata(value).toJson(),
  "catalogRequest" => _catalogRequest(value),
  "catalogResponse" => api.parseCatalogResponse(value).toJson(),
  "historyRequest" => _historyRequest(value),
  "historyResponse" => api.parseHistoryResponse(value, sessionId: null).toJson(),
  "renameRequest" => _renameRequest(value),
  "renameResponse" => _renameResponse(value),
  "askUserQuestionRequest" => api.parseQuestionRequest(value).toJson(),
  "askUserQuestionResponse" => api.parseQuestionResponse(value).toJson(),
  "sessionStatusNotification" => api.parseSessionStatus(value).toJson(),
  "subagentNotification" => api.parseSubagentNotification(value).toJson(),
  _ => throw StateError("Unknown fixture definition $definition"),
};

Map<String, dynamic> _catalogRequest(Map<String, dynamic> value) {
  final request = DeepSeekCatalogRequestDto.fromJson(value);
  if (!request.cwd.startsWith("/") && !RegExp(r"^[A-Za-z]:[\\/]").hasMatch(request.cwd)) {
    throw const FormatException("cwd");
  }
  return request.toJson();
}

Map<String, dynamic> _historyRequest(Map<String, dynamic> value) {
  final request = DeepSeekHistoryRequestDto.fromJson(value);
  if (request.maxMessages < 1 || request.maxMessages > 100) throw const FormatException("maxMessages");
  return request.toJson();
}

Map<String, dynamic> _renameRequest(Map<String, dynamic> value) {
  final request = DeepSeekRenameRequestDto.fromJson(value);
  if (!request.title.contains(RegExp(r"\S"))) throw const FormatException("title");
  return request.toJson();
}

Map<String, dynamic> _renameResponse(Map<String, dynamic> value) {
  final response = DeepSeekRenameResponseDto.fromJson(value);
  if (!response.title.contains(RegExp(r"\S"))) throw const FormatException("title");
  return response.toJson();
}
