import "package:freezed_annotation/freezed_annotation.dart";

import "openapi/location_public_ref.g.dart";
import "openapi/model_ref.g.dart";
import "openapi/permission_reply.g.dart";
import "openapi/project_commands.g.dart";
import "openapi/project_icon.g.dart";
import "openapi/prompt_agent_attachment.g.dart";
import "openapi/prompt_input_file_attachment.g.dart";
import "openapi/prompt_input_skill_attachment.g.dart";
import "openapi/session_inbox_delivery.g.dart";

part "v2_request_bodies.freezed.dart";
part "v2_request_bodies.g.dart";

@Freezed(toJson: true, copyWith: false)
sealed class V2CreateSessionBody with _$V2CreateSessionBody {
  const factory({
    required LocationPublicRef location,
    required String? title,
    required String? agent,
    required ModelRef? model,
  }) = _V2CreateSessionBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2RenameSessionBody with _$V2RenameSessionBody {
  const factory({required String title}) = _V2RenameSessionBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2SwitchAgentBody with _$V2SwitchAgentBody {
  const factory({required String agent}) = _V2SwitchAgentBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2SwitchModelBody with _$V2SwitchModelBody {
  const factory({required ModelRef model}) = _V2SwitchModelBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2PromptBody with _$V2PromptBody {
  const factory({
    required String? id,
    required String text,
    required List<PromptInputFileAttachment>? files,
    required List<PromptAgentAttachment>? agents,
    required List<PromptInputSkillAttachment>? skills,
    required SessionInboxDelivery? delivery,
    required bool? resume,
  }) = _V2PromptBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2CommandBody with _$V2CommandBody {
  const factory({
    required String name,
    required String text,
    required List<PromptInputFileAttachment>? files,
    required List<PromptAgentAttachment>? agents,
    required List<PromptInputSkillAttachment>? skills,
    required SessionInboxDelivery? delivery,
  }) = _V2CommandBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2SyntheticBody with _$V2SyntheticBody {
  const factory({
    required String? id,
    required String text,
    required String? description,
    required SessionInboxDelivery? delivery,
    required bool? resume,
  }) = _V2SyntheticBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2CompactBody with _$V2CompactBody {
  const factory({required String? id, required SessionInboxDelivery? delivery}) = _V2CompactBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2PermissionReplyBody with _$V2PermissionReplyBody {
  const factory({required PermissionReply decision, required String? message}) = _V2PermissionReplyBody;
}

@Freezed(toJson: true, copyWith: false)
sealed class V2UpdateProjectBody with _$V2UpdateProjectBody {
  const factory({
    required String? canonical,
    required String? name,
    required ProjectIcon? icon,
    required ProjectCommands? commands,
  }) = _V2UpdateProjectBody;
}
