import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

part "codex_image_bearing_item_dto.freezed.dart";
part "codex_image_bearing_item_dto.g.dart";

enum CodexImageGenerationStatus() {
  @JsonValue("in_progress")
  inProgress,
  completed,
  failed,
  unknown,
}

enum CodexToolCallStatus() {
  inProgress,
  completed,
  failed,
  declined,
  unknown,
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexImageBearingItemDto with _$CodexImageBearingItemDto {
  @FreezedUnionValue("imageGeneration")
  const factory CodexImageBearingItemDto.imageGeneration({
    required String id,
    @JsonKey(
      unknownEnumValue: CodexImageGenerationStatus.unknown,
      defaultValue: CodexImageGenerationStatus.unknown,
    )
    required CodexImageGenerationStatus status,
    required String? revisedPrompt,
    required String result,
    required String? savedPath,
  }) = CodexImageGenerationItemDto;

  @FreezedUnionValue("mcpToolCall")
  const factory CodexImageBearingItemDto.mcpToolCall({
    required String id,
    required String? server,
    required String? tool,
    @JsonKey(
      unknownEnumValue: CodexToolCallStatus.unknown,
      defaultValue: CodexToolCallStatus.unknown,
    )
    required CodexToolCallStatus status,
    @JsonKey(name: "result") @CodexMcpResultContentConverter() required List<CodexImageBearingContentDto> content,
    @CodexToolErrorConverter() required String? error,
  }) = CodexMcpToolCallItemDto;

  @FreezedUnionValue("dynamicToolCall")
  const factory CodexImageBearingItemDto.dynamicToolCall({
    required String id,
    @CodexToolNameConverter() required String tool,
    required Object? arguments,
    @JsonKey(
      unknownEnumValue: CodexToolCallStatus.unknown,
      defaultValue: CodexToolCallStatus.unknown,
    )
    required CodexToolCallStatus status,
    @JsonKey(name: "contentItems")
    @CodexImageBearingContentListConverter()
    required List<CodexImageBearingContentDto> content,
  }) = CodexDynamicToolCallItemDto;

  const factory CodexImageBearingItemDto.unknown() = CodexUnknownImageBearingItemDto;

  factory CodexImageBearingItemDto.fromJson(Map<String, dynamic> json) => _$CodexImageBearingItemDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexImageBearingContentDto with _$CodexImageBearingContentDto {
  @FreezedUnionValue("text")
  const factory CodexImageBearingContentDto.mcpText({
    required String text,
  }) = CodexMcpTextContentDto;

  @FreezedUnionValue("image")
  const factory CodexImageBearingContentDto.mcpImage({
    required String data,
    required String mimeType,
  }) = CodexMcpImageContentDto;

  @FreezedUnionValue("inputText")
  const factory CodexImageBearingContentDto.dynamicText({
    required String text,
  }) = CodexDynamicTextContentDto;

  @FreezedUnionValue("inputImage")
  const factory CodexImageBearingContentDto.dynamicImage({
    required String imageUrl,
  }) = CodexDynamicImageContentDto;

  @FreezedUnionValue("inputAudio")
  const factory CodexImageBearingContentDto.dynamicAudio({
    required String audioUrl,
  }) = CodexDynamicAudioContentDto;

  const factory CodexImageBearingContentDto.unknown() = CodexUnknownImageBearingContentDto;

  factory CodexImageBearingContentDto.fromJson(Map<String, dynamic> json) =>
      _$CodexImageBearingContentDtoFromJson(json);
}

class const CodexImageBearingContentListConverter() implements JsonConverter<List<CodexImageBearingContentDto>, Object?> {
  @override
  List<CodexImageBearingContentDto> fromJson(Object? json) {
    if (json == null) return const [];
    if (json is! List) {
      Log.w("[codex] skipping malformed image-bearing tool content list");
      return const [];
    }
    final content = <CodexImageBearingContentDto>[];
    for (final item in json) {
      try {
        content.add(
          CodexImageBearingContentDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        );
      } on Object {
        Log.w("[codex] skipping malformed image-bearing tool content item");
      }
    }
    return content;
  }

  @override
  Object toJson(List<CodexImageBearingContentDto> object) => throw UnsupportedError("decode only");
}

class const CodexMcpResultContentConverter() extends CodexImageBearingContentListConverter {
  @override
  List<CodexImageBearingContentDto> fromJson(Object? json) {
    if (json == null) return const [];
    if (json is! Map) {
      Log.w("[codex] skipping malformed MCP tool result");
      return const [];
    }
    return super.fromJson(json["content"]);
  }
}

class const CodexToolErrorConverter() implements JsonConverter<String?, Object?> {
  @override
  String? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Map && json["message"] is String) {
      return json["message"] as String;
    }
    Log.w("[codex] skipping malformed image-bearing tool error");
    return null;
  }

  @override
  Object? toJson(String? object) => throw UnsupportedError("decode only");
}

class const CodexToolNameConverter() implements JsonConverter<String, Object?> {
  @override
  String fromJson(Object? json) {
    if (json is String && json.isNotEmpty) return json;
    Log.w("[codex] using fallback for malformed dynamic tool name");
    return "tool";
  }

  @override
  Object toJson(String object) => throw UnsupportedError("decode only");
}
