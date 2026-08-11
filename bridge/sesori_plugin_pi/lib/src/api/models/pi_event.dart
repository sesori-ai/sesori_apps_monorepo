import "../../models/pi_compaction_reason.dart";
import "../../models/pi_thinking_level.dart";
import "pi_assistant_delta.dart";
import "pi_frame_fields.dart";

/// One agent event from Pi v0.84.1's stdout event stream.
///
/// Every known top-level event type is routed to a variant so no event silently
/// becomes anonymous data; unknown types survive as [PiUnknownEvent] because Pi
/// gains events between releases and a strict parser would drop a whole turn.
///
/// Only Pi's own scalars are typed here. Message, entry, tool, and result
/// payloads stay raw maps until the step that consumes them adds their DTOs.
sealed class PiEvent {
  const PiEvent({required this.raw});

  final Map<String, Object?> raw;

  /// Routes one event by its `type` discriminator.
  static PiEvent parse({required String type, required Map<String, Object?> json}) {
    return switch (type) {
      "agent_start" => PiAgentStartEvent(raw: json),
      "agent_end" => PiAgentEndEvent(willRetry: boolOrFalse(json["willRetry"]), raw: json),
      "agent_settled" => PiAgentSettledEvent(raw: json),
      "turn_start" => PiTurnStartEvent(raw: json),
      "turn_end" => PiTurnEndEvent(message: mapOrEmpty(json["message"]), raw: json),
      "message_start" => PiMessageStartEvent(message: mapOrEmpty(json["message"]), raw: json),
      "message_update" => PiMessageUpdateEvent(
        delta: PiAssistantDelta.parse(json: mapOrEmpty(json["assistantMessageEvent"])),
        raw: json,
      ),
      "message_end" => PiMessageEndEvent(message: mapOrEmpty(json["message"]), raw: json),
      "tool_execution_start" => PiToolExecutionStartEvent(
        toolCallId: stringOrNull(json["toolCallId"]),
        toolName: stringOrNull(json["toolName"]),
        args: mapOrEmpty(json["args"]),
        raw: json,
      ),
      "tool_execution_update" => PiToolExecutionUpdateEvent(
        toolCallId: stringOrNull(json["toolCallId"]),
        toolName: stringOrNull(json["toolName"]),
        args: mapOrEmpty(json["args"]),
        partialResult: mapOrEmpty(json["partialResult"]),
        raw: json,
      ),
      "tool_execution_end" => PiToolExecutionEndEvent(
        toolCallId: stringOrNull(json["toolCallId"]),
        toolName: stringOrNull(json["toolName"]),
        result: mapOrEmpty(json["result"]),
        isError: boolOrFalse(json["isError"]),
        raw: json,
      ),
      "bash_execution_update" => PiBashExecutionUpdateEvent(
        bashId: stringOrNull(json["id"]),
        delta: stringOrNull(json["delta"]),
        raw: json,
      ),
      "queue_update" => PiQueueUpdateEvent(
        steeringCount: stringListOrNull(json["steering"])?.length,
        followUpCount: stringListOrNull(json["followUp"])?.length,
        raw: json,
      ),
      "compaction_start" => PiCompactionStartEvent(
        reason: PiCompactionReason.tryParse(value: json["reason"]),
        raw: json,
      ),
      "compaction_end" => PiCompactionEndEvent(
        reason: PiCompactionReason.tryParse(value: json["reason"]),
        aborted: boolOrFalse(json["aborted"]),
        willRetry: boolOrFalse(json["willRetry"]),
        errorMessage: stringOrNull(json["errorMessage"]),
        raw: json,
      ),
      "entry_appended" => PiEntryAppendedEvent(entry: mapOrEmpty(json["entry"]), raw: json),
      // An absent or cleared name is `undefined` upstream; both mean "no
      // explicit name", so null models it honestly.
      "session_info_changed" => PiSessionInfoChangedEvent(name: stringOrNull(json["name"]), raw: json),
      "thinking_level_changed" => PiThinkingLevelChangedEvent(
        level: PiThinkingLevel.tryParse(value: stringOrNull(json["level"])),
        raw: json,
      ),
      "auto_retry_start" => PiAutoRetryStartEvent(
        attempt: intOrNull(json["attempt"]),
        maxAttempts: intOrNull(json["maxAttempts"]),
        delayMs: intOrNull(json["delayMs"]),
        errorMessage: stringOrNull(json["errorMessage"]),
        raw: json,
      ),
      "auto_retry_end" => PiAutoRetryEndEvent(
        success: boolOrFalse(json["success"]),
        attempt: intOrNull(json["attempt"]),
        finalError: stringOrNull(json["finalError"]),
        raw: json,
      ),
      "summarization_retry_scheduled" => PiSummarizationRetryScheduledEvent(
        attempt: intOrNull(json["attempt"]),
        maxAttempts: intOrNull(json["maxAttempts"]),
        delayMs: intOrNull(json["delayMs"]),
        errorMessage: stringOrNull(json["errorMessage"]),
        raw: json,
      ),
      "summarization_retry_attempt_start" => PiSummarizationRetryAttemptStartEvent(
        source: stringOrNull(json["source"]),
        reason: PiCompactionReason.tryParse(value: json["reason"]),
        raw: json,
      ),
      "summarization_retry_finished" => PiSummarizationRetryFinishedEvent(raw: json),
      "extension_error" => PiExtensionErrorEvent(
        extensionPath: stringOrNull(json["extensionPath"]),
        event: stringOrNull(json["event"]),
        error: stringOrNull(json["error"]),
        raw: json,
      ),
      _ => PiUnknownEvent(type: type, raw: json),
    };
  }
}

/// A low-level agent run started.
final class PiAgentStartEvent extends PiEvent {
  const PiAgentStartEvent({required super.raw});
}

/// One low-level run ended. Not completion: a retry, compaction recovery, or
/// queued continuation may still follow, which is what [willRetry] signals.
final class PiAgentEndEvent extends PiEvent {
  const PiAgentEndEvent({required this.willRetry, required super.raw});

  final bool willRetry;
}

/// No automatic continuation remains. Pi's only true idle signal.
final class PiAgentSettledEvent extends PiEvent {
  const PiAgentSettledEvent({required super.raw});
}

final class PiTurnStartEvent extends PiEvent {
  const PiTurnStartEvent({required super.raw});
}

final class PiTurnEndEvent extends PiEvent {
  const PiTurnEndEvent({required this.message, required super.raw});

  final Map<String, Object?> message;
}

final class PiMessageStartEvent extends PiEvent {
  const PiMessageStartEvent({required this.message, required super.raw});

  final Map<String, Object?> message;
}

/// A streaming increment. Pi strips the cumulative snapshot from these frames,
/// so [delta] is the only new information they carry.
final class PiMessageUpdateEvent extends PiEvent {
  const PiMessageUpdateEvent({required this.delta, required super.raw});

  final PiAssistantDelta delta;
}

/// The final authority for one message.
final class PiMessageEndEvent extends PiEvent {
  const PiMessageEndEvent({required this.message, required super.raw});

  final Map<String, Object?> message;
}

final class PiToolExecutionStartEvent extends PiEvent {
  const PiToolExecutionStartEvent({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    required super.raw,
  });

  final String? toolCallId;
  final String? toolName;
  final Map<String, Object?> args;
}

/// Cumulative progress for one tool call: each update replaces the last.
final class PiToolExecutionUpdateEvent extends PiEvent {
  const PiToolExecutionUpdateEvent({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    required this.partialResult,
    required super.raw,
  });

  final String? toolCallId;
  final String? toolName;
  final Map<String, Object?> args;
  final Map<String, Object?> partialResult;
}

final class PiToolExecutionEndEvent extends PiEvent {
  const PiToolExecutionEndEvent({
    required this.toolCallId,
    required this.toolName,
    required this.result,
    required this.isError,
    required super.raw,
  });

  final String? toolCallId;
  final String? toolName;
  final Map<String, Object?> result;
  final bool isError;
}

/// Streaming output of a user-invoked `bash` command.
final class PiBashExecutionUpdateEvent extends PiEvent {
  const PiBashExecutionUpdateEvent({required this.bashId, required this.delta, required super.raw});

  final String? bashId;
  final String? delta;
}

/// Pi's own steering/follow-up queue depth. Only the counts are modelled: the
/// queued strings are user prompt text and stay in [PiEvent.raw].
final class PiQueueUpdateEvent extends PiEvent {
  const PiQueueUpdateEvent({required this.steeringCount, required this.followUpCount, required super.raw});

  final int? steeringCount;
  final int? followUpCount;
}

final class PiCompactionStartEvent extends PiEvent {
  const PiCompactionStartEvent({required this.reason, required super.raw});

  final PiCompactionReason? reason;
}

final class PiCompactionEndEvent extends PiEvent {
  const PiCompactionEndEvent({
    required this.reason,
    required this.aborted,
    required this.willRetry,
    required this.errorMessage,
    required super.raw,
  });

  final PiCompactionReason? reason;
  final bool aborted;
  final bool willRetry;
  final String? errorMessage;
}

/// A session entry was persisted. The entry stays raw until history mapping.
final class PiEntryAppendedEvent extends PiEvent {
  const PiEntryAppendedEvent({required this.entry, required super.raw});

  final Map<String, Object?> entry;
}

/// The explicit session name changed. Null means the name was cleared.
final class PiSessionInfoChangedEvent extends PiEvent {
  const PiSessionInfoChangedEvent({required this.name, required super.raw});

  final String? name;
}

final class PiThinkingLevelChangedEvent extends PiEvent {
  const PiThinkingLevelChangedEvent({required this.level, required super.raw});

  final PiThinkingLevel? level;
}

final class PiAutoRetryStartEvent extends PiEvent {
  const PiAutoRetryStartEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.errorMessage,
    required super.raw,
  });

  final int? attempt;
  final int? maxAttempts;
  final int? delayMs;

  /// Raw provider text. It can carry request details, so it is never logged.
  final String? errorMessage;
}

final class PiAutoRetryEndEvent extends PiEvent {
  const PiAutoRetryEndEvent({
    required this.success,
    required this.attempt,
    required this.finalError,
    required super.raw,
  });

  final bool success;
  final int? attempt;
  final String? finalError;
}

final class PiSummarizationRetryScheduledEvent extends PiEvent {
  const PiSummarizationRetryScheduledEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.errorMessage,
    required super.raw,
  });

  final int? attempt;
  final int? maxAttempts;
  final int? delayMs;
  final String? errorMessage;
}

/// A summarization retry began. [reason] is present only for the `compaction`
/// source; branch summaries carry none.
final class PiSummarizationRetryAttemptStartEvent extends PiEvent {
  const PiSummarizationRetryAttemptStartEvent({required this.source, required this.reason, required super.raw});

  /// `branchSummary` or `compaction`.
  final String? source;

  final PiCompactionReason? reason;
}

final class PiSummarizationRetryFinishedEvent extends PiEvent {
  const PiSummarizationRetryFinishedEvent({required super.raw});
}

/// An extension handler threw. Pi keeps running, so this never ends a turn.
final class PiExtensionErrorEvent extends PiEvent {
  const PiExtensionErrorEvent({
    required this.extensionPath,
    required this.event,
    required this.error,
    required super.raw,
  });

  final String? extensionPath;
  final String? event;
  final String? error;
}

/// An event type this build does not model.
final class PiUnknownEvent extends PiEvent {
  const PiUnknownEvent({required this.type, required super.raw});

  final String type;
}
