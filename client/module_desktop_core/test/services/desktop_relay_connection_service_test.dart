import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockAuthSession() extends Mock implements AuthSession;

class _MockConnectionService() extends Mock implements ConnectionService;

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockAuthSession authSession;
  late _MockConnectionService connectionService;
  late DesktopRelayConnectionService service;

  setUp(() {
    authSession = _MockAuthSession();
    connectionService = _MockConnectionService();
    service = DesktopRelayConnectionService(
      authSession: authSession,
      connectionService: connectionService,
    );
    when(() => connectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
  });

  test("connects for a fully authenticated destination", () async {
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _user));

    await service.connectForAuthenticatedDestination();

    verify(() => connectionService.connectWithFreshAuthToken()).called(1);
    verifyNever(() => authSession.hasLocallyValidSession());
  });

  test("connects for a token-only destination with locally valid tokens", () async {
    when(() => authSession.currentState).thenReturn(const AuthState.initial());
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);

    await service.connectForAuthenticatedDestination();

    verify(() => authSession.hasLocallyValidSession()).called(1);
    verify(() => connectionService.connectWithFreshAuthToken()).called(1);
  });

  test("does not connect for an initial state without locally valid tokens", () async {
    when(() => authSession.currentState).thenReturn(const AuthState.initial());
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);

    await service.connectForAuthenticatedDestination();

    verifyNever(() => connectionService.connectWithFreshAuthToken());
  });

  test("a failed provisional-session check stays disconnected", () async {
    when(() => authSession.currentState).thenReturn(const AuthState.initial());
    when(() => authSession.hasLocallyValidSession()).thenThrow(StateError("storage unavailable"));

    await service.connectForAuthenticatedDestination();

    verifyNever(() => connectionService.connectWithFreshAuthToken());
  });

  test("does not connect after the auth session becomes unauthenticated", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    var stateReads = 0;
    when(() => authSession.currentState).thenAnswer((_) {
      stateReads++;
      return stateReads == 1 ? const AuthState.initial() : const AuthState.unauthenticated();
    });

    await service.connectForAuthenticatedDestination();

    verifyNever(() => connectionService.connectWithFreshAuthToken());
  });
}
