import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolDefinition;

const Map<String, Object?> _prSchema = {
  "type": "string",
  "description": "The PR as owner/repo#123 or its full URL (https://github.com/owner/repo/pull/123).",
};

const Map<String, Object?> _prOnlySchema = {
  "type": "object",
  "properties": {"pr": _prSchema},
  "required": ["pr"],
  "additionalProperties": false,
};

/// The PR monitor's tools.
enum PullRequestMonitorTool({
  required final String wireName,
  required final String description,

  /// Advertised as MCP's `readOnlyHint`. Tools that write nothing on GitHub
  /// count as read-only.
  required final bool readOnly,
  required final Map<String, Object?> inputSchema,
}) {
  watchPr(
    wireName: "watch_pr",
    readOnly: false,
    description:
        "Watch a GitHub pull request from this session. Call it right after you open a PR, or when asked to watch "
        "or babysit one. Sesori polls the PR through the gh CLI once a minute and messages this session a "
        "[PR Monitor] report when CI finishes or fails, a review or comment arrives, a conflict appears, or the PR "
        "is merged or closed; act on every report. Reports arrive on their own, so end your turn instead of "
        "polling or sleeping. The result is the PR's current report. The watch survives a bridge restart and ends "
        "once the PR is merged or closed; a sub-agent's watch belongs to its root session.",
    inputSchema: {
      "type": "object",
      "properties": {
        "pr": _prSchema,
        "auto_merge": {
          "type": "boolean",
          "description":
              "Only when the user asked for this PR to be merged without human review: marking it ready then "
              "squash-merges it once. Leave it out for the user's default from configure_pr_monitor, which is "
              "off unless they changed it.",
        },
      },
      "required": ["pr"],
      "additionalProperties": false,
    },
  ),
  unwatchPr(
    wireName: "unwatch_pr",
    readOnly: false,
    description: "Stop this session's watch of a PR. Other sessions watching it keep their watch.",
    inputSchema: _prOnlySchema,
  ),
  prWatchStatus(
    wireName: "pr_watch_status",
    readOnly: true,
    description:
        "List the PRs this session watches: whether a report is buffered or held for CI, how long since the last "
        "report, poll failures and readiness, plus how many PRs this computer polls.",
    inputSchema: {"type": "object", "properties": <String, Object?>{}, "additionalProperties": false},
  ),
  getPrReport(
    wireName: "get_pr_report",
    readOnly: true,
    description:
        "Fetch a PR this session watches now and return its report: what changed since this session's last "
        "report, which it then counts as reported. Use it when you need the current state before the next report "
        "arrives; never call it in a loop.",
    inputSchema: _prOnlySchema,
  ),
  getPrFeedback(
    wireName: "get_pr_feedback",
    readOnly: true,
    description:
        "Fetch the full text of a PR's feedback still awaiting your reply: each unanswered review thread with its "
        "id, and the PR comments and review summaries since your last reply. Reports only count comments, so read "
        "them here before acting on them.",
    inputSchema: _prOnlySchema,
  ),
  replyOnPr(
    wireName: "reply_on_pr",
    readOnly: false,
    description:
        "Post your reply on a PR: in a review thread when thread_id is given, otherwise as a PR comment. Sesori "
        "prefixes it with [Sesori reply] so the monitor never reports it back as new feedback. Reply to each "
        "review comment once you have fixed it or decided not to.",
    inputSchema: {
      "type": "object",
      "properties": {
        "pr": _prSchema,
        "body": {"type": "string", "description": "The reply, in GitHub Markdown."},
        "thread_id": {
          "type": "string",
          "description": "The review thread id from get_pr_feedback, such as PRRT_kwDO…; omit for a PR comment.",
        },
      },
      "required": ["pr", "body"],
      "additionalProperties": false,
    },
  ),
  markPrReady(
    wireName: "mark_pr_ready",
    readOnly: false,
    description:
        "Mark a PR ready: add the agent-ready label, handing it to a human reviewer. Call it once checks pass, "
        "expected reviews have arrived and every comment is answered, with nothing left for you to do. When "
        "auto-merge is on for the PR, this is the merge approval: Sesori makes one squash-merge attempt at the "
        "head it last polled.",
    inputSchema: _prOnlySchema,
  ),
  unmarkPrReady(
    wireName: "unmark_pr_ready",
    readOnly: false,
    description:
        "Withdraw a PR's ready label, for example when new work turns up after you marked it ready. A watched PR "
        "that still qualifies is labelled again after its next quiet report.",
    inputSchema: _prOnlySchema,
  ),
  setPrAutoMerge(
    wireName: "set_pr_auto_merge",
    readOnly: false,
    description:
        "Turn auto-merge on or off for a PR this session watches, only when the user asks. With it on, the ready "
        "label is the merge approval: Sesori squash-merges the PR once it is marked ready. Turning it on removes a "
        "ready label the PR already carries, so it is merged only after a fresh judgment.",
    inputSchema: {
      "type": "object",
      "properties": {
        "pr": _prSchema,
        "enabled": {"type": "boolean", "description": "true to turn auto-merge on, false to turn it off."},
      },
      "required": ["pr", "enabled"],
      "additionalProperties": false,
    },
  ),
  configurePrMonitor(
    wireName: "configure_pr_monitor",
    readOnly: false,
    description:
        "Change the PR monitor's settings on this computer, only when the user asks: whether PRs watched without "
        "choosing auto_merge get auto-merge, for every repository or one, and the report timings. Timings apply to "
        "every watch from its next poll; the auto-merge default applies to watches started afterwards. Turning "
        "auto-merge on by default asks the user to allow it, and the result says whether it waits for their "
        "answer. pr_watch_status shows the current settings.",
    inputSchema: {
      "type": "object",
      "properties": {
        "auto_merge": {
          "type": "string",
          "enum": ["on", "off"],
          "description": "The auto-merge default: for every repository, or for repository alone when given.",
        },
        "repository": {
          "type": "string",
          "description": "owner/repo: auto_merge or clear_repository then sets that repository's own default.",
        },
        "clear_repository": {
          "type": "boolean",
          "description": "true to remove repository's own auto-merge default, so it follows every repository's.",
        },
        "quiet_minutes": {
          "type": "integer",
          "description":
              "1 to 60: how long a report waits after the latest activity, so a burst arrives as one "
              "report. Default 2.",
        },
        "ci_wait_minutes": {
          "type": "integer",
          "description":
              "5 to 240: how long a due report waits for running CI before it goes out anyway. "
              "Default 30.",
        },
        "idle_reminder_minutes": {
          "type": "integer",
          "description":
              "5 to 240, or 0 for none: how long an open PR stays still before this session is "
              "reminded of it. Default 25.",
        },
      },
      "additionalProperties": false,
    },
  );

  SesoriToolDefinition get definition =>
      SesoriToolDefinition(name: wireName, description: description, readOnly: readOnly, inputSchema: inputSchema);
}
