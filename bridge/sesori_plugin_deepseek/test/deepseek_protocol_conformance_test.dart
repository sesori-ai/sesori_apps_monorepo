import "dart:convert";
import "dart:io";

import "package:deepseek_plugin/src/api/deepseek_acp_api.dart";
import "package:deepseek_plugin/src/api/models/deepseek_protocol_dto.dart";
import "package:test/test.dart";

void main() {
  const api = DeepSeekAcpApi();
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
      "initializeMetadata",
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
Never _rejectInvalid(DeepSeekAcpApi api, String definition, Map<String, dynamic> value) {
  switch (definition) {
    case "initializeMetadata":
      api.parseInitializeMetadata(value);
    case "promptMetadata":
      api.parsePromptMetadata(value);
    case "catalogRequest":
      final request = DeepSeekCatalogRequestDto.fromJson(value);
      if (!request.cwd.startsWith("/") && !RegExp(r"^[A-Za-z]:[\\/]").hasMatch(request.cwd)) {
        throw const FormatException("cwd");
      }
    case "catalogResponse":
      api.parseCatalogResponse(value);
    case "historyRequest":
      final request = DeepSeekHistoryRequestDto.fromJson(value);
      if (request.maxMessages < 1 || request.maxMessages > 100) throw const FormatException("maxMessages");
    case "historyResponse":
      DeepSeekHistoryResponseDto.fromJson(value);
    case "renameRequest":
      final request = DeepSeekRenameRequestDto.fromJson(value);
      if (!request.title.contains(RegExp(r"\S"))) throw const FormatException("title");
    case "renameResponse":
      final response = DeepSeekRenameResponseDto.fromJson(value);
      if (!response.title.contains(RegExp(r"\S"))) throw const FormatException("title");
    case "askUserQuestionRequest":
      api.parseQuestionRequest(value);
    case "askUserQuestionResponse":
      api.parseQuestionResponse(value);
    case "sessionStatusNotification":
      api.parseSessionStatus(value);
    default:
      throw StateError("Unknown fixture definition $definition");
  }
  throw StateError("Invalid fixture accepted: $definition");
}
