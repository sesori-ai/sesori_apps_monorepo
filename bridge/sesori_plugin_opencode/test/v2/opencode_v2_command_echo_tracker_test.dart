import "package:opencode_plugin/src/v2/repositories/opencode_v2_command_echo_tracker.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:test/test.dart";

void main() {
  late OpenCodeV2CommandEchoTracker tracker;
  setUp(() => tracker = OpenCodeV2CommandEchoTracker());

  test("the first message admitted to the command's session takes its prompt", () {
    tracker.expect(sessionId: "session", promptId: "command-prompt");
    tracker.observeAdmitted(sessionId: "other", messageId: "msg_other");
    tracker.observeAdmitted(sessionId: "session", messageId: "msg_command");
    tracker.observeAdmitted(sessionId: "session", messageId: "msg_typed");

    expect(tracker.promptIdFor(messageId: "msg_other"), isNull);
    expect(tracker.promptIdFor(messageId: "msg_command"), "command-prompt");
    expect(tracker.promptIdFor(messageId: "msg_typed"), isNull);
  });

  test("a message Sesori named for its own prompt never takes the command's", () {
    tracker.expect(sessionId: "session", promptId: "command-prompt");
    final prompt = V2MessageMapper.withPromptId(messageId: "msg_prompt", promptId: "other-prompt");
    tracker.observeAdmitted(sessionId: "session", messageId: prompt);
    tracker.observeAdmitted(sessionId: "session", messageId: "msg_command");

    expect(tracker.promptIdFor(messageId: prompt), isNull);
    expect(tracker.promptIdFor(messageId: "msg_command"), "command-prompt");
  });

  test("a forgotten command claims nothing, and forgetting an older one keeps the newer", () {
    tracker.expect(sessionId: "session", promptId: "newer-prompt");
    tracker.forget(sessionId: "session", promptId: "older-prompt");
    tracker.observeAdmitted(sessionId: "session", messageId: "msg_newer");
    expect(tracker.promptIdFor(messageId: "msg_newer"), "newer-prompt");

    tracker.expect(sessionId: "session", promptId: "refused-prompt");
    tracker.forget(sessionId: "session", promptId: "refused-prompt");
    tracker.observeAdmitted(sessionId: "session", messageId: "msg_typed");
    expect(tracker.promptIdFor(messageId: "msg_typed"), isNull);
  });
}
