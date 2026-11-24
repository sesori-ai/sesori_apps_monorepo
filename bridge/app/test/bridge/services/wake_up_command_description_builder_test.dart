import "package:sesori_bridge/src/repositories/models/agent_approval_change.dart";
import "package:sesori_bridge/src/repositories/models/session_wake_up.dart";
import "package:sesori_bridge/src/services/wake_up_command_description_builder.dart";
import "package:test/test.dart";

void main() {
  String card({required String command}) => const WakeUpCommandDescriptionBuilder().build(
    change: ScheduleCommandWakeUp(
      sessionId: "s1",
      label: "check",
      prompt: "Look at the result.",
      command: command,
      when: const WakeUpInMinutes(minutes: 5),
      timeZone: null,
    ),
    workingDirectory: "/work",
  );

  test("shows bidi and zero-width characters as their codes", () {
    final description = card(command: "echo safe \u202E# fr- mr\u2066x\u200B");

    expect(description, contains("echo safe <U+202E># fr- mr<U+2066>x<U+200B>"));
    expect(description, contains("invisible characters"));
    expect(description, isNot(matches(RegExp("[\u202E\u2066\u200B]"))));
  });

  test("leaves a plain command as written", () {
    final description = card(command: "make check");

    expect(description, contains("\nmake check\n"));
    expect(description, isNot(contains("invisible characters")));
  });
}
