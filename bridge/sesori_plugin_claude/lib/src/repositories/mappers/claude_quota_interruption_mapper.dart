import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:timezone/data/latest.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;

import "../../api/models/claude_stream_message.dart";
import "claude_content_mapper.dart";

/// Recognizes the tagged quota error observed in Claude Code transcripts.
/// Process-wide rate-limit warnings are not evidence of a failed root turn.
final class ClaudeQuotaInterruptionMapper({required final ClaudeContentMapper contentMapper}) {
  this {
    tz_data.initializeTimeZones();
  }

  static final _reset = RegExp(
    r"^You've hit your session limit · resets (\d{1,2})(?::(\d{2}))?(am|pm) \(([^)]+)\)$",
  );

  PluginQuotaInterruption? map({required ClaudeAssistantMessage message, required DateTime observedAt}) {
    final id = message.messageId;
    if (message.parentToolUseId != null ||
        message.error != ClaudeAssistantError.rateLimit ||
        id == null ||
        id.isEmpty) {
      return null;
    }
    final text = [
      for (final block in contentMapper.map(content: message.message["content"]))
        if (block case ClaudeMappedTextContentBlock(:final text)) text,
    ].join("\n").trim();
    if (!text.startsWith("You've hit your session limit")) return null;
    final observed = (message.timestamp ?? observedAt).toUtc();
    return PluginQuotaInterruption(
      errorMessageId: id,
      observedAt: observed,
      reset: _parseReset(text: text, observedAt: observed),
    );
  }

  PluginQuotaReset _parseReset({required String text, required DateTime observedAt}) {
    final match = _reset.firstMatch(text);
    if (match == null) return const PluginQuotaResetUnknown();
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2] ?? "0");
    if (hour < 1 || hour > 12 || minute > 59) return const PluginQuotaResetUnknown();
    final tz.Location location;
    try {
      location = tz.getLocation(match[4]!);
    } on tz.LocationNotFoundException {
      return const PluginQuotaResetUnknown();
    }
    final local = tz.TZDateTime.from(observedAt, location);
    final wallTime = DateTime.utc(local.year, local.month, local.day, hour % 12 + (match[3] == "pm" ? 12 : 0), minute);
    // A date-less reset is usable only on the observed local date. Do not guess
    // a next day, a normalized DST gap, or one side of a repeated wall time.
    final candidates = <DateTime>{};
    for (final offset in location.zones.map((zone) => zone.offset).toSet()) {
      final candidate = wallTime.subtract(offset);
      final zoned = tz.TZDateTime.from(candidate, location);
      if (zoned.year == wallTime.year &&
          zoned.month == wallTime.month &&
          zoned.day == wallTime.day &&
          zoned.hour == wallTime.hour &&
          zoned.minute == wallTime.minute &&
          zoned.second == 0) {
        candidates.add(candidate);
      }
    }
    if (candidates.length != 1 || !candidates.single.isAfter(observedAt)) return const PluginQuotaResetUnknown();
    return PluginQuotaResetKnown(resetAt: candidates.single);
  }
}
