import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _FakeTimeZoneSource() implements DeviceTimeZoneSource {
  String? zone = "Europe/Bucharest";

  @override
  Future<String> currentZoneName() async => zone ?? (throw StateError("no zone"));
}

/// Monday 2026-11-16, 10:30 on the device's clock.
final _now = DateTime(2026, 11, 16, 10, 30);

TaskComposerSubmission _submission({String prompt = "Summarize yesterday", CommandInfo? command}) =>
    TaskComposerSubmission(
      project: const NewSessionProject(id: "fixture-project", name: "Fixture", kind: ProjectKind.folder),
      pluginId: "fixture",
      agent: "build",
      model: const PromptModel(providerID: "provider", modelID: "model"),
      variant: null,
      fastMode: false,
      dedicatedWorktree: true,
      prompt: prompt,
      command: command,
    );

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(scheduledTaskFixture(id: "fallback").definition);
  });

  late MockScheduledTaskRepository repository;
  late _FakeTimeZoneSource timeZones;
  late MockBridgeSettingsService bridgeSettings;
  late BehaviorSubject<YoloSettingsResponse> yolo;
  late MockProductAnalyticsService analytics;

  setUp(() {
    repository = MockScheduledTaskRepository();
    timeZones = _FakeTimeZoneSource();
    bridgeSettings = MockBridgeSettingsService();
    yolo = BehaviorSubject.seeded(const YoloSettingsResponse(enabled: false));
    analytics = stubbedProductAnalyticsService();
    when(() => bridgeSettings.yoloSettings).thenAnswer((_) => yolo.stream);
    addTearDown(yolo.close);
  });

  ScheduledTaskEditorCubit createCubit({String? taskId}) {
    final cubit = ScheduledTaskEditorCubit(
      repository: repository,
      timeZoneSource: timeZones,
      bridgeSettingsService: bridgeSettings,
      productAnalyticsService: analytics,
      now: () => _now,
      taskId: taskId,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<ScheduledTaskEditorState> settled(ScheduledTaskEditorCubit cubit) async =>
      cubit.state is ScheduledTaskEditorLoading ? await cubit.stream.first : cubit.state;

  Future<ScheduledTaskEditorReady> ready(ScheduledTaskEditorCubit cubit) async =>
      await settled(cubit) as ScheduledTaskEditorReady;

  ScheduledTaskEditorReady current(ScheduledTaskEditorCubit cubit) => cubit.state as ScheduledTaskEditorReady;

  void answerCreate(ScheduledTaskResult<ScheduledTask> result) =>
      when(() => repository.create(definition: any(named: "definition"))).thenAnswer((_) async => result);

  ScheduledTaskDefinition createdDefinition() =>
      verify(() => repository.create(definition: captureAny(named: "definition"))).captured.single
          as ScheduledTaskDefinition;

  List<ProductAnalyticsEvent> reportedEvents() => verify(
    () => analytics.logEvent(event: captureAny(named: "event"), occurredAtUtc: any(named: "occurredAtUtc")),
  ).captured.cast<ProductAnalyticsEvent>();

  group("new task", () {
    test("opens on every day at 09:00 in the device zone, run when back, a new session, asking", () async {
      final state = await ready(createCubit());

      expect(state.editing, isNull);
      expect(state.schedule, const TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)));
      expect(state.timeZone, "Europe/Bucharest");
      expect(state.missedRunPolicy, TaskMissedRunPolicy.runWhenBack);
      expect(state.runMode, const TaskRunMode.newSession());
      expect(state.approvalMode, TaskApprovalMode.ask);
      expect(state.offersMissedRunChoice, isTrue);
    });

    test("approves everything when the computer's YOLO setting is on", () async {
      yolo.add(const YoloSettingsResponse(enabled: true));

      expect((await ready(createCubit())).approvalMode, TaskApprovalMode.approveAll);
    });

    test("cannot open without the device zone", () async {
      timeZones.zone = null;

      expect(
        await settled(createCubit()),
        const ScheduledTaskEditorState.unavailable(reason: ScheduledTaskEditorUnavailableReason.loadFailed),
      );
    });

    test("saves the composer's choices with the When and Each run choices, named after the prompt", () async {
      answerCreate(ScheduledTaskSuccess(value: scheduledTaskFixture(id: "task")));
      final cubit = createCubit();
      await ready(cubit);
      cubit
        ..setTime(time: const TaskTimeOfDay(hour: 7, minute: 15))
        ..setSameSession(sameSession: true)
        ..setApprovalMode(mode: TaskApprovalMode.approveAll);

      await cubit.save(submission: _submission(prompt: "Summarize yesterday\nKeep it short"));

      expect(
        createdDefinition(),
        const ScheduledTaskDefinition(
          name: "Summarize yesterday",
          prompt: ScheduledTaskPrompt.text(text: "Summarize yesterday\nKeep it short"),
          projectId: "fixture-project",
          pluginId: "fixture",
          agent: "build",
          model: PromptModel(providerID: "provider", modelID: "model"),
          variant: null,
          fastMode: false,
          dedicatedWorktree: true,
          schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 7, minute: 15)),
          timeZone: "Europe/Bucharest",
          missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
          runMode: TaskRunMode.sameSession(autoCompact: false),
          approvalMode: TaskApprovalMode.approveAll,
        ),
      );
      expect(current(cubit).save, isA<ScheduledTaskEditorSaved>());
      expect(reportedEvents(), [
        const ProductAnalyticsEvent.scheduledTaskSaved(
          action: AnalyticsScheduledTaskAction.created,
          repeat: AnalyticsScheduledTaskRepeat.daily,
          runMode: AnalyticsScheduledTaskRunMode.sameSession,
          approvalMode: AnalyticsScheduledTaskApprovalMode.approveAll,
          missedRunPolicy: AnalyticsScheduledTaskMissedRunPolicy.runWhenBack,
          autoCompact: false,
        ),
      ]);
    });

    test("saves a slash command with its arguments, named after both", () async {
      answerCreate(ScheduledTaskSuccess(value: scheduledTaskFixture(id: "task")));
      final cubit = createCubit();
      await ready(cubit);
      const command = CommandInfo(
        name: "review",
        template: null,
        hints: null,
        description: null,
        agent: null,
        model: null,
        provider: null,
        source: null,
        subtask: null,
      );

      await cubit.save(submission: _submission(prompt: "", command: command));

      final definition = createdDefinition();
      expect(
        definition.prompt,
        const ScheduledTaskPrompt.command(name: "review", source: CommandSource.command, arguments: null),
      );
      expect(definition.name, "/review");
    });

    test("shows the bridge's refusal and reports nothing", () async {
      answerCreate(const ScheduledTaskRefused(code: ScheduledTaskErrorCode.unknownHarness));
      final cubit = createCubit();
      await ready(cubit);

      await cubit.save(submission: _submission());

      expect(current(cubit).save, isA<ScheduledTaskEditorRefused>());
      expect((current(cubit).save as ScheduledTaskEditorRefused).code, ScheduledTaskErrorCode.unknownHarness);
      verifyNever(() => analytics.logEvent(event: any(named: "event"), occurredAtUtc: any(named: "occurredAtUtc")));
    });

    test("says when the computer's bridge predates scheduled tasks", () async {
      answerCreate(const ScheduledTaskBridgeOutdated());
      final cubit = createCubit();
      await ready(cubit);

      await cubit.save(submission: _submission());

      expect(current(cubit).save, isA<ScheduledTaskEditorSaveBridgeOutdated>());
    });

    test("a changed choice clears the refusal", () async {
      answerCreate(const ScheduledTaskRefused(code: ScheduledTaskErrorCode.unknownHarness));
      final cubit = createCubit();
      await ready(cubit);
      await cubit.save(submission: _submission());

      cubit.setApprovalMode(mode: TaskApprovalMode.approveAll);

      expect(current(cubit).save, isA<ScheduledTaskEditorSaveIdle>());
    });
  });

  group("validation", () {
    test("refuses an empty prompt without asking the bridge", () async {
      final cubit = createCubit();
      await ready(cubit);

      await cubit.save(submission: _submission(prompt: ""));

      expect((current(cubit).save as ScheduledTaskEditorRefused).code, ScheduledTaskErrorCode.emptyPrompt);
      verifyNever(() => repository.create(definition: any(named: "definition")));
    });

    test("refuses a weekly schedule with no days", () async {
      final cubit = createCubit();
      await ready(cubit);
      cubit
        ..selectRepeat(repeat: ScheduledTaskRepeat.weekly)
        ..toggleWeekday(day: TaskWeekday.monday);

      await cubit.save(submission: _submission());

      expect(current(cubit).schedule, const TaskSchedule.weekly(days: {}, time: TaskTimeOfDay(hour: 9, minute: 0)));
      expect((current(cubit).save as ScheduledTaskEditorRefused).code, ScheduledTaskErrorCode.invalidSchedule);
      verifyNever(() => repository.create(definition: any(named: "definition")));
    });

    test("refuses a one-off time that has passed", () async {
      final cubit = createCubit();
      await ready(cubit);
      cubit
        ..selectRepeat(repeat: ScheduledTaskRepeat.once)
        ..setDateTime(at: const TaskLocalDateTime(year: 2026, month: 11, day: 16, hour: 10, minute: 30));

      await cubit.save(submission: _submission());

      expect((current(cubit).save as ScheduledTaskEditorRefused).code, ScheduledTaskErrorCode.onceTimeInPast);
      verifyNever(() => repository.create(definition: any(named: "definition")));
    });
  });

  group("When", () {
    test("Once lands on the next time the clock time comes round and hides the missed-run choice", () async {
      final cubit = createCubit();
      await ready(cubit);

      cubit.selectRepeat(repeat: ScheduledTaskRepeat.once);

      // 09:00 has passed at 10:30, so tomorrow.
      expect(
        current(cubit).schedule,
        const TaskSchedule.once(at: TaskLocalDateTime(year: 2026, month: 11, day: 17, hour: 9, minute: 0)),
      );
      expect(current(cubit).offersMissedRunChoice, isFalse);
    });

    test("switching presets keeps the time of day", () async {
      final cubit = createCubit();
      await ready(cubit);
      cubit
        ..setTime(time: const TaskTimeOfDay(hour: 18, minute: 45))
        ..selectRepeat(repeat: ScheduledTaskRepeat.weekly);

      expect(
        current(cubit).schedule,
        const TaskSchedule.weekly(days: {TaskWeekday.monday}, time: TaskTimeOfDay(hour: 18, minute: 45)),
      );

      cubit.selectRepeat(repeat: ScheduledTaskRepeat.everyHours);

      expect(
        current(cubit).schedule,
        const TaskSchedule.everyHours(
          hours: ScheduledTaskEditorCubit.defaultHours,
          start: TaskLocalDateTime(year: 2026, month: 11, day: 16, hour: 18, minute: 45),
        ),
      );
    });

    test("holds the interval to 1 to 12 hours", () async {
      final cubit = createCubit();
      await ready(cubit);
      cubit
        ..selectRepeat(repeat: ScheduledTaskRepeat.everyHours)
        ..setHours(hours: 13);

      expect((current(cubit).schedule as TaskScheduleEveryHours).hours, 12);
    });
  });

  group("edit", () {
    void answerList(List<ScheduledTask> tasks) =>
        when(() => repository.listTasks()).thenAnswer((_) async => ScheduledTaskSuccess(value: tasks));

    test("opens on the task's own choices and zone", () async {
      final task = scheduledTaskFixture(
        id: "task",
        schedule: const TaskSchedule.weekdays(time: TaskTimeOfDay(hour: 8, minute: 0)),
        runMode: const TaskRunMode.sameSession(autoCompact: true),
      );
      answerList([task]);

      final state = await ready(createCubit(taskId: "task"));

      expect(state.editing, task);
      expect(state.schedule, const TaskSchedule.weekdays(time: TaskTimeOfDay(hour: 8, minute: 0)));
      expect(state.runMode, const TaskRunMode.sameSession(autoCompact: true));
      expect(state.timeZone, "UTC");
    });

    test("a task that left the list, or has parts from a newer app, cannot be edited", () async {
      answerList([scheduledTaskFixture(id: "task", schedule: const TaskSchedule.unknown())]);

      expect(
        await settled(createCubit(taskId: "task")),
        const ScheduledTaskEditorState.unavailable(reason: ScheduledTaskEditorUnavailableReason.newerApp),
      );
      expect(
        await settled(createCubit(taskId: "other")),
        const ScheduledTaskEditorState.unavailable(reason: ScheduledTaskEditorUnavailableReason.taskGone),
      );
    });

    test("updates the task, keeping a name the user chose", () async {
      final task = scheduledTaskFixture(id: "task", name: "Morning summary");
      answerList([task]);
      when(
        () => repository.update(taskId: "task", definition: any(named: "definition")),
      ).thenAnswer((_) async => ScheduledTaskSuccess(value: task));
      final cubit = createCubit(taskId: "task");
      await ready(cubit);

      await cubit.save(submission: _submission(prompt: "Summarize the week"));

      final definition =
          verify(
                () => repository.update(taskId: "task", definition: captureAny(named: "definition")),
              ).captured.single
              as ScheduledTaskDefinition;
      expect(definition.name, "Morning summary");
      expect(definition.prompt, const ScheduledTaskPrompt.text(text: "Summarize the week"));
      expect(reportedEvents().single.parameters["action"], "edited");
    });

    test("a name taken from the prompt follows the new prompt", () async {
      answerList([scheduledTaskFixture(id: "task", name: "Summarize yesterday")]);
      when(
        () => repository.update(taskId: "task", definition: any(named: "definition")),
      ).thenAnswer((_) async => ScheduledTaskSuccess(value: scheduledTaskFixture(id: "task")));
      final cubit = createCubit(taskId: "task");
      await ready(cubit);

      await cubit.save(submission: _submission(prompt: "Summarize the week"));

      final definition =
          verify(
                () => repository.update(taskId: "task", definition: captureAny(named: "definition")),
              ).captured.single
              as ScheduledTaskDefinition;
      expect(definition.name, "Summarize the week");
    });
  });

  test("the composer opens an edited task on its harness, picks and prompt", () {
    const project = NewSessionProject(id: "fixture-project", name: "Fixture", kind: ProjectKind.folder);
    final definition = scheduledTaskFixture(id: "task").definition.copyWith(
      prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.skill, arguments: "src"),
      model: const PromptModel(providerID: "provider", modelID: "model"),
    );

    final selection = definition.composerSelection(project: project);

    expect(selection.harness?.pluginId, "fixture");
    expect(selection.harness?.picks.model?.modelId, "model");
    expect(selection.prompt, "src");
    expect(selection.commandName, "review");
  });
}
