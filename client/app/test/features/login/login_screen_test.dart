import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/login/login_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

class RecordingNavigatorObserver extends NavigatorObserver {
  bool poppedPopupRoute = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<void>) poppedPopupRoute = true;
    super.didPop(route, previousRoute);
  }
}

class MockAuthSession extends Mock implements AuthSession {
  final BehaviorSubject<AuthState> _authState = BehaviorSubject.seeded(const AuthState.unauthenticated());

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;

  @override
  Future<AuthUser> loginWithEmail({required String email, required String password}) async => const AuthUser(
    id: "user-1",
    provider: AuthProvider.email,
    providerUserId: "alex@example.com",
    providerUsername: null,
  );
}

void main() {
  late MockOAuthFlowProvider mockOAuthFlowProvider;
  late MockUrlLauncher mockUrlLauncher;
  late MockAuthSession mockAuthSession;
  late MockLifecycleSource mockLifecycleSource;

  setUpAll(() {
    registerFallbackValue(AuthProvider.github);
  });

  setUp(() {
    mockOAuthFlowProvider = MockOAuthFlowProvider();
    mockUrlLauncher = MockUrlLauncher();
    mockAuthSession = MockAuthSession();
    mockLifecycleSource = MockLifecycleSource();

    final getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingleton<OAuthFlowProvider>(mockOAuthFlowProvider);
    getIt.registerSingleton<UrlLauncher>(mockUrlLauncher);
    getIt.registerSingleton<AuthSession>(mockAuthSession);
    getIt.registerSingleton<LifecycleSource>(mockLifecycleSource);

    when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer(
      (_) => BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed).stream,
    );

    when(() => mockAuthSession.getCurrentUser()).thenAnswer((_) async => null);
    when(() => mockAuthSession.restoreSession()).thenAnswer((_) async => false);
    when(() => mockAuthSession.logoutCurrentDevice()).thenAnswer((_) async {});
    when(() => mockAuthSession.invalidateAllSessions()).thenAnswer((_) async {});
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets("email success commits autofill before navigating", (tester) async {
    final observer = RecordingNavigatorObserver();
    final router = GoRouter(
      initialLocation: "/login",
      observers: [observer],
      routes: [
        GoRoute(path: "/login", builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: "/projects",
          builder: (_, _) => const Scaffold(body: Text("Projects")),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text("Sign in with Email"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, "alex@example.com");
    await tester.enterText(find.byType(TextFormField).last, "hunter2");
    await tester.tap(find.text("Sign in"));
    await tester.pumpAndSettle();

    expect(find.text("Projects"), findsOneWidget);
    expect(observer.poppedPopupRoute, isTrue);
  });
}
