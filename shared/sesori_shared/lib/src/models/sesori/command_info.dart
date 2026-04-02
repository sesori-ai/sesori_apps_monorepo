import "package:freezed_annotation/freezed_annotation.dart";

part "command_info.freezed.dart";

part "command_info.g.dart";

enum CommandSource {
  command,
  mcp,
  skill,
  unknown,
}

/// Represents an available slash command from `GET /command`.
@Freezed(fromJson: true, toJson: true)
sealed class CommandInfo with _$CommandInfo {
  const factory CommandInfo({
    required String name,
    String? template,
    List<String>? hints,
    String? description,
    String? agent,
    String? model,
    required String? provider,
    @JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source,
    bool? subtask,
  }) = _CommandInfo;

  factory CommandInfo.fromJson(Map<String, dynamic> json) => _$CommandInfoFromJson(json);
}
