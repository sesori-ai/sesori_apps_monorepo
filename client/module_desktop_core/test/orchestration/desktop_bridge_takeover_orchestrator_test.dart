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
  late BehaviorSubject<BridgeProcessState> processStates;
  late DesktopBridgeTakeoverOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    commandService = _FakeControlCommandService();
    instanceService = _MockDesktopInstanceService();
    promptTracker = BridgePromptTracker();
    statusTracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage());
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
      startupObservationTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await processStates.close();
    promptTracker.dispose();
    await statusTracker.dispose();
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

class _FakeControlCommandService() implements ControlCommandService {
  final List<ControlPromptRequest> answeredPrompts = <ControlPromptRequest>[];

  @override
  void answerPrompt({required ControlPromptRequest prompt, required bool accepted}) {
    if (accepted) {
      answeredPrompts.add(prompt);
    }
  }

  @override
  void unregisterAndExit() {}
}
