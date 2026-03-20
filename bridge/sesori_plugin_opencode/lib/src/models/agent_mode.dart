import "package:json_annotation/json_annotation.dart";

/// The mode that determines where an agent is selectable.
///
/// - [all]: available as both primary (user-facing) and subagent (via task tool)
/// - [primary]: only available as a primary agent
/// - [subagent]: only available as a subagent
/// - [unknown]: fallback for unrecognised values from the server
enum AgentMode {
  @JsonValue("all")
  all,
  @JsonValue("primary")
  primary,
  @JsonValue("subagent")
  subagent,
  @JsonValue("unknown")
  unknown,
}
