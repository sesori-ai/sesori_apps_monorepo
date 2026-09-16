import "dart:async";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockDesktopInstanceService instanceService;
  late _MockBridgeProcessService processService;
  late _MockDesktopApplicationTerminator applicationTerminator;
  late _MockWindowBoundsService windowBoundsService;
  late DesktopStartupOrchestrator orchestrator;
  late _MockAuthSession authSession;
  late _MockLaunchAtLogin launchAtLogin;
  late StreamController<AuthState> authChanges;
  late AuthState authState;
  const signedIn = AuthState.authenticated(
    user: AuthUser(id: "user", provider: AuthProvider.github, providerUserId: "provider", providerUsername: "test"),
  );

  setUp(() {
    instanceService = _MockDesktopInstanceService();
    processService = _MockBridgeProcessService();
    applicationTerminator = _MockDesktopApplicationTerminator();
    windowBoundsService = _MockWindowBoundsService();
    authSession = _MockAuthSession();
    launchAtLogin = _MockLaunchAtLogin();
    authChanges = StreamController<AuthState>.broadcast(sync: true);
    authState = const AuthState.unauthenticated();
    when(() => authSession.currentState).thenAnswer((_) => authState);
    when(() => authSession.authStateStream).thenAnswer((_) => authChanges.stream);
    when(launchAtLogin.enable).thenAnswer((_) async {});
    when(processService.start).thenAnswer((_) async {});
    when(instanceService.initializeFirstRunBridgeState).thenAnswer((_) async => true);
    orchestrator = DesktopStartupOrchestrator(
      instanceService: instanceService,
      processService: processService,
      applicationTerminator: applicationTerminator,
      windowBoundsService: windowBoundsService,
      authSession: authSession,
      launchAtLogin: launchAtLogin,
    );
  });

  tearDown(() async {
    await orchestrator.dispose();
    await authChanges.close();
  });

  test("signed out does nothing; later sign-in applies first-run defaults", () async {
    await orchestrator.applyFirstRunBridgeDefaults();
    verifyNever(instanceService.initializeFirstRunBridgeState);
    authState = signedIn;
    authChanges.add(authState);
    await Future<void>.delayed(Duration.zero);
    verify(instanceService.initializeFirstRunBridgeState).called(1);
    verify(processService.start).called(1);
    verify(launchAtLogin.enable).called(1);
  });

  test("a retained preference or canceled default does no lifecycle or native work", () async {
    authState = signedIn;
    when(instanceService.initializeFirstRunBridgeState).thenAnswer((_) async => false);
    await orchestrator.applyFirstRunBridgeDefaults();
    verifyNever(processService.start);
    verifyNever(launchAtLogin.enable);
  });

  test("native enable failure still leaves the first-run bridge starting", () async {
    authState = signedIn;
    when(launchAtLogin.enable).thenThrow(StateError("native unavailable"));
    await orchestrator.applyFirstRunBridgeDefaults();
    verify(processService.start).called(1);
  });

  test("persistence failure performs no spawn or native registration", () async {
    authState = signedIn;
    when(instanceService.initializeFirstRunBridgeState).thenThrow(StateError("disk"));
    await orchestrator.applyFirstRunBridgeDefaults();
    verifyNever(processService.start);
    verifyNever(launchAtLogin.enable);
  });

  for (final dispose in [false, true]) {
    test("pending default does not start after ${dispose ? 'disposal' : 'sign-out'}", () async {
      authState = signedIn;
      final persisted = Completer<bool>();
      when(instanceService.initializeFirstRunBridgeState).thenAnswer((_) => persisted.future);
      final operation = orchestrator.applyFirstRunBridgeDefaults();
      if (dispose) {
        await orchestrator.dispose();
      } else {
        authState = const AuthState.unauthenticated();
        authChanges.add(authState);
      }
      persisted.complete(true);
      await operation;
      verifyNever(processService.start);
      verifyNever(launchAtLogin.enable);
    });
  }

  test("native enable completion cannot initiate a late bridge start", () async {
    authState = signedIn;
    final enabled = Completer<void>();
    when(launchAtLogin.enable).thenAnswer((_) => enabled.future);
    final operation = orchestrator.applyFirstRunBridgeDefaults();
    await Future<void>.delayed(Duration.zero);
    verify(processService.start).called(1);
    authState = const AuthState.unauthenticated();
    enabled.complete();
    await operation;
    verifyNever(processService.start);
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

  test("initializes the persisted native window through the bounds service", () async {
    when(() => windowBoundsService.initializeWindow(hidden: true)).thenAnswer((_) async {});

    await orchestrator.initializeWindow(hidden: true);

    verify(() => windowBoundsService.initializeWindow(hidden: true)).called(1);
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

class _MockWindowBoundsService() extends Mock implements WindowBoundsService;
class _MockAuthSession() extends Mock implements AuthSession;
class _MockLaunchAtLogin() extends Mock implements LaunchAtLogin;
