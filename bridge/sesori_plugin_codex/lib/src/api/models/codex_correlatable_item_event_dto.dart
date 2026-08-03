import "codex_command_execution_dto.dart";
import "codex_file_change_dto.dart";

enum CodexCorrelatableItemLifecycle {
  started,
  completed,
}

sealed class CodexCorrelatableItemEventDto {
  const CodexCorrelatableItemEventDto({
    required this.lifecycle,
    required this.threadId,
    required this.turnId,
    required this.itemId,
  });

  final CodexCorrelatableItemLifecycle lifecycle;
  final String threadId;
  final String? turnId;
  final String itemId;
}

final class CodexCommandExecutionEventDto extends CodexCorrelatableItemEventDto {
  const CodexCommandExecutionEventDto({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.command,
    required this.aggregatedOutput,
    required this.status,
    required this.exitCode,
  });

  final String? command;
  final String? aggregatedOutput;
  final CodexCommandExecutionStatus status;
  final int? exitCode;
}

final class CodexFileChangeEventDto extends CodexCorrelatableItemEventDto {
  const CodexFileChangeEventDto({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.status,
  });

  final CodexFileChangeStatus status;
}
