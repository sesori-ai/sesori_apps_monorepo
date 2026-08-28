import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockBridgeProcessService processService;
  late _MockAuthSession authSession;
  late DesktopLogoutOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    authSession = _MockAuthSession();
    orchestrator = DesktopLogoutOrchestrator(
      processService: processService,
      authSession: authSession,
    );
  });

  test("stops the supervised helper before clearing the local session", () async {
    final List<String> operations = <String>[];
    when(() => processService.stop()).thenAnswer((_) async => operations.add("stop"));
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["stop", "logout"]);
  });

  test("does not clear authentication when the helper cannot stop", () async {
    when(() => processService.stop()).thenThrow(StateError("helper remained alive"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.bridgeStopFailed);
    verifyNever(() => authSession.logoutCurrentDevice());
  });

  test("reports a local-session failure after a successful helper stop", () async {
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("secure storage unavailable"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.localSessionClearFailed);
    verify(() => processService.stop()).called(1);
  });
}

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockAuthSession() extends Mock implements AuthSession;
