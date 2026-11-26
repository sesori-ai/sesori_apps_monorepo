import "package:omp_plugin/src/repositories/mappers/omp_harness_turn_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = OmpHarnessTurnMapper();

  PluginMessagePart text(String text) =>
      PluginMessagePart.text(id: "m1-text", sessionID: "s1", messageID: "m1", text: text);

  PluginMessageWithParts user({required List<PluginMessagePart> parts}) => PluginMessageWithParts(
    info: const PluginMessage.user(
      id: "m1",
      sessionID: "s1",
      agent: null,
      time: null,
      promptId: null,
      invocation: null,
    ),
    parts: parts,
  );

  bool kept(PluginMessageWithParts message) => mapper.withoutHarnessTurns(messages: [message]).isNotEmpty;

  test("drops a user turn that is one whole OMP harness block", () {
    const leftoverReminder =
        "<system-reminder>\nYour bash calls left 1 process running:\n- pid 4242 (&, started 3s ago): `sleep 600 &`\n"
        "</system-reminder>";
    for (final block in [
      leftoverReminder,
      "<system-notice>\nCheckpoint is active.\n</system-notice>\n",
      '<system-interrupt reason="thinking_loop">\nStop and act.\n</system-interrupt>',
      '<tangent-notice handle="job-1">\nwork\n</tangent-notice>',
      '<irc from="parent">\nhello\n</irc>',
    ]) {
      expect(kept(user(parts: [text(block)])), isFalse, reason: block);
    }
  });

  test("drops a user turn whose every text part is a harness block", () {
    final message = user(
      parts: [
        text("<system-reminder>\none\n</system-reminder>"),
        text("<system-warning>\ntwo\n</system-warning>"),
      ],
    );

    expect(kept(message), isFalse);
  });

  test("keeps user text that is not wholly a harness block", () {
    for (final typed in [
      "start a server",
      "Why did you get this? <system-reminder>\nx\n</system-reminder>",
      "<system-reminder>\nx\n</system-reminder>\nand then do this",
      "<system-reminder>\nunclosed",
      "<system-reminder>\nx\n</system-notice>",
      "<skill>\nbody\n</skill>",
      "<context-window-reminder>\nx\n</context-window-reminder>",
    ]) {
      expect(kept(user(parts: [text(typed)])), isTrue, reason: typed);
    }
    expect(
      kept(user(parts: [text("<system-reminder>\nx\n</system-reminder>"), text("my own words")])),
      isTrue,
    );
  });

  test("keeps assistant replies that quote a harness block", () {
    final reply = PluginMessageWithParts(
      info: const PluginMessage.assistant(
        id: "m2",
        sessionID: "s1",
        agent: null,
        modelID: null,
        providerID: null,
        variant: null,
        sender: PluginMessageSender.agent,
        time: null,
      ),
      parts: [text("<system-reminder>\nx\n</system-reminder>")],
    );

    expect(mapper.withoutHarnessTurns(messages: [reply]), [reply]);
  });
}
