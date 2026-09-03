import "../../models/claude_effort_level.dart";
import "../../models/claude_tool_use_result.dart";

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
sealed class const ClaudeTranscriptRecord({
  /// The session this record belongs to.
  ///
  /// Nullable because a record that omits it must still be kept: the
  /// authoritative session id is the transcript's filename, and this field is
  /// only ever used to cross-check it.
  required final String? sessionId,

  /// The undecoded record, so later steps can reach fields this build does not
  /// model without a second parse.
  required final Map<String, Object?> raw,
});

/// A non-message record that still attributes a transcript to a project.
enum ClaudeTranscriptContextKind({required final String wireType}) {
  attachment(wireType: "attachment"),
  system(wireType: "system");

  static ClaudeTranscriptContextKind? tryParse(String raw) {
    for (final kind in values) {
      if (kind.wireType == raw) return kind;
    }
    return null;
  }
}

/// Common project and timestamp fields on message and context records.
sealed class const ClaudeTranscriptAttributedRecord({
  /// The directory the session ran in. This is what the bridge groups sessions
  /// by, so the munged transcript directory name is never un-munged.
  required final String? cwd,
  required final DateTime? timestamp,

  /// Marks a subagent record. Whole subagent transcripts are separate files,
  /// but a small number of session files also carry sidechain records, so this
  /// flag is checked in addition to the filename.
  required final bool? isSidechain,

  /// The sub-agent that wrote the record. Sub-agent transcripts carry the
  /// **parent's** [sessionId], so this is what attributes them.
  required final String? agentId,
  required final String? gitBranch,

  /// The CLI version that wrote the record.
  required final String? version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptRecord;

/// A persisted user message.
final class const ClaudeTranscriptUserRecord({
  required final String id,
  required final Object? content,
  required final bool isMeta,
  required final bool isVisibleInTranscriptOnly,

  /// The typed result of the tool call this record's `tool_result` completes.
  required final ClaudeToolUseResult toolUseResult,

  /// True when the CLI injected this record to deliver a background task's
  /// outcome to the model; it is never user-authored.
  required final bool isTaskNotification,
  required super.cwd,
  required super.timestamp,
  required super.isSidechain,
  required super.agentId,
  required super.gitBranch,
  required super.version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptAttributedRecord {
  static const String wireType = "user";
}

/// A persisted assistant message block.
///
/// Claude can split one Anthropic message across several transcript records;
/// records carrying the same [id] belong to one plugin message.
final class const ClaudeTranscriptAssistantRecord({
  required final String id,
  required final String? model,
  required final ClaudeEffortLevel? effort,
  required final Object? content,
  required super.cwd,
  required super.timestamp,
  required super.isSidechain,
  required super.agentId,
  required super.gitBranch,
  required super.version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptAttributedRecord {
  static const String wireType = "assistant";
}

/// A CLI-generated API failure persisted using the `assistant` wire type.
///
/// Claude marks these records with `isApiErrorMessage` and uses a synthetic
/// model. They are errors rather than assistant replies; keeping a separate
/// variant prevents cold replay from rendering the explanatory text beside the
/// equivalent terminal error captured from the live stream.
final class const ClaudeTranscriptApiErrorRecord({
  required final String id,
  required final Object? content,
  required final int? apiErrorStatus,
  required super.cwd,
  required super.timestamp,
  required super.isSidechain,
  required super.agentId,
  required super.gitBranch,
  required super.version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptAttributedRecord;

/// A user or assistant record with no usable persisted message identity.
///
/// It can still attribute the transcript to a project, but cannot be replayed
/// as a plugin message without inventing an id.
final class const ClaudeTranscriptUnreplayableMessageRecord({
  required super.cwd,
  required super.timestamp,
  required super.isSidechain,
  required super.agentId,
  required super.gitBranch,
  required super.version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptAttributedRecord;

/// Internal context attached by Claude rather than a user-visible message.
final class const ClaudeTranscriptContextRecord({
  required final ClaudeTranscriptContextKind kind,
  required super.cwd,
  required super.timestamp,
  required super.isSidechain,
  required super.agentId,
  required super.gitBranch,
  required super.version,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptAttributedRecord;

/// An `ai-title` record — the session title, written by the CLI itself.
final class const ClaudeTranscriptTitleRecord({
  /// Non-empty by construction; the repository rejects a blank title.
  required final String title,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptRecord {
  static const String wireType = "ai-title";
}

/// Any record type this build does not model.
///
/// Kept rather than dropped so a scan reports honest record counts and so a new
/// record type never truncates a transcript.
final class const ClaudeTranscriptUnknownRecord({
  /// Null when the record had no string `type` at all.
  required final String? type,
  required super.sessionId,
  required super.raw,
}) extends ClaudeTranscriptRecord;
