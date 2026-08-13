import "package:freezed_annotation/freezed_annotation.dart";

part "pi_session_metadata_dto.freezed.dart";
part "pi_session_metadata_dto.g.dart";

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "type",
  unionValueCase: FreezedUnionCase.none,
)
sealed class PiSessionMetadataDto with _$PiSessionMetadataDto {
  @FreezedUnionValue("session")
  const factory session({
    @JsonKey(fromJson: _intOrNull) required int? version,
    @JsonKey(fromJson: _stringOrNull) required String? id,
    @JsonKey(fromJson: _timestampOrNull) required DateTime? timestamp,
    @JsonKey(fromJson: _stringOrNull) required String? cwd,
    @JsonKey(fromJson: _stringOrNull) required String? parentSession,
  }) = PiSessionHeaderDto;

  @FreezedUnionValue("session_info")
  const factory sessionInfo({
    @JsonKey(fromJson: _strictNullableString) required String? name,
  }) = PiSessionInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionMetadataDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiSettingsDto with _$PiSettingsDto {
  const factory({
    @JsonKey(fromJson: _strictNullableString) required String? sessionDir,
  }) = _PiSettingsDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSettingsDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

String? _strictNullableString(Object? value) {
  if (value == null || value is String) return value as String?;
  throw const FormatException("Expected a string");
}

int? _intOrNull(Object? value) => value is num && value.isFinite ? value.toInt() : null;

DateTime? _timestampOrNull(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
