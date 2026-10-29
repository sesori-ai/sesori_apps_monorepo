import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = ActiveSessionRunningCalculator();

  ActiveSession session({
    bool mainAgentRunning = false,
    bool awaitingInput = false,
    List<String> childSessionIds = const [],
    bool isRetrying = false,
  }) => ActiveSession(
    id: "s",
    mainAgentRunning: mainAgentRunning,
    awaitingInput: awaitingInput,
    childSessionIds: childSessionIds,
    isRetrying: isRetrying,
    lastUserActivityAt: null,
    updatedAt: null,
  );

  test("a session runs while its main agent works", () {
    expect(calculator.isRunning(session: session(mainAgentRunning: true)), isTrue);
  });

  test("a session runs while it waits to retry", () {
    expect(calculator.isRunning(session: session(isRetrying: true)), isTrue);
  });

  test("a session runs while a child task is active", () {
    expect(calculator.isRunning(session: session(childSessionIds: ["c"])), isTrue);
  });

  test("an idle session, or one only awaiting input, does not run", () {
    expect(calculator.isRunning(session: session()), isFalse);
    expect(calculator.isRunning(session: session(awaitingInput: true)), isFalse);
  });
}
