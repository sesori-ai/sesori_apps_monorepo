import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceModeRepository() extends Mock implements VoiceModeRepository;

void main() {
  setUpAll(() => registerFallbackValue(VoiceEngine.device));

  testWidgets("lists the three engines, marks the stored one, and a tap picks another", (tester) async {
    final repository = _MockVoiceModeRepository();
    when(repository.loadEngine).thenAnswer((_) async {});
    when(() => repository.engine).thenReturn(VoiceEngine.device);
    when(() => repository.setEngine(engine: any(named: "engine"))).thenAnswer((_) async {});
    final cubit = VoiceEngineCubit(voiceModeRepository: repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VoiceEngineSettingsView(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in ["Embedded", "Device", "Remote"]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.getSemantics(find.text("Device")), isSemantics(isChecked: true));
    expect(tester.getSemantics(find.text("Remote")), isSemantics(isChecked: false));

    await tester.tap(find.text("Remote"));
    await tester.pumpAndSettle();

    expect(cubit.state, VoiceEngine.remote);
    verify(() => repository.setEngine(engine: VoiceEngine.remote)).called(1);
  });
}
