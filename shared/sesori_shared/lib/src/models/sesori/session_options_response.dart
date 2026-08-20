import "package:freezed_annotation/freezed_annotation.dart";

import "agent_info.dart";
import "command_list_response.dart";
import "provider_info.dart";

part "session_options_response.freezed.dart";
part "session_options_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionOptionsResponse with _$SessionOptionsResponse {
  const factory({
    required Agents agents,
    required ProviderListResponse providers,
    required CommandListResponse commands,
    /// Whether the bridge served a cached snapshot older than its freshness
    /// window, making it worth a background refresh. Freshly discovered options
    /// are never stale, and a bridge that predates the signal never asks for
    /// one.
    @Default(false) bool stale,
  }) = _SessionOptionsResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionOptionsResponseFromJson(json);
}
