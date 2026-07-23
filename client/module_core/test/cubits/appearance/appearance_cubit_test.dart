import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockAppearanceStore extends Mock implements AppearanceStore {}

void main() {
  late _MockAppearanceStore store;

  setUpAll(() => registerFallbackValue(AppearanceMode.system));

  setUp(() {
    store = _MockAppearanceStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
  });

  test("starts in the persisted mode handed to it", () {
    final cubit = AppearanceCubit(store: store, initialMode: AppearanceMode.dark);

    expect(cubit.state, AppearanceMode.dark);
  });

  test("select switches the app and persists the choice", () async {
    final cubit = AppearanceCubit(store: store, initialMode: AppearanceMode.system);

    await cubit.select(mode: AppearanceMode.light);

    expect(cubit.state, AppearanceMode.light);
    verify(() => store.write(mode: AppearanceMode.light)).called(1);
  });

  test("re-selecting the current mode does not rewrite storage", () async {
    final cubit = AppearanceCubit(store: store, initialMode: AppearanceMode.system);

    await cubit.select(mode: AppearanceMode.system);

    verifyNever(() => store.write(mode: any(named: "mode")));
  });
}
