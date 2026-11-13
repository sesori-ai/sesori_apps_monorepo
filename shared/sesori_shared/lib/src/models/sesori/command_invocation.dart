import "package:freezed_annotation/freezed_annotation.dart";

import "command_info.dart";

part "command_invocation.freezed.dart";

part "command_invocation.g.dart";

/// The command, skill or MCP prompt a user turn ran, as the bridge sent it.
///
/// [name] is the bare command name without the leading `/`. [arguments] is
/// the text the user typed after it; null when they typed none, never empty.
@Freezed(fromJson: true, toJson: true)
sealed class CommandInvocation with _$CommandInvocation {
  const factory({
    required String name,
    @JsonKey(unknownEnumValue: CommandSource.unknown) required CommandSource source,
    required String? arguments,
  }) = _CommandInvocation;

  factory fromJson(Map<String, dynamic> json) => _$CommandInvocationFromJson(json);
}
