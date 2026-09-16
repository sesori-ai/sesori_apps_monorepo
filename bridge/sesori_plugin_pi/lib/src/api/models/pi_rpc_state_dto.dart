import "package:freezed_annotation/freezed_annotation.dart";

part "pi_rpc_state_dto.freezed.dart";
part "pi_rpc_state_dto.g.dart";

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiRpcStateDto with _$PiRpcStateDto {
  const factory({
    required PiRpcStateModelDto? model,
    required String? thinkingLevel,
    @Default(false) bool isStreaming,
    @Default(0) int pendingMessageCount,
  }) = _PiRpcStateDto;

  factory fromJson(Map<String, dynamic> json) => _$PiRpcStateDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiRpcStateModelDto with _$PiRpcStateModelDto {
  const factory({
    required String provider,
    required String id,
  }) = _PiRpcStateModelDto;

  factory fromJson(Map<String, dynamic> json) => _$PiRpcStateModelDtoFromJson(json);
}
