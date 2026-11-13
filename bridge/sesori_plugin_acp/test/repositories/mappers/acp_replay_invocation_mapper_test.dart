import "package:acp_plugin/src/repositories/mappers/acp_replay_invocation_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = AcpReplayInvocationMapper();
  const commands = [
    PluginCommand(name: "plan", provider: null, source: PluginCommandSource.command),
    PluginCommand(name: "legacy", provider: null),
  ];

  PluginMessageWithParts user({required String text, required PluginCommandInvocation? invocation}) =>
      PluginMessageWithParts(
        info: PluginMessage.user(
          id: "m1",
          sessionID: "s1",
          agent: null,
          time: null,
          promptId: null,
          invocation: invocation,
        ),
        parts: [PluginMessagePart.text(id: "m1-text", sessionID: "s1", messageID: "m1", text: text)],
      );

  PluginCommandInvocation? named({required String text}) {
    final [message] = mapper.nameInvocations(
      messages: [user(text: text, invocation: null)],
      commands: commands,
    );
    return switch (message.info) {
      PluginMessageUser(:final invocation) => invocation,
      _ => null,
    };
  }

  test("names an advertised command with its arguments", () {
    expect(
      named(text: "/plan Write the\ntests "),
      const PluginCommandInvocation(name: "plan", source: PluginCommandSource.command, arguments: "Write the\ntests "),
    );
  });

  test("a command without arguments has null arguments", () {
    expect(
      named(text: "/plan"),
      const PluginCommandInvocation(name: "plan", source: PluginCommandSource.command, arguments: null),
    );
  });

  test("an advertised command without a kind is unknown", () {
    expect(
      named(text: "/legacy x"),
      const PluginCommandInvocation(name: "legacy", source: PluginCommandSource.unknown, arguments: "x"),
    );
  });

  test("text that does not run an advertised command stays plain", () {
    expect(named(text: "/tmp/x is broken"), isNull);
    expect(named(text: "please /plan this"), isNull);
    expect(named(text: " /plan this"), isNull);
  });

  test("a turn the harness already named keeps its own invocation", () {
    const own = PluginCommandInvocation(name: "own", source: PluginCommandSource.skill, arguments: null);
    final [message] = mapper.nameInvocations(
      messages: [user(text: "/plan x", invocation: own)],
      commands: commands,
    );
    expect(message.info, isA<PluginMessageUser>().having((info) => info.invocation, "invocation", own));
  });
}
