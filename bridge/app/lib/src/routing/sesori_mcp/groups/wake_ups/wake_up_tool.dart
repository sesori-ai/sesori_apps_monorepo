import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolDefinition;

/// The wake-up tools Sesori's MCP server offers.
enum WakeUpTool({
  required final String wireName,
  required final String description,

  /// Advertised as MCP's `readOnlyHint`.
  required final bool readOnly,

  /// The JSON Schema of the tool's arguments, as MCP's `inputSchema`.
  required final Map<String, Object?> inputSchema,
}) {
  scheduleWakeUp(
    wireName: "schedule_wakeup",
    readOnly: false,
    description:
        "Ask Sesori to send this session a prompt later, once or on repeat. Use it instead of a harness timer, a "
        "sleep or a polling loop: the user sees each wake-up in the Sesori app and can cancel it, and it survives a "
        "bridge restart. The prompt arrives as a message once this session's turn has ended, never inside one; a "
        "sub-agent's goes to its root session. Needs no approval unless it runs a command. A repeating wake-up "
        "repeats until you call cancel_wakeup, so never set it again yourself.",
    inputSchema: {
      "type": "object",
      "properties": {
        "label": {"type": "string", "description": "What it is for, in up to 100 characters. The user sees it."},
        "prompt": {"type": "string", "description": "The message Sesori sends this session when it fires."},
        "when": {..._wakeUpWhenSchema, "description": _wakeUpWhenDescription},
        "time_zone": {
          "type": "string",
          "description":
              "An IANA time zone, such as Europe/Bucharest, for daily, weekdays and weekly. This "
              "computer's zone by default.",
        },
        "command": {
          "type": "string",
          "description":
              "A shell command Sesori runs right before it sends the prompt, through a login shell in this "
              "session's folder (its worktree when it has one), stopped after 10 minutes. The prompt then ends "
              "with the exit code, stdout and stderr; a stream over 500 words comes as its file's path and its "
              "last 20 lines. Needs the user's Allow, once, unless this session approves everything.",
        },
      },
      "required": ["label", "prompt", "when"],
      "additionalProperties": false,
    },
  ),
  listWakeUps(
    wireName: "list_wakeups",
    readOnly: true,
    description: "List this session's wake-ups, soonest first: id, label, next time and how it repeats.",
    inputSchema: {"type": "object", "properties": <String, Object?>{}, "additionalProperties": false},
  ),
  cancelWakeUp(
    wireName: "cancel_wakeup",
    readOnly: false,
    description: "Cancel one of this session's wake-ups, repeating ones included. Find ids with list_wakeups.",
    inputSchema: {
      "type": "object",
      "properties": {
        "wakeup_id": {"type": "string"},
      },
      "required": ["wakeup_id"],
      "additionalProperties": false,
    },
  );

  SesoriToolDefinition get definition =>
      SesoriToolDefinition(name: wireName, description: description, readOnly: readOnly, inputSchema: inputSchema);
}

const String _wakeUpWhenDescription =
    '{"kind":"in","minutes":1-10080} fires once that many minutes from now; {"kind":"every","minutes":1-10080} '
    "repeats at that interval, first one interval from now; "
    '{"kind":"daily","time":TIME}, {"kind":"weekdays","time":TIME} (Monday to Friday) or '
    '{"kind":"weekly","days":["monday",...],"time":TIME} repeat at that wall-clock time. TIME is "HH:MM", 24-hour, '
    "in time_zone.";

/// Lists every kind's fields, as the task schedule does: a strict-schema
/// provider lets the model send only listed properties. A kind ignores the
/// others.
const Map<String, Object?> _wakeUpWhenSchema = {
  "type": "object",
  "properties": {
    "kind": {
      "type": "string",
      "enum": ["in", "every", "daily", "weekdays", "weekly"],
    },
    "minutes": {"type": "integer", "description": "in and every: 1 to 10080 (a week)."},
    "time": {"type": "string", "description": 'daily, weekdays and weekly: "HH:MM", 24-hour.'},
    "days": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
      },
      "description": "weekly: the days it fires.",
    },
  },
  "required": ["kind"],
};
