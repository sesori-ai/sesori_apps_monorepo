import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  test("4-phase DI bootstrap lets LoginCubit be constructed with no missing registrations", () async {
    configureDesktopDependencies();

    // Acceptance for the platform-adapter slice: every LoginCubit dependency
    // resolves through getIt, while the cubit itself stays out of DI.
    final LoginCubit cubit = LoginCubit(getIt(), getIt(), getIt(), getIt());
    addTearDown(cubit.close);

    expect(getIt.isRegistered<LoginCubit>(), isFalse);
  });
}
