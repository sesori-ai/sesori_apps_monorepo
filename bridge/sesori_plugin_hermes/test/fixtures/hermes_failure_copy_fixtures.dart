/// The final response Hermes streamed when its model provider stayed
/// unreachable through every retry (reported 2026-11-09 on Hermes 0.21.5,
/// whose `agent/turn_failure_copy.py::exhausted_copy` writes this shape).
const String providerTimeoutNotice =
    "custom didn't respond in time on any of 3 attempts — it looks temporarily unavailable. "
    "Wait a minute and send /retry, or switch models with /model. To avoid this in future, "
    "add a backup provider with `hermes fallback add`.\n\nProvider said: Connection error.";

/// The row Hermes saves to close a turn that failed before any tool ran
/// (`messages.display_kind = 'failed_turn'` in `~/.hermes/state.db`).
const String failedTurnBoundary = "Your request was not processed. Send it again if you still want me to carry it out.";

/// The same row when a tool already ran in the failed turn.
const String partialFailedTurnBoundary =
    "This turn did not complete. Some actions may already have run; verify their effects before resending.";

/// The row Hermes saves when an automated (cron, process or webhook) turn was
/// lost across a gateway restart.
const String automationInterruptedBoundary =
    "An automated delivery was interrupted and was not run again. Some actions may already have run; verify their "
    "effects.";

/// One rendered final response per family of Hermes failure copy, filled in
/// the way Hermes 0.21.5 fills its templates.
const Map<String, String> failureNotices = {
  "retries exhausted": providerTimeoutNotice,
  "retries exhausted on a usage limit":
      "Nous Portal returned a server error on all 3 attempts — its usage limit resets in ~3h. "
      "Send /retry after that, or switch models with /model. To avoid this in future, "
      "add a backup provider with `hermes fallback add`.\n\nProvider said: HTTP 503",
  "retries exhausted with appended guidance":
      "$providerTimeoutNotice\n\nThe connection kept dropping while the model was writing — this often "
      "happens when it writes a very large file in one go. Ask me to write the file in smaller sections "
      "(or via execute_code with Python's open()).",
  "unknown model":
      "Model 'gpt-9' isn't available on OpenRouter. Pick a different model with /model "
      "(or `hermes model` in a terminal).\n\nProvider said: HTTP 404: model not found",
  "rejected API key":
      "OpenRouter rejected your API key, so the model can't be reached. Update it in "
      "Settings → Providers, or run `hermes setup` in a terminal.\n\nProvider said: HTTP 401",
  "rejected sign-in":
      "Nous Portal rejected your sign-in, so the model can't be reached. Sign in again: `hermes portal`."
      "\n\nProvider said: HTTP 401",
  "other rejection":
      "OpenRouter rejected the request and retrying won't help. Pick another model with /model, "
      "or check the details in `~/.hermes/logs/agent.log`.\n\nProvider said: HTTP 400",
  "content policy":
      "⚠️ OpenRouter's safety filter refused this request, so the model didn't answer. Try rewording your "
      "message or removing sensitive attachments, or switch to another model with /model."
      "\n\nProvider said: content_filter",
  "content policy (0.23.1)":
      "⚠️ OpenRouter's safety filter refused this request, so the model didn't answer. That message has been "
      "left out of this conversation, so you're not stuck — just ask something else and you can keep going. "
      "Rewording it, removing any sensitive attachments, or switching models with /model can also help. If a "
      "later message is refused too, start a new chat with /new (in a Bot Chat, Archive it from its tab menu)."
      "\n\nProvider said: content_filter",
  "first-attempt rate limit (0.22.6)":
      "Nous Portal is rate-limiting requests right now — its usage limit resets in ~2m. "
      "Send /retry after that, or switch models with /model. To avoid this in future, "
      "add a backup provider with `hermes fallback add`.\n\nProvider said: HTTP 429",
  "stream lifetime (0.22.6)":
      "The response was still streaming when agent.stream_max_lifetime (900s) cut it, on all 3 attempts. "
      "Raise agent.stream_max_lifetime, or set it to 0 to turn the cap off, if this model legitimately "
      "streams this long.",
  "data policy":
      "This conversation holds a result from a connected app that may only go to a model that does not train "
      "on your data, and 'gpt-5' on OpenRouter can't promise that. Switch models with /model, run /compress to "
      "summarize the result away, or start fresh with /new. If you are on the free tier, no free model can take "
      "this content: upgrade, or use /compress or /new.\n\nProvider said: HTTP 403",
  "billing": "Billing or credits exhausted: HTTP 402: insufficient credits",
  "free-tier outage":
      "The free model is having trouble responding right now. Try sending your message again in a minute.",
  "free-tier refusal":
      "You've used up the allowance for chatting without signing in. It refreshes in 3 hours. "
      "Sign in for a bigger allowance, it's free. To sign in: /login.",
  "loop error":
      "Hermes hit repeated errors and stopped this turn so it wouldn't keep retrying. Your message is saved. "
      "Send `continue` to try again, or start a new session with /new. If it happens again, run "
      "`hermes doctor` and share the error details.\n\nDetails: KeyError: 'choices'",
  "context overflow":
      "This conversation has grown too long for gpt-5 to read, and Hermes couldn't shrink it enough "
      "automatically. Start a new session with /new (your history is kept), or try /compress once more. "
      "Switching to a model with a bigger context window also works.",
  "shutdown":
      "Hermes was shutting down and stopped this turn. Your conversation is saved — reopen it and send "
      "your message again.",
  "launch credentials (0.23.1)":
      "⚠️ This chat can't use the API key it was started with any more (OPENROUTER_API_KEY: unavailable), so "
      "nothing can run in it. An open chat never switches to a different key on its own, so /retry fails the same "
      "way. Use /new to start a new chat on your current key.\n\nDetails: launch_credentials_unavailable "
      "(OPENROUTER_API_KEY: unavailable)",
  "launch credentials without a named key (0.23.1)":
      "⚠️ This chat can't use the API key it was started with any more, so nothing can run in it. An open chat "
      "never switches to a different key on its own, so /retry fails the same way. Use /new to start a new chat on "
      "your current key.",
  // Only the details line stays in English.
  "launch credentials in another language (0.23.1)":
      "⚠️ Dieser Chat kann den API-Schlüssel, mit dem er gestartet wurde, nicht mehr verwenden "
      "(OPENROUTER_API_KEY: unavailable). Starte mit /new einen neuen Chat.\n\nDetails: "
      "launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
  "scheduled-job chat (0.23.1)":
      "⚠️ This chat belongs to a scheduled job and only runs that job, so your message was not run. Start a new "
      "chat to send it.",
  "missing working folder (0.23.1)":
      "⚠️ This chat's working folder no longer exists (/repo/gone), so your message was not run. Recreate the "
      "folder, or move the chat to another one (`/worktree new` in the CLI, Move to project in the desktop app), "
      "then send your message again.",
  "pending tool result (0.23.1)":
      "⚠️ No reply: the turn stopped while a tool result was still pending and the model produced no follow-up "
      "text. Send `continue` to let it summarize.",
  "pending tool result with the explainer off (0.23.1)":
      "No reply: the turn stopped while a tool result was still pending. Send `continue` to let the model "
      "summarize.",
};

/// The row Hermes 0.23.1 replays for a turn its model's safety filter refused.
const String contentRefusedRow = "This message was refused by the model's safety filter — try a different query.";
