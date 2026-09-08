import "package:flutter/scheduler.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_motion_tuning/sesori_motion_tuning.dart";
import "package:theme_prego/module_prego.dart";

const _duration = MotionDuration(
  id: "card.duration",
  label: "Duration",
  source: "Card entrance",
  initialValue: Duration(milliseconds: 200),
  min: Duration.zero,
  max: Duration(milliseconds: 1000),
);
const _curve = MotionCurve(
  id: "card.curve",
  label: "Easing",
  source: "Card entrance",
  initialValue: MotionEasing.easeOut,
);
const _card = MotionTarget(id: "card", label: "Card entrance", parameters: [_duration, _curve]);
const _hidden = MotionTarget(id: "hidden", label: "Hidden transition", parameters: []);
const _outer = MotionTarget(id: "outer", label: "Outer transition", parameters: []);

void main() {
  testWidgets("global speed slows unconnected tickers and restores normal without editing values", (tester) async {
    addTearDown(() => timeDilation = 1);
    final runs = <MotionSnapshot>[];
    await _pump(
      tester: tester,
      overlapping: false,
      textScale: 1,
      onPress: () {},
      onReplay: ({required target, required values}) => runs.add(values),
    );
    await tester.tap(find.byTooltip("Expand motion controls"));
    await tester.pumpAndSettle();
    final animation = AnimationController(vsync: tester, duration: const Duration(seconds: 1));
    addTearDown(animation.dispose);
    var selectedLabel = "Normal (1×)";
    for (final (label, progress) in [("0.5×", 0.05), ("0.2×", 0.02), ("Normal (1×)", 0.1)]) {
      await tester.tap(find.text(selectedLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      selectedLabel = label;
      animation.forward(from: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.value, closeTo(progress, 0.001));
      animation.stop();
    }
    expect(runs, isEmpty);
    await _selectCard(tester: tester);
    await tester.tap(find.byTooltip("Replay animation"));
    expect(runs.single.duration(parameter: _duration), const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(timeDilation, 1);
  });

  testWidgets("fixture replacement releases slowdown and reparenting preserves the selected speed", (tester) async {
    addTearDown(() => timeDilation = 1);
    await _pump(
      tester: tester,
      overlapping: false,
      textScale: 1,
      onPress: () {},
      onReplay: ({required target, required values}) {},
    );
    await tester.tap(find.byTooltip("Expand motion controls"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Normal (1×)"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("0.2×"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Collapse motion controls"));
    await tester.pumpAndSettle();
    expect(find.text("Motion · 0.2×"), findsOneWidget);
    expect(timeDilation, 5);
    final preview = tester.widget<MotionTuningHost>(find.byType(MotionTuningHost));
    final nextPreview = MotionTuningHost(
      key: GlobalKey(),
      fixtureId: "next-fixture",
      targets: preview.targets,
      onReplay: preview.onReplay,
      child: preview.child,
    );
    await tester.pumpWidget(nextPreview);
    expect(timeDilation, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(timeDilation, 1);

    await tester.pumpWidget(nextPreview);
    await tester.tap(find.byTooltip("Expand motion controls"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Normal (1×)"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("0.5×"));
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox(child: nextPreview));
    expect(timeDilation, 2);
    expect(find.text("Motion · 0.5×"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(timeDilation, 1);
  });

  testWidgets("selection consumes a tap, then normal interaction resumes", (tester) async {
    var presses = 0;
    await _pump(
      tester: tester,
      overlapping: false,
      textScale: 1,
      onPress: () => presses++,
      onReplay: ({required target, required values}) {},
    );
    await tester.tap(find.byTooltip("Select an element"));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text("Preview action")));
    await tester.pumpAndSettle();
    expect(presses, 0);
    expect(find.text("Card entrance"), findsWidgets);
    await tester.tapAt(tester.getCenter(find.text("Preview action")));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets("edits apply on replay, compare preserves draft, reset restores default", (tester) async {
    final runs = <MotionSnapshot>[];
    await _pump(
      tester: tester,
      overlapping: false,
      textScale: 1,
      onPress: () {},
      onReplay: ({required target, required values}) => runs.add(values),
    );
    await _selectCard(tester: tester);
    await tester.enterText(find.byType(TextFormField), "6");
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), "68");
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), "680");
    await tester.pumpAndSettle();
    expect(runs, isEmpty);
    await tester.tap(find.byTooltip("Replay animation"));
    await tester.pump();
    expect(runs.last.duration(parameter: _duration), const Duration(milliseconds: 680));
    final captured = runs.last;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(runs.last.duration(parameter: _duration), const Duration(milliseconds: 200));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(runs.last.duration(parameter: _duration), const Duration(milliseconds: 680));
    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();
    expect(runs.last.duration(parameter: _duration), const Duration(milliseconds: 200));
    expect(captured.duration(parameter: _duration), const Duration(milliseconds: 680));
    expect(tester.takeException(), isNull);
  });

  testWidgets("hidden targets and easing menus work above the app navigator", (tester) async {
    MotionTarget? replayed;
    await _pump(
      tester: tester,
      overlapping: false,
      textScale: 1,
      onPress: () {},
      onReplay: ({required target, required values}) => replayed = target,
    );
    await tester.tap(find.byTooltip("Expand motion controls"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Choose an animation"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Hidden transition"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Replay animation"));
    expect(replayed, _hidden);
    await _selectCard(tester: tester);
    await tester.tap(find.text(MotionEasing.easeOut.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MotionEasing.linear.label));
    await tester.pumpAndSettle();
    expect(find.text(MotionEasing.linear.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("overlapping regions offer an explicit choice without activating either", (tester) async {
    var presses = 0;
    await _pump(
      tester: tester,
      overlapping: true,
      textScale: 1,
      onPress: () => presses++,
      onReplay: ({required target, required values}) {},
    );
    await tester.tap(find.byTooltip("Select an element"));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text("Preview action")));
    await tester.pumpAndSettle();
    expect(presses, 0);
    expect(find.text("Overlapping elements — choose one:"), findsOneWidget);
    await tester.tap(find.text("Outer transition"));
    await tester.pumpAndSettle();
    expect(find.text("Overlapping elements — choose one:"), findsNothing);
    expect(find.text("Outer transition"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("small view, large text, keyboard, and dragging keep controls usable", (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester: tester,
      textScale: 1.6,
      overlapping: false,
      onPress: () {},
      onReplay: ({required target, required values}) {},
    );
    await _selectCard(tester: tester);
    await tester.drag(find.text("Motion"), const Offset(600, 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final replay = tester.getRect(find.byTooltip("Replay animation"));
    expect(replay.right, lessThanOrEqualTo(320));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip("Replay animation")).bottom, lessThan(328));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _selectCard({required WidgetTester tester}) async {
  await tester.tap(find.byTooltip("Select an element"));
  await tester.pump();
  await tester.tapAt(tester.getCenter(find.text("Preview action")));
  await tester.pumpAndSettle();
}

Future<void> _pump({
  required WidgetTester tester,
  required VoidCallback onPress,
  required void Function({required MotionTarget target, required MotionSnapshot values}) onReplay,
  required bool overlapping,
  required double textScale,
}) async {
  final action = MotionTargetRegion(
    targetId: _card.id,
    child: TextButton(onPressed: onPress, child: const Text("Preview action")),
  );
  await tester.pumpWidget(
    MotionTuningHost(
      fixtureId: "test",
      targets: [_card, _hidden, if (overlapping) _outer],
      onReplay: onReplay,
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: MotionTuningOverlay(child: child ?? const SizedBox.shrink()),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 24),
              child: overlapping ? MotionTargetRegion(targetId: _outer.id, child: action) : action,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
