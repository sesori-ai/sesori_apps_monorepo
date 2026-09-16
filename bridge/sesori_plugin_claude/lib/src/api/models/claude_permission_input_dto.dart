import "package:freezed_annotation/freezed_annotation.dart";

part "claude_permission_input_dto.freezed.dart";
part "claude_permission_input_dto.g.dart";

/// Known built-in tool inputs on Claude's can_use_tool request. Custom/MCP
/// tools are not decoded as built-ins merely because they use similar keys.
@Freezed(fromJson: true, toJson: false)
sealed class ClaudePermissionInputDto with _$ClaudePermissionInputDto {
  const factory({
    required String? command,
    @JsonKey(name: "file_path") required String? filePath,
    @JsonKey(name: "notebook_path") required String? notebookPath,
    required String? url,
  }) = _ClaudePermissionInputDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudePermissionInputDtoFromJson(json);
}
