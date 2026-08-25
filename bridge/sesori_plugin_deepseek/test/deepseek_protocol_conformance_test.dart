import "dart:convert";
import "dart:io";

import "package:deepseek_plugin/src/api/deepseek_acp_api.dart";
import "package:deepseek_plugin/src/api/models/deepseek_protocol_dto.dart";
import "package:deepseek_plugin/src/deepseek_identity.dart";
import "package:test/test.dart";

void main() {
  const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
  final fixtureDirectory = Directory("test/fixtures/protocol/v1");
  test("all valid runtime fixtures decode and encode through generated DTOs", () async {
    final corpus = jsonDecode(await File("${fixtureDirectory.path}/valid.json").readAsString()) as List;
    final definitions = <String>{};
    for (final fixture in corpus.cast<Map<String, dynamic>>()) {
      final definition = fixture["definition"] as String;
      final value = (fixture["value"] as Map).cast<String, dynamic>();
      definitions.add(definition);
      expect(_decodeValid(api, definition, value), isA<Map<String, dynamic>>(), reason: definition);
    }
    expect(definitions, {
      "initializeMetadata", "promptMetadata", "catalogRequest", "catalogResponse",
      "historyRequest", "historyResponse", "renameRequest", "renameResponse",
      "askUserQuestionRequest", "askUserQuestionResponse", "sessionStatusNotification",
    });
  });
  test("all invalid runtime fixtures are rejected", () async {
    final corpus = jsonDecode(await File("${fixtureDirectory.path}/invalid.json").readAsString()) as List;
    for (final fixture in corpus.cast<Map<String, dynamic>>()) {
      final value = (fixture["value"] as Map).cast<String, dynamic>();
      expect(
        () => _rejectInvalid(api, fixture["definition"] as String, value),
        throwsA(anything),
        reason: fixture["definition"] as String,
      );
    }
  });
  test("catalog rejects bounded collection and entry violations", () async {
    final corpus = jsonDecode(await File("${fixtureDirectory.path}/valid.json").readAsString()) as List;
    Map<String, dynamic> fixture(String definition) => (corpus.cast<Map<String, dynamic>>().firstWhere(
      (fixture) => fixture["definition"] == definition,
    )["value"] as Map).cast<String, dynamic>();
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
      mutate((value) => value["commands"] = [{"name": "", "description": "invalid"}]),
      mutate((value) => value["commands"] = List.filled(129, {"name": "valid", "description": "valid"})),
      mutate((value) => value["failures"] = [
        {"providerId": "provider", "category": "catalog", "message": "x".padRight(513, "x")},
      ]),
      mutate((value) => value["failures"] = List.filled(65, {
        "providerId": "provider", "category": "catalog", "message": "failed",
      })),
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
}

Map<String, dynamic> _decodeValid(DeepSeekAcpApi api, String definition, Map<String, dynamic> value) =>
    switch (definition) {
      "initializeMetadata" => api.parseInitializeMetadata(value).toJson(),
      "promptMetadata" => api.parsePromptMetadata(value).toJson(),
      "catalogRequest" => DeepSeekCatalogRequestDto.fromJson(value).toJson(),
      "catalogResponse" => api.parseCatalogResponse(value).toJson(),
      "historyRequest" => DeepSeekHistoryRequestDto.fromJson(value).toJson(),
      "historyResponse" => DeepSeekHistoryResponseDto.fromJson(value).toJson(),
      "renameRequest" => DeepSeekRenameRequestDto.fromJson(value).toJson(),
      "renameResponse" => DeepSeekRenameResponseDto.fromJson(value).toJson(),
      "askUserQuestionRequest" => api.parseQuestionRequest(value).toJson(),
      "askUserQuestionResponse" => api.parseQuestionResponse(value).toJson(),
      "sessionStatusNotification" => api.parseSessionStatus(value).toJson(),
      _ => throw StateError("Unknown fixture definition $definition"),
    };
void _rejectInvalid(DeepSeekAcpApi api, String definition, Map<String, dynamic> value) {
  switch (definition) {
    case "initializeMetadata" ||
        "promptMetadata" ||
        "catalogResponse" ||
        "historyResponse" ||
        "askUserQuestionRequest" ||
        "askUserQuestionResponse" ||
        "sessionStatusNotification":
      _decodeValid(api, definition, value);
    case "catalogRequest":
      final request = DeepSeekCatalogRequestDto.fromJson(value);
      if (!request.cwd.startsWith("/") && !RegExp(r"^[A-Za-z]:[\\/]").hasMatch(request.cwd)) {
        throw const FormatException("cwd");
      }
    case "historyRequest":
      final request = DeepSeekHistoryRequestDto.fromJson(value);
      if (request.maxMessages < 1 || request.maxMessages > 100) throw const FormatException("maxMessages");
    case "renameRequest":
      final request = DeepSeekRenameRequestDto.fromJson(value);
      if (!request.title.contains(RegExp(r"\S"))) throw const FormatException("title");
    case "renameResponse":
      final response = DeepSeekRenameResponseDto.fromJson(value);
      if (!response.title.contains(RegExp(r"\S"))) throw const FormatException("title");
    default:
      throw StateError("Unknown fixture definition $definition");
  }
}
