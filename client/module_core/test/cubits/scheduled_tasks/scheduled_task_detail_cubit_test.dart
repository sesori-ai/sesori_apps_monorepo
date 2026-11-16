import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _connected = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "bridge"),
  health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
);

const _run = ScheduledTaskRun(
  id: "run-1",
  scheduledFor: ScheduledTaskInstant(at: 1000, offsetMinutes: 0),
  outcome: ScheduledTaskRunOutcome.started(
    session: ScheduledTaskRunSession(id: "session-1", projectId: "fixture-project"),
    late: false,
  ),
);

class _FixedTimeZoneSource() implements DeviceTimeZoneSource {
  @override
  Future<String> currentZoneName() async => "Europe/Bucharest";
}

void main() {
  setUpAll(() => registerFallbackValue(scheduledTaskFixture(id: "fallback").definition));
  late MockScheduledTaskRepository repository;
  late MockConnectionService connection;
  late StreamController<SseEvent> events;

  setUp(() {
    repository = MockScheduledTaskRepository();
    connection = MockConnectionService();
    events = StreamController<SseEvent>.broadcast();
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(_connected);
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => repository.listRuns(taskId: "task")).thenAnswer((_) async => const ScheduledTaskSuccess(value: [_run]));
    addTearDown(events.close);
    addTearDown(statuses.close);
  });

  void answerList(List<ScheduledTask> tasks) =>
      when(() => repository.listTasks()).thenAnswer((_) async => ScheduledTaskSuccess(value: tasks));

  ScheduledTaskDetailCubit create() {
    final cubit = ScheduledTaskDetailCubit(
      repository: repository,
      connectionService: connection,
      timeZoneSource: _FixedTimeZoneSource(),
      taskId: "task",
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test("loads the task with its runs", () async {
    answerList([scheduledTaskFixture(id: "other"), scheduledTaskFixture(id: "task")]);
    final cubit = create();
    expect(cubit.state, isA<ScheduledTaskDetailLoading>());

    await pumpEventQueue();

    final state = cubit.state as ScheduledTaskDetailLoaded;
    expect(state.task.id, "task");
    expect(state.runs, [_run]);
    expect(state.editable, isTrue);
  });

  test("a task with a schedule or run mode from a newer app is read-only", () async {
    for (final task in [
      scheduledTaskFixture(id: "task", schedule: const TaskSchedule.unknown()),
      scheduledTaskFixture(id: "task", runMode: const TaskRunMode.unknown()),
    ]) {
      answerList([task]);
      final cubit = create();
      await pumpEventQueue();

      expect((cubit.state as ScheduledTaskDetailLoaded).editable, isFalse);
      expect(await cubit.rename(name: "Renamed"), isFalse);
    }
    verifyNever(
      () => repository.update(
        taskId: "task",
        definition: any(named: "definition"),
      ),
    );
  });

  test("refetches when the bridge says the tasks changed, and shows a task that left the list as gone", () async {
    answerList([scheduledTaskFixture(id: "task")]);
    final cubit = create();
    await pumpEventQueue();

    answerList([]);
    events.add(SseEvent(data: const SesoriSseEvent.scheduledTasksChanged()));
    await pumpEventQueue();

    expect(cubit.state, isA<ScheduledTaskDetailGone>());
  });

  test("an older bridge shows the update state", () async {
    when(() => repository.listTasks()).thenAnswer((_) async => const ScheduledTaskBridgeOutdated());
    when(() => repository.listRuns(taskId: "task")).thenAnswer((_) async => const ScheduledTaskBridgeOutdated());
    final cubit = create();
    await pumpEventQueue();

    expect(cubit.state, isA<ScheduledTaskDetailBridgeOutdated>());
  });

  test("Run now passes the previous-run refusal on to the page", () async {
    answerList([scheduledTaskFixture(id: "task")]);
    when(
      () => repository.runNow(taskId: "task"),
    ).thenAnswer((_) async => const ScheduledTaskRefused(code: ScheduledTaskErrorCode.previousRunActive));
    final cubit = create();
    await pumpEventQueue();

    expect(
      await cubit.runNow(),
      isA<ScheduledTaskRefused<ScheduledTaskRun>>().having(
        (result) => result.code,
        "code",
        ScheduledTaskErrorCode.previousRunActive,
      ),
    );
  });

  test("Pause shows at once and reverts when the bridge fails", () async {
    answerList([scheduledTaskFixture(id: "task")]);
    final cubit = create();
    await pumpEventQueue();
    final answer = Completer<ScheduledTaskResult<ScheduledTask>>();
    when(() => repository.setEnabled(taskId: "task", enabled: false)).thenAnswer((_) => answer.future);

    final changed = cubit.setEnabled(enabled: false);
    expect((cubit.state as ScheduledTaskDetailLoaded).task.enabled, isFalse);

    answer.complete(ScheduledTaskFailure(error: NonSuccessCodeError(errorCode: 503, rawErrorString: null)));
    expect(await changed, isFalse);
    expect((cubit.state as ScheduledTaskDetailLoaded).task.enabled, isTrue);
  });
}
