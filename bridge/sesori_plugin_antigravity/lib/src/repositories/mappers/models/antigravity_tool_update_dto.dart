// rawInput/rawOutput/_meta and preserved content entries are arbitrary ACP JSON;
// known native fields and text content below still use generated typed decoding.
// ignore_for_file: no_slop_linter/prefer_specific_type

import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_tool_update_dto.freezed.dart";
part "antigravity_tool_update_dto.g.dart";

const _input = Freezed(copyWith: false, equal: false, toStringOverride: false, toJson: false);
const _output = Freezed(copyWith: false, equal: false, toStringOverride: false, fromJson: false, toJson: true);

@JsonEnum(fieldRename: FieldRename.snake)
enum AntigravityUpdateKind() {
  toolCall,
  toolCallUpdate,
  unknown,
}

enum AntigravityNormalizedToolKind() {
  execute,
}

@_input
sealed class AntigravityToolUpdateDto with _$AntigravityToolUpdateDto {
  const factory({
    @JsonKey(unknownEnumValue: AntigravityUpdateKind.unknown) required AntigravityUpdateKind sessionUpdate,
    required String? title,
    required String? kind,
    required Object? rawInput,
    required Object? rawOutput,
    @JsonKey(name: "_meta") required Object? metadata,
  }) = _AntigravityToolUpdateDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityToolUpdateDtoFromJson(json);
}

/// Native aliases corroborated by the pinned AntigravityProtocol.ts boundary.
@_input
sealed class AntigravityNativeToolFieldsDto with _$AntigravityNativeToolFieldsDto {
  const factory({
    required String? command,
    @JsonKey(name: "CommandLine") required String? upperCommandLine,
    @JsonKey(name: "command_line") required String? snakeCommandLine,
    required String? commandLine,
    required String? cwd,
    @JsonKey(name: "Cwd") required String? upperCwd,
    @JsonKey(name: "WorkingDirectory") required String? workingDirectory,
    @JsonKey(name: "working_dir") required String? snakeWorkingDir,
    required String? workingDir,
    required String? stdout,
    required String? stderr,
    required String? combinedOutput,
    @JsonKey(name: "combined_output") required String? snakeCombinedOutput,
    @JsonKey(name: "formatted_output") required String? formattedOutput,
    required int? exitCode,
    @JsonKey(name: "exit_code") required int? snakeExitCode,
    required String? imagePath,
  }) = _AntigravityNativeToolFieldsDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityNativeToolFieldsDtoFromJson(json);
}

@_output
sealed class AntigravityNormalizedUpdateDto with _$AntigravityNormalizedUpdateDto {
  const factory({
    required String? title,
    required AntigravityNormalizedToolKind? kind,
    required Object? rawInput,
    required Object? rawOutput,
    required List<Object?>? content,
    @JsonKey(name: "_meta") required Object? metadata,
  }) = _AntigravityNormalizedUpdateDto;
}

@_output
sealed class AntigravityNormalizedToolFieldsDto with _$AntigravityNormalizedToolFieldsDto {
  const factory({
    required String? command,
    required String? cwd,
    required String? stdout,
    required int? exitCode,
    required String? imagePath,
  }) = _AntigravityNormalizedToolFieldsDto;
}

/// Recognize only text when replacing duplicated native display output. Other
/// standard content (including images/diffs) is forwarded from the original entry.
@Freezed(copyWith: false, equal: false, toStringOverride: false, unionKey: "type", fallbackUnion: "unknown")
sealed class AntigravityToolContentDto with _$AntigravityToolContentDto {
  const factory content({required AntigravityToolContentDto content}) = AntigravityWrappedToolContentDto;
  const factory text({required String text}) = AntigravityTextToolContentDto;
  const factory unknown() = AntigravityUnknownToolContentDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityToolContentDtoFromJson(json);
}
