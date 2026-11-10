import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockAppearanceStore() extends Mock implements AppearanceStore;

void main() {
  late AppearanceCubit cubit;

  setUpAll(() => registerFallbackValue(AppearanceMode.system));
  setUp(() {
    final store = _MockAppearanceStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    cubit = AppearanceCubit(store: store, initialMode: AppearanceMode.system);
  });
  tearDown(() => cubit.close());

  for (final brightness in Brightness.values) {
    testWidgets("the Light and Dark tiles stand apart from the page like settings cards in $brightness", (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: buildPregoThemeData(brightness: brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AppearancePicker()),
          ),
        ),
      );
      final page = tester.element(find.byType(AppearancePicker)).prego.colors.bgSurface1;
      Color? canvas({required int tile}) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(of: find.byType(AspectRatio).at(tile), matching: find.byType(DecoratedBox)).first,
        );
        return switch (box.decoration) {
          BoxDecoration(:final color) => color,
          _ => fail("The preview canvas is not a box."),
        };
      }

      expect(canvas(tile: 0), PregoColors.light.bgSurface3);
      expect(canvas(tile: 1), PregoColors.dark.bgSurface3);
      expect(canvas(tile: 0), isNot(page));
      expect(canvas(tile: 1), isNot(page));
    });
  }
}
