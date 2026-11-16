/// The outcome of writing a fork's transcript.
sealed class const ClaudeForkResult();

/// The fork's transcript is on disk, so it resumes like any session.
final class const ClaudeForkWritten() extends ClaudeForkResult;

/// Nothing was written.
final class const ClaudeForkUnavailable({required final ClaudeForkRefusal reason}) extends ClaudeForkResult;

enum ClaudeForkRefusal() {
  /// The origin has no transcript, such as one Claude Code pruned.
  transcriptMissing,

  /// The message is not on the transcript's active branch.
  notOnActiveBranch,
}
