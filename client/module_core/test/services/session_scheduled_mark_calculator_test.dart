import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = SessionScheduledMarkCalculator();
  const task = SessionScheduledTaskMark(taskId: "t-1", name: "Nightly triage", kind: ScheduledTaskKind.recurring);

  SessionScheduledMark markOf({required SessionArming arming, required SessionScheduledTaskMark? task}) =>
      calculator.mark(
        session: testSession(id: "s-1").copyWith(arming: arming, scheduledTask: task),
      );

  test("an armed session names what wakes it and when, task or not", () {
    for (final mark in [task, null]) {
      expect(
        markOf(
          arming: const SessionArming.armed(name: "Check CI", nextAt: 9000),
          task: mark,
        ),
        const SessionScheduledMark.armed(name: "Check CI", nextAt: 9000),
      );
    }
  });

  test("a task's session that nothing wakes again says where it came from", () {
    expect(
      markOf(arming: const SessionArming.notArmed(), task: task),
      const SessionScheduledMark.fromTask(name: "Nightly triage"),
    );
  });

  test("an older bridge keeps the plain task mark", () {
    expect(
      markOf(arming: const SessionArming.unreported(), task: task),
      const SessionScheduledMark.legacyTask(task: task),
    );
  });

  test("a session the user started, that nothing wakes, has no mark", () {
    for (final arming in const [SessionArming.notArmed(), SessionArming.unreported()]) {
      expect(markOf(arming: arming, task: null), const SessionScheduledMark.none());
    }
  });
}
