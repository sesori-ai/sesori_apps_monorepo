import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockDesktopInstanceService instanceService;
  late _MockBridgeProcessService processService;
  late DesktopStartupOrchestrator orchestrator;

  setUp(() {
    instanceService = _MockDesktopInstanceService();
    processService = _MockBridgeProcessService();
    orchestrator = DesktopStartupOrchestrator(
      instanceService: instanceService,
      processService: processService,
    );
  });

  test("returns the instance service's launch ownership decision", () async {
    when(() => instanceService.claimLaunch()).thenAnswer(
      (_) async => DesktopInstanceLaunchDisposition.secondaryActivated,
    );

    expect(await orchestrator.claimLaunch(), DesktopInstanceLaunchDisposition.secondaryActivated);
  });

  test("restores a persisted desired On through the process service", () async {
    when(() => instanceService.readBridgeDesiredState()).thenAnswer((_) async => BridgeProcessDesiredState.on);
    when(() => processService.start()).thenAnswer((_) async {});

    await orchestrator.restoreBridgeDesiredState();

    verify(() => processService.start()).called(1);
  });

  test("persisted desired Off performs no bridge lifecycle work", () async {
    when(() => instanceService.readBridgeDesiredState()).thenAnswer((_) async => BridgeProcessDesiredState.off);

    await orchestrator.restoreBridgeDesiredState();

    verifyNever(() => processService.start());
  });

  test("a state-read failure leaves startup usable and performs no spawn", () async {
    when(() => instanceService.readBridgeDesiredState()).thenThrow(const FileSystemException("unavailable"));

    await orchestrator.restoreBridgeDesiredState();

    verifyNever(() => processService.start());
  });
}

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;
