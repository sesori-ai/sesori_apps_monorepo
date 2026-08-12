import "codex_command_execution_dto.dart";
import "codex_file_change_dto.dart";

enum CodexCorrelatableItemLifecycle() {
  started,
  completed,
}

sealed class const CodexCorrelatableItemEventDto({
    required final CodexCorrelatableItemLifecycle lifecycle,
    required final String threadId,
    required final String? turnId,
    required final String itemId,
  });

final class const CodexCommandExecutionEventDto({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required final String? command,
    required final String? aggregatedOutput,
    required final CodexCommandExecutionStatus status,
    required final int? exitCode,
  }) extends CodexCorrelatableItemEventDto;

final class const CodexFileChangeEventDto({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required final CodexFileChangeStatus status,
  }) extends CodexCorrelatableItemEventDto;
