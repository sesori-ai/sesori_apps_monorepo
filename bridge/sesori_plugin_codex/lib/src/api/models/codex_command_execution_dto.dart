import "package:freezed_annotation/freezed_annotation.dart";

part "codex_command_execution_dto.freezed.dart";
part "codex_command_execution_dto.g.dart";

enum CodexCommandExecutionItemType() {
  @JsonValue("commandExecution")
  commandExecution,
  unknown,
}

enum CodexCommandExecutionStatus() {
  inProgress,
  completed,
  failed,
  declined,
  unknown,
}

CodexCommandExecutionStatus _commandExecutionStatusFromJson(Object? value) {
  return switch (value) {
    "inProgress" => CodexCommandExecutionStatus.inProgress,
    "completed" => CodexCommandExecutionStatus.completed,
    "failed" => CodexCommandExecutionStatus.failed,
    "declined" => CodexCommandExecutionStatus.declined,
    _ => CodexCommandExecutionStatus.unknown,
  };
}

int? _commandExecutionExitCodeFromJson(Object? value) {
  return value is num ? value.toInt() : null;
}

String? _commandExecutionTextFromJson(Object? value) {
  return value is String ? value : null;
}

@freezed
sealed class CodexCommandExecutionParamsDto with _$CodexCommandExecutionParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexCommandExecutionItemDto item,
  }) = _CodexCommandExecutionParamsDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$CodexCommandExecutionParamsDtoFromJson(json);
}

@freezed
sealed class CodexCommandExecutionItemDto with _$CodexCommandExecutionItemDto {
  const factory({
    @JsonKey(
      unknownEnumValue: CodexCommandExecutionItemType.unknown,
      defaultValue: CodexCommandExecutionItemType.unknown,
    )
    required CodexCommandExecutionItemType type,
    required String? id,
    @JsonKey(fromJson: _commandExecutionTextFromJson) required String? command,
    @JsonKey(fromJson: _commandExecutionTextFromJson) required String? aggregatedOutput,
    @JsonKey(fromJson: _commandExecutionStatusFromJson) required CodexCommandExecutionStatus status,
    @JsonKey(fromJson: _commandExecutionExitCodeFromJson) required int? exitCode,
  }) = _CodexCommandExecutionItemDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$CodexCommandExecutionItemDtoFromJson(json);
}
