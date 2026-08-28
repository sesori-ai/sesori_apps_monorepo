import "package:freezed_annotation/freezed_annotation.dart";

import "agent_info.dart";
import "command_list_response.dart";
import "provider_info.dart";
import "session.dart";

part "session_options_response.freezed.dart";
part "session_options_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionOptionsResponse with _$SessionOptionsResponse {
  const factory({
    required Agents agents,
    required ProviderListResponse providers,
    required CommandListResponse commands,
    // COMPATIBILITY 2026-08-27 (v1.8.2): Bridges before v1.8.2 omit
    // lastUsedPromptDefaults, which means no bridge-stored new-session selection
    // is available. Missing nullable JSON fields decode to null.
    required SessionPromptDefaults? lastUsedPromptDefaults,

    /// Whether the bridge served a cached snapshot older than its freshness
    /// window, making it worth a background refresh. Freshly discovered options
    /// are never stale.
    // COMPATIBILITY 2026-08-20 (v1.8.0): Bridges before v1.8.0 omit stale, which
    // means they never recommend a background refresh. Remove @Default and
    // require stale after the minimum supported bridge sends it.
    @Default(false) bool stale,
  }) = _SessionOptionsResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionOptionsResponseFromJson(json);
}
