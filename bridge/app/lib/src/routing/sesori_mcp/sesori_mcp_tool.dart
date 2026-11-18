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
  ),
  createTask(
    wireName: "create_task",
    readOnly: false,
    description:
        "Propose a new scheduled task in this session's project (or project_id) with this session's harness. The "
        "user allows or rejects it on their phone; nothing is created until they allow it. A session has one "
        "request waiting at a time: a new one replaces it.",
    inputSchema: {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "prompt": {"type": "string", "description": "The text each run sends."},
        "schedule": _scheduleSchema,
        "time_zone": _timeZoneSchema,
        "project_id": {"type": "string", "description": "A project id from list_tasks; this session's by default."},
        "missed_run_policy": _missedRunPolicySchema,
        "run_mode": _runModeSchema,
        "model": _modelSchema,
        "effort": _effortSchema,
        "approval_mode": _approvalModeSchema,
      },
      "required": ["name", "prompt", "schedule", "time_zone"],
      "additionalProperties": false,
    },
  ),
  updateTask(
    wireName: "update_task",
    readOnly: false,
    description:
        "Propose changes to a scheduled task; fields you leave out keep their value. The user allows or rejects "
        "it on their phone, and a change the user makes to the task first wins. A session has one request "
        "waiting at a time: a new one replaces it.",
    inputSchema: {
      "type": "object",
      "properties": {
        "task_id": {"type": "string"},
        "name": {"type": "string"},
        "prompt": {"type": "string", "description": "A new prompt text. Only for tasks that send text."},
        "command_arguments": {
          "type": "string",
          "description": "New arguments for a task that runs a command; the command stays.",
        },
        "schedule": _scheduleSchema,
        "time_zone": _timeZoneSchema,
        "missed_run_policy": _missedRunPolicySchema,
        "run_mode": _runModeSchema,
        "model": _modelSchema,
        "effort": _effortSchema,
        "approval_mode": _approvalModeSchema,
      },
      "required": ["task_id"],
      "additionalProperties": false,
    },
  ),
  pauseTask(
    wireName: "pause_task",
    readOnly: false,
    description: "Propose pausing a scheduled task. The user allows or rejects it on their phone.",
    inputSchema: _taskIdSchema,
  ),
  resumeTask(
    wireName: "resume_task",
    readOnly: false,
    description:
        "Propose resuming a paused scheduled task from its next time. The user allows or rejects it on their "
        "phone.",
    inputSchema: _taskIdSchema,
  ),
  runTaskNow(
    wireName: "run_task_now",
    readOnly: false,
    description: "Propose running a scheduled task once now. The user allows or rejects it on their phone.",
    inputSchema: _taskIdSchema,
  );

  static SesoriMcpTool? fromWireName({required String name}) {
    for (final tool in values) {
      if (tool.wireName == name) return tool;
    }
    return null;
  }
}

const Map<String, Object?> _taskIdSchema = {
  "type": "object",
  "properties": {
    "task_id": {"type": "string"},
  },
  "required": ["task_id"],
  "additionalProperties": false,
};

const Map<String, Object?> _scheduleSchema = {
  "type": "object",
  "description":
      'One of {"kind":"once","at":DATE_TIME}, {"kind":"daily","time":TIME}, {"kind":"weekdays","time":TIME} '
      '(Monday to Friday), {"kind":"weekly","days":["monday",...],"time":TIME} or '
      '{"kind":"everyHours","hours":1-12,"start":DATE_TIME}. TIME is {"hour":0-23,"minute":0-59}; DATE_TIME is '
      '{"year","month","day","hour","minute"}; both are wall-clock time in time_zone.',
  "properties": {
    "kind": {
      "type": "string",
      "enum": ["once", "daily", "weekdays", "weekly", "everyHours"],
    },
  },
  "required": ["kind"],
};

const Map<String, Object?> _timeZoneSchema = {
  "type": "string",
  "description": "An IANA time zone, such as Europe/Bucharest.",
};

const Map<String, Object?> _missedRunPolicySchema = {
  "type": "string",
  "enum": ["runWhenBack", "waitForNext"],
  "description": "When the computer was off at a run's time: run once when back (the default), or wait for the next.",
};

const Map<String, Object?> _runModeSchema = {
  "type": "object",
  "description":
      '{"kind":"newSession"} starts a session per run (the default); {"kind":"sameSession","autoCompact":true} '
      "continues one session, compacting it before each run when autoCompact is true.",
  "properties": {
    "kind": {
      "type": "string",
      "enum": ["newSession", "sameSession"],
    },
    "autoCompact": {"type": "boolean"},
  },
  "required": ["kind"],
};

const Map<String, Object?> _modelSchema = {
  "type": "string",
  "description": "provider/model, as this harness names it. Left out, the harness picks.",
};

const Map<String, Object?> _effortSchema = {
  "type": "string",
  "description": "The harness's effort (variant) id. Left out, the harness picks.",
};

const Map<String, Object?> _approvalModeSchema = {
  "type": "string",
  "enum": ["ask", "approveAll"],
  "description": "ask (the default) waits for the user on every permission; approveAll lets runs act without asking.",
};
