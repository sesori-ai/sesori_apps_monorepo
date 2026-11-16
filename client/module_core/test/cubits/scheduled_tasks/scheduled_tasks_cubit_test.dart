import "dart:async";

import "package:fake_async/fake_async.dart";
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

final _daily = scheduledTaskFixture(id: "daily");
final _unknown = scheduledTaskFixture(id: "newer", schedule: const TaskSchedule.unknown());
final _later = scheduledTaskFixture(
  id: "later",
  schedule: const TaskSchedule.once(at: TaskLocalDateTime(year: 2026, month: 12, day: 2, hour: 9, minute: 0)),
  nextRunAt: const ScheduledTaskInstant(at: 2000, offsetMinutes: 0),
);
final _sooner = scheduledTaskFixture(
  id: "sooner",
  schedule: const TaskSchedule.once(at: TaskLocalDateTime(year: 2026, month: 12, day: 1, hour: 9, minute: 0)),
  nextRunAt: const ScheduledTaskInstant(at: 1000, offsetMinutes: 0),
);
final _pausedOnce = scheduledTaskFixture(
  id: "paused",
  schedule: const TaskSchedule.once(at: TaskLocalDateTime(year: 2026, month: 11, day: 30, hour: 9, minute: 0)),
  enabled: false,
);

void main() {
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
    addTearDown(events.close);
    addTearDown(statuses.close);
  });

  void answerList(ScheduledTaskResult<List<ScheduledTask>> result) =>
      when(() => repository.listTasks()).thenAnswer((_) async => result);

  ScheduledTasksCubit create() {
    final cubit = ScheduledTasksCubit(repository: repository, connectionService: connection);
    addTearDown(cubit.close);
    return cubit;
  }

  test("loads recurring tasks in bridge order and one-off tasks soonest first, paused last", () async {
    answerList(ScheduledTaskSuccess(value: [_pausedOnce, _later, _daily, _sooner, _unknown]));
    final cubit = create();
    expect(cubit.state, isA<ScheduledTasksLoading>());

    await pumpEventQueue();

    final state = cubit.state as ScheduledTasksLoaded;
    expect(state.recurring.map((task) => task.id), ["daily", "newer"]);
    expect(state.once.map((task) => task.id), ["sooner", "later", "paused"]);
  });

  test("refetches when the bridge says the tasks changed", () async {
    answerList(ScheduledTaskSuccess(value: [_daily]));
    final cubit = create();
    await pumpEventQueue();

    answerList(ScheduledTaskSuccess(value: [_daily, _sooner]));
    events.add(SseEvent(data: const SesoriSseEvent.scheduledTasksChanged()));
    await pumpEventQueue();

    expect((cubit.state as ScheduledTasksLoaded).once.map((task) => task.id), ["sooner"]);
    verify(() => repository.listTasks()).called(2);
  });

  test("an older bridge shows the update state", () async {
    answerList(const ScheduledTaskBridgeOutdated());
    final cubit = create();
    await pumpEventQueue();

    expect(cubit.state, isA<ScheduledTasksBridgeOutdated>());
  });

  test("a failed first load fails, while a failed refresh keeps the tasks shown", () async {
    answerList(ScheduledTaskFailure(error: NonSuccessCodeError(errorCode: 503, rawErrorString: null)));
    final cubit = create();
    await pumpEventQueue();
    expect(cubit.state, isA<ScheduledTasksFailed>());

    answerList(ScheduledTaskSuccess(value: [_daily]));
    await cubit.retry();
    answerList(ScheduledTaskFailure(error: NonSuccessCodeError(errorCode: 503, rawErrorString: null)));
    await cubit.refresh();

    expect((cubit.state as ScheduledTasksLoaded).recurring.single.id, "daily");
  });

  test("a switch moves at once and goes back when the bridge refuses", () async {
    answerList(ScheduledTaskSuccess(value: [_daily]));
    final cubit = create();
    await pumpEventQueue();
    final answer = Completer<ScheduledTaskResult<ScheduledTask>>();
    when(() => repository.setEnabled(taskId: "daily", enabled: false)).thenAnswer((_) => answer.future);

    final changed = cubit.setEnabled(taskId: "daily", enabled: false);
    expect((cubit.state as ScheduledTasksLoaded).recurring.single.enabled, isFalse);

    answer.complete(const ScheduledTaskRefused(code: ScheduledTaskErrorCode.taskNotFound));
    expect(await changed, isFalse);
    expect((cubit.state as ScheduledTasksLoaded).recurring.single.enabled, isTrue);
  });

  test("an older switch answer arriving last does not undo a newer tap", () async {
    answerList(ScheduledTaskSuccess(value: [_daily]));
    final cubit = create();
    await pumpEventQueue();
    final pause = Completer<ScheduledTaskResult<ScheduledTask>>();
    final resume = Completer<ScheduledTaskResult<ScheduledTask>>();
    when(() => repository.setEnabled(taskId: "daily", enabled: false)).thenAnswer((_) => pause.future);
    when(() => repository.setEnabled(taskId: "daily", enabled: true)).thenAnswer((_) => resume.future);

    final paused = cubit.setEnabled(taskId: "daily", enabled: false);
    final resumed = cubit.setEnabled(taskId: "daily", enabled: true);
    resume.complete(ScheduledTaskSuccess(value: _daily));
    await resumed;
    pause.complete(ScheduledTaskSuccess(value: _daily.copyWith(enabled: false, nextRunAt: null)));
    await paused;

    expect((cubit.state as ScheduledTasksLoaded).recurring.single.enabled, isTrue);
  });

  test("a failed refresh is tried again until a snapshot applies", () {
    fakeAsync((async) {
      answerList(ScheduledTaskSuccess(value: [_daily]));
      final cubit = create();
      async.flushMicrotasks();

      answerList(ScheduledTaskFailure(error: NonSuccessCodeError(errorCode: 503, rawErrorString: null)));
      unawaited(cubit.refresh());
      async.flushMicrotasks();
      answerList(ScheduledTaskSuccess(value: [_daily, _sooner]));
      async.elapse(const Duration(seconds: 5));

      expect((cubit.state as ScheduledTasksLoaded).once.single.id, "sooner");
      verify(() => repository.listTasks()).called(3);
    });
  });
}
