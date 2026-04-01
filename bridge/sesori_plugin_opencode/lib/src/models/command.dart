import "package:freezed_annotation/freezed_annotation.dart";

part "command.freezed.dart";

part "command.g.dart";

enum CommandSource {
  command,
  mcp,
  skill,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class Command with _$Command {
  const factory Command({
    required String name,
    required String template,
    required List<String> hints,
    String? description,
    String? agent,
    String? model,
    @JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source,
    bool? subtask,
  }) = _Command;

  factory Command.fromJson(Map<String, dynamic> json) => _$CommandFromJson(json);
}
