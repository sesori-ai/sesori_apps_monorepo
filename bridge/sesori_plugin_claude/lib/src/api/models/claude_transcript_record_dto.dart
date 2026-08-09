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
@Freezed(fromJson: true, toJson: false)
sealed class ClaudeTranscriptRecordDto with _$ClaudeTranscriptRecordDto {
  const factory ClaudeTranscriptRecordDto({
    @JsonKey(fromJson: _stringOrNull) required String? type,
    @JsonKey(fromJson: _stringOrNull) required String? sessionId,
    @JsonKey(fromJson: _stringOrNull) required String? cwd,
    @JsonKey(fromJson: _timestampOrNull) required DateTime? timestamp,
    @JsonKey(fromJson: _boolOrNull) required bool? isSidechain,
    @JsonKey(fromJson: _stringOrNull) required String? gitBranch,
    @JsonKey(fromJson: _stringOrNull) required String? version,
    @JsonKey(fromJson: _stringOrNull) required String? aiTitle,
  }) = _ClaudeTranscriptRecordDto;

  factory ClaudeTranscriptRecordDto.fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptRecordDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;

DateTime? _timestampOrNull(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
