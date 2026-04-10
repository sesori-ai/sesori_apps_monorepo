import "package:freezed_annotation/freezed_annotation.dart";

import "send_prompt_request.dart";
import "worktree_mode.dart";

part "create_session_request.freezed.dart";

part "create_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CreateSessionRequest with _$CreateSessionRequest {
  const factory CreateSessionRequest({
    required String projectId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required WorktreeMode worktreeMode,
    required String? selectedBranch,
  }) = _CreateSessionRequest;

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);
}
