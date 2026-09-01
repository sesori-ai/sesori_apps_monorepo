import "package:freezed_annotation/freezed_annotation.dart";

import "pi_frame_fields.dart";

part "pi_tool_call_start_dto.freezed.dart";
part "pi_tool_call_start_dto.g.dart";

/// The typed wire shape introduced for Pi's `toolcall_start` delta.
///
/// The converters retain the transport boundary's tolerant behavior: Pi is a
/// foreign process, so malformed optional scalars become null instead of
/// aborting the surrounding turn.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiToolCallStartDto with _$PiToolCallStartDto {
  const factory({
    @JsonKey(fromJson: intOrNull) required int? contentIndex,
    @JsonKey(fromJson: stringOrNull) required String? id,
    @JsonKey(fromJson: stringOrNull) required String? toolName,
  }) = _PiToolCallStartDto;

  factory fromJson(Map<String, dynamic> json) => _$PiToolCallStartDtoFromJson(json);
}
