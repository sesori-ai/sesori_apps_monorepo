import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/splash/splash_cubit.dart";
import "package:sesori_dart_core/src/cubits/splash/splash_state.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:test/test.dart";

class _MockAuthSession extends Mock implements AuthSession {}

void main() {
  group("SplashCubit", () {
    late _MockAuthSession authSession;

    setUp(() {
      authSession = _MockAuthSession();
    });

    test("initial state is SplashInitializing", () {
      when(authSession.hasLocallyValidSession).thenAnswer((_) async => false);

      final cubit = SplashCubit(authSession);
      addTearDown(cubit.close);

      expect(cubit.state, isA<SplashInitializing>());
    });

    test("emits SplashReady(projects) when local session appears valid", () async {
      when(authSession.hasLocallyValidSession).thenAnswer((_) async => true);

      final cubit = SplashCubit(authSession);
      addTearDown(cubit.close);
      final completed = cubit.stream.firstWhere((s) => s is SplashReady);

      final state = await completed;

      expect(state, isA<SplashReady>());
      expect((state as SplashReady).route, isA<AppRouteProjects>());
      verifyNever(() => authSession.restoreSession());
    });

    test("emits SplashReady(login) when no local session is available", () async {
      when(authSession.hasLocallyValidSession).thenAnswer((_) async => false);

      final cubit = SplashCubit(authSession);
      addTearDown(cubit.close);
      final state = await cubit.stream.firstWhere((s) => s is SplashReady);

      expect((state as SplashReady).route, isA<AppRouteLogin>());
      verifyNever(() => authSession.restoreSession());
    });

    test("emits SplashReady(login) when local session check throws", () async {
      when(authSession.hasLocallyValidSession).thenThrow(StateError("storage failed"));

      final cubit = SplashCubit(authSession);
      addTearDown(cubit.close);

      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<SplashReady>());
      expect((cubit.state as SplashReady).route, isA<AppRouteLogin>());
      verifyNever(() => authSession.restoreSession());
    });
  });
}
