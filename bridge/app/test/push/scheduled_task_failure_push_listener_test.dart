import "dart:async";

import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_bridge/src/push/scheduled_task_failure_push_listener.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_failure.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late StreamController<ScheduledTaskRunFailure> failures;
  late _FakeDispatcher dispatcher;
  late ScheduledTaskFailurePushListener listener;

  setUp(() {
    failures = StreamController<ScheduledTaskRunFailure>.broadcast(sync: true);
    dispatcher = _FakeDispatcher();
    listener = ScheduledTaskFailurePushListener(
      source: failures.stream,
      contentBuilder: const PushNotificationContentBuilder(),
      dispatcher: dispatcher,
    );
    addTearDown(() async {
      await listener.dispose();
      await failures.close();
    });
  });

  test("each run that could not start is pushed with its task and reason", () {
    listener.start();

    failures
      ..add(
        const ScheduledTaskRunFailure(
          taskId: "stk_a",
          taskName: "Morning summary",
          reason: TaskRunFailureReason.modelUnavailable,
        ),
      )
      ..add(
        const ScheduledTaskRunFailure(
          taskId: "stk_b",
          taskName: "Nightly review",
          reason: TaskRunFailureReason.projectMissing,
        ),
      );

    expect(dispatcher.sent, [
      (taskId: "stk_a", title: "Morning summary", body: "Couldn't start: the model is no longer offered."),
      (taskId: "stk_b", title: "Nightly review", body: "Couldn't start: the project is gone."),
    ]);
  });

  test("nothing is pushed before start or after dispose", () async {
    const failure = ScheduledTaskRunFailure(
      taskId: "stk_a",
      taskName: "Morning summary",
      reason: TaskRunFailureReason.startFailed,
    );
    failures.add(failure);
    listener.start();
    await listener.dispose();
    failures.add(failure);

    expect(dispatcher.sent, isEmpty);
  });
}

class _FakeDispatcher() implements PushDispatcher {
  final List<({String taskId, String title, String body})> sent = [];

  @override
  void dispatchScheduledTaskFailure({required String taskId, required String title, required String body}) {
    sent.add((taskId: taskId, title: title, body: body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
