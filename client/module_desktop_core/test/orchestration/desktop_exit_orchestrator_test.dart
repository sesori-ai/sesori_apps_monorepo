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
    when(() => updateService.applyDownloadedUpdate(restart: any(named: "restart"))).thenAnswer((_) async {});
    orchestrator = DesktopExitOrchestrator(processService: processService, updateService: updateService);
  });

  test("quit stops the helper, then applies a downloaded update without restarting", () async {
    await orchestrator.prepareExit(intent: DesktopExitIntent.quit);
    verifyInOrder([() => processService.stop(), () => updateService.applyDownloadedUpdate(restart: false)]);
    verifyNever(() => updateService.prepareRestartToUpdate());
  });

  test("restart to update relaunches a package before the helper stops and applies a download after", () async {
    await orchestrator.prepareExit(intent: DesktopExitIntent.restartToUpdate);
    verifyInOrder([
      () => updateService.prepareRestartToUpdate(),
      () => processService.stop(),
      () => updateService.applyDownloadedUpdate(restart: true),
    ]);
    verifyNever(() => processService.start());
  });

  test("a quit whose updater fails to start still exits", () async {
    when(() => updateService.applyDownloadedUpdate(restart: false)).thenThrow(StateError("updater missing"));
    await orchestrator.prepareExit(intent: DesktopExitIntent.quit);
    verifyNever(() => processService.start());
  });

  test("a restart whose updater fails to start restores the helper and reports the failure", () async {
    when(() => updateService.applyDownloadedUpdate(restart: true)).thenThrow(StateError("updater missing"));
    await expectLater(
      orchestrator.prepareExit(intent: DesktopExitIntent.restartToUpdate),
      throwsA(isA<StateError>()),
    );
    verify(() => processService.start()).called(1);
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
    verifyNever(() => updateService.applyDownloadedUpdate(restart: any(named: "restart")));
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
