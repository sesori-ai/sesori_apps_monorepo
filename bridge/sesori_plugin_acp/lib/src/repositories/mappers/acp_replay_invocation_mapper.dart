import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Names the replayed user turns that ran an advertised slash command.
///
/// ACP has no command record of its own: a command reaches the agent as the
/// `/name args` prompt text, and that text is what `session/load` replays.
/// A turn is named only when its name is one the agent advertises, so a
/// prompt that merely starts with a path such as `/tmp/x` stays a plain turn.
class const AcpReplayInvocationMapper() {
  static final RegExp _commandLine = RegExp(r"^/(\S+)(?:\s+([\s\S]*))?$");

  List<PluginMessageWithParts> nameInvocations({
    required List<PluginMessageWithParts> messages,
    required List<PluginCommand> commands,
  }) {
    if (commands.isEmpty) return messages;
    final commandsByName = {for (final command in commands) command.name: command};
    return [
      for (final message in messages)
        switch (message.info) {
          final PluginMessageUser user when user.invocation == null => switch (_invocation(
            parts: message.parts,
            commandsByName: commandsByName,
          )) {
            final invocation? => message.copyWith(info: user.copyWith(invocation: invocation)),
            null => message,
          },
          _ => message,
        },
    ];
  }

  PluginCommandInvocation? _invocation({
    required List<PluginMessagePart> parts,
    required Map<String, PluginCommand> commandsByName,
  }) {
    final text = parts.whereType<PluginMessagePartText>().singleOrNull?.text;
    if (text == null) return null;
    final match = _commandLine.firstMatch(text);
    if (match == null) return null;
    final name = match.group(1);
    final command = name == null ? null : commandsByName[name];
    if (name == null || command == null) return null;
    final arguments = match.group(2);
    return PluginCommandInvocation(
      name: name,
      source: command.source ?? PluginCommandSource.unknown,
      arguments: arguments == null || arguments.isEmpty ? null : arguments,
    );
  }
}
