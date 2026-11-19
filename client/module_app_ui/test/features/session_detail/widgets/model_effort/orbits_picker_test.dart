import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbits_painter.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbits_picker.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show EffortLevel, FastModeControl, FastModeToggleApply, FastModeToggleDecision, ModelOrbits;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbits_fixture.dart";

/// The chip sits where the mock puts it: 14 pt in, the rings' centre at y = 610.
const _anchor = Rect.fromLTWH(14, 591, 150, 39);

typedef _Pick = ({String providerID, String modelID, SessionVariant? variant});

final class _Harness() {
  final picks = <_Pick>[];
  final fastChanges = <bool>[];
  int allModelsOpened = 0;
  int selectionHaptics = 0;
  int pickHaptics = 0;
}

OrbitGeometry _geometry({required ModelOrbits orbits}) => OrbitGeometry(
  orbits: orbits,
  origin: Offset(_anchor.left + _anchor.height / 2, _anchor.center.dy),
  size: const Size(393, 700),
  fastToggleRect: null,
  // Only dots are located through this geometry.
  nameLengths: [for (final _ in orbits.rings) 0],
);

Future<_Harness> _open(
  WidgetTester tester, {
  required ModelOrbits orbits,
  FastModeControl fastModeControl = FastModeControl.off,
  FastModeToggleDecision decision = const FastModeToggleApply(fastMode: true),
  Duration? openFor,
}) async {
  tester.view
    ..physicalSize = const Size(393, 700)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == "HapticFeedback.vibrate") {
      switch (call.arguments) {
        case "HapticFeedbackType.selectionClick":
          harness.selectionHaptics++;
        case "HapticFeedbackType.lightImpact":
          harness.pickHaptics++;
      }
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
  unawaited(
    showOrbitsPicker(
      context: tester.element(find.byType(Scaffold)),
      anchorRect: _anchor,
      handoff: null,
      orbits: orbits,
      onModelSelected: ({required providerID, required modelID, required variant}) =>
          harness.picks.add((providerID: providerID, modelID: modelID, variant: variant)),
      onShowAllModels: () => harness.allModelsOpened++,
      fastModeControl: fastModeControl,
      decideFastModeToggle: () => decision,
      onFastModeChanged: harness.fastChanges.add,
    ),
  );
  if (openFor == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(openFor);
  }
  return harness;
}

void main() {
  final orbits = claudeOrbits(totalModels: 4, current: opus, currentLevel: EffortLevel.high);
  final geometry = _geometry(orbits: orbits);
  final picker = find.byType(OrbitsPicker);

  testWidgets("a tap on a dot picks that model and level and closes", (tester) async {
    final harness = await _open(tester, orbits: orbits);

    await tester.tapAt(geometry.dotCenter(ringIndex: 0, levelIndex: 3));
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "fable", variant: const SessionVariant(id: "xhigh"))]);
    expect(harness.pickHaptics, 1);
    expect(picker, findsNothing);
  });

  testWidgets("a tap while the rings still ripple in lands on the dot as drawn", (tester) async {
    final harness = await _open(tester, orbits: orbits, openFor: const Duration(milliseconds: 60));
    // Fable is the last ring to settle, so it is still drawn at 84 % here,
    // over the spot that Opus owns once settled.
    final origin = geometry.origin;
    final drawn = origin + (geometry.dotCenter(ringIndex: 0, levelIndex: 4) - origin) * .84;
    expect(geometry.hitTest(drawn), const OrbitLevelTarget(ringIndex: 1, levelIndex: 4));

    await tester.tapAt(drawn);
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "fable", variant: const SessionVariant(id: "max"))]);
  });

  testWidgets("one slide picks the dot it is released on, with a haptic per patch", (tester) async {
    final harness = await _open(tester, orbits: orbits);

    final gesture = await tester.startGesture(geometry.dotCenter(ringIndex: 1, levelIndex: 2));
    await tester.pump();
    // Out along the high ray to Fable, then down to its max dot.
    await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 2));
    await tester.pump();
    await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 3));
    await tester.pump();
    await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 4));
    await tester.pump();
    expect(harness.picks, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "fable", variant: const SessionVariant(id: "max"))]);
    expect(harness.selectionHaptics, 4);
    expect(harness.pickHaptics, 1);
    expect(picker, findsNothing);
  });

  testWidgets("releasing outside every patch closes without a change", (tester) async {
    final harness = await _open(tester, orbits: orbits);

    final gesture = await tester.startGesture(geometry.dotCenter(ringIndex: 1, levelIndex: 0));
    await tester.pump();
    await gesture.moveTo(const Offset(370, 80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.picks, isEmpty);
    expect(harness.pickHaptics, 0);
    expect(picker, findsNothing);
  });

  testWidgets("a tap on a model name picks the model and leaves the level to the switch rule", (tester) async {
    final harness = await _open(tester, orbits: orbits);

    await tester.tap(find.bySemanticsLabel("Sonnet 5.5"));
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "sonnet", variant: null)]);
  });

  testWidgets("a model without levels is picked from anywhere on its ring", (tester) async {
    final harness = await _open(tester, orbits: orbits);

    await tester.tapAt(geometry.levellessDotCenter(ringIndex: 3));
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "haiku", variant: null)]);
  });

  testWidgets("All N models shows only for a larger catalog and hands off to the full list", (tester) async {
    var harness = await _open(tester, orbits: orbits);
    expect(find.bySemanticsLabel("All 4 models"), findsNothing);
    await tester.tapAt(const Offset(380, 20));
    await tester.pumpAndSettle();

    harness = await _open(tester, orbits: orbits.copyWith(totalModels: 7));
    await tester.tap(find.bySemanticsLabel("All 7 models"));
    await tester.pumpAndSettle();

    expect(harness.allModelsOpened, 1);
    expect(harness.picks, isEmpty);
    expect(picker, findsNothing);
  });

  testWidgets("labels every dot for screen readers and marks the current choice", (tester) async {
    await _open(tester, orbits: orbits);

    expect(
      tester.getSemantics(find.bySemanticsLabel("Opus 5.5, high effort")),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel("Fable 5.1, low effort")),
      isSemantics(isButton: true, isSelected: false, hasTapAction: true),
    );
  });

  testWidgets("draws OFF as the weakest level and picks it", (tester) async {
    final pi = orbitRing(
      modelID: "pi",
      name: "Pi Model",
      levels: const [EffortLevel.off, EffortLevel.low, EffortLevel.high],
      fast: false,
    );
    final offOrbits = ModelOrbits(
      rings: [pi],
      levels: const [EffortLevel.off, EffortLevel.low, EffortLevel.high],
      totalModels: 1,
      current: pi,
      currentLevel: EffortLevel.high,
    );
    final harness = await _open(tester, orbits: offOrbits);

    expect(
      tester.getSemantics(find.bySemanticsLabel("Pi Model, effort off")),
      isSemantics(isButton: true, isSelected: false, hasTapAction: true),
    );
    await tester.tapAt(_geometry(orbits: offOrbits).dotCenter(ringIndex: 0, levelIndex: 0));
    await tester.pumpAndSettle();

    expect(harness.picks, [(providerID: "anthropic", modelID: "pi", variant: const SessionVariant(id: "off"))]);
  });

  group("while a finger is down", () {
    final painter = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is OrbitsPainter);
    final palette = OrbitPalette(colors: PregoDesignSystem.light.colors);

    /// Dots painted in this order, each `(ring, level, fill)`, among any
    /// other drawing.
    PaintPattern dots(List<(int, int, Color)> expected) {
      final pattern = paints;
      for (final (ringIndex, levelIndex, color) in expected) {
        final center = geometry.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex);
        pattern.something(
          (method, arguments) =>
              method == #drawCircle &&
              ((arguments[0] as Offset) - center).distance < .01 &&
              (arguments[2] as Paint).color.toARGB32() == color.toARGB32(),
        );
      }
      return pattern;
    }

    testWidgets("shows no level word with no finger down", (tester) async {
      await _open(tester, orbits: orbits);

      for (final level in EffortLevel.values) {
        expect(find.text(level.wireId.toUpperCase()), findsNothing);
      }
    });

    testWidgets("the touched dot names its level just above it, following the finger", (tester) async {
      await _open(tester, orbits: orbits);

      final xhigh = geometry.dotCenter(ringIndex: 0, levelIndex: 3);
      final gesture = await tester.startGesture(xhigh);
      await tester.pumpAndSettle();
      expect(find.text("XHIGH"), findsOneWidget);
      final word = tester.getRect(find.text("XHIGH"));
      expect(word.bottom, lessThan(xhigh.dy - 20));
      expect(word.center.dx, closeTo(xhigh.dx, 1));

      await gesture.moveTo(geometry.dotCenter(ringIndex: 0, levelIndex: 4));
      await tester.pumpAndSettle();
      expect(find.text("MAX"), findsOneWidget);
      expect(find.text("XHIGH"), findsNothing);

      // A model name gets no word.
      await gesture.moveTo(geometry.pointAt(radius: 315, angle: 92));
      await tester.pumpAndSettle();
      expect(find.text("MAX"), findsNothing);

      await gesture.moveTo(const Offset(370, 80));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("draws the committed choice with solid dots along its trail", (tester) async {
      await _open(tester, orbits: orbits);

      // Opus at high: low and medium are on the trail, xhigh above it.
      expect(
        painter,
        dots([
          (1, 0, palette.trailDot),
          (1, 1, palette.trailDot),
          (1, 2, palette.background),
          (1, 3, palette.bead),
        ]),
      );
      expect(painter, isNot(dots([(0, 0, palette.trailDot)])));
    });

    testWidgets("draws the touched dot exactly as if it were picked", (tester) async {
      await _open(tester, orbits: orbits);

      final gesture = await tester.startGesture(geometry.dotCenter(ringIndex: 0, levelIndex: 3));
      await tester.pumpAndSettle();

      // Fable's trail lights up to xhigh, and Opus at high goes plain.
      expect(
        painter,
        dots([
          (0, 0, palette.trailDot),
          (0, 2, palette.trailDot),
          (0, 3, palette.background),
          (0, 4, palette.bead),
          (1, 0, palette.bead),
          (1, 2, palette.bead),
        ]),
      );
      expect(painter, isNot(dots([(1, 2, palette.background)])));

      // Off every target, the committed choice is back.
      await gesture.moveTo(const Offset(370, 80));
      await tester.pumpAndSettle();
      expect(painter, dots([(1, 2, palette.background)]));
      expect(painter, isNot(dots([(0, 2, palette.trailDot)])));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    test("a name shows the model at the current level when it offers it, else without a level", () {
      expect(shownOrbitChoice(orbits: orbits, hot: null), (ringIndex: 1, levelIndex: 2));
      expect(
        shownOrbitChoice(orbits: orbits, hot: const OrbitLevelTarget(ringIndex: 0, levelIndex: 4)),
        (ringIndex: 0, levelIndex: 4),
      );
      expect(shownOrbitChoice(orbits: orbits, hot: const OrbitNameTarget(ringIndex: 2)), (ringIndex: 2, levelIndex: 2));
      expect(shownOrbitChoice(orbits: orbits, hot: const OrbitNameTarget(ringIndex: 3)), (
        ringIndex: 3,
        levelIndex: null,
      ));
      final atMax = claudeOrbits(totalModels: 4, current: opus, currentLevel: EffortLevel.max);
      expect(shownOrbitChoice(orbits: atMax, hot: const OrbitNameTarget(ringIndex: 2)), (
        ringIndex: 2,
        levelIndex: null,
      ));
      expect(shownOrbitChoice(orbits: atMax, hot: const OrbitAllModelsTarget()), (ringIndex: 1, levelIndex: 4));
    });
  });

  test("dark mode tints the hollow dots and the All pill, light mode keeps its look", () {
    final dark = PregoDesignSystem.dark.colors;
    final darkPalette = OrbitPalette(colors: dark);
    expect(darkPalette.bead, dark.fgQuaternary);
    expect(darkPalette.beadEdge, dark.fgSecondary);
    expect(darkPalette.levelText, dark.textTertiary);
    expect(darkPalette.surface, dark.alphaWhite100);

    final light = PregoDesignSystem.light.colors;
    final lightPalette = OrbitPalette(colors: light);
    expect(lightPalette.bead, light.alphaWhite100);
    expect(lightPalette.beadEdge, light.fgQuaternary);
    expect(lightPalette.levelText, light.textQuaternary);
  });

  group("fast toggle", () {
    testWidgets("switches fast mode and stays open", (tester) async {
      final harness = await _open(tester, orbits: orbits);

      await tester.tap(find.bySemanticsLabel("Fast mode"));
      await tester.pumpAndSettle();

      expect(harness.fastChanges, [true]);
      expect(picker, findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel("Fast mode")), isSemantics(isToggled: true));
    });

    testWidgets("ignores a slide that ends on it", (tester) async {
      final harness = await _open(tester, orbits: orbits);

      final gesture = await tester.startGesture(geometry.dotCenter(ringIndex: 0, levelIndex: 4));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.bySemanticsLabel("Fast mode")));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.fastChanges, isEmpty);
      expect(harness.picks, isEmpty);
      expect(picker, findsNothing);
    });

    testWidgets("says why when the selected model has no fast mode", (tester) async {
      final harness = await _open(
        tester,
        orbits: claudeOrbits(totalModels: 4, current: fable, currentLevel: EffortLevel.max),
        fastModeControl: FastModeControl.hidden,
      );

      await tester.tap(find.bySemanticsLabel("Fast mode"));
      await tester.pump();

      expect(find.text("Fable 5.1 has no fast mode."), findsOneWidget);
      expect(harness.fastChanges, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });
  });
}
