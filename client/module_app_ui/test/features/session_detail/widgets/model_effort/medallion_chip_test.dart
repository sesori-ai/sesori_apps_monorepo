import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/medallion_chip.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbits_picker.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, FastModeControl, ModelOrbits, OrbitRing;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbits_fixture.dart";

const _screen = Size(393, 700);

typedef _Pick = ({String providerID, String modelID, SessionVariant? variant});

ProviderModel _model(OrbitRing ring) => ProviderModel(
  id: ring.modelID,
  providerID: ring.providerID,
  name: ring.name,
  variants: [for (final level in ring.levels) level.variant.id],
  defaultVariant: null,
  family: null,
  fastMode: ring.fastMode,
  releaseDate: null,
);

final _providers = [
  ProviderInfo(
    id: "anthropic",
    name: "Anthropic",
    models: {
      for (final ring in [fable, opus, sonnet, haiku]) ring.modelID: _model(ring),
    },
    defaultModelID: "opus",
  ),
];

Future<List<_Pick>> _pump(
  WidgetTester tester, {
  required ModelOrbits? orbits,
  PregoInteractionMode mode = PregoInteractionMode.touch,
  bool readOnly = false,
  bool settle = true,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = _screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picks = <_Pick>[];
  await tester.pumpWidget(
    PregoInteractionScope(
      mode: mode,
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: AgentModelButtons(
                    surfaceStyle: PregoComposerSurfaceStyle.subtle,
                    agents: const [],
                    selectedAgent: null,
                    onAgentSelected: (_) {},
                    providers: _providers,
                    selectedAgentModel: const AgentModel(providerID: "anthropic", modelID: "opus", variant: "high"),
                    onModelSelected: ({required providerID, required modelID, required variant}) =>
                        picks.add((providerID: providerID, modelID: modelID, variant: variant)),
                    availableVariants: const [
                      SessionVariant(id: "high"),
                      SessionVariant(id: "low"),
                    ],
                    onVariantSelected: (_) {},
                    modelOrbits: orbits,
                    fastModeControl: FastModeControl.off,
                    decideFastModeToggle: () => null,
                    onFastModeChanged: (_) {},
                    compact: mode == PregoInteractionMode.pointer,
                    readOnly: readOnly,
                    trailing: const [],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return picks;
}

/// The geometry the picker lays out over the whole screen from the chip.
OrbitGeometry _geometry(WidgetTester tester, {required ModelOrbits orbits}) {
  final chip = tester.getRect(find.byType(MedallionChip));
  return OrbitGeometry(
    orbits: orbits,
    origin: Offset(chip.left + chip.height / 2, chip.center.dy),
    size: _screen,
    fastToggleRect: null,
  );
}

void main() {
  final orbits = claudeOrbits(totalModels: 6, current: opus, currentLevel: EffortLevel.high);
  final chip = find.byType(MedallionChip);
  final picker = find.byType(OrbitsPicker);

  testWidgets("an orbit catalog on touch shows the chip in place of the model, effort and fast pills", (tester) async {
    await _pump(tester, orbits: orbits);

    expect(chip, findsOneWidget);
    expect(find.byType(PregoPickerButton), findsNothing);
    // As tall as the row's other touch pills, so the row does not jump.
    expect(tester.getSize(chip).height, 36);
  });

  testWidgets("the pointer layout keeps its pills for an orbit catalog", (tester) async {
    await _pump(tester, orbits: orbits, mode: PregoInteractionMode.pointer);

    expect(chip, findsNothing);
    expect(find.byType(PregoPickerButton), findsNWidgets(2));
  });

  testWidgets("a catalog without orbits keeps its pills on touch", (tester) async {
    await _pump(tester, orbits: null);

    expect(chip, findsNothing);
    expect(find.byType(PregoPickerButton), findsNWidgets(2));
  });

  testWidgets("read-only keeps the chip in place without opening the picker", (tester) async {
    await _pump(tester, orbits: orbits);
    final live = tester.getRect(chip);

    await _pump(tester, orbits: orbits, readOnly: true);
    expect(tester.getRect(chip), live);

    await tester.tap(chip, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
  });

  testWidgets("one press on the chip slides on into the picker and picks model and effort", (tester) async {
    final picks = await _pump(tester, orbits: orbits);
    final geometry = _geometry(tester, orbits: orbits);

    final gesture = await tester.startGesture(tester.getRect(chip).centerLeft + const Offset(18, 0));
    await tester.pumpAndSettle();
    expect(picker, findsOneWidget);

    await gesture.moveTo(geometry.dotCenter(ringIndex: 2, levelIndex: 1));
    await tester.pump();
    await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 3));
    await tester.pump();
    expect(picks, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(picks, [(providerID: "anthropic", modelID: "fable", variant: const SessionVariant(id: "xhigh"))]);
    expect(picker, findsNothing);
  });

  testWidgets("a press slid off the rings and released cancels", (tester) async {
    final picks = await _pump(tester, orbits: orbits);

    final gesture = await tester.startGesture(tester.getCenter(chip));
    await tester.pumpAndSettle();
    await gesture.moveTo(const Offset(380, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(picks, isEmpty);
    expect(picker, findsNothing);
  });

  testWidgets("a tap on the chip opens the picker and leaves it open for a tap", (tester) async {
    final picks = await _pump(tester, orbits: orbits);
    final geometry = _geometry(tester, orbits: orbits);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(picker, findsOneWidget);

    await tester.tapAt(geometry.dotCenter(ringIndex: 2, levelIndex: 0));
    await tester.pumpAndSettle();

    expect(picks, [(providerID: "anthropic", modelID: "sonnet", variant: const SessionVariant(id: "low"))]);
    expect(picker, findsNothing);
  });

  testWidgets("All models closes the orbits and opens the model list", (tester) async {
    await _pump(tester, orbits: orbits);
    final geometry = _geometry(tester, orbits: orbits);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tapAt(geometry.allModelsCenter);
    await tester.pumpAndSettle();

    expect(picker, findsNothing);
    expect(find.byType(ModelPicker), findsOneWidget);
  });

  testWidgets("larger reader text grows the chip's text, up to what fits the pill height", (tester) async {
    await _pump(tester, orbits: orbits);
    final standard = tester.getSize(chip).width;

    await _pump(tester, orbits: orbits, textScale: 1.3);
    final larger = tester.getSize(chip).width;
    await _pump(tester, orbits: orbits, textScale: 2);

    expect(larger, greaterThan(standard));
    expect(tester.getSize(chip), Size(larger, 36));
  });

  testWidgets("a new model eases the plate to its width rather than snapping", (tester) async {
    await _pump(tester, orbits: orbits);
    final before = tester.getSize(chip).width;

    await _pump(
      tester,
      orbits: orbits.copyWith(current: sonnet, currentLevel: EffortLevel.low),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 110));
    final midway = tester.getSize(chip).width;
    await tester.pumpAndSettle();
    final after = tester.getSize(chip).width;

    expect(after, greaterThan(before));
    expect(midway, inExclusiveRange(before, after));
  });
}
