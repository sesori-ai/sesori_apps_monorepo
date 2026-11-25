/// Provenance relevant to user-role message attribution and task lifecycle.
///
/// Claude's peer/socket messages are not human-authored, even though their
/// message role is `user`. Missing and unmodelled origins keep existing user
/// behavior; in particular a channel can carry human input.
enum ClaudeMessageOriginKind() {
  peer,
  taskNotification,

  /// Claude Code's label for text the bridge sent with `isSynthetic: true`,
  /// and for the expanded body of a slash command sent that way (verified on
  /// 2.1.332). Hidden like any other harness-generated frame.
  unclassified,

  /// A message the bridge sent with `isSynthetic: true`, as only its own
  /// transcript record shows. Shown as Sesori wrote it.
  host,
  unknown;

  static ClaudeMessageOriginKind parse({required Object? kind}) => switch (kind) {
    "peer" => peer,
    "task-notification" => taskNotification,
    "unclassified" => unclassified,
    _ => unknown,
  };
}
