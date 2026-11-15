/// A parsed Codex rollout file name.
///
/// Codex names a thread's first rollout `rollout-<timestamp>-<threadId>.jsonl`.
/// `thread/revert` writes the thread's next rollout as
/// `rollout-<timestamp>-<threadId>_<rolloutId>.jsonl` and keeps the old file,
/// so one thread can own several rollouts. The first rollout's rollout id is
/// the thread id.
class const CodexRolloutFileName({
  /// `YYYY-MM-DDTHH-MM-SS` in the writer's local time; it orders lexically.
  required final String timestamp,
  required final String threadId,
  required final String rolloutId,
}) {
  /// Null for anything that is not a rollout file name.
  static CodexRolloutFileName? tryParse({required String fileName}) {
    if (!fileName.startsWith(_prefix) || !fileName.endsWith(_suffix)) return null;
    final core = fileName.substring(_prefix.length, fileName.length - _suffix.length);
    // The timestamp is 19 characters, followed by a dash and the ids.
    if (core.length < 20 || core[19] != "-") return null;
    final ids = core.substring(20);
    final separator = ids.indexOf("_");
    final threadId = separator < 0 ? ids : ids.substring(0, separator);
    final rolloutId = separator < 0 ? ids : ids.substring(separator + 1);
    if (!_uuidPattern.hasMatch(threadId) || !_uuidPattern.hasMatch(rolloutId)) return null;
    return CodexRolloutFileName(timestamp: core.substring(0, 19), threadId: threadId, rolloutId: rolloutId);
  }

  /// Whether this rollout supersedes [other] as its thread's current rollout.
  /// Codex picks the newest file name, breaking a same-second tie by the
  /// UUIDv7 rollout id.
  bool isNewerThan({required CodexRolloutFileName other}) {
    final byTime = timestamp.compareTo(other.timestamp);
    return byTime > 0 || (byTime == 0 && rolloutId.compareTo(other.rolloutId) > 0);
  }

  static const String _prefix = "rollout-";
  static const String _suffix = ".jsonl";
  static final RegExp _uuidPattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    caseSensitive: false,
  );
}
