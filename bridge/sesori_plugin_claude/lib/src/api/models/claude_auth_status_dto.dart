import "package:freezed_annotation/freezed_annotation.dart";

part "claude_auth_status_dto.freezed.dart";
part "claude_auth_status_dto.g.dart";

/// PII-free subset of `claude auth status`.
///
/// The source payload also contains account identity and organization fields;
/// excluding them here prevents setup inspection from retaining those values.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeAuthStatusDto with _$ClaudeAuthStatusDto {
  const factory({
    @JsonKey(fromJson: _boolOrNull) required bool? loggedIn,
  }) = _ClaudeAuthStatusDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeAuthStatusDtoFromJson(json);
}

bool? _boolOrNull(Object? value) => value is bool ? value : null;
