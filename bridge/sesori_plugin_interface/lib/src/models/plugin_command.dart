import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_command.freezed.dart";
part "plugin_command.g.dart";

enum PluginCommandSource {
  command,
  mcp,
  skill,
  unknown,
}

@JsonEnum()
enum PluginCommandOrigin {
  manual,
  automatic,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginCommand with _$PluginCommand {
  const factory PluginCommand({
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

  factory PluginCommand.fromJson(Map<String, dynamic> json) => _$PluginCommandFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginCommandInvocationContext with _$PluginCommandInvocationContext {
  const factory PluginCommandInvocationContext({
    required String invocationId,
    required String name,
    required String? arguments,
    required int acceptedAt,
    required String? backendMessageId,
  }) = _PluginCommandInvocationContext;

  factory PluginCommandInvocationContext.fromJson(Map<String, dynamic> json) =>
      _$PluginCommandInvocationContextFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginCommandDispatch with _$PluginCommandDispatch {
  const factory PluginCommandDispatch({
    required String? backendMessageId,
  }) = _PluginCommandDispatch;

  factory PluginCommandDispatch.fromJson(Map<String, dynamic> json) => _$PluginCommandDispatchFromJson(json);
}
