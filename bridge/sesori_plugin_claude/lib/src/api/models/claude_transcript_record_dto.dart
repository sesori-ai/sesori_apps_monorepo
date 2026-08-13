import "package:freezed_annotation/freezed_annotation.dart";

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
    @JsonKey(fromJson: _stringOrNull) required String? gitBranch,
    @JsonKey(fromJson: _stringOrNull) required String? version,
    @JsonKey(fromJson: _stringOrNull) required String? aiTitle,
    @JsonKey(fromJson: _stringOrNull) required String? uuid,
    @JsonKey(fromJson: _boolOrNull) required bool? isMeta,
    @JsonKey(fromJson: _boolOrNull) required bool? isVisibleInTranscriptOnly,
    @JsonKey(fromJson: _messageOrNull) required ClaudeTranscriptMessageDto? message,
  }) = _ClaudeTranscriptRecordDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptRecordDtoFromJson(json);
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

ClaudeTranscriptMessageDto? _messageOrNull(Object? value) =>
    value is Map ? ClaudeTranscriptMessageDto.fromJson(value.cast<String, dynamic>()) : null;

DateTime? _timestampOrNull(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
