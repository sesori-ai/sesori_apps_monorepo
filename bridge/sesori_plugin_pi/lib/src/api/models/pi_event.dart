import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../models/pi_compaction_reason.dart";
import "../../models/pi_summarization_source.dart";
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
sealed class const PiEvent({required final Map<String, Object?> raw}) {
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
        reason: _compactionReason(json["reason"]),
        raw: json,
      ),
      "compaction_end" => PiCompactionEndEvent(
        reason: _compactionReason(json["reason"]),
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
        level: _thinkingLevel(stringOrNull(json["level"])),
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
      "summarization_retry_attempt_start" => _summarizationRetryAttempt(json),
      "summarization_retry_finished" => PiSummarizationRetryFinishedEvent(raw: json),
      "extension_error" => PiExtensionErrorEvent(
        extensionPath: stringOrNull(json["extensionPath"]),
        event: stringOrNull(json["event"]),
        error: stringOrNull(json["error"]),
        raw: json,
      ),
      _ => _unknownEvent(type: type, json: json),
    };
  }
}

PiCompactionReason? _compactionReason(Object? value) {
  final reason = PiCompactionReason.tryParse(value: value);
  if (value != null && reason == null) Log.w("[pi] received an unknown compaction reason");
  return reason;
}

PiThinkingLevel? _thinkingLevel(String? value) {
  final level = PiThinkingLevel.tryParse(value: value);
  if (value != null && level == null) Log.w("[pi] received an unknown thinking level");
  return level;
}

PiEvent _summarizationRetryAttempt(Map<String, Object?> json) {
  final source = PiSummarizationSource.parse(
    source: stringOrNull(json["source"]),
    reason: json["reason"],
  );
  if (source is PiUnknownSummarizationSource) {
    Log.w("[pi] received an unknown summarization retry source");
  }
  return PiSummarizationRetryAttemptStartEvent(source: source, raw: json);
}

PiEvent _unknownEvent({required String type, required Map<String, Object?> json}) {
  Log.w("[pi] received an unknown event type");
  return PiUnknownEvent(type: type, raw: json);
}

/// A low-level agent run started.
final class const PiAgentStartEvent({required super.raw}) extends PiEvent;

/// One low-level run ended. Not completion: a retry, compaction recovery, or
/// queued continuation may still follow, which is what [willRetry] signals.
final class const PiAgentEndEvent({required final bool willRetry, required super.raw}) extends PiEvent;

/// No automatic continuation remains. Pi's only true idle signal.
final class const PiAgentSettledEvent({required super.raw}) extends PiEvent;

final class const PiTurnStartEvent({required super.raw}) extends PiEvent;

final class const PiTurnEndEvent({required final Map<String, Object?> message, required super.raw}) extends PiEvent;

final class const PiMessageStartEvent({required final Map<String, Object?> message, required super.raw})
    extends PiEvent;

/// A streaming increment. Pi strips the cumulative snapshot from these frames,
/// so [delta] is the only new information they carry.
final class const PiMessageUpdateEvent({required final PiAssistantDelta delta, required super.raw}) extends PiEvent;

/// The final authority for one message.
final class const PiMessageEndEvent({required final Map<String, Object?> message, required super.raw})
    extends PiEvent;

final class const PiToolExecutionStartEvent({
  required final String? toolCallId,
  required final String? toolName,
  required final Map<String, Object?> args,
  required super.raw,
}) extends PiEvent;

/// Cumulative progress for one tool call: each update replaces the last.
final class const PiToolExecutionUpdateEvent({
  required final String? toolCallId,
  required final String? toolName,
  required final Map<String, Object?> args,
  required final Map<String, Object?> partialResult,
  required super.raw,
}) extends PiEvent;

final class const PiToolExecutionEndEvent({
  required final String? toolCallId,
  required final String? toolName,
  required final Map<String, Object?> result,
  required final bool isError,
  required super.raw,
}) extends PiEvent;

/// Streaming output of a user-invoked `bash` command.
final class const PiBashExecutionUpdateEvent({
  required final String? bashId,
  required final String? delta,
  required super.raw,
}) extends PiEvent;

/// Pi's own steering/follow-up queue depth. Only the counts are modelled: the
/// queued strings are user prompt text and stay in [PiEvent.raw].
final class const PiQueueUpdateEvent({
  required final int? steeringCount,
  required final int? followUpCount,
  required super.raw,
}) extends PiEvent;

final class const PiCompactionStartEvent({required final PiCompactionReason? reason, required super.raw})
    extends PiEvent;

final class const PiCompactionEndEvent({
  required final PiCompactionReason? reason,
  required final bool aborted,
  required final bool willRetry,
  required final String? errorMessage,
  required super.raw,
}) extends PiEvent;

/// A session entry was persisted. The entry stays raw until history mapping.
final class const PiEntryAppendedEvent({required final Map<String, Object?> entry, required super.raw})
    extends PiEvent;

/// The explicit session name changed. Null means the name was cleared.
final class const PiSessionInfoChangedEvent({required final String? name, required super.raw}) extends PiEvent;

final class const PiThinkingLevelChangedEvent({required final PiThinkingLevel? level, required super.raw})
    extends PiEvent;

final class const PiAutoRetryStartEvent({
  required final int? attempt,
  required final int? maxAttempts,
  required final int? delayMs,

  /// Raw provider text, forwarded unchanged in the user-facing retry status.
  required final String? errorMessage,
  required super.raw,
}) extends PiEvent;

final class const PiAutoRetryEndEvent({
  required final bool success,
  required final int? attempt,
  required final String? finalError,
  required super.raw,
}) extends PiEvent;

final class const PiSummarizationRetryScheduledEvent({
  required final int? attempt,
  required final int? maxAttempts,
  required final int? delayMs,

  /// Raw provider text, forwarded unchanged in the user-facing retry status.
  required final String? errorMessage,
  required super.raw,
}) extends PiEvent;

/// A summarization retry began.
final class const PiSummarizationRetryAttemptStartEvent({
  required final PiSummarizationSource source,
  required super.raw,
}) extends PiEvent;

final class const PiSummarizationRetryFinishedEvent({required super.raw}) extends PiEvent;

/// An extension handler threw. Pi keeps running, so this never ends a turn.
final class const PiExtensionErrorEvent({
  required final String? extensionPath,
  required final String? event,
  required final String? error,
  required super.raw,
}) extends PiEvent;

/// An event type this build does not model.
final class const PiUnknownEvent({required final String type, required super.raw}) extends PiEvent;
