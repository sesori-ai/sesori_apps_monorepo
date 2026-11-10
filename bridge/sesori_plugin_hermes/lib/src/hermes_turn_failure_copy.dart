// ponytail: Hermes's wording is not a promised API, and nothing else on the
// ACP wire marks a failed turn. These are Hermes's own templates, copied
// verbatim (Python `{field}` placeholders and all) from the Hermes 0.21.5
// source read on 2026-11-09:
//   - `agent/turn_failure_copy.py`: `exhausted_copy`, `_NONRETRYABLE_COPY`,
//     `_AUTH_COPY`, `content_policy_copy`, `_SITE_COPY`, and the saved rows
//     `FAILED_TURN_NOTICE` / `PARTIAL_FAILED_TURN_NOTICE`;
//   - `agent/conversation_loop.py`: `_billing_terminal_label`;
//   - `hermes_cli/anon_auth.py`: `welcome_refusal_copy`,
//     `_WELCOME_ROUTE_COPY` and `FREE_TIER_OUTAGE_COPY` (the chat forms).
// If Hermes rewords one, that failure shows as plain assistant text again,
// which is how it showed before these matchers existed. Paste the new
// template here from the Hermes source.

/// Hermes's chat copy for a turn that ended in failure, keyed by Hermes's own
/// name for it.
///
/// Left out on purpose: `reasoning_only`, which ends with the model's own last
/// thoughts ("which may contain the answer"), so it stays a reply.
const Map<String, String> _turnFailureTemplates = {
  // exhausted_copy: every `_EXHAUSTED_LEADS` lead ends in "{attempts} attempts".
  "exhausted":
      "{lead} attempts — it looks temporarily unavailable. Wait a minute and send /retry, or switch models with "
      "/model. To avoid this in future, add a backup provider with `hermes fallback add`.\n\nProvider said: {summary}",
  "exhausted_until_reset":
      "{lead} attempts — its usage limit resets in {window}. Send /retry after that, or switch models with /model. "
      "To avoid this in future, add a backup provider with `hermes fallback add`.\n\nProvider said: {summary}",
  // nonretryable_copy: a `_NONRETRYABLE_COPY` / `_AUTH_COPY` body, then the provider's words.
  "model_not_found":
      "Model '{model}' isn't available on {label}. Pick a different model with /model (or `hermes model` in a "
      "terminal).{prefix_hint}\n\nProvider said: {summary}",
  "format_error":
      "{label} rejected this request as malformed, so the model didn't answer. Start a clean session with /new or "
      "switch models with /model; if it keeps happening, run `hermes doctor`.\n\nProvider said: {summary}",
  "role_alternation":
      "{label} requires user and assistant turns to strictly alternate and rejected this conversation's shape. "
      "Start a clean session with /new or switch models with /model.\n\nProvider said: {summary}",
  "ssl_cert_verification":
      "Hermes couldn't verify {label}'s security certificate, so the connection was refused. This is usually a "
      "corporate proxy or an outdated certificate store on this computer — see the terminal or "
      "`{home}/logs/agent.log` for the exact fix, or try another provider with /model.\n\nProvider said: {summary}",
  "provider_policy_blocked":
      "{label} refused this request because of a policy on your account (its data/privacy settings, or a block the "
      "model's upstream provider placed on the account), so the model didn't answer and retrying won't help. Check "
      "the account with the provider, or switch models with /model.\n\nProvider said: {summary}",
  "upstream_blocked":
      "A firewall/CDN in front of {label} blocked the request before it reached the model, so your key is probably "
      "fine. Set a custom User-Agent via the provider's extra_headers, check the proxy/WAF rules, or switch "
      "providers with /model.\n\nProvider said: {summary}",
  "nonretryable_default":
      "{label} rejected the request and retrying won't help. Pick another model with /model, or check the details in "
      "`{home}/logs/agent.log`.\n\nProvider said: {summary}",
  "auth_oauth":
      "{label} rejected your sign-in, so the model can't be reached. Sign in again: `{relogin}`.\n\n"
      "Provider said: {summary}",
  "auth_api_key":
      "{label} rejected your API key, so the model can't be reached. Update it in Settings → Providers, or run "
      "`hermes setup` in a terminal.\n\nProvider said: {summary}",
  // content_policy_copy (sent with a leading "⚠️ ").
  "content_policy":
      "{label}'s safety filter refused this request, so the model didn't answer. Try rewording your message or "
      "removing sensitive attachments, or switch to another model with /model.\n\nProvider said: {summary}",
  // _SITE_COPY.
  "context_overflow":
      "This conversation has grown too long for {model} to read, and Hermes couldn't shrink it enough "
      "automatically. Start a new session with /new (your history is kept), or try /compress once more. Switching "
      "to a model with a bigger context window also works.",
  "truncated":
      "The model's reply was cut off before it finished (it hit its output length limit), so Hermes didn't run the "
      "incomplete action. Nothing was changed. Send `continue`, ask for the work in smaller steps, or raise "
      "max_tokens for this model.",
  "invalid_response":
      "{label} sent back an empty or broken reply {attempts} times — it is probably overloaded or rate-limiting you. "
      "Wait a minute and send /retry, or switch models with /model.\n\nDetails: {detail}",
  "loop_error":
      "Hermes hit repeated errors and stopped this turn so it wouldn't keep retrying. Your message is saved. Send "
      "`continue` to try again, or start a new session with /new. If it happens again, run `hermes doctor` and "
      "share the error details.\n\nDetails: {detail}",
  "interpreter_shutdown":
      "Hermes was shutting down and stopped this turn. Your conversation is saved — reopen it{resume} and send your "
      "message again.",
  "payload_too_large":
      "This conversation (including attachments) has grown too large to send to {model}, and Hermes couldn't shrink "
      "it enough automatically. Start a new session with /new (your history is kept), or try /compress once more.",
  "compression_disabled":
      "This conversation is too long for {model} and automatic shrinking is turned off in your settings "
      "(compression.enabled). Run /compress to shrink it now, /new to start fresh, or pick a model with a bigger "
      "context window.",
  "server_context_rejection":
      "The model server rejected this request as too large, but this conversation is only about {tokens:,} tokens — "
      "well under the {window:,}-token window Hermes knows for {model} — so shrinking it would not help. Another "
      "request on the same server (for example a background memory review from an earlier session) was probably "
      "holding its capacity, or the server runs {model} with a smaller window than Hermes assumes. Wait a moment "
      "and send /retry; if it keeps happening, check the server's context setting.",
  "truncated_unreported":
      "The model's action arrived cut off partway through, so Hermes didn't run it. Nothing was changed. The model "
      "didn't report hitting its output limit, so this was most likely a dropped connection or a provider/router "
      "cutting the reply short. Send /retry; if it keeps happening, ask for the work in smaller steps.",
  "stream_dropped_tool_call":
      "The connection to {label} kept dropping while the model was writing a large action, so nothing was run. Check "
      "your network and send /retry; asking for the file in smaller pieces also helps.",
  "stream_closed_tool_call":
      "{label} kept closing the stream before the model finished writing its action, without reporting an error, so "
      "nothing was run. This is usually the provider or a proxy in front of it cutting long replies short. Send "
      "/retry; asking for the work in smaller steps also helps.",
  "local_processing_error":
      "Hermes hit an internal error while handling the model's reply and stopped this turn. Your message is saved. "
      "Send `continue` to try again, or start a new session with /new. If it happens again, run `hermes doctor` "
      "and share the error details.\n\nDetails: {detail}",
  "max_iterations_no_summary":
      "I ran out of steps for this turn ({limit} tool calls) before finishing, and couldn't produce a summary. Send "
      "`continue` to keep going, or raise `max_iterations` in your config.",
  // _billing_terminal_label.
  "billing": "Billing or credits exhausted: {summary}",
  "billing_unverified":
      "Provider reported usage/credit exhaustion (unverified — the same error can be a content-filter rejection, not "
      "billing): {summary}",
  // Nous free tier, chat forms. Each sentence ends in an optional sign-in hint.
  "free_tier_outage":
      "The free model is having trouble responding right now. Try sending your message again in a minute.",
  "model_not_free":
      "{what} available without signing in, so Hermes uses {serves} for now. Sign in for more models.{signin}",
  "feature_not_free": "That isn't available without signing in. Sign in to use it, it's free.{signin}",
  "at_capacity":
      "Chatting without signing in is really busy right now. Sign in to skip the queue, it's free, or try again in "
      "{wait}.{signin}",
  "admission_closed":
      "Chatting without signing in is full right now. Sign in to keep going, it's free, or try again in "
      "{wait}.{signin}",
  "rate_limited":
      "You've used up the allowance for chatting without signing in. It refreshes in {wait}. Sign in for a bigger "
      "allowance, it's free.{signin}",
  "welcome_refusal_default": "Hermes couldn't send that without signing in. Signing in is free.{signin}",
  "anon_on_paid_host":
      "This install is set to use a different Nous server (NOUS_INFERENCE_BASE_URL). Unset it to use the free model, "
      "or sign in.{signin}",
  "named_on_welcome_host": "This Nous account needs to reconnect.{model_hint}",
  "tier_disabled":
      "Using Hermes without signing in is switched off right now. Sign in to keep chatting, it's free.{signin}",
  "welcome_route_default": "Hermes couldn't reach the free model on this route.",
};

/// The rows Hermes saves in its own history to close a failed turn, in place
/// of the failure text it sent live (which it never saves).
const Set<String> _failedTurnRows = {
  "Your request was not processed. Send it again if you still want me to carry it out.",
  "This turn did not complete. Some actions may already have run; verify their effects before resending.",
};

/// Placeholders that hold the provider's or Hermes's raw detail, always last
/// in their template; they may span lines.
const Set<String> _trailingDetailFields = {"summary", "detail"};

/// Each template as a pattern: its fixed text must match exactly, from the
/// start, with an optional "⚠️ " lead. A placeholder matches any text on its
/// line, and Hermes may append guidance paragraphs after the copy
/// (`agent/turn_recovery.py`). A reply that only quotes the copy starts with
/// other text, so it never matches.
final List<RegExp> _turnFailurePatterns = [
  for (final template in _turnFailureTemplates.values)
    RegExp(
      "^(?:⚠️ )?"
      "${template.splitMapJoin(
        RegExp(r"\{(\w+)[^}]*\}"),
        onMatch: (field) => _trailingDetailFields.contains(field[1]) ? r"[\s\S]*" : r"[^\n]*?",
        onNonMatch: RegExp.escape,
      )}"
      r"(?:\n\n[\s\S]*)?$",
    ),
];

/// Whether [text] is the explanation Hermes sends as its whole final response
/// when a turn fails.
bool isHermesTurnFailureNotice({required String text}) => _turnFailurePatterns.any((pattern) => pattern.hasMatch(text));

/// Whether [text] is the row Hermes saved to close a failed turn. Hermes reads
/// this row the same way (`untyped_failed_turn_display_kind`): the exact text
/// and nothing else, so a reply that quotes it stays a reply.
bool isHermesFailedTurnRow({required String text}) => _failedTurnRows.contains(text.trim());
