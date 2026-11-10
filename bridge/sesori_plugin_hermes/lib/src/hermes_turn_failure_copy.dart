// ponytail: Hermes's wording is not a promised API. Both matchers copy the
// text Hermes writes in `agent/turn_failure_copy.py` (read in the Hermes
// 0.21.5 source on 2026-11-09): `exhausted_copy` for the live notice, and
// `FAILED_TURN_NOTICE` / `PARTIAL_FAILED_TURN_NOTICE` for the saved row. If
// Hermes rewords them, the live notice shows as plain assistant text again and
// the saved row reappears after a reload, which is the behavior before these
// matchers existed. Update the copies here from the new Hermes source.

/// The final response Hermes streams when its model provider failed every
/// retry and fallback:
/// "{provider} {lead} {N} attempts — {next step} To avoid this in future, add a
/// backup provider with `hermes fallback add`.\n\nProvider said: {summary}".
///
/// The whole fixed tail must follow the lead, so a reply that only mentions a
/// provider failure, or quotes this notice after its own text, stays a reply.
final RegExp _providerFailureNotice = RegExp(
  r"^[^\n]+ \d+ attempts — "
  r"(?:it looks temporarily unavailable\. Wait a minute and send /retry"
  r"|its usage limit resets in [^\n]+?\. Send /retry after that)"
  r", or switch models with /model\. To avoid this in future, add a backup provider with `hermes fallback add`\."
  r"\n\nProvider said: \S",
);

/// The assistant rows Hermes saves to close a failed turn. They are not the
/// model's answer: Hermes marks them `display_kind = 'failed_turn'` in its own
/// database, but replays them over ACP as ordinary assistant text.
const Set<String> _failedTurnBoundaries = {
  "Your request was not processed. Send it again if you still want me to carry it out.",
  "This turn did not complete. Some actions may already have run; verify their effects before resending.",
};

/// Whether [text] is Hermes's live explanation of a turn its model provider
/// never answered.
bool isHermesProviderFailureNotice({required String text}) => _providerFailureNotice.hasMatch(text);

/// Whether [text] is the row Hermes saves in place of a failed turn's answer.
/// Hermes's own reader matches these by exact trimmed text too, so a reply
/// that quotes one stays a reply.
bool isHermesFailedTurnBoundary({required String text}) => _failedTurnBoundaries.contains(text.trim());
