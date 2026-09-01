import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../support/bridge_id_storage.dart";

void main() {
  late _MockBridgeProcessService processService;
  late _FakeControlCommandService commandService;
  late _MockDesktopInstanceService instanceService;
  late BridgePromptTracker promptTracker;
  late BridgeStatusTracker statusTracker;
  late DesktopLogoutTracker logoutTracker;
  late BehaviorSubject<BridgeProcessState> processStates;
  late DesktopBridgeTakeoverOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    instanceService = _MockDesktopInstanceService();
    promptTracker = BridgePromptTracker();
    commandService = _FakeControlCommandService(promptTracker: promptTracker);
    statusTracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage());
    logoutTracker = DesktopLogoutTracker();
    processStates = BehaviorSubject<BridgeProcessState>.seeded(const BridgeProcessStopped());

    when(() => processService.states).thenAnswer((_) => processStates.stream);
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on),
    ).thenAnswer((_) async {});
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => processService.start()).thenAnswer((_) async {});
    orchestrator = DesktopBridgeTakeoverOrchestrator.forTesting(
      processService: processService,
      controlCommandService: commandService,
      instanceService: instanceService,
      promptTracker: promptTracker,
      statusTracker: statusTracker,
      logoutTracker: logoutTracker,
      startupObservationTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await processStates.close();
    promptTracker.dispose();
    await statusTracker.dispose();
    await logoutTracker.dispose();
  });

  test("persists On, respawns, and accepts a replacement prompt", () async {
    final List<String> order = <String>[];
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on),
    ).thenAnswer((_) async {
      order.add("persist");
    });
    when(() => processService.stop()).thenAnswer((_) async {
      order.add("stop");
    });
    final Completer<void> startGate = Completer<void>();
    when(() => processService.start()).thenAnswer((_) async {
      order.add("start");
      await startGate.future;
    });
    const ControlPromptRequest staleReplacementPrompt = ControlPromptRequest(
      id: "stale-replace",
      kind: ControlPromptKind.replaceBridge,
      message: "stale",
    );
    promptTracker.addPrompt(prompt: staleReplacementPrompt);
    const ControlPromptRequest loginPrompt = ControlPromptRequest(
      id: "login-1",
      kind: ControlPromptKind.loginNeeded,
      message: "login",
    );
    const ControlPromptRequest replacementPrompt = ControlPromptRequest(
      id: "replace-1",
      kind: ControlPromptKind.replaceBridge,
      message: "replace",
    );

    final Future<void> operation = orchestrator.takeOver();
    await pumpEventQueue(times: 2);
    promptTracker.addPrompt(prompt: loginPrompt);
    promptTracker.addPrompt(prompt: replacementPrompt);
    await pumpEventQueue(times: 2);
    startGate.complete();
    statusTracker.handleRegistered(bridgeId: "bridge-new", accountId: "account-a");
    await operation;

    expect(order, ["persist", "stop", "start"]);
    verify(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on),
    ).called(1);
    verify(() => processService.stop()).called(1);
    verify(() => processService.start()).called(1);
    expect(commandService.answeredPrompts, [replacementPrompt]);
  });

  test("accepts multiple fresh replacement prompts without stale answer attempts", () async {
    final Completer<void> startGate = Completer<void>();
    when(() => processService.start()).thenAnswer((_) => startGate.future);
    const ControlPromptRequest firstPrompt = ControlPromptRequest(
      id: "replace-1",
      kind: ControlPromptKind.replaceBridge,
      message: "replace first",
    );
    const ControlPromptRequest secondPrompt = ControlPromptRequest(
      id: "replace-2",
      kind: ControlPromptKind.replaceBridge,
      message: "replace second",
    );

    final Future<void> operation = orchestrator.takeOver();
    await pumpEventQueue(times: 2);
    promptTracker.addPrompt(prompt: firstPrompt);
    promptTracker.addPrompt(prompt: secondPrompt);
    await pumpEventQueue(times: 4);
    startGate.complete();
    statusTracker.handleRegistered(bridgeId: "bridge-new", accountId: "account-a");
    await operation;

    expect(commandService.answeredPrompts, [firstPrompt, secondPrompt]);
    expect(commandService.staleAnswerAttempts, 0);
  });

  test("ignores a replayed contention state while awaiting the fresh helper", () async {
    processStates.add(const BridgeProcessContention());
    final Completer<void> startGate = Completer<void>();
    when(() => processService.start()).thenAnswer((_) => startGate.future);
    const ControlPromptRequest replacementPrompt = ControlPromptRequest(
      id: "replace-fresh",
      kind: ControlPromptKind.replaceBridge,
      message: "replace",
    );

    final Future<void> operation = orchestrator.takeOver();
    await pumpEventQueue(times: 2);
    startGate.complete();
    await startGate.future;
    promptTracker.addPrompt(prompt: replacementPrompt);
    await pumpEventQueue(times: 2);
    statusTracker.handleRegistered(bridgeId: "bridge-new", accountId: "account-a");
    await operation;

    expect(commandService.answeredPrompts, [replacementPrompt]);
  });

  test("does not respawn when logout begins during the takeover stop", () async {
    final Completer<void> stopStarted = Completer<void>();
    final Completer<void> stopGate = Completer<void>();
    when(() => processService.stop()).thenAnswer((_) {
      stopStarted.complete();
      return stopGate.future;
    });

    final Future<void> operation = orchestrator.takeOver();
    await stopStarted.future;
    logoutTracker.markInProgress();
    stopGate.complete();
    await operation;

    verifyNever(() => processService.start());
  });

  test("settles when the fresh helper reaches local contention", () async {
    final Completer<void> startGate = Completer<void>();
    when(() => processService.start()).thenAnswer((_) async {
      await startGate.future;
      processStates.add(const BridgeProcessContention());
    });

    final Future<void> operation = orchestrator.takeOver();
    await pumpEventQueue(times: 2);
    startGate.complete();
    await operation;

    verify(() => processService.stop()).called(1);
    verify(() => processService.start()).called(1);
  });

  test("coalesces concurrent takeover calls into one lifecycle operation", () async {
    final Completer<void> stopGate = Completer<void>();
    when(() => processService.stop()).thenAnswer((_) => stopGate.future);

    final Future<void> first = orchestrator.takeOver();
    final Future<void> second = orchestrator.takeOver();
    expect(identical(first, second), isTrue);

    stopGate.complete();
    await pumpEventQueue(times: 3);
    statusTracker.handleRegistered(bridgeId: "bridge-new", accountId: "account-a");
    await first;

    verify(() => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).called(1);
    verify(() => processService.stop()).called(1);
    verify(() => processService.start()).called(1);
  });

  test("does not stop the current helper when desired-state persistence fails", () async {
    final StateError failure = StateError("read-only application support");
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on),
    ).thenThrow(failure);

    await expectLater(orchestrator.takeOver(), throwsA(same(failure)));

    verifyNever(() => processService.stop());
    verifyNever(() => processService.start());
  });

  test("surfaces a respawn failure after persisting On and stopping", () async {
    final StateError failure = StateError("helper could not start");
    when(() => processService.start()).thenThrow(failure);

    await expectLater(orchestrator.takeOver(), throwsA(same(failure)));

    verify(() => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).called(1);
    verify(() => processService.stop()).called(1);
  });
}

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;

class _FakeControlCommandService({required BridgePromptTracker promptTracker}) implements ControlCommandService {
  final BridgePromptTracker _promptTracker = promptTracker;
  final List<ControlPromptRequest> answeredPrompts = <ControlPromptRequest>[];
  int staleAnswerAttempts = 0;

  @override
  void answerPrompt({required ControlPromptRequest prompt, required bool accepted}) {
    if (!_promptTracker.prompts.any((pending) => identical(pending, prompt))) {
      staleAnswerAttempts++;
      throw ControlPromptNotPendingException(id: prompt.id);
    }
    if (accepted) {
      answeredPrompts.add(prompt);
    }
    _promptTracker.removePrompt(id: prompt.id);
  }

  @override
  void unregisterAndExit() {}
}
