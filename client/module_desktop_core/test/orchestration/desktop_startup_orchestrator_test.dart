import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockDesktopInstanceService instanceService;
  late _MockBridgeProcessService processService;
  late _MockDesktopApplicationTerminator applicationTerminator;
  late DesktopStartupOrchestrator orchestrator;

  setUp(() {
    instanceService = _MockDesktopInstanceService();
    processService = _MockBridgeProcessService();
    applicationTerminator = _MockDesktopApplicationTerminator();
    orchestrator = DesktopStartupOrchestrator(
      instanceService: instanceService,
      processService: processService,
      applicationTerminator: applicationTerminator,
    );
  });

  test("lets only the primary launch continue to UI construction", () async {
    when(() => instanceService.claimLaunch()).thenAnswer((_) async => DesktopInstanceLaunchDisposition.primary);

    expect(await orchestrator.preparePrimaryLaunch(), isTrue);
    verifyNever(() => applicationTerminator.terminate(exitCode: any(named: "exitCode")));
  });

  test("terminates a secondary launch before UI construction", () async {
    when(() => instanceService.claimLaunch()).thenAnswer(
      (_) async => DesktopInstanceLaunchDisposition.secondaryActivated,
    );
    expect(await orchestrator.preparePrimaryLaunch(), isFalse);
    verify(() => applicationTerminator.terminate(exitCode: 0)).called(1);
  });

  test("restores a persisted desired On through the process service", () async {
    when(
      () => instanceService.readBridgeDesiredStateForRestore(),
    ).thenAnswer((_) async => BridgeProcessDesiredState.on);
    when(() => processService.start()).thenAnswer((_) async {});

    await orchestrator.restoreBridgeDesiredState();

    verify(() => processService.start()).called(1);
  });

  test("persisted desired Off performs no bridge lifecycle work", () async {
    when(
      () => instanceService.readBridgeDesiredStateForRestore(),
    ).thenAnswer((_) async => BridgeProcessDesiredState.off);

    await orchestrator.restoreBridgeDesiredState();

    verifyNever(() => processService.start());
  });

  test("a canceled stale state read performs no bridge lifecycle work", () async {
    when(() => instanceService.readBridgeDesiredStateForRestore()).thenAnswer((_) async => null);

    await orchestrator.restoreBridgeDesiredState();

    verifyNever(() => processService.start());
  });

  test("a state-read failure leaves startup usable and performs no spawn", () async {
    when(
      () => instanceService.readBridgeDesiredStateForRestore(),
    ).thenThrow(const FileSystemException("unavailable"));

    await orchestrator.restoreBridgeDesiredState();

    verifyNever(() => processService.start());
  });
}

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockDesktopApplicationTerminator() extends Mock implements DesktopApplicationTerminator;
