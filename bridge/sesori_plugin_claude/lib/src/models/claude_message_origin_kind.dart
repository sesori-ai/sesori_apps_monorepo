/// Provenance relevant to user-role message attribution and task lifecycle.
///
/// Claude's peer/socket messages are not human-authored, even though their
/// message role is `user`. Missing and unmodelled origins keep existing user
/// behavior; in particular a channel can carry human input.
enum ClaudeMessageOriginKind() {
  peer,
  taskNotification,
  unknown;

  static ClaudeMessageOriginKind parse({required Object? kind}) => switch (kind) {
    "peer" => peer,
    "task-notification" => taskNotification,
    _ => unknown,
  };
}
