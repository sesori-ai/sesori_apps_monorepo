import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/settings/widgets/chat_input_mode_picker.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockChatInputModeStore() extends Mock implements ChatInputModeStore;

void main() {
  late _MockChatInputModeStore store;
  late ChatInputModeCubit cubit;

  setUpAll(() => registerFallbackValue(ChatInputMode.voiceFirst));
  setUp(() {
    store = _MockChatInputModeStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    cubit = ChatInputModeCubit(store: store, initialMode: ChatInputMode.voiceFirst);
  });
  tearDown(() => cubit.close());

  Widget app({required Brightness brightness, required VoidCallback onBack, required VoidCallback onClose}) {
    return BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultInputSettingsView(onBack: onBack, onClose: onClose),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets("Voice and Text states match preview geometry and theme tokens in $brightness", (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(brightness: brightness, onBack: () {}, onClose: () {}));
      await tester.pumpAndSettle();
      final colors = tester.element(find.byType(ChatInputModePicker)).prego.colors;
      for (final mode in ChatInputMode.values) {
        await tester.runAsync(() => cubit.select(mode: mode));
        await tester.pumpAndSettle();
        final previews = find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxHeight == 69);
        expect(previews, findsNWidgets(2));
        expect(tester.getTopLeft(previews.first).dx, 16);
        expect(tester.getTopLeft(previews.last).dx - tester.getTopRight(previews.first).dx, 12);
        for (var index = 0; index < 2; index++) {
          final preview = tester.widget<Container>(previews.at(index));
          final border = (preview.foregroundDecoration! as BoxDecoration).border! as Border;
          final selected = index == (mode == ChatInputMode.voiceFirst ? 0 : 1);
          expect(border.top.width, 2);
          expect(border.top.color, selected ? colors.borderBrand : Colors.transparent);
        }
        final waveform = tester
            .widgetList<Container>(find.byType(Container))
            .where(
              (widget) => widget.constraints?.maxWidth == 4.9,
            );
        expect(waveform, hasLength(22));
        expect(
          (waveform.elementAt(2).decoration! as BoxDecoration).color,
          mode == ChatInputMode.voiceFirst ? colors.textSecondaryOnBrand : colors.textSecondary.withValues(alpha: 0.8),
        );
        final microphone = find.descendant(of: previews.first, matching: find.byIcon(TablerRegular.microphone));
        expect(microphone, findsOneWidget);
        final button = find.ancestor(of: microphone, matching: find.byType(Container)).first;
        expect(tester.getSize(button), const Size(44, 44));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("selection persists, external changes react, and options expose exclusive semantics", (tester) async {
    await tester.pumpWidget(app(brightness: Brightness.dark, onBack: () {}, onClose: () {}));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    void expectChoice({required String label, required bool checked}) {
      expect(
        tester.getSemantics(find.text(label)),
        matchesSemantics(
          label: label,
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: checked,
          hasTapAction: true,
        ),
      );
    }

    expectChoice(label: "Voice", checked: true);
    expectChoice(label: "Text", checked: false);
    await tester.tap(find.text("Text"));
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(cubit.state, ChatInputMode.textFirst);
    verify(() => store.write(mode: ChatInputMode.textFirst)).called(1);
    expectChoice(label: "Voice", checked: false);
    expectChoice(label: "Text", checked: true);
    await tester.runAsync(() => cubit.select(mode: ChatInputMode.voiceFirst));
    await tester.pumpAndSettle();
    expectChoice(label: "Voice", checked: true);
    expectChoice(label: "Text", checked: false);
    semantics.dispose();
  });

  testWidgets("Back and Close dispatch independently with readable accessibility text", (tester) async {
    tester.view.physicalSize = const Size(320, 874);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var backs = 0;
    var closes = 0;
    await tester.pumpWidget(app(brightness: Brightness.dark, onBack: () => backs++, onClose: () => closes++));
    await tester.pumpAndSettle();
    expect(find.text("Choose how you default talk to Sesori."), findsOneWidget);
    expect(find.text("Voice"), findsOneWidget);
    expect(find.text("Text"), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.tap(find.byIcon(TablerRegular.x));
    expect(backs, 1);
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets("picker labels wrap without overflow at maximum accessibility text", (tester) async {
    tester.view.physicalSize = const Size(320, 874);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(PregoSpacing.xl), child: ChatInputModePicker()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Voice"), findsOneWidget);
    expect(find.text("Text"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
