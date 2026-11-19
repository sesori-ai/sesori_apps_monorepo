import "package:flutter/services.dart" show LogicalKeyboardKey, SystemChannels;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/model_effort_chip.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/model_level_strip.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbits_picker.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, FastModeControl, ModelOrbits, OrbitRing;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbits_fixture.dart";

const _screen = Size(393, 700);

typedef _Pick = ({String providerID, String modelID, SessionVariant? variant});

ProviderModel _model(OrbitRing ring, {String? family}) => ProviderModel(
  id: ring.modelID,
  providerID: ring.providerID,
  name: ring.name,
  variants: [for (final level in ring.levels) level.variant.id],
  defaultVariant: null,
  family: family,
  fastMode: ring.fastMode,
  releaseDate: null,
);

final _providers = [
  ProviderInfo(
    id: "anthropic",
    name: "Anthropic",
    models: {
      fable.modelID: _model(fable),
      opus.modelID: _model(opus, family: "Opus"),
      // An older Opus, which the model list folds into its family by default.
      "opus-4-1": _model(opus, family: "Opus").copyWith(id: "opus-4-1", name: "Opus 4.1"),
      sonnet.modelID: _model(sonnet),
      haiku.modelID: _model(haiku),
    },
    defaultModelID: "opus",
  ),
];

Future<List<_Pick>> _pump(
  WidgetTester tester, {
  required ModelOrbits? orbits,
  PregoInteractionMode mode = PregoInteractionMode.touch,
  bool readOnly = false,
  FastModeControl fastModeControl = FastModeControl.off,
  Size screen = _screen,
  bool settle = true,
  double textScale = 1,
  List<AgentInfo> agents = const [],
  List<Widget> trailing = const [],
}) async {
  tester.view
    ..physicalSize = screen
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
                    agents: agents,
                    selectedAgent: agents.firstOrNull?.name,
                    onAgentSelected: (_) {},
                    providers: _providers,
                    selectedAgentModel: const AgentModel(providerID: "anthropic", modelID: "opus", variant: "high"),
                    onModelSelected: ({required providerID, required modelID, required variant}) {
                      picks.add((providerID: providerID, modelID: modelID, variant: variant));
                      return null;
                    },
                    modelOrbits: orbits,
                    fastModeControl: fastModeControl,
                    decideFastModeToggle: () => null,
                    onFastModeChanged: (_) {},
                    compact: mode == PregoInteractionMode.pointer,
                    readOnly: readOnly,
                    trailing: trailing,
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

/// Records each haptic the app plays, by its `HapticFeedbackType`.
List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == "HapticFeedback.vibrate") haptics.add("${call.arguments}");
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

const _openHaptic = "HapticFeedbackType.lightImpact";
const _slideHaptic = "HapticFeedbackType.selectionClick";

/// The geometry the picker lays out over the whole screen from the chip.
OrbitGeometry _geometry(WidgetTester tester, {required ModelOrbits orbits}) {
  final chip = tester.getRect(find.byType(ModelEffortChip));
  return OrbitGeometry(
    orbits: orbits,
    origin: Offset(chip.left + chip.height / 2, chip.center.dy),
    size: _screen,
    fastToggleRect: null,
    // Only dots are located through this geometry.
    nameLengths: [for (final _ in orbits.rings) 0],
  );
}

void main() {
  final orbits = claudeOrbits(totalModels: 6, current: opus, currentLevel: EffortLevel.high);
  final chip = find.byType(ModelEffortChip);
  final picker = find.byType(OrbitsPicker);

  testWidgets("an orbit catalog on touch shows the chip in place of the model, effort and fast pills", (tester) async {
    await _pump(tester, orbits: orbits);

    expect(chip, findsOneWidget);
    expect(find.byType(PregoPickerButton), findsNothing);
    // As tall as the row's other touch pills, so the row does not jump.
    expect(tester.getSize(chip).height, 36);
  });

  testWidgets("the chip leads the row and everything else on it sits at the end", (tester) async {
    const status = Key("status");
    await _pump(
      tester,
      // A short label: the test font draws every glyph a full em wide.
      orbits: orbits.copyWith(current: haiku, currentLevel: null),
      agents: const [
        AgentInfo(name: "build", description: null, model: null, mode: AgentMode.all),
        AgentInfo(name: "plan", description: null, model: null, mode: AgentMode.all),
      ],
      trailing: const [SizedBox.square(key: status, dimension: 36)],
    );
    final row = tester.getRect(find.byType(AgentModelButtons));
    final agent = tester.getRect(find.byType(PregoPickerButton));

    expect(tester.getRect(chip).left, row.left);
    expect(tester.getRect(find.byKey(status)).right, row.right);
    expect(agent.right, tester.getRect(find.byKey(status)).left - 8);
    // The agent pill hugs its label, leaving the gap after the chip open.
    expect(agent.left - tester.getRect(chip).right, greaterThan(40));
  });

  testWidgets("under a pointer an orbit catalog reads model and level in one pill", (tester) async {
    await _pump(tester, orbits: orbits, mode: PregoInteractionMode.pointer);

    expect(chip, findsNothing);
    expect(find.byType(PregoPickerButton), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "Opus 5.5 · High"), findsOneWidget);
  });

  testWidgets("a catalog without orbits gets the same chip on touch, beside its fast pill", (tester) async {
    await _pump(tester, orbits: null);

    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text(" · High")), findsOneWidget);
    expect(find.byType(PregoPickerButton), findsNothing);
    expect(find.bySemanticsLabel("Fast mode"), findsOneWidget);
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

  testWidgets("a press on the chip answers with one haptic as the picker opens", (tester) async {
    // A long name stretches the chip into the innermost ring's last patch, so
    // a press on its far end lands on a dot without having slid there.
    final long = opus.copyWith(name: "Opus 5.5 with the 1M context window");
    final wide = orbits.copyWith(rings: [fable, long, sonnet, haiku], current: long);
    await _pump(tester, orbits: wide);
    final haptics = _recordHaptics(tester);
    final geometry = _geometry(tester, orbits: wide);

    final end = tester.getRect(chip).topLeft + const Offset(160, 4);
    expect(tester.getRect(chip).contains(end), isTrue);
    expect(geometry.hitTest(end), isNotNull);
    final gesture = await tester.startGesture(end);
    await tester.pumpAndSettle();

    expect(picker, findsOneWidget);
    expect(haptics, [_openHaptic]);

    await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 3));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // A selection tick on reaching the dot, and a firmer one as it picks.
    expect(haptics, [_openHaptic, _slideHaptic, _openHaptic]);
  });

  testWidgets("a key or a screen reader opening the chip answers with a haptic too", (tester) async {
    await _pump(tester, orbits: orbits);
    final haptics = _recordHaptics(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(haptics, [_openHaptic]);

    Navigator.of(tester.element(picker)).pop();
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    tester.semantics.tap(find.semantics.byLabel(RegExp("Opus 5.5")));
    await tester.pumpAndSettle();
    semantics.dispose();

    expect(picker, findsOneWidget);
    expect(haptics, [_openHaptic, _openHaptic]);
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

  testWidgets("a hardware keyboard focuses the chip and Enter opens the picker", (tester) async {
    await _pump(tester, orbits: orbits);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picker, findsOneWidget);
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
    // Every model, not one per family.
    expect(find.descendant(of: find.byType(ModelPicker), matching: find.text("Opus 4.1")), findsOneWidget);
  });

  testWidgets("All models sets the effort too: a level commits model and level and closes", (tester) async {
    final picks = await _pump(tester, orbits: orbits);
    final geometry = _geometry(tester, orbits: orbits);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tapAt(geometry.allModelsCenter);
    await tester.pumpAndSettle();

    final strip = find.byType(ModelLevelStrip);
    expect(strip, findsOneWidget);
    await tester.tap(find.descendant(of: strip, matching: find.text("Low")));
    await tester.pumpAndSettle();

    expect(picks, [(providerID: "anthropic", modelID: "opus", variant: const SessionVariant(id: "low"))]);
    expect(find.byType(ModelPicker), findsNothing);
  });

  testWidgets("the chip's list keeps one model per family until a search", (tester) async {
    await _pump(tester, orbits: null);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.byType(ModelPicker), findsOneWidget);
    expect(find.descendant(of: find.byType(ModelPicker), matching: find.text("Opus 4.1")), findsNothing);
  });

  testWidgets("the chip reads the model and level, with a bolt only while fast", (tester) async {
    final bolt = find.descendant(of: chip, matching: find.byIcon(TablerRegular.bolt));
    final caret = find.descendant(of: chip, matching: find.byIcon(TablerRegular.selector));
    await _pump(tester, orbits: orbits);

    expect(find.descendant(of: chip, matching: find.text("Opus 5.5")), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text(" · High")), findsOneWidget);
    expect(bolt, findsNothing);
    expect(caret, findsOneWidget);

    await _pump(tester, orbits: orbits, fastModeControl: FastModeControl.on);
    expect(bolt, findsOneWidget);

    await _pump(tester, orbits: orbits.copyWith(current: haiku, currentLevel: null));
    expect(find.descendant(of: chip, matching: find.text("Haiku 4.5")), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.textContaining("·")), findsNothing);

    await _pump(tester, orbits: orbits.copyWith(currentLevel: EffortLevel.off));
    expect(find.descendant(of: chip, matching: find.text(" · Off")), findsOneWidget);
  });

  testWidgets("read-only hides the caret in place", (tester) async {
    double caretOpacity() =>
        tester.widget<AnimatedOpacity>(find.descendant(of: chip, matching: find.byType(AnimatedOpacity))).opacity;
    await _pump(tester, orbits: orbits);
    expect(caretOpacity(), 1);

    await _pump(tester, orbits: orbits, readOnly: true);
    expect(caretOpacity(), 0);
  });

  testWidgets("the largest reader text on a narrow phone cuts both texts without overflowing", (tester) async {
    const status = Key("status");
    await _pump(
      tester,
      orbits: orbits.copyWith(currentLevel: EffortLevel.medium),
      fastModeControl: FastModeControl.on,
      screen: const Size(320, 700),
      textScale: 3,
      agents: const [
        AgentInfo(name: "build", description: null, model: null, mode: AgentMode.all),
        AgentInfo(name: "plan", description: null, model: null, mode: AgentMode.all),
      ],
      trailing: const [SizedBox.square(key: status, dimension: 36)],
    );

    expect(tester.takeException(), isNull);
    final name = tester.getRect(find.descendant(of: chip, matching: find.text("Opus 5.5")));
    final level = tester.getRect(find.descendant(of: chip, matching: find.text(" · Medium")));
    // Both keep a share of the pill, and the pill stays clear of the agent pill.
    expect(name.width, greaterThan(0));
    expect(level.width, greaterThan(0));
    expect(level.left, greaterThanOrEqualTo(name.right));
    expect(tester.getRect(chip).right, lessThanOrEqualTo(tester.getRect(find.byType(PregoPickerButton)).left));
  });

  testWidgets("a cut label stays inside the chip while a change cross-fades", (tester) async {
    Future<void> pumpChip(EffortLevel level) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: ModelEffortChip(
              name: orbits.current.name,
              level: level.wireId,
              fast: false,
              showsCaret: true,
              surfaceStyle: PregoComposerSurfaceStyle.subtle,
            ),
          ),
        ),
      ),
    );
    await pumpChip(EffortLevel.medium);
    await pumpChip(EffortLevel.low);
    await tester.pump(const Duration(milliseconds: 110));

    final caret = tester.getRect(find.descendant(of: chip, matching: find.byIcon(TablerRegular.selector)));
    final labels = find.descendant(of: chip, matching: find.byWidgetPredicate((widget) => widget is Text));
    // The outgoing and the incoming face are both on screen.
    expect(labels, findsNWidgets(4));
    for (final label in labels.evaluate()) {
      final rect = tester.getRect(find.byWidget(label.widget));
      expect(rect.left, greaterThanOrEqualTo(tester.getRect(chip).left));
      expect(rect.right, lessThanOrEqualTo(caret.left));
    }
  });

  testWidgets("larger reader text grows the chip, at the pills' height", (tester) async {
    await _pump(tester, orbits: orbits);
    final standard = tester.getSize(chip).width;

    await _pump(tester, orbits: orbits, textScale: 1.3);

    expect(tester.getSize(chip).width, greaterThan(standard));
    expect(tester.getSize(chip).height, 36);
  });

  testWidgets("a new model eases the pill to its width rather than snapping", (tester) async {
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
