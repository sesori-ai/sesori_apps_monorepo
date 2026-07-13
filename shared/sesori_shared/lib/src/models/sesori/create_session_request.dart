import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_identity.dart";
import "send_prompt_request.dart";
import "session_variant.dart";

part "create_session_request.freezed.dart";

part "create_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CreateSessionRequest with _$CreateSessionRequest {
  const factory CreateSessionRequest({
    required String projectId,
    // COMPATIBILITY 2026-07-13 (v1.5.0): Old create requests omit pluginId and mean OpenCode. Remove default; require it.
    @Default(legacyMissingPluginId) String pluginId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required SessionVariant? variant,
    required bool dedicatedWorktree,
  }) = _CreateSessionRequest;

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);
}
