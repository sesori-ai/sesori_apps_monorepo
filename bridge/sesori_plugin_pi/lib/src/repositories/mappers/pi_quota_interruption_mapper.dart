import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/pi_event.dart";
import "../../models/pi_assistant_stop_reason.dart";
import "pi_history_mapper.dart";

/// Pi's openai-codex adapter formats a provider reset as approximate minutes.
/// Keep that duration anchored to the original assistant error, never a replay.
final class const PiQuotaInterruptionMapper({required final PiHistoryMapper historyMapper}) {
  // Dart DateTime's representable Unix-millisecond range.
  static const _maxMilliseconds = 8640000000000000;
  static final _usageLimit = RegExp(
    r"^You have hit your ChatGPT usage limit(?: \([^()]+ plan\))?\.",
  );
  static final _reset = RegExp(r" Try again in ~([0-9]+) min\.$");

  PluginQuotaInterruption? map({
    required PiMessageEndEvent event,
    required PluginMessage? mappedMessage,
    required DateTime observedAt,
  }) {
    final message = historyMapper.decodeAssistantMessage(raw: event.message);
    if (message == null ||
        message.stopReason != PiAssistantStopReason.error ||
        message.provider != "openai-codex" ||
        mappedMessage is! PluginMessageError) {
      return null;
    }
    final text = message.errorMessage?.trim();
    if (text == null) return null;
    final match = _usageLimit.firstMatch(text);
    if (match == null && text != "Codex error: The usage limit has been reached") return null;
    final timestamp = message.timestamp;
    final hasTimestamp = timestamp != null && timestamp >= -_maxMilliseconds && timestamp <= _maxMilliseconds;
    final observed = hasTimestamp ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true) : observedAt.toUtc();
    final duration = _reset.firstMatch(text)?[1];
    final minutes = duration == null ? null : int.tryParse(duration);
    PluginQuotaReset reset = const PluginQuotaResetUnknown();
    if (hasTimestamp && minutes != null && minutes > 0 && minutes <= (_maxMilliseconds - timestamp) ~/ 60000) {
      reset = PluginQuotaResetKnown(
        resetAt: DateTime.fromMillisecondsSinceEpoch(timestamp + minutes * 60000, isUtc: true),
      );
    }
    return PluginQuotaInterruption(errorMessageId: mappedMessage.id, observedAt: observed, reset: reset);
  }
}
