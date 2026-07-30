import "package:freezed_annotation/freezed_annotation.dart";

import "agent_info.dart";
import "command_list_response.dart";
import "provider_info.dart";

part "session_options_response.freezed.dart";
part "session_options_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionOptionsResponse with _$SessionOptionsResponse {
  const factory SessionOptionsResponse({
    required Agents agents,
    required ProviderListResponse providers,
    required CommandListResponse commands,
  }) = _SessionOptionsResponse;

  factory SessionOptionsResponse.fromJson(Map<String, dynamic> json) => _$SessionOptionsResponseFromJson(json);
}
