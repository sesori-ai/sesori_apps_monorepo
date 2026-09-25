import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:http/http.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart"
    show AuthLoginResult, OAuthFlowDenied, OAuthFlowExpired, OAuthFlowProvider, OAuthHandoff;
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_failed_reason.dart";
import "package:sesori_dart_core/src/cubits/login/login_handoff.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/services/installation_analytics_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockOAuthFlowProvider() extends Mock implements OAuthFlowProvider;

class MockUrlLauncher() extends Mock implements UrlLauncher;

class MockLifecycleSource() extends Mock implements LifecycleSource;

class MockInstallationAnalyticsService() extends Mock implements InstallationAnalyticsService;

final testHandoff = OAuthHandoff(
  authUrl: Uri.parse("https://accounts.google.com/o/oauth2/auth"),
  expiresAt: DateTime(2026, 9, 25, 12, 5),
  deviceName: "Test Mac",
);

const testAuthUser = AuthUser(
  id: "id",
  provider: AuthProvider.google,
  providerUserId: "user123",
  providerUsername: null,
);
const testAuthLoginResult = AuthLoginResult(user: testAuthUser, accountStatus: AccountStatus.existing);

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProvider.google);
    registerFallbackValue(LoginAttemptFailureCause.unknown);
    registerFallbackValue(Uri.parse(redirectUri));
    registerFallbackValue(testAuthUser);
    registerFallbackValue(AccountStatus.existing);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;
    late MockAuthSession mockAuthSession;
    late MockLifecycleSource mockLifecycleSource;
    late MockInstallationAnalyticsService mockInstallationAnalyticsService;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();
      mockAuthSession = MockAuthSession();
      mockLifecycleSource = MockLifecycleSource();
      mockInstallationAnalyticsService = MockInstallationAnalyticsService();
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
      when(
        () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
      ).thenAnswer((_) async => testHandoff);
      when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async => testAuthLoginResult);
      when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => false);
      when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthLoginResult);
      when(
        () => mockInstallationAnalyticsService.loginAttemptStarted(provider: any(named: "provider")),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(
        () => mockInstallationAnalyticsService.loginAttemptCompleted(
          provider: any(named: "provider"),
          accountStatus: any(named: "accountStatus"),
        ),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(
        () => mockInstallationAnalyticsService.loginAttemptFailed(
          provider: any(named: "provider"),
          cause: any(named: "cause"),
        ),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer(
        (_) => BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed).stream,
      );
    });

    LoginCubit buildCubit() => LoginCubit(
      oAuthFlowProvider: mockOAuthFlowProvider,
      urlLauncher: mockUrlLauncher,
      authSession: mockAuthSession,
      lifecycleSource: mockLifecycleSource,
      installationAnalyticsService: mockInstallationAnalyticsService,
    );

    test("initial state is LoginState.idle", () {
      final cubit = buildCubit();
      expect(cubit.state, isA<LoginIdle>());
    });

    group("Google OAuth", () {
      test("reports one started and one completed installation outcome", () async {
        final cubit = buildCubit();

        await cubit.loginWithProvider(AuthProvider.google);

        verify(
          () => mockInstallationAnalyticsService.loginAttemptStarted(provider: AuthProvider.google),
        ).called(1);
        verify(
          () => mockInstallationAnalyticsService.loginAttemptCompleted(
            provider: AuthProvider.google,
            accountStatus: AccountStatus.existing,
          ),
        ).called(1);
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: any(named: "provider"),
            cause: any(named: "cause"),
          ),
        );
        await cubit.close();
      });

      test("reports timeout once as the terminal installation outcome", () async {
        when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));
        final cubit = buildCubit();

        await cubit.loginWithProvider(AuthProvider.google);

        verify(
          () => mockInstallationAnalyticsService.loginAttemptStarted(provider: AuthProvider.google),
        ).called(1);
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.google,
            cause: LoginAttemptFailureCause.timeout,
          ),
        ).called(1);
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptCompleted(
            provider: any(named: "provider"),
            accountStatus: any(named: "accountStatus"),
          ),
        );
        await cubit.close();
      });

      test("Apple native cancellation terminates its already-started attempt", () async {
        final cubit = buildCubit();

        final attempt = cubit.beginAppleLoginAttempt();
        expect(cubit.state, isA<LoginAuthenticating>());
        cubit.onAppleSignInCancelled(attempt: attempt);

        expect(cubit.state, isA<LoginIdle>());
        verify(
          () => mockInstallationAnalyticsService.loginAttemptStarted(provider: AuthProvider.apple),
        ).called(1);
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.apple,
            cause: LoginAttemptFailureCause.cancelled,
          ),
        ).called(1);
        await cubit.close();
      });

      test("Apple native errors use the platform-neutral unknown outcome", () async {
        final cubit = buildCubit();
        final attempt = cubit.beginAppleLoginAttempt();

        cubit.onAppleSignInError(attempt: attempt);

        expect(cubit.state, isA<LoginFailed>());
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.apple,
            cause: LoginAttemptFailureCause.unknown,
          ),
        ).called(1);
        await cubit.close();
      });

      test("a replacement terminates the displaced attempt and rejects its stale callbacks", () async {
        final authentication = Completer<AuthLoginResult>();
        when(
          () => mockAuthSession.loginWithApple(
            idToken: any(named: "idToken"),
            nonce: any(named: "nonce"),
          ),
        ).thenAnswer((_) => authentication.future);
        final cubit = buildCubit();
        final staleAttempt = cubit.beginAppleLoginAttempt();
        final staleLogin = cubit.loginWithApple(
          attempt: staleAttempt,
          idToken: "stale-token",
          nonce: "stale-nonce",
        );
        await untilCalled(
          () => mockAuthSession.loginWithApple(
            idToken: any(named: "idToken"),
            nonce: any(named: "nonce"),
          ),
        );

        cubit.beginAppleLoginAttempt();
        cubit.onAppleSignInError(attempt: staleAttempt);
        authentication.complete(testAuthLoginResult);

        expect(await staleLogin, isFalse);
        expect(cubit.state, isA<LoginAuthenticating>());
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptCompleted(
            provider: AuthProvider.apple,
            accountStatus: AccountStatus.existing,
          ),
        );
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.apple,
            cause: LoginAttemptFailureCause.unknown,
          ),
        ).called(1);
        await cubit.close();
      });

      test("starting Apple leaves a prior resumable OAuth timeout", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => true);
        final cubit = buildCubit();

        await cubit.loginWithProvider(AuthProvider.google);
        expect(cubit.state, isA<LoginTimeout>());

        cubit.beginAppleLoginAttempt();
        expect(cubit.state, isA<LoginAuthenticating>());
        lifecycleSubject
          ..add(LifecycleState.paused)
          ..add(LifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockOAuthFlowProvider.resumeOAuthFlow());
        await cubit.close();
        await lifecycleSubject.close();
      });

      test("starting Apple invalidates a pending OAuth resume check", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
        final activeSessionCheck = Completer<bool>();
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));
        when(
          () => mockOAuthFlowProvider.hasActiveOAuthSession(),
        ).thenAnswer((_) => activeSessionCheck.future);
        final cubit = buildCubit();

        await cubit.loginWithProvider(AuthProvider.google);
        expect(cubit.state, isA<LoginTimeout>());

        lifecycleSubject
          ..add(LifecycleState.paused)
          ..add(LifecycleState.resumed);
        await untilCalled(() => mockOAuthFlowProvider.hasActiveOAuthSession());

        cubit.beginAppleLoginAttempt();
        activeSessionCheck.complete(true);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<LoginAuthenticating>());
        verifyNever(() => mockOAuthFlowProvider.resumeOAuthFlow());
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptCompleted(
            provider: AuthProvider.apple,
            accountStatus: AccountStatus.existing,
          ),
        );
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.apple,
            cause: any(named: "cause"),
          ),
        );
        await cubit.close();
        await lifecycleSubject.close();
      });

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) starts OAuth flow with AuthProvider.google",
        build: buildCubit,
        act: (cubit) async => await cubit.loginWithProvider(AuthProvider.google),
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
        "loginWithProvider(AuthProvider.google) keeps polling when browser launch returns false",
        build: buildCubit,
        act: (cubit) async {
          when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginPolling>().having((state) => state.handoff.browser, "browser", LoginBrowserLaunch.opened),
          isA<LoginPolling>().having((state) => state.handoff.browser, "browser", LoginBrowserLaunch.failed),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockOAuthFlowProvider.pollForResult()).called(1);
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
          when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthLoginResult);
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
          when(() => mockOAuthFlowProvider.resumeOAuthFlow()).thenAnswer((_) async => testAuthLoginResult);

          lifecycleSubject.add(LifecycleState.resumed);
          await Future<void>.delayed(Duration.zero);

          await cubit.close();
          await sub.cancel();
          await lifecycleSubject.close();

          expect(cubit.state, isA<LoginSuccess>());
          expect(states, contains(isA<LoginSuccess>()));
          for (final polling in states.whereType<LoginPolling>()) {
            expect(polling.handoff.oauth, same(testHandoff));
          }
          verify(() => mockOAuthFlowProvider.resumeOAuthFlow()).called(1);
          verify(
            () => mockInstallationAnalyticsService.loginAttemptStarted(provider: AuthProvider.google),
          ).called(1);
          verify(
            () => mockInstallationAnalyticsService.loginAttemptCompleted(
              provider: AuthProvider.google,
              accountStatus: AccountStatus.existing,
            ),
          ).called(1);
          verifyNever(
            () => mockInstallationAnalyticsService.loginAttemptFailed(
              provider: any(named: "provider"),
              cause: any(named: "cause"),
            ),
          );
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
        when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));

        final cubit = buildCubit();
        await cubit.loginWithProvider(AuthProvider.google);

        final states = <LoginState>[];
        final sub = cubit.stream.listen(states.add);

        lifecycleSubject.add(LifecycleState.resumed);

        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        await sub.cancel();

        expect(states, [
          isA<LoginPolling>()
              .having((state) => state.handoff.provider, "provider", AuthProvider.google)
              .having((state) => state.handoff.oauth, "oauth", same(testHandoff)),
          isA<LoginSuccess>(),
        ]);
        verify(() => mockOAuthFlowProvider.resumeOAuthFlow()).called(1);
      });

      test("does not resume polling when app resumes but no active session", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.paused);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenAnswer((_) async => false);
        when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));

        final cubit = buildCubit();
        await cubit.loginWithProvider(AuthProvider.google);

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

      test("a failed active-session precheck terminates the interrupted attempt", () async {
        final lifecycleSubject = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
        when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleSubject.stream);
        when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async {
          lifecycleSubject.add(LifecycleState.paused);
          await Future<void>.delayed(Duration.zero);
          throw ClientException("Software caused connection abort");
        });
        when(() => mockOAuthFlowProvider.hasActiveOAuthSession()).thenThrow(StateError("session read failed"));
        final cubit = buildCubit();

        await cubit.loginWithProvider(AuthProvider.google);
        expect(cubit.state, isA<LoginPolling>());

        lifecycleSubject.add(LifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<LoginFailed>());
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(
            provider: AuthProvider.google,
            cause: LoginAttemptFailureCause.unknown,
          ),
        ).called(1);
        await cubit.close();
        await lifecycleSubject.close();
      });
    });

    group("Browser handoff", () {
      late Completer<AuthLoginResult> poll;

      setUp(() {
        poll = Completer<AuthLoginResult>();
        when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) => poll.future);
        when(() => mockOAuthFlowProvider.cancelOAuthFlow()).thenAnswer((_) async {});
      });

      Future<void> settle() => Future<void>.delayed(Duration.zero);

      void verifyFailedCause(LoginAttemptFailureCause cause) {
        verify(
          () => mockInstallationAnalyticsService.loginAttemptFailed(provider: AuthProvider.google, cause: cause),
        ).called(1);
      }

      test("polling carries the provider, link, expiry and device name", () async {
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();

        final state = cubit.state as LoginPolling;
        expect(state.handoff.provider, AuthProvider.google);
        expect(state.handoff.oauth.authUrl, testHandoff.authUrl);
        expect(state.handoff.oauth.expiresAt, testHandoff.expiresAt);
        expect(state.handoff.oauth.deviceName, "Test Mac");
        expect(state.handoff.browser, LoginBrowserLaunch.opened);
        await cubit.close();
      });

      test("cancel returns to idle, reports cancelled and ignores the late poll result", () async {
        final cubit = buildCubit();
        final login = cubit.loginWithProvider(AuthProvider.google);
        await settle();

        await cubit.cancel();
        expect(cubit.state, isA<LoginIdle>());
        verify(() => mockOAuthFlowProvider.cancelOAuthFlow()).called(1);
        verifyFailedCause(LoginAttemptFailureCause.cancelled);

        poll.complete(testAuthLoginResult);
        expect(await login, isFalse);
        expect(cubit.state, isA<LoginIdle>());
        verifyNever(
          () => mockInstallationAnalyticsService.loginAttemptCompleted(
            provider: any(named: "provider"),
            accountStatus: any(named: "accountStatus"),
          ),
        );
        await cubit.close();
      });

      test("a failed cancel is logged and still ends in idle", () async {
        when(() => mockOAuthFlowProvider.cancelOAuthFlow()).thenAnswer((_) async => throw StateError("storage failed"));
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();

        await cubit.cancel();

        expect(cubit.state, isA<LoginIdle>());
        await cubit.close();
      });

      test("a new attempt started right after cancel is not disturbed by the cancelled poll", () async {
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();
        await cubit.cancel();

        final oldPoll = poll;
        poll = Completer<AuthLoginResult>();
        final retry = cubit.loginWithProvider(AuthProvider.google);
        await settle();
        oldPoll.completeError(Exception("superseded"));
        await settle();
        expect(cubit.state, isA<LoginPolling>());

        poll.complete(testAuthLoginResult);
        expect(await retry, isTrue);
        expect(cubit.state, isA<LoginSuccess>());
        await cubit.close();
      });

      test("cancel after a failed launch reports launch", () async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();
        expect((cubit.state as LoginPolling).handoff.browser, LoginBrowserLaunch.failed);

        await cubit.cancel();

        verifyFailedCause(LoginAttemptFailureCause.launch);
        await cubit.close();
      });

      test("a timeout after a failed launch reports launch", () async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
        final cubit = buildCubit();
        final login = cubit.loginWithProvider(AuthProvider.google);
        await settle();

        poll.completeError(TimeoutException("OAuth authorization timed out"));
        await login;

        expect(cubit.state, isA<LoginTimeout>());
        verifyFailedCause(LoginAttemptFailureCause.launch);
        await cubit.close();
      });

      test("reopen launches the same link again and reports the new launch result", () async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();

        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
        await cubit.reopenBrowser();

        final state = cubit.state as LoginPolling;
        expect(state.handoff.browser, LoginBrowserLaunch.opened);
        expect(state.handoff.oauth, same(testHandoff));
        verify(() => mockUrlLauncher.launch(testHandoff.authUrl)).called(2);

        await cubit.cancel();
        verifyFailedCause(LoginAttemptFailureCause.cancelled);
        await cubit.close();
      });

      test("a reopen that finishes after cancel does not bring the waiting state back", () async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();

        final reopenLaunch = Completer<bool>();
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) => reopenLaunch.future);
        final reopen = cubit.reopenBrowser();
        await cubit.cancel();
        reopenLaunch.complete(true);
        await reopen;

        expect(cubit.state, isA<LoginIdle>());
        verifyFailedCause(LoginAttemptFailureCause.launch);
        await cubit.close();
      });

      test("a failed reopen after an opened browser still reports cancelled", () async {
        final cubit = buildCubit();
        unawaited(cubit.loginWithProvider(AuthProvider.google));
        await settle();

        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
        await cubit.reopenBrowser();
        expect((cubit.state as LoginPolling).handoff.browser, LoginBrowserLaunch.failed);

        await cubit.cancel();
        verifyFailedCause(LoginAttemptFailureCause.cancelled);
        await cubit.close();
      });

      test("a server-expired session ends in timeout", () async {
        final cubit = buildCubit();
        final login = cubit.loginWithProvider(AuthProvider.google);
        await settle();

        poll.completeError(const OAuthFlowExpired());
        await login;

        expect(cubit.state, isA<LoginTimeout>());
        verifyFailedCause(LoginAttemptFailureCause.timeout);
        await cubit.close();
      });

      test("a declined sign-in fails with the declined reason", () async {
        final cubit = buildCubit();
        final login = cubit.loginWithProvider(AuthProvider.google);
        await settle();

        poll.completeError(const OAuthFlowDenied());
        await login;

        expect(cubit.state, const LoginState.failed(reason: LoginFailedReason.declined));
        verifyFailedCause(LoginAttemptFailureCause.cancelled);
        await cubit.close();
      });
    });

    group("Email Login", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithEmail calls AuthSession.loginWithEmail with correct email/password",
        build: buildCubit,
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail(email: "test@example.com", password: "password123")).thenAnswer(
            (_) async => testAuthLoginResult,
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
          verify(
            () => mockInstallationAnalyticsService.loginAttemptCompleted(
              provider: AuthProvider.email,
              accountStatus: AccountStatus.existing,
            ),
          ).called(1);
        },
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
          verifyNever(
            () => mockInstallationAnalyticsService.loginAttemptStarted(provider: any(named: "provider")),
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
