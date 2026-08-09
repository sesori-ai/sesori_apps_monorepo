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
/// Only the fields the session catalog consumes are modelled here. Message
/// content lands with the history mapper that reads it.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/active/claude-code-plugin/PROTOCOL.md` section 9.
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

/// The record types that carry a working directory and a wall-clock time.
///
/// These four behave identically for the catalog, so they are one variant with
/// a closed scalar kind rather than four variants with identical fields. They
/// diverge once message content is modelled; the variant splits then.
enum ClaudeTranscriptContentKind {
  user(wireType: "user"),
  assistant(wireType: "assistant"),
  attachment(wireType: "attachment"),
  system(wireType: "system");

  const ClaudeTranscriptContentKind({required this.wireType});

  final String wireType;

  static ClaudeTranscriptContentKind? tryParse(String raw) {
    for (final kind in values) {
      if (kind.wireType == raw) return kind;
    }
    return null;
  }
}

/// A `user`, `assistant`, `attachment`, or `system` record.
final class ClaudeTranscriptContentRecord extends ClaudeTranscriptRecord {
  const ClaudeTranscriptContentRecord({
    required this.kind,
    required this.cwd,
    required this.timestamp,
    required this.isSidechain,
    required this.gitBranch,
    required this.version,
    required super.sessionId,
    required super.raw,
  });

  final ClaudeTranscriptContentKind kind;

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

/// An `ai-title` record — the session title, written by the CLI itself.
final class ClaudeTranscriptTitleRecord extends ClaudeTranscriptRecord {
  const ClaudeTranscriptTitleRecord({required this.title, required super.sessionId, required super.raw});

  static const String wireType = "ai-title";

  /// Non-empty by construction; [ClaudeTranscriptRecord.parse] rejects a blank
  /// title rather than storing one.
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
