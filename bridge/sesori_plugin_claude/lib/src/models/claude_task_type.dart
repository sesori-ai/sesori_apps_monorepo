/// The kind of resident work a `system/task_started` frame announces.
///
/// Only sub-agents get a presentation of their own; every other kind (shells,
/// workflows) matters solely because it lives inside the resident process.
enum ClaudeTaskType() {
  subAgent,
  other;

  static ClaudeTaskType parse(Object? raw) => raw == "local_agent" ? subAgent : other;
}
