import "package:freezed_annotation/freezed_annotation.dart";

import "command_info.dart";

part "command_list_response.freezed.dart";

part "command_list_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CommandListResponse with _$CommandListResponse {
  const factory CommandListResponse({
    required List<CommandInfo> items,
  }) = _CommandListResponse;

  factory CommandListResponse.fromJson(Map<String, dynamic> json) => _$CommandListResponseFromJson(json);
}
