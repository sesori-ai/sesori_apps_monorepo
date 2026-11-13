import "package:omp_plugin/src/repositories/mappers/omp_skill_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = OmpSkillMapper();

  PluginMessageWithParts user({required String text}) => PluginMessageWithParts(
    info: const PluginMessage.user(
      id: "m1",
      sessionID: "s1",
      agent: null,
      time: null,
      promptId: null,
      invocation: null,
    ),
    parts: [PluginMessagePart.text(id: "m1-text", sessionID: "s1", messageID: "m1", text: text)],
  );

  PluginMessageWithParts named({required String text}) {
    final [message] = mapper.nameSkillRuns(messages: [user(text: text)]);
    return message;
  }

  PluginCommandInvocation? invocationOf(PluginMessageWithParts message) => switch (message.info) {
    PluginMessageUser(:final invocation) => invocation,
    _ => null,
  };

  String textOf(PluginMessageWithParts message) => (message.parts.single as PluginMessagePartText).text;

  const ompPrompt =
      '[IMPORTANT: User invoked the "hello" skill; follow its instructions. Full skill below.]\n\n'
      "Reply briefly.\nUser: not the arguments\n\n---\n\n"
      "[Skill directory: /skills/hello]\n"
      "Resolve relative paths in this skill (e.g. `scripts/foo.js`) against this absolute directory.";

  test("names OMP's injected skill prompt, with the user's text as arguments", () {
    final message = named(text: "$ompPrompt\nUser: for Bob\nand Ann");

    expect(
      invocationOf(message),
      const PluginCommandInvocation(
        name: "skill:hello",
        source: PluginCommandSource.skill,
        arguments: "for Bob\nand Ann",
      ),
    );
    expect(textOf(message), "/skill:hello for Bob\nand Ann");
  });

  test("OMP's injected skill prompt without user text has null arguments", () {
    final message = named(text: ompPrompt);

    expect(invocationOf(message)?.name, "skill:hello");
    expect(invocationOf(message)?.arguments, isNull);
    expect(textOf(message), "/skill:hello");
  });

  test("text that is not a whole skill prompt stays as it is", () {
    for (final text in [
      '<skill name="hello" location="/skills/hello/SKILL.md">\nReply briefly.\n</skill>\n\nfor Bob',
      "/skill:hello",
      "Quote: $ompPrompt",
    ]) {
      final message = named(text: text);
      expect(invocationOf(message), isNull);
      expect(textOf(message), text);
    }
  });

  test("marks skill: commands as skills and leaves other commands alone", () {
    final labelled = mapper.labelSkills(
      commands: const [
        PluginCommand(name: "skill:hello", provider: null, source: PluginCommandSource.command),
        PluginCommand(name: "compact", provider: null, source: PluginCommandSource.command),
      ],
    );

    expect(labelled.map((command) => command.source), [PluginCommandSource.skill, PluginCommandSource.command]);
  });
}
