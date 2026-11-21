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
        "user allows or rejects it on their phone; nothing is created until they allow it. $_answeredOnItsOwn",
    inputSchema: {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "prompt": {"type": "string", "description": "The text each run sends."},
        "schedule": {..._scheduleSchema, "description": _scheduleDescription},
        "time_zone": {"type": "string", "description": _timeZoneDescription},
        "project_id": {"type": "string", "description": "A project id from list_tasks; this session's by default."},
        "missed_run_policy": {..._missedRunPolicySchema, "description": _missedRunPolicyDescription},
        "run_mode": {..._runModeSchema, "description": _runModeDescription},
        "model": {"type": "string", "description": "$_modelDescription Left out, the harness picks."},
        "effort": {"type": "string", "description": "$_effortDescription Left out, the harness picks."},
        "approval_mode": {..._approvalModeSchema, "description": _approvalModeDescription},
      },
      "required": ["name", "prompt", "schedule", "time_zone"],
      "additionalProperties": false,
    },
  ),
  updateTask(
    wireName: "update_task",
    readOnly: false,
    description:
        "Propose changes to a scheduled task. $_leaveOutUnchanged The user allows or rejects it on their phone. "
        "If the fields it changes are changed first, nothing is applied. $_answeredOnItsOwn",
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
        "schedule": {..._scheduleSchema, "description": "$_scheduleDescription $_leaveOutUnchanged"},
        "time_zone": {"type": "string", "description": "$_timeZoneDescription $_leaveOutUnchanged"},
        "missed_run_policy": {
          ..._missedRunPolicySchema,
          "description": "$_missedRunPolicyDescription $_leaveOutUnchanged",
        },
        "run_mode": {..._runModeSchema, "description": "$_runModeDescription $_leaveOutUnchanged"},
        "model": {"type": "string", "description": "$_modelDescription $_leaveOutUnchanged"},
        "effort": {"type": "string", "description": "$_effortDescription $_leaveOutUnchanged"},
        "approval_mode": {..._approvalModeSchema, "description": "$_approvalModeDescription $_leaveOutUnchanged"},
      },
      "required": ["task_id"],
      "additionalProperties": false,
    },
  ),
  pauseTask(
    wireName: "pause_task",
    readOnly: false,
    description: "Propose pausing a scheduled task. The user allows or rejects it on their phone. $_answeredOnItsOwn",
    inputSchema: _taskIdSchema,
  ),
  resumeTask(
    wireName: "resume_task",
    readOnly: false,
    description:
        "Propose resuming a paused scheduled task from its next time. The user allows or rejects it on their "
        "phone. $_answeredOnItsOwn",
    inputSchema: _taskIdSchema,
  ),
  runTaskNow(
    wireName: "run_task_now",
    readOnly: false,
    description:
        "Propose running a scheduled task once now. The user allows or rejects it on their phone. $_answeredOnItsOwn",
    inputSchema: _taskIdSchema,
  ),
  sendPage(
    wireName: "send_page",
    readOnly: true,
    description:
        "Ask the user on a page in the Sesori app, on whichever device they pick up: for decisions, choices "
        "between options, or input you need from them, especially several questions at once or anything that "
        "needs images. Also shows information that needs no answer. Returns at once; Sesori messages this "
        "session with the user's answers, or that they closed the page, so don't wait or poll for it, and don't "
        "ask the same thing in chat too. A page has sections, each with an optional heading, a Markdown body, "
        "images and questions. Question kinds: single (pick one option), multiple (pick any options) or text "
        "(free text). Sesori gives every question its own note field and ends every page with a free-text "
        '"Anything else?" field, so do not add your own catch-all question such as "Anything else?" or '
        '"Other comments". '
        "Images are absolute paths to png, jpg, gif or webp files, copied when sent. Limits: title 200 "
        "characters, 20 images (20 MiB each, 50 MiB in all), 50 questions, 12 options per question. "
        "Question ids are unique in the page and option ids in their question.",
    inputSchema: {
      "type": "object",
      "properties": {
        "title": {"type": "string"},
        "intro": {"type": "string", "description": "Markdown under the title."},
        "sections": {"type": "array", "items": _pageSectionSchema},
      },
      "required": ["title", "sections"],
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

const Map<String, Object?> _taskIdSchema = {
  "type": "object",
  "properties": {
    "task_id": {"type": "string"},
  },
  "required": ["task_id"],
  "additionalProperties": false,
};

/// Ends update_task's description and each of its setting descriptions: a
/// model that fills every field would otherwise propose changes nobody asked
/// for, such as a new schedule when only the prompt should change.
const String _leaveOutUnchanged = "Leave out every field you are not changing; left-out fields keep their value.";

const String _answeredOnItsOwn =
    "Each request is answered on its own; Sesori messages this session with the user's answer, so don't poll "
    "get_task for it.";

// The setting schemas below leave out their description: create_task and
// update_task each add their own, built from these texts.

const String _scheduleDescription =
    'One of {"kind":"once","at":DATE_TIME}, {"kind":"daily","time":TIME}, {"kind":"weekdays","time":TIME} '
    '(Monday to Friday), {"kind":"weekly","days":["monday",...],"time":TIME} or '
    '{"kind":"everyHours","hours":1-12,"start":DATE_TIME}. TIME is {"hour":0-23,"minute":0-59}; DATE_TIME is '
    '{"year","month","day","hour","minute"}; both are wall-clock time in time_zone.';

/// Lists every kind's fields, not just `kind`: a strict-schema provider lets
/// the model send only listed properties. A kind ignores the others.
const Map<String, Object?> _scheduleSchema = {
  "type": "object",
  "properties": {
    "kind": {
      "type": "string",
      "enum": ["once", "daily", "weekdays", "weekly", "everyHours"],
    },
    "at": {..._localDateTimeSchema, "description": "once: when it runs."},
    "time": {..._timeOfDaySchema, "description": "daily, weekdays and weekly: the time of day."},
    "days": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
      },
      "description": "weekly: the days it runs.",
    },
    "hours": {"type": "integer", "description": "everyHours: 1 to 12 hours between runs."},
    "start": {..._localDateTimeSchema, "description": "everyHours: the first run."},
  },
  "required": ["kind"],
};

const Map<String, Object?> _timeOfDaySchema = {
  "type": "object",
  "properties": {
    "hour": {"type": "integer"},
    "minute": {"type": "integer"},
  },
  "required": ["hour", "minute"],
};

const Map<String, Object?> _localDateTimeSchema = {
  "type": "object",
  "properties": {
    "year": {"type": "integer"},
    "month": {"type": "integer"},
    "day": {"type": "integer"},
    "hour": {"type": "integer"},
    "minute": {"type": "integer"},
  },
  "required": ["year", "month", "day", "hour", "minute"],
};

const String _timeZoneDescription = "An IANA time zone, such as Europe/Bucharest.";

const String _missedRunPolicyDescription =
    "When the computer was off at a run's time: run once when back (the default), or wait for the next.";

const Map<String, Object?> _missedRunPolicySchema = {
  "type": "string",
  "enum": ["runWhenBack", "waitForNext"],
};

const String _runModeDescription =
    '{"kind":"newSession"} starts a session per run (the default); {"kind":"sameSession","autoCompact":true} '
    "continues one session, compacting it before each run when autoCompact is true.";

const Map<String, Object?> _runModeSchema = {
  "type": "object",
  "properties": {
    "kind": {
      "type": "string",
      "enum": ["newSession", "sameSession"],
    },
    "autoCompact": {"type": "boolean"},
  },
  "required": ["kind"],
};

const String _modelDescription = "provider/model, as this harness names it.";

const String _effortDescription = "The harness's effort (variant) id.";

const String _approvalModeDescription =
    "ask (the default) waits for the user on every permission; approveAll lets runs act without asking.";

const Map<String, Object?> _approvalModeSchema = {
  "type": "string",
  "enum": ["ask", "approveAll"],
};

const Map<String, Object?> _pageImageSchema = {
  "type": "object",
  "properties": {
    "path": {"type": "string", "description": "Absolute path."},
    "caption": {"type": "string"},
  },
  "required": ["path"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageImagesSchema = {"type": "array", "items": _pageImageSchema};

const Map<String, Object?> _pageOptionSchema = {
  "type": "object",
  "properties": {
    "id": {"type": "string"},
    "label": {"type": "string"},
    "description": {"type": "string", "description": "Markdown."},
    "image": _pageImageSchema,
    "recommended": {"type": "boolean", "description": "Shows a label; never preselected."},
  },
  "required": ["id", "label"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageQuestionSchema = {
  "type": "object",
  "properties": {
    "id": {"type": "string"},
    "title": {"type": "string"},
    "body": {"type": "string", "description": "Markdown."},
    "images": _pageImagesSchema,
    "kind": {
      "type": "string",
      "enum": ["single", "multiple", "text"],
    },
    "options": {
      "type": "array",
      "items": _pageOptionSchema,
      "description": "single and multiple only.",
    },
    "required": {"type": "boolean", "description": "Must be answered to submit; false by default."},
  },
  "required": ["id", "title", "kind"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageSectionSchema = {
  "type": "object",
  "properties": {
    "heading": {"type": "string"},
    "body": {"type": "string", "description": "Markdown."},
    "images": _pageImagesSchema,
    "questions": {
      "type": "array",
      "items": _pageQuestionSchema,
      "description": 'No catch-all "Anything else?" question: the page already ends with one.',
    },
  },
  "additionalProperties": false,
};
