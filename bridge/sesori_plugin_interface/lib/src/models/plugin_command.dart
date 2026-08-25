import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_command.freezed.dart";
part "plugin_command.g.dart";

enum PluginCommandSource() {
  command,
  mcp,
  skill,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginCommand with _$PluginCommand {
  static PluginCommand compaction({required String name}) => PluginCommand(
    name: name,
    description: "Summarize the conversation so far to free up the context window",
    provider: null,
    source: PluginCommandSource.command,
  );

  // ignore: no_slop_linter/prefer_required_named_parameters, generated public model signature
  const factory({
    required String name,
    String? template,
    @Default(<String>[]) List<String> hints,
    String? description,
    String? agent,
    String? model,
    required String? provider,
    PluginCommandSource? source,
    bool? subtask,
  }) = _PluginCommand;

  factory fromJson(Map<String, dynamic> json) => _$PluginCommandFromJson(json);
}
