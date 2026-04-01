import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_command.freezed.dart";
part "plugin_command.g.dart";

enum PluginCommandSource {
  command,
  mcp,
  skill,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginCommand with _$PluginCommand {
  const factory PluginCommand({
    required String name,
    required String template,
    required List<String> hints,
    String? description,
    String? agent,
    String? model,
    PluginCommandSource? source,
    bool? subtask,
  }) = _PluginCommand;

  factory PluginCommand.fromJson(Map<String, dynamic> json) => _$PluginCommandFromJson(json);
}
