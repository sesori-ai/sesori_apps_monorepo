import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/settings/settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/settings/settings_state.dart";
import "package:test/test.dart";

class _MockAuthSession extends Mock implements AuthSession {}

void main() {
  group("SettingsCubit", () {
    late _MockAuthSession authSession;

    setUp(() {
      authSession = _MockAuthSession();
    });

    test("initial state is SettingsInitial", () {
      final cubit = SettingsCubit(authSession: authSession);
      addTearDown(cubit.close);

      expect(cubit.state, isA<SettingsInitial>());
    });

    test("emits loggingOut then loggedOut after logout succeeds", () async {
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

      final cubit = SettingsCubit(authSession: authSession);
      addTearDown(cubit.close);

      final futureStates = cubit.stream.take(2).toList();
      await cubit.logout();

      final states = await futureStates;

      expect(states[0], isA<SettingsLoggingOut>());
      expect(states[1], isA<SettingsLoggedOut>());
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });

    test("emits loggingOut then logoutFailed when logout throws", () async {
      when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("boom"));

      final cubit = SettingsCubit(authSession: authSession);
      addTearDown(cubit.close);

      final futureStates = cubit.stream.take(2).toList();
      await cubit.logout();

      final states = await futureStates;

      expect(states[0], isA<SettingsLoggingOut>());
      expect(states[1], isA<SettingsLogoutFailed>());
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });

    test("ignores duplicate logout calls while already loggingOut", () async {
      final completer = Completer<void>();
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) => completer.future);

      final cubit = SettingsCubit(authSession: authSession);
      addTearDown(cubit.close);

      final firstLogout = cubit.logout();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<SettingsLoggingOut>());

      await cubit.logout();

      completer.complete();
      await firstLogout;

      expect(cubit.state, isA<SettingsLoggedOut>());
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });
  });
}
