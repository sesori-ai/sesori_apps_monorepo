import "package:freezed_annotation/freezed_annotation.dart";

/// The terminal outcome Grok Build reports in `subagent_finished.status`.
/// `completed` and `cancelled` were observed on the wire; `failed` is the
/// third outcome the CLI renders. Anything else parses as [unknown].
enum GrokSubagentStatus() {
  @JsonValue("completed")
  completed,
  @JsonValue("failed")
  failed,
  @JsonValue("cancelled")
  cancelled,
  unknown,
}
