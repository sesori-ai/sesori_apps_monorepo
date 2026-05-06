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

    test("emits SettingsLoggedOut after logout succeeds", () async {
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

      final cubit = SettingsCubit(authSession: authSession);
      addTearDown(cubit.close);

      final futureState = cubit.stream.firstWhere((state) => state is SettingsLoggedOut);
      await cubit.logout();

      final state = await futureState;

      expect(state, isA<SettingsLoggedOut>());
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });
  });
}
