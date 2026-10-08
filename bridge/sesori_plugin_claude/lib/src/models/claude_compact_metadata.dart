import "package:freezed_annotation/freezed_annotation.dart";

part "claude_compact_metadata.freezed.dart";
part "claude_compact_metadata.g.dart";

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
/// The live `compact_boundary` frame spells the token counts snake_case
/// (`compact_metadata.pre_tokens`); the transcript record spells them camelCase
/// (`compactMetadata.preTokens`), so each count reads whichever is present.
/// Verified against Claude CLI 2.1.291.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeCompactMetadata with _$ClaudeCompactMetadata {
  const factory({
    @JsonKey(fromJson: _triggerOrNull) required ClaudeCompactTrigger? trigger,

    /// The context size before compacting, in tokens.
    @JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) required int? preTokens,

    /// The context size after compacting, in tokens.
    @JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) required int? postTokens,
  }) = _ClaudeCompactMetadata;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeCompactMetadataFromJson(json);

  /// Null when [json] is not an object.
  static ClaudeCompactMetadata? fromJsonOrNull({required Object? json}) =>
      json is Map ? ClaudeCompactMetadata.fromJson(json.cast<String, dynamic>()) : null;
}

Object? _readPreTokens(Map<dynamic, dynamic> json, String _) => json["preTokens"] ?? json["pre_tokens"];

Object? _readPostTokens(Map<dynamic, dynamic> json, String _) => json["postTokens"] ?? json["post_tokens"];

ClaudeCompactTrigger? _triggerOrNull(Object? value) => ClaudeCompactTrigger.tryParse(raw: value);

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;
