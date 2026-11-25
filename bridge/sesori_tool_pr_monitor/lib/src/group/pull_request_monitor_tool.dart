import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolDefinition;

const Map<String, Object?> _prSchema = {
  "type": "string",
  "description": "The PR as owner/repo#123 or its full URL (https://github.com/owner/repo/pull/123).",
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
      "properties": {"pr": _prSchema},
      "required": ["pr"],
      "additionalProperties": false,
    },
  ),
  unwatchPr(
    wireName: "unwatch_pr",
    readOnly: false,
    description: "Stop this session's watch of a PR. Other sessions watching it keep their watch.",
    inputSchema: {
      "type": "object",
      "properties": {"pr": _prSchema},
      "required": ["pr"],
      "additionalProperties": false,
    },
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
    inputSchema: {
      "type": "object",
      "properties": {"pr": _prSchema},
      "required": ["pr"],
      "additionalProperties": false,
    },
  );

  SesoriToolDefinition get definition =>
      SesoriToolDefinition(name: wireName, description: description, readOnly: readOnly, inputSchema: inputSchema);
}
