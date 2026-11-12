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
// Later additions are marked with the release they were copied from (read
// on 2026-11-12).
// If Hermes rewords one, that failure shows as plain assistant text again,
// which is how it showed before these matchers existed. Paste the new
// template here from the Hermes source.

/// Hermes's chat copy for a turn that ended in failure, keyed by Hermes's own
/// name for it.
///
/// Left out on purpose: `reasoning_only`, which ends with the model's own last
/// thoughts ("which may contain the answer"), so it stays a reply, and the
/// "No reply:" explanations for exits that do not fail the turn
/// (`empty_response`, `partial_stream_recovery`, `fallback_prior_turn_content`,
/// `redirect_restart_limit_exceeded`, `rebuilt_restart_limit_exceeded`,
/// `budget_exhausted`, `interrupted_during_api_call`, `max_iterations_reached`).
const Map<String, String> _turnFailureTemplates = {
  // exhausted_copy: `{lead}` is an `_EXHAUSTED_LEADS` lead or, since 0.22.6, a
  // first-attempt `_EXHAUSTED_FIRST_ATTEMPT_LEADS` lead.
  "exhausted":
      "{lead} — it looks temporarily unavailable. Wait a minute and send /retry, or switch models with "
      "/model. To avoid this in future, add a backup provider with `hermes fallback add`.\n\nProvider said: {summary}",
  "exhausted_until_reset":
      "{lead} — its usage limit resets in {window}. Send /retry after that, or switch models with /model. "
      "To avoid this in future, add a backup provider with `hermes fallback add`.\n\nProvider said: {summary}",
  // 0.22.6: exhausted_copy for a stream cut by `agent.stream_max_lifetime`.
  "stream_lifetime_exhausted":
      "The response was still streaming when agent.stream_max_lifetime ({cap:g}s) cut it, on all {attempts} "
      "attempts. Raise agent.stream_max_lifetime, or set it to 0 to turn the cap off, if this model legitimately "
      "streams this long.",
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
  "data_policy_denied":
      "This conversation holds a result from a connected app that may only go to a model that does not train on "
      "your data, and '{model}' on {label} can't promise that. Switch models with /model, run /compress to "
      "summarize the result away, or start fresh with /new. If you are on the free tier, no free model can take "
      "this content: upgrade, or use /compress or /new.\n\nProvider said: {summary}",
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
  // 0.23.1: content_policy_copy with `CONTENT_POLICY_NEXT_STEPS`.
  "content_policy_next_steps":
      "{label}'s safety filter refused this request, so the model didn't answer. That message has been left out of "
      "this conversation, so you're not stuck — just ask something else and you can keep going. Rewording it, "
      "removing any sensitive attachments, or switching models with /model can also help. If a later message is "
      "refused too, start a new chat with /new (in a Bot Chat, Archive it from its tab menu).\n\n"
      "Provider said: {summary}",
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
  // 0.23.1 `locales/en.yaml` `gateway.errors` (sent with a leading "⚠️ "). In
  // other languages only launch_credentials_unavailable is recognized, by its
  // shape and untranslated details line (see [_isLaunchCredentialsNotice]).
  "launch_credentials_unavailable":
      "This chat can't use the API key it was started with any more{detail}, so nothing can run in it. An open chat "
      "never switches to a different key on its own, so /retry fails the same way. Use /new to start a new chat on "
      "your current key.",
  "cron_session_read_only":
      "This chat belongs to a scheduled job and only runs that job, so your message was not run. Start a new chat to "
      "send it.",
  "workspace_unavailable":
      "This chat's working folder no longer exists ({path}), so your message was not run. Recreate the folder, or move "
      "the chat to another one (`/worktree new` in the CLI, Move to project in the desktop app), then send your "
      "message again.",
  // 0.23.1 `agent/turn_finalizer.py`: the turn stopped on a tool result. With
  // Hermes's turn explainer on, `explainer.no_reply_prefix` +
  // `explainer.exit.pending_tool_result` ("⚠️ No reply: …"); with it off, a
  // fixed fallback.
  "pending_tool_result":
      "No reply: the turn stopped while a tool result was still pending and the model produced no follow-up text. "
      "Send `continue` to let it summarize.",
  "pending_tool_result_fallback":
      "No reply: the turn stopped while a tool result was still pending. Send `continue` to let the model summarize.",
  // 0.23.1 `agent/turn_explainers.py`: the other "⚠️ No reply: …" explanations
  // for exits that fail the turn (`_EXIT_REASON_FAILURES` with fails_turn).
  "all_retries_exhausted_no_response":
      "No reply: the model provider didn't answer after all retries. Send /retry, or switch models with /model.",
  "ollama_runtime_context_too_small":
      "No reply: the local model's context window was too small to finish. Increase the context size or use a "
      "larger model.",
  "error_near_max_iterations":
      "No reply: an error occurred near the iteration limit before a final answer. Check the tool output above, "
      "then send `continue`.",
  "repeated_outer_errors":
      "No reply: the turn kept failing with repeated errors and was stopped early instead of retrying forever. "
      "Check the errors above, then send `continue` to retry.",
  // The same for `session_persistence_failed`, by cause (`explainer.persistence`).
  "persistence_compression":
      "No reply: the turn was stopped because another process was compressing this session. Your message should "
      "already be saved — please send it again after compression completes.",
  "persistence_compression_closed":
      "No reply: the turn was stopped because this session was rotated by context compression and its live "
      "continuation could not be adopted. The storage itself is healthy — refresh the client (or start a new turn) "
      "so it picks up the new session id, then send your message again.",
  "persistence_turn_lease":
      "No reply: the turn was stopped because another Hermes process took over this session. Your reply was not "
      "saved — wait for the other process to finish, then send your message again.",
  "persistence_session_row_missing":
      "No reply: this session was deleted from storage while the chat was still open, and Hermes could not "
      "recreate it, so this message was not saved. Send your message again; if it keeps failing, run `hermes "
      "{profile_arg}doctor`.",
  "persistence_locked":
      "No reply: the turn was stopped because session storage was busy (another Hermes process was writing to the "
      "state database). Your message should already be saved — please send it again in a moment.",
  "persistence_replaced":
      "No reply: the session database file was replaced while Hermes was running, so this message was not saved (a "
      "copy is kept in {home}/sessions/). Stop Hermes (`hermes {profile_arg}gateway stop`), run `hermes "
      "{profile_arg}doctor` — not `hermes {profile_arg}doctor --fix`, which would repair the wrong file in place — "
      "then start it again and send your message once more. Advanced recovery steps are in the log.",
  "persistence_deleted_wal":
      "No reply: another Hermes process still holds an old copy of the session database's write-ahead log, so "
      "Hermes stopped writing to keep the file safe and this message was not saved (a copy is kept in "
      "{home}/sessions/). Nothing is lost. Quit every Hermes process on this profile (Desktop app, `hermes "
      "{profile_arg}gateway stop`, dashboard, cron), run `hermes {profile_arg}doctor` — it names any process still "
      "holding the log — then start Hermes again and send your message once more. Do not run `doctor --fix` or "
      "delete any state.db files while they run. Guide: {recovery_docs}",
  "persistence_corrupt":
      "No reply: the turn was stopped because the state database reported structural corruption (the transcript "
      "would have been lost on restart). Freeing disk space will not help. Recovery options:\n1. Run `hermes "
      "{profile_arg}doctor --fix`\n2. Stop the gateway, then recover with:\n   hermes {profile_arg}sessions "
      "recover --source {db_path} --inspect-only\n   (if it reports recoverable) hermes {profile_arg}sessions "
      "recover --source {db_path} --output recovered-state.db\n   — recovery snapshots the damaged file first; do "
      'NOT run `sqlite3 ... ".recover"` against the live state.db, a vulnerable sqlite3 CLI can corrupt it '
      "further\n3. Restore from a backup in {backups_dir}/\nThen send your message again.",
  "persistence_fts_index":
      "No reply: the turn was stopped because the session search index (FTS5) is corrupt and could not be "
      "detached, so this message was not saved. The message store itself is not damaged: do not run recovery tools "
      "or restore a backup. Run `hermes {profile_arg}doctor --fix` (or restart Hermes, which repairs the index on "
      "open), then send your message again.",
  "persistence_disk":
      "No reply: Hermes couldn't save this conversation to disk, so it stopped rather than lose your messages. The "
      "disk is probably full: free some space (or fix the permissions on {home}/state.db), then send your message "
      "again.",
  "persistence_default":
      "No reply: Hermes couldn't save this conversation, so it stopped rather than lose your messages. Possible "
      "causes: the drive is out of room, or another Hermes process is holding the database. Close other Hermes "
      "windows, run `hermes {profile_arg}doctor` to check storage, then send your message again.",
};

/// Whether [text] is launch_credentials_unavailable in any language with the
/// refused key named (`launch_credentials_copy`): the translated copy, one
/// line starting with "⚠️ " and naming ` (<field>: <detail>)`, then the
/// untranslated `Details: launch_credentials_unavailable (<field>: <detail>)`
/// with the same key, and nothing else. A reply that only ends with the
/// details line does not have this shape. Checked with string operations so a
/// long reply costs one scan.
bool _isLaunchCredentialsNotice({required String text}) {
  const details = "\n\nDetails: launch_credentials_unavailable";
  final trimmed = text.trimRight();
  if (!trimmed.startsWith("⚠️ ")) return false;
  final at = trimmed.indexOf(details);
  if (at < 0) return false;
  final notice = trimmed.substring(0, at);
  final key = trimmed.substring(at + details.length);
  return key.startsWith(" (") &&
      key.endsWith(")") &&
      !key.contains("\n") &&
      !notice.contains("\n") &&
      notice.contains(key);
}

/// The row Hermes saves in its own history to close a failed turn, in place
/// of the failure text it sent live (which it never saves): `FAILED_TURN_NOTICE`.
const String hermesFailedTurnRow =
    "Your request was not processed. Send it again if you still want me to carry it out.";

/// The rows Hermes saves instead when actions may already have run, a warning
/// the live reason does not carry.
const Set<String> _partialTurnRows = {
  // PARTIAL_FAILED_TURN_NOTICE: a tool already ran in the failed turn.
  "This turn did not complete. Some actions may already have run; verify their effects before resending.",
  // AUTOMATION_INTERRUPTED_NOTICE: a cron, process or webhook turn lost across a gateway restart.
  "An automated delivery was interrupted and was not run again. Some actions may already have run; verify their effects.",
};

/// Placeholders that hold the provider's or Hermes's raw detail, which may
/// span lines.
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
bool isHermesTurnFailureNotice({required String text}) =>
    _turnFailurePatterns.any((pattern) => pattern.hasMatch(text)) || _isLaunchCredentialsNotice(text: text);

/// Whether [text] is the row Hermes saved to close a failed turn before any
/// tool ran. Hermes reads its rows the same way
/// (`untyped_failed_turn_display_kind`): the exact text and nothing else, so a
/// reply that quotes one stays a reply.
bool isHermesFailedTurnRow({required String text}) => text.trim() == hermesFailedTurnRow;

/// [text] without the generic saved row Hermes appends as its last paragraph
/// after a live reason; the row alone stays. The bridge's history store drops
/// the row from a notice the same way when the replayed row is the same kind.
String withoutTrailingFailedTurnRow({required String text}) {
  final trimmed = text.trimRight();
  const appended = "\n\n$hermesFailedTurnRow";
  if (!trimmed.endsWith(appended)) return text;
  final reason = trimmed.substring(0, trimmed.length - appended.length);
  return reason.trim().isEmpty ? text : reason;
}

/// Whether [text] is a row Hermes saved to close a turn whose actions may
/// already have run, matched like [isHermesFailedTurnRow].
bool isHermesPartialTurnRow({required String text}) => _partialTurnRows.contains(text.trim());

/// The row Hermes keeps in place of a turn its model's safety filter refused
/// (0.23.1 `CONTENT_REFUSED_NOTICE`), matched like [isHermesFailedTurnRow].
bool isHermesContentRefusedRow({required String text}) =>
    text.trim() == "This message was refused by the model's safety filter — try a different query.";
