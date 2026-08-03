import "package:freezed_annotation/freezed_annotation.dart";

part "codex_command_execution_dto.freezed.dart";
part "codex_command_execution_dto.g.dart";

enum CodexCommandExecutionItemType {
  @JsonValue("commandExecution")
  commandExecution,
  unknown,
}

enum CodexCommandExecutionStatus {
  inProgress,
  completed,
  failed,
  declined,
  unknown,
}

enum CodexCommandExecutionLifecycle {
  started,
  completed,
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

@freezed
sealed class CodexCommandExecutionParamsDto with _$CodexCommandExecutionParamsDto {
  const factory CodexCommandExecutionParamsDto({
    required String? threadId,
    required String? turnId,
    required CodexCommandExecutionItemDto item,
  }) = _CodexCommandExecutionParamsDto;

  factory CodexCommandExecutionParamsDto.fromJson(Map<String, dynamic> json) =>
      _$CodexCommandExecutionParamsDtoFromJson(json);
}

@freezed
sealed class CodexCommandExecutionItemDto with _$CodexCommandExecutionItemDto {
  const factory CodexCommandExecutionItemDto({
    @JsonKey(
      unknownEnumValue: CodexCommandExecutionItemType.unknown,
      defaultValue: CodexCommandExecutionItemType.unknown,
    )
    required CodexCommandExecutionItemType type,
    required String? id,
    @JsonKey(fromJson: _commandExecutionStatusFromJson) required CodexCommandExecutionStatus status,
    @JsonKey(fromJson: _commandExecutionExitCodeFromJson) required int? exitCode,
  }) = _CodexCommandExecutionItemDto;

  factory CodexCommandExecutionItemDto.fromJson(Map<String, dynamic> json) =>
      _$CodexCommandExecutionItemDtoFromJson(json);
}

final class CodexCommandExecutionEventDto {
  const CodexCommandExecutionEventDto({
    required this.lifecycle,
    required this.threadId,
    required this.turnId,
    required this.itemId,
    required this.status,
    required this.exitCode,
  });

  final CodexCommandExecutionLifecycle lifecycle;
  final String threadId;
  final String? turnId;
  final String itemId;
  final CodexCommandExecutionStatus status;
  final int? exitCode;
}
