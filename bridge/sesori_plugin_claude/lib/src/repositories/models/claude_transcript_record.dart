/// One decoded line of a Claude Code transcript.
///
/// Transcripts live at `$CLAUDE_CONFIG_DIR ?? ~/.claude` +
/// `/projects/<munged-cwd>/<session-id>.jsonl`, one JSON object per line.
///
/// The API returns a generated wire DTO; the transcript catalog repository maps
/// it into these hand-written domain variants. The type set is open: a survey of
/// 1,888 real transcripts found **sixteen** record types where the protocol
/// capture had recorded six, so absorbing the unrecognized rest is the primary
/// requirement rather than modelling each one as a generated union variant.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 9.
sealed class ClaudeTranscriptRecord {
  const ClaudeTranscriptRecord({required this.sessionId, required this.raw});

  /// The session this record belongs to.
  ///
  /// Nullable because a record that omits it must still be kept: the
  /// authoritative session id is the transcript's filename, and this field is
  /// only ever used to cross-check it.
  final String? sessionId;

  /// The undecoded record, so later steps can reach fields this build does not
  /// model without a second parse.
  final Map<String, Object?> raw;
}

/// A non-message record that still attributes a transcript to a project.
enum ClaudeTranscriptContextKind {
  attachment(wireType: "attachment"),
  system(wireType: "system");

  const ClaudeTranscriptContextKind({required this.wireType});

  final String wireType;

  static ClaudeTranscriptContextKind? tryParse(String raw) {
    for (final kind in values) {
      if (kind.wireType == raw) return kind;
    }
    return null;
  }
}

/// Common project and timestamp fields on message and context records.
sealed class ClaudeTranscriptAttributedRecord extends ClaudeTranscriptRecord {
  const ClaudeTranscriptAttributedRecord({
    required this.cwd,
    required this.timestamp,
    required this.isSidechain,
    required this.gitBranch,
    required this.version,
    required super.sessionId,
    required super.raw,
  });

  /// The directory the session ran in. This is what the bridge groups sessions
  /// by, so the munged transcript directory name is never un-munged.
  final String? cwd;

  final DateTime? timestamp;

  /// Marks a subagent record. Whole subagent transcripts are separate files,
  /// but a small number of session files also carry sidechain records, so this
  /// flag is checked in addition to the filename.
  final bool? isSidechain;

  final String? gitBranch;

  /// The CLI version that wrote the record.
  final String? version;
}

/// A persisted user message.
final class ClaudeTranscriptUserRecord extends ClaudeTranscriptAttributedRecord {
  const ClaudeTranscriptUserRecord({
    required this.id,
    required this.content,
    required this.isMeta,
    required this.isVisibleInTranscriptOnly,
    required super.cwd,
    required super.timestamp,
    required super.isSidechain,
    required super.gitBranch,
    required super.version,
    required super.sessionId,
    required super.raw,
  });

  static const String wireType = "user";

  final String id;
  final Object? content;
  final bool isMeta;
  final bool isVisibleInTranscriptOnly;
}

/// A persisted assistant message block.
///
/// Claude can split one Anthropic message across several transcript records;
/// records carrying the same [id] belong to one plugin message.
final class ClaudeTranscriptAssistantRecord extends ClaudeTranscriptAttributedRecord {
  const ClaudeTranscriptAssistantRecord({
    required this.id,
    required this.model,
    required this.content,
    required super.cwd,
    required super.timestamp,
    required super.isSidechain,
    required super.gitBranch,
    required super.version,
    required super.sessionId,
    required super.raw,
  });

  static const String wireType = "assistant";

  final String id;
  final String? model;
  final Object? content;
}

/// A user or assistant record with no usable persisted message identity.
///
/// It can still attribute the transcript to a project, but cannot be replayed
/// as a plugin message without inventing an id.
final class ClaudeTranscriptUnreplayableMessageRecord extends ClaudeTranscriptAttributedRecord {
  const ClaudeTranscriptUnreplayableMessageRecord({
    required super.cwd,
    required super.timestamp,
    required super.isSidechain,
    required super.gitBranch,
    required super.version,
    required super.sessionId,
    required super.raw,
  });
}

/// Internal context attached by Claude rather than a user-visible message.
final class ClaudeTranscriptContextRecord extends ClaudeTranscriptAttributedRecord {
  const ClaudeTranscriptContextRecord({
    required this.kind,
    required super.cwd,
    required super.timestamp,
    required super.isSidechain,
    required super.gitBranch,
    required super.version,
    required super.sessionId,
    required super.raw,
  });

  final ClaudeTranscriptContextKind kind;
}

/// An `ai-title` record — the session title, written by the CLI itself.
final class ClaudeTranscriptTitleRecord extends ClaudeTranscriptRecord {
  const ClaudeTranscriptTitleRecord({required this.title, required super.sessionId, required super.raw});

  static const String wireType = "ai-title";

  /// Non-empty by construction; the repository rejects a blank title.
  final String title;
}

/// Any record type this build does not model.
///
/// Kept rather than dropped so a scan reports honest record counts and so a new
/// record type never truncates a transcript.
final class ClaudeTranscriptUnknownRecord extends ClaudeTranscriptRecord {
  const ClaudeTranscriptUnknownRecord({required this.type, required super.sessionId, required super.raw});

  /// Null when the record had no string `type` at all.
  final String? type;
}
