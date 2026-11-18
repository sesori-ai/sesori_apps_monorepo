/// The tools Sesori's MCP server offers. A tool not listed here does not exist
/// for agents.
enum SesoriMcpTool({
  required final String wireName,
  required final String description,

  /// Advertised as MCP's `readOnlyHint`.
  required final bool readOnly,

  /// The JSON Schema of the tool's arguments, as MCP's `inputSchema`.
  required final Map<String, Object?> inputSchema,
}) {
  listTasks(
    wireName: "list_tasks",
    readOnly: true,
    description:
        "List the Sesori scheduled tasks on this computer: id, name, project, schedule, whether it is on, its next "
        "run and its last outcome.",
    inputSchema: {
      "type": "object",
      "properties": {
        "project_id": {"type": "string", "description": "Only tasks of this project (a project id from the list)."},
      },
      "additionalProperties": false,
    },
  ),
  getTask(
    wireName: "get_task",
    readOnly: true,
    description:
        "Show one scheduled task's full definition and state. Without task_id, shows this session's own task when "
        "this session is a scheduled run.",
    inputSchema: {
      "type": "object",
      "properties": {
        "task_id": {"type": "string"},
      },
      "additionalProperties": false,
    },
  ),
  listTaskRuns(
    wireName: "list_task_runs",
    readOnly: true,
    description:
        "List a task's newest runs (up to 20), newest first: when, the outcome, whether it ran late, and the start "
        "of each run's final reply. Read a whole run with get_task_run_transcript.",
    inputSchema: {
      "type": "object",
      "properties": {
        "task_id": {"type": "string"},
      },
      "required": ["task_id"],
      "additionalProperties": false,
    },
  ),
  getTaskRunTranscript(
    wireName: "get_task_run_transcript",
    readOnly: true,
    description:
        "Read the transcript of one task run's session: user and assistant messages, tool names and short tool "
        "results. Returns the newest page first; pass its next_page as page to read older messages. Runs of a "
        "same-session task share one session, so their transcript covers every run in it.",
    inputSchema: {
      "type": "object",
      "properties": {
        "task_id": {"type": "string"},
        "run_id": {"type": "string"},
        "page": {"type": "integer", "description": "The next_page value of the previous result."},
      },
      "required": ["task_id", "run_id"],
      "additionalProperties": false,
    },
  );

  static SesoriMcpTool? fromWireName({required String name}) {
    for (final tool in values) {
      if (tool.wireName == name) return tool;
    }
    return null;
  }
}
