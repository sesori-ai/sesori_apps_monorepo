import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_identity.dart";
import "send_prompt_request.dart";
import "session_variant.dart";

part "create_session_request.freezed.dart";

part "create_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CreateSessionRequest with _$CreateSessionRequest {
  const factory({
    required String projectId,
    // COMPATIBILITY 2026-07-13 (v1.5.0): Old create requests omit pluginId and mean OpenCode. Remove default; require it.
    @Default(legacyMissingPluginId) String pluginId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required SessionVariant? variant,
    // COMPATIBILITY 2026-09-23 (v1.9.0): Apps before fast mode omit fastMode and cannot select it, so the session starts at normal speed. Remove @Default and require the field once the minimum supported app always sends it.
    @Default(false) bool fastMode,
    required bool dedicatedWorktree,
  }) = _CreateSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);
}
