import "package:freezed_annotation/freezed_annotation.dart";

part "command.freezed.dart";

part "command.g.dart";

enum CommandSource {
  command,
  mcp,
  skill,
  unknown,
}

/// OpenCode may return `template` as `{}` (empty map) for MCP tool commands
/// instead of a String.  Coerce non-strings to null so Freezed can parse them.
Object? _readTemplate(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

@Freezed(fromJson: true, toJson: true)
sealed class Command with _$Command {
  const factory Command({
    required String name,
    @JsonKey(readValue: _readTemplate) String? template,
    @Default(<String>[]) List<String> hints,
    String? description,
    String? agent,
    String? model,
    required String? provider,
    @JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source,
    bool? subtask,
  }) = _Command;

  factory Command.fromJson(Map<String, dynamic> json) => _$CommandFromJson(json);
}
