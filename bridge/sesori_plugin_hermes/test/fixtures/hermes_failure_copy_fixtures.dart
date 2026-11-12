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
  // Hermes 0.23.1 `locales/{de,ja,ar}.yaml`, filled by `launch_credentials_copy`.
  "launch credentials in German (0.23.1)":
      "⚠️ Dieser Chat kann den API-Schlüssel, mit dem er gestartet wurde, nicht mehr verwenden "
      "(OPENROUTER_API_KEY: unavailable), daher kann darin nichts mehr ausgeführt werden. Ein offener Chat wechselt "
      "nie von selbst zu einem anderen Schlüssel, deshalb scheitert /retry genauso. Starte mit /new einen neuen Chat "
      "mit deinem aktuellen Schlüssel.\n\nDetails: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
  "launch credentials in Japanese (0.23.1)": "⚠️ このチャットは開始時の API キーをもう使えないため (OPENROUTER_API_KEY: unavailable)、このチャットでは何も実行できません。開いているチャットが自動で別のキーに切り替わることはないので、/retry でも同じように失敗します。/new で現在のキーを使う新しいチャットを始めてください。\n\nDetails: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
  "launch credentials in Arabic (0.23.1)":
      "⚠️ لم تعد هذه المحادثة قادرة على استخدام مفتاح API الذي بدأت به (OPENROUTER_API_KEY: unavailable)، لذلك لا "
      "يمكن تشغيل أي شيء فيها. المحادثة المفتوحة لا تنتقل أبدًا إلى مفتاح مختلف من تلقاء نفسها، لذا سيفشل /retry "
      "بالطريقة نفسها. استخدم /new لبدء محادثة جديدة بمفتاحك الحالي.\n\n"
      "Details: launch_credentials_unavailable (OPENROUTER_API_KEY: unavailable)",
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
  "retries exhausted with no reply (0.23.1)":
      "⚠️ No reply: the model provider didn't answer after all retries. Send /retry, or switch models with /model.",
  "local context too small (0.23.1)":
      "⚠️ No reply: the local model's context window was too small to finish. Increase the context size or use a "
      "larger model.",
  "error near the iteration limit (0.23.1)":
      "⚠️ No reply: an error occurred near the iteration limit before a final answer. Check the tool output above, "
      "then send `continue`.",
  "repeated errors (0.23.1)":
      "⚠️ No reply: the turn kept failing with repeated errors and was stopped early instead of retrying forever. "
      "Check the errors above, then send `continue` to retry.",
  "session storage busy (0.23.1)":
      "⚠️ No reply: the turn was stopped because session storage was busy (another Hermes process was writing to "
      "the state database). Your message should already be saved — please send it again in a moment.",
  "session storage corrupt (0.23.1)":
      "⚠️ No reply: the turn was stopped because the state database reported structural corruption (the "
      "transcript would have been lost on restart). Freeing disk space will not help. Recovery options:\n1. Run "
      "`hermes doctor --fix`\n2. Stop the gateway, then recover with:\n   hermes sessions recover --source "
      "/home/u/.hermes/state.db --inspect-only\n   (if it reports recoverable) hermes sessions recover --source "
      "/home/u/.hermes/state.db --output recovered-state.db\n   — recovery snapshots the damaged file first; do "
      'NOT run `sqlite3 ... ".recover"` against the live state.db, a vulnerable sqlite3 CLI can corrupt it '
      "further\n3. Restore from a backup in /home/u/.hermes/backups/\nThen send your message again.",
  "session storage unsaved (0.23.1)":
      "⚠️ No reply: Hermes couldn't save this conversation, so it stopped rather than lose your messages. Possible "
      "causes: the drive is out of room, or another Hermes process is holding the database. Close other Hermes "
      "windows, run `hermes -p work doctor` to check storage, then send your message again.",
};

/// The row Hermes 0.23.1 replays for a turn its model's safety filter refused.
const String contentRefusedRow = "This message was refused by the model's safety filter — try a different query.";

/// "No reply:" explanations Hermes 0.23.1 gives for exits that do not fail the
/// turn, which stay replies.
const Map<String, String> advisoryNoReplyTexts = {
  "empty response":
      "⚠️ No reply: gpt-5 didn't produce a reply this time, even after retries. Send `continue` to try again, or switch "
      "models with /model.",
  "budget exhausted":
      "⚠️ No reply: the per-turn iteration/cost budget was exhausted before a final answer. Send `continue` to keep "
      "going.",
  "iteration limit":
      "⚠️ No reply: the maximum tool-iteration limit was reached before a final answer. Send `continue` to keep going, "
      "or raise `max_iterations`.",
  "interrupted call":
      "⚠️ No reply: the request was interrupted mid-call before a reply was received. Send `continue` to retry.",
};
