import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockBridgeProcessService processService;
  late _MockDesktopUpdateService updateService;
  late DesktopExitOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    updateService = _MockDesktopUpdateService();
    when(() => processService.desiredState).thenReturn(BridgeProcessDesiredState.on);
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => processService.start()).thenAnswer((_) async {});
    when(() => updateService.prepareRestartToUpdate()).thenAnswer((_) async {});
    orchestrator = DesktopExitOrchestrator(processService: processService, updateService: updateService);
  });

  test("quit only stops the helper", () async {
    await orchestrator.prepareExit(intent: DesktopExitIntent.quit);
    verify(() => processService.stop()).called(1);
    verifyNever(() => updateService.prepareRestartToUpdate());
  });

  test("restart to update starts the new desktop before stopping the helper", () async {
    await orchestrator.prepareExit(intent: DesktopExitIntent.restartToUpdate);
    verifyInOrder([() => updateService.prepareRestartToUpdate(), () => processService.stop()]);
    verifyNever(() => processService.start());
  });

  test("a failed update step leaves the running helper untouched and reports the failure", () async {
    when(() => updateService.prepareRestartToUpdate()).thenThrow(const ProcessException("sesori-desktop", []));
    await expectLater(
      orchestrator.prepareExit(intent: DesktopExitIntent.restartToUpdate),
      throwsA(isA<ProcessException>()),
    );
    verifyNever(() => processService.stop());
    verifyNever(() => processService.start());
  });

  test("a failed stop restores a helper that was on and reports the failure", () async {
    when(() => processService.stop()).thenThrow(StateError("stop failed"));
    await expectLater(orchestrator.prepareExit(intent: DesktopExitIntent.quit), throwsA(isA<StateError>()));
    verifyNever(() => updateService.prepareRestartToUpdate());
    verify(() => processService.start()).called(1);
  });

  test("a failed stop leaves a helper that was off stopped", () async {
    when(() => processService.desiredState).thenReturn(BridgeProcessDesiredState.off);
    when(() => processService.stop()).thenThrow(StateError("stop failed"));
    await expectLater(orchestrator.prepareExit(intent: DesktopExitIntent.quit), throwsA(isA<StateError>()));
    verifyNever(() => processService.start());
  });
}

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockDesktopUpdateService() extends Mock implements DesktopUpdateService;
