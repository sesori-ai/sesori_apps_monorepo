import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_command.dart";

part "plugin_command_invocation.freezed.dart";
part "plugin_command_invocation.g.dart";

/// The command, skill or MCP prompt a user message ran, as the backend's own
/// record names it. Plugin-side equivalent of `CommandInvocation` from
/// `sesori_shared`.
///
/// [name] is the bare command name without the leading `/`. [arguments] is
/// the text the user typed after it; null when they typed none, never empty.
@freezed
sealed class PluginCommandInvocation with _$PluginCommandInvocation {
  const factory({
    required String name,
    required PluginCommandSource source,
    required String? arguments,
  }) = _PluginCommandInvocation;
}
