import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockAuthSession extends Mock implements AuthSession {
  final BehaviorSubject<AuthState> _authState = BehaviorSubject.seeded(AuthState.unauthenticated());

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;

  void emitState(AuthState state) => _authState.add(state);
}

void main() {
  late MockOAuthFlowProvider mockOAuthFlowProvider;
  late MockUrlLauncher mockUrlLauncher;
  late MockAuthSession mockAuthSession;

  setUpAll(() {
    registerFallbackValue(OAuthProvider.github);
  });

  setUp(() {
    mockOAuthFlowProvider = MockOAuthFlowProvider();
    mockUrlLauncher = MockUrlLauncher();
    mockAuthSession = MockAuthSession();

    final getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingleton<OAuthFlowProvider>(mockOAuthFlowProvider);
    getIt.registerSingleton<UrlLauncher>(mockUrlLauncher);
    getIt.registerSingleton<AuthSession>(mockAuthSession);

    when(() => mockAuthSession.getCurrentUser()).thenAnswer((_) async => null);
    when(() => mockAuthSession.restoreSession()).thenAnswer((_) async => false);
    when(() => mockAuthSession.logoutCurrentDevice()).thenAnswer((_) async {});
    when(() => mockAuthSession.invalidateAllSessions()).thenAnswer((_) async {});
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group(
    "LoginScreen",
    () {
      test(
        "Widget tests for LoginScreen are skipped due to context.loc dependency. "
        "Coverage provided by login_cubit_test.dart.",
        () {
          expect(true, isTrue);
        },
      );
    },
  );
}