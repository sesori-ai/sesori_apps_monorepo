/// What started a compaction.
enum ClaudeCompactTrigger() {
  manual,
  auto;

  /// Null when absent or unknown.
  static ClaudeCompactTrigger? tryParse({required Object? raw}) => switch (raw) {
    "manual" => manual,
    "auto" => auto,
    _ => null,
  };
}

/// The details Claude records with a compact boundary.
///
/// The live `compact_boundary` frame spells them snake_case
/// (`compact_metadata.pre_tokens`); the transcript record spells them camelCase
/// (`compactMetadata.preTokens`). Verified against Claude CLI 2.1.291.
final class const ClaudeCompactMetadata({
  required final ClaudeCompactTrigger? trigger,

  /// The context size before compacting, in tokens.
  required final int? preTokens,

  /// The context size after compacting, in tokens.
  required final int? postTokens,
}) {
  /// Reads the live frame's `compact_metadata`; null when it is not an object.
  static ClaudeCompactMetadata? fromStream({required Object? json}) => switch (json) {
    final Map<Object?, Object?> map => ClaudeCompactMetadata(
      trigger: ClaudeCompactTrigger.tryParse(raw: map["trigger"]),
      preTokens: _intOrNull(map["pre_tokens"]),
      postTokens: _intOrNull(map["post_tokens"]),
    ),
    _ => null,
  };

  /// Reads the transcript record's `compactMetadata`; null when it is not an
  /// object.
  static ClaudeCompactMetadata? fromTranscript({required Object? json}) => switch (json) {
    final Map<Object?, Object?> map => ClaudeCompactMetadata(
      trigger: ClaudeCompactTrigger.tryParse(raw: map["trigger"]),
      preTokens: _intOrNull(map["preTokens"]),
      postTokens: _intOrNull(map["postTokens"]),
    ),
    _ => null,
  };
}

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;
