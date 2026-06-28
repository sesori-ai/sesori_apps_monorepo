import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:http/http.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart" show AuthSession, OAuthFlowProvider;
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_failed_reason.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockAuthSession extends Mock implements AuthSession {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

const testAuthInitResponse = AuthInitResponse(
  authUrl: "https://accounts.google.com/o/oauth2/auth",
  state: "oauth-state",
  expiresIn: 300,
);

const testAuthUser = AuthUser(
  id: "id",
  provider: AuthProvider.google,
  providerUserId: "user123",
  providerUsername: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProvider.google);
    registerFallbackValue(Uri.parse(redirectUri));
    registerFallbackValue(testAuthUser);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;
    late MockAuthSession mockAuthSession;
    late MockLifecycleSource mockLifecycleSource;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();
      mockAuthSession = MockAuthSession();
      mockLifecycleSource = MockLifecycleSource();
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
      when(
        () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
      ).thenAnswer((_) async => testAuthInitResponse);
      when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async => testAuthUser);
      when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => false);
      when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthUser);
      when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer(
        (_) => BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed).stream,
      );
    });

    LoginCubit buildCubit() => LoginCubit(
      mockOAuthFlowProvider,
      mockUrlLauncher,
      mockAuthSession,
      mockLifecycleSource,
    );

    test("initial state is LoginState.idle", () {
      final cubit = buildCubit();
      expect(cubit.state, isA<LoginIdle>());
    });

    group("Google OAuth", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) starts OAuth flow with AuthProvider.google",
        build: buildCubit,
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(
            () => mockOAuthFlowProvider.startOAuthFlow(provider: AuthProvider.google),
          ).called(1);
          verify(() => mockOAuthFlowProvider.pollForResult()).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits polling then success",
        build: buildCubit,
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockUrlLauncher.launch(Uri.parse(testAuthInitResponse.authUrl))).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits the polling OAuth sequence without legacy callback state",
        build: buildCubit,
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits failed when startOAuthFlow throws",
        build: buildCubit,
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
          ).thenThrow(Exception("network error"));
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits failed when browser launch returns false",
        build: buildCubit,
        act: (cubit) async {
          when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>(),
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockOAuthFlowProvider.pollForResult());
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits timeout when polling times out",
        build: buildCubit,
        act: (cubit) async {
          when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>(),
          isA<LoginTimeout>(),
        ],
      );

      group("background interruption", () {
        test("parks interrupted background poll in LoginPolling instead of LoginFailed", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.paused);
            await Future<void>.delayed(Duration.zero);
            throw ClientException("Software caused connection abort");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginPolling>());
          expect(states, contains(isA<LoginPolling>()));
          expect(states, isNot(contains(isA<LoginFailed>())));
        });

        test("retries late poll abort after app already resumed and completes login", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => true);
          when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthUser);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.paused);
            await Future<void>.delayed(Duration.zero);
            lifecycleSubject.add(LifecycleState.resumed);
            await Future<void>.delayed(Duration.zero);
            throw ClientException("Software caused connection abort");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);
          // The abort settled after the app already returned to the foreground;
          // recovery must be kicked immediately rather than waiting for a
          // resume event that will never arrive. Pump the retry microtask.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginSuccess>());
          expect(states, isNot(contains(isA<LoginFailed>())));
          verify(() => mockOAuthFlowProvider.resumeOAuthFlow()).called(1);
        });

        test("parks poll abort when app was already backgrounded before polling starts", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(
            ClientException("Software caused connection abort"),
          );

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginPolling>());
          expect(states, contains(isA<LoginPolling>()));
          expect(states, isNot(contains(isA<LoginFailed>())));
        });

        test("background poll timeout emits LoginTimeout instead of parking", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginTimeout>());
          expect(states, contains(isA<LoginTimeout>()));
          expect(states, isNot(contains(isA<LoginFailed>())));
        });

        test("parks poll abort during inactive lifecycle transition", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.inactive);
            await Future<void>.delayed(Duration.zero);
            throw ClientException("Software caused connection abort");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginPolling>());
          expect(states, contains(isA<LoginPolling>()));
          expect(states, isNot(contains(isA<LoginFailed>())));
        });

        test("resume after background-interrupted poll completes login", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.paused);
            await Future<void>.delayed(Duration.zero);
            throw ClientException("Software caused connection abort");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);
          expect(cubit.state, isA<LoginPolling>());

          when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => true);
          when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthUser);

          lifecycleSubject.add(LifecycleState.resumed);
          await Future<void>.delayed(Duration.zero);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginSuccess>());
          expect(states, contains(isA<LoginSuccess>()));
          verify(() => mockOAuthFlowProvider.resumeOAuthFlow()).called(1);
        });

        blocTest<LoginCubit, LoginState>(
          "foreground poll error still fails",
          build: buildCubit,
          act: (cubit) async {
            when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(StateError("poll failed"));
            await cubit.loginWithProvider(AuthProvider.google);
          },
          expect: () => [
            isA<LoginAuthenticating>(),
            isA<LoginPolling>(),
            isA<LoginFailed>().having(
              (state) => state.reason,
              "reason",
              LoginFailedReason.unknown,
            ),
          ],
        );

        test("background terminal poll error still fails", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.paused);
            await Future<void>.delayed(Duration.zero);
            throw StateError("OAuth authorization was denied");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginFailed>());
          expect(states, contains(isA<LoginFailed>()));
        });

        test("resume with expired session resets interrupted poll to LoginIdle", () async {
          final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
          when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
          when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
            lifecycleSubject.add(LifecycleState.paused);
            await Future<void>.delayed(Duration.zero);
            throw ClientException("Software caused connection abort");
          });

          final cubit = buildCubit();
          final states = <LoginState>[];
          final sub = cubit.stream.listen(states.add);

          await cubit.loginWithProvider(AuthProvider.google);
          expect(cubit.state, isA<LoginPolling>());

          when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => false);

          lifecycleSubject.add(LifecycleState.resumed);
          await Future<void>.delayed(Duration.zero);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginIdle>());
          expect(states, contains(isA<LoginIdle>()));
          verifyNever(() => mockOAuthFlowProvider.resumeOAuthFlow());
        });
      });
    });

    group("Lifecycle resume", () {
      test("resumes polling when app resumes and active OAuth session exists", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => true);

        final cubit = buildCubit();
        // Park the flow in a resumable state (e.g. a prior timeout) before resume.
        cubit.emit(const LoginState.timeout());

        final states = <LoginState>[];
        final sub = cubit.stream.listen(states.add);

        lifecycleSubject.add(LifecycleState.resumed);

        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        await sub.cancel();

        expect(states, [
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ]);
        verify(() => mockOAuthFlowProvider.resumeOAuthFlow()).called(1);
      });

      test("does not resume polling when app resumes but no active session", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => false);

        final cubit = buildCubit();
        // A resumable, non-polling state (timeout) must not auto-reset to idle.
        cubit.emit(const LoginState.timeout());

        final states = <LoginState>[];
        final sub = cubit.stream.listen(states.add);

        lifecycleSubject.add(LifecycleState.resumed);

        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        await sub.cancel();

        expect(states, isEmpty);
        verifyNever(() => mockOAuthFlowProvider.resumeOAuthFlow());
      });

      test("does not resume polling when state is idle", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => true);

        final cubit = buildCubit();

        final states = <LoginState>[];
        final sub = cubit.stream.listen(states.add);

        lifecycleSubject.add(LifecycleState.resumed);

        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        await sub.cancel();

        expect(states, isEmpty);
        verifyNever(() => mockOAuthFlowProvider.resumeOAuthFlow());
      });
    });

    group("Email Login", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithEmail calls AuthSession.loginWithEmail with correct email/password",
        build: buildCubit,
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail(email: "test@example.com", password: "password123")).thenAnswer(
            (_) async => testAuthUser,
          );
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockAuthSession.loginWithEmail(email: "test@example.com", password: "password123")).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail emits loading then success state on successful login",
        build: buildCubit,
        act: (cubit) async {
          when(
            () => mockAuthSession.loginWithEmail(
              email: any(named: "email"),
              password: any(named: "password"),
            ),
          ).thenAnswer(
            (_) async => testAuthUser,
          );
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginSuccess>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail emits failed state on 401 error",
        build: buildCubit,
        act: (cubit) async {
          when(
            () => mockAuthSession.loginWithEmail(
              email: any(named: "email"),
              password: any(named: "password"),
            ),
          ).thenThrow(Exception("Invalid email or password"));
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "wrongpassword",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail shows validation error for empty email",
        build: buildCubit,
        act: (cubit) async {
          await cubit.loginWithEmail(
            email: "",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(
            () => mockAuthSession.loginWithEmail(
              email: any(named: "email"),
              password: any(named: "password"),
            ),
          );
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail shows validation error for empty password",
        build: buildCubit,
        act: (cubit) async {
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "",
          );
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(
            () => mockAuthSession.loginWithEmail(
              email: any(named: "email"),
              password: any(named: "password"),
            ),
          );
        },
      );
    });
  });
}
