import "package:freezed_annotation/freezed_annotation.dart";

import "../../models/claude_message_origin_kind.dart";
import "../../models/claude_tool_use_result.dart";

part "claude_transcript_record_dto.freezed.dart";
part "claude_transcript_record_dto.g.dart";

/// One generated record DTO paired with its complete decoded wire map.
typedef ClaudeTranscriptLineDto = ({ClaudeTranscriptRecordDto record, Map<String, Object?> raw});

/// Tolerant wire shape shared by the transcript record variants.
///
/// Claude adds record types independently of the bridge. A flat boundary DTO
/// lets generated JSON decoding absorb missing and wrong-typed catalog fields;
/// the repository maps it into the smaller sealed variants the catalog actually
/// consumes.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeTranscriptRecordDto with _$ClaudeTranscriptRecordDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? type,
    @JsonKey(fromJson: _stringOrNull) required String? sessionId,
    @JsonKey(fromJson: _stringOrNull) required String? cwd,
    @JsonKey(fromJson: _timestampOrNull) required DateTime? timestamp,
    @JsonKey(fromJson: _boolOrNull) required bool? isSidechain,

    /// The sub-agent that wrote the record; null on a root session's records.
    @JsonKey(fromJson: _stringOrNull) required String? agentId,
    @JsonKey(fromJson: _stringOrNull) required String? gitBranch,
    @JsonKey(fromJson: _stringOrNull) required String? version,
    @JsonKey(fromJson: _stringOrNull) required String? aiTitle,
    @JsonKey(fromJson: _stringOrNull) required String? uuid,
    @JsonKey(fromJson: _boolOrNull) required bool? isMeta,
    @JsonKey(fromJson: _boolOrNull) required bool? isVisibleInTranscriptOnly,

    /// Marks the continuation summary the CLI injects after a compaction.
    @JsonKey(fromJson: _boolOrNull) required bool? isCompactSummary,
    @JsonKey(fromJson: _boolOrNull) required bool? isApiErrorMessage,
    @JsonKey(fromJson: _intOrNull) required int? apiErrorStatus,
    @JsonKey(fromJson: _stringOrNull) required String? effort,
    @JsonKey(fromJson: _messageOrNull) required ClaudeTranscriptMessageDto? message,

    /// The typed result persisted beside a `user` record's tool result.
    @JsonKey(fromJson: ClaudeToolUseResult.parse) required ClaudeToolUseResult toolUseResult,

    /// Host-stamped provenance, independent of the record's `user` role.
    /// Unknown provenance never promotes ordinary user input to automation.
    @JsonKey(name: "origin", fromJson: _originKind) required ClaudeMessageOriginKind originKind,

    /// The payload of an `attachment` record.
    @JsonKey(fromJson: _attachmentOrNull) required ClaudeTranscriptAttachmentDto? attachment,
  }) = _ClaudeTranscriptRecordDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptRecordDtoFromJson(json);
}

/// The payload of an `attachment` record. Only the fields of a
/// `queued_command`, a command Claude queued while a turn was running, are
/// modelled.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeTranscriptAttachmentDto with _$ClaudeTranscriptAttachmentDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? type,

    /// The queued content: a string or content blocks, like a user message's.
    required Object? prompt,
    @JsonKey(fromJson: _stringOrNull) required String? commandMode,

    /// The id the live stream gave the command; older CLIs omit it.
    @JsonKey(name: "source_uuid", fromJson: _stringOrNull) required String? sourceUuid,
    @JsonKey(fromJson: _boolOrNull) required bool? isMeta,
    @JsonKey(name: "origin", fromJson: _originKind) required ClaudeMessageOriginKind originKind,
  }) = _ClaudeTranscriptAttachmentDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptAttachmentDtoFromJson(json);
}

/// The nested Anthropic message persisted by `user` and `assistant` records.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeTranscriptMessageDto with _$ClaudeTranscriptMessageDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? id,
    @JsonKey(fromJson: _stringOrNull) required String? model,
    required Object? content,
  }) = _ClaudeTranscriptMessageDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptMessageDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

ClaudeMessageOriginKind _originKind(Object? value) =>
    ClaudeMessageOriginKind.parse(kind: value is Map ? value["kind"] : null);

ClaudeTranscriptMessageDto? _messageOrNull(Object? value) =>
    value is Map ? ClaudeTranscriptMessageDto.fromJson(value.cast<String, dynamic>()) : null;

ClaudeTranscriptAttachmentDto? _attachmentOrNull(Object? value) =>
    value is Map ? ClaudeTranscriptAttachmentDto.fromJson(value.cast<String, dynamic>()) : null;

DateTime? _timestampOrNull(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
