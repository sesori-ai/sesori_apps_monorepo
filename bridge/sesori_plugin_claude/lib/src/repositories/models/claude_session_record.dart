/// One transcript reduced to the facts the catalog needs.
///
/// Hand-written and dependency-free because it crosses an isolate boundary and
/// is internal to the plugin; nothing outside this package sees it.
class ClaudeSessionRecord {
  const ClaudeSessionRecord({
    required this.id,
    required this.transcriptPath,
    required this.cwd,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.gitBranch,
    required this.cliVersion,
  });

  /// The transcript filename minus `.jsonl`, validated as a UUID.
  final String id;

  final String transcriptPath;

  /// The directory the session ran in.
  final String cwd;

  /// From the CLI's own `ai-title` record. Null when it never wrote one.
  final String? title;

  final DateTime? createdAt;

  /// Transcript mtime: for an append-only file, the session's last activity.
  final DateTime? updatedAt;

  final String? gitBranch;

  /// The CLI version that wrote the transcript.
  final String? cliVersion;
}
