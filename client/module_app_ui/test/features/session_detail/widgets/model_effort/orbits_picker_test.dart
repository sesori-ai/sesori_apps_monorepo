import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbits_picker.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show EffortLevel, FastModeControl, FastModeToggleApply, FastModeToggleDecision, ModelOrbits;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "orbits_fixture.dart";

/// The chip sits where the mock puts it: 14 pt in, its medallion at y = 610.
const _anchor = Rect.fromLTWH(14, 591, 150, 39);

typedef _Pick = ({String providerID, String modelID, SessionVariant? variant});

final class _Harness() {
  final picks = <_Pick>[];
  final fastChanges = <bool>[];
  int allModelsOpened = 0;
  int selectionHaptics = 0;
}

OrbitGeometry _geometry({required ModelOrbits orbits}) => OrbitGeometry(
  orbits: orbits,
  origin: Offset(_anchor.left + _anchor.height / 2, _anchor.center.dy),
  size: const Size(393, 700),
  fastToggleRect: null,
);

Future<_Harness> _open(
  WidgetTester tester, {
  required ModelOrbits orbits,
  FastModeControl fastModeControl = FastModeControl.off,
  FastModeToggleDecision decision = const FastModeToggleApply(fastMode: true),
}) async {
  tester.view
    ..physicalSize = const Size(393, 700)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == "HapticFeedback.vibrate" && call.arguments == "HapticFeedbackType.selectionClick") {
      harness.selectionHaptics++;
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
      orbits: orbits,
      onModelSelected: ({required providerID, required modelID, required variant}) =>
          harness.picks.add((providerID: providerID, modelID: modelID, variant: variant)),
      onShowAllModels: () => harness.allModelsOpened++,
      fastModeControl: fastModeControl,
      decideFastModeToggle: () => decision,
      onFastModeChanged: harness.fastChanges.add,
    ),
  );
  await tester.pumpAndSettle();
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
    expect(picker, findsNothing);
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
