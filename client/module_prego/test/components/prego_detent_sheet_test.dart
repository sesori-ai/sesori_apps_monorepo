import "package:flutter/semantics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

// An 800-point-tall screen with a 40-point status bar: the sheet rests with
// its top at 400 (half the screen) or 40 (full, below the status bar).
const _screen = Size(400, 800);
const _statusBar = 40.0;
const _halfTop = 400.0;
const _fullTop = _statusBar;

const _openLabel = "Open";
const _inputKey = ValueKey("input");
const _listKey = ValueKey("list");

class _Harness() {
  Future<String?>? result;
}

Future<_Harness> _open(WidgetTester tester, {int items = 60}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _screen
    ..padding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text("Behind"),
              TextButton(
                onPressed: () => harness.result = showPregoDetentSheet<String>(
                  context: context,
                  builder: (context, scrollController) => Column(
                    children: [
                      const SizedBox(height: 44, child: Text("Header")),
                      Expanded(
                        child: ListView.builder(
                          key: _listKey,
                          controller: scrollController,
                          itemCount: items,
                          itemExtent: 40,
                          itemBuilder: (_, index) => Text("Row $index"),
                        ),
                      ),
                      const SizedBox(key: _inputKey, height: 48, child: TextField()),
                    ],
                  ),
                ),
                child: const Text(_openLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
  return harness;
}

double _sheetTop(WidgetTester tester) => tester.getTopLeft(find.byType(PregoSheetGrabber)).dy;

bool _sheetOpen(WidgetTester tester) => find.byType(PregoSheetGrabber).evaluate().isNotEmpty;

double _scrimOpacity(WidgetTester tester) {
  final scrim = tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .map((box) => box.color)
      .where((color) => color.a > 0 && color.r == 0 && color.g == 0 && color.b == 0);
  return scrim.single.a;
}

ScrollPosition _listPosition(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byKey(_listKey), matching: find.byType(Scrollable)))
    .position;

/// Drags the grabber by [dy] slowly enough that the release isn't a fling.
Future<void> _slowDrag(WidgetTester tester, double dy) async {
  await tester.timedDrag(find.byType(PregoSheetGrabber), Offset(0, dy), const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  group("showPregoDetentSheet", () {
    testWidgets("opens at half height over the page, which stays mounted", (tester) async {
      await _open(tester);

      expect(_sheetTop(tester), _halfTop);
      expect(find.text("Behind"), findsOneWidget);
    });

    testWidgets("follows the finger continuously", (tester) async {
      await _open(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PregoSheetGrabber)));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      final afterSlop = _sheetTop(tester);

      for (var step = 1; step <= 5; step++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        expect(_sheetTop(tester), afterSlop - 20 * step);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("snaps up to full height past the midpoint and back to half before it", (tester) async {
      await _open(tester);

      await _slowDrag(tester, -150);
      expect(_sheetTop(tester), _halfTop);

      await _slowDrag(tester, -250);
      expect(_sheetTop(tester), _fullTop);
    });

    testWidgets("a fling up from half goes to full, a fling down from full to half", (tester) async {
      await _open(tester);

      await tester.fling(find.byType(PregoSheetGrabber), const Offset(0, -60), 1500);
      await tester.pumpAndSettle();
      expect(_sheetTop(tester), _fullTop);

      await tester.fling(find.byType(PregoSheetGrabber), const Offset(0, 60), 1500);
      await tester.pumpAndSettle();
      expect(_sheetTop(tester), _halfTop);
    });

    testWidgets("a fling down from half closes the sheet", (tester) async {
      final harness = await _open(tester);

      await tester.fling(find.byType(PregoSheetGrabber), const Offset(0, 60), 1500);
      await tester.pumpAndSettle();

      expect(_sheetOpen(tester), isFalse);
      expect(await harness.result, isNull);
    });

    testWidgets("a slow drag down from half returns to half, or closes past halfway", (tester) async {
      await _open(tester);

      await _slowDrag(tester, 80);
      expect(_sheetTop(tester), _halfTop);

      await _slowDrag(tester, 300);
      expect(_sheetOpen(tester), isFalse);
    });

    testWidgets("the scrim is light at half height, deepens toward full, and closes on a tap", (tester) async {
      await _open(tester);
      final atHalf = _scrimOpacity(tester);

      await _slowDrag(tester, -400);
      final atFull = _scrimOpacity(tester);
      expect(atHalf, greaterThan(0));
      expect(atFull, greaterThan(atHalf));

      await _slowDrag(tester, 360);
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(_sheetOpen(tester), isFalse);
    });

    testWidgets("a drag down on a list at its top moves the sheet", (tester) async {
      await _open(tester);
      await _slowDrag(tester, -400);

      await tester.timedDrag(find.byKey(_listKey), const Offset(0, 250), const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(_sheetTop(tester), _halfTop);
      expect(_listPosition(tester).pixels, 0);
    });

    testWidgets("a drag up on a half-height list grows the sheet before scrolling", (tester) async {
      await _open(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listKey)));
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();

      expect(_sheetTop(tester), lessThan(_halfTop - 90));
      expect(_listPosition(tester).pixels, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("a scrolled list scrolls back before the sheet moves", (tester) async {
      await _open(tester);
      await _slowDrag(tester, -400);
      _listPosition(tester).jumpTo(400);
      await tester.pump();

      await tester.timedDrag(find.byKey(_listKey), const Offset(0, 120), const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(_sheetTop(tester), _fullTop);
      expect(_listPosition(tester).pixels, lessThan(400));
    });

    testWidgets("a drag that grows the sheet, scrolls the list and flicks back down scrolls the list", (tester) async {
      await _open(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listKey)));
      // Up 560 over a second: 360 grow the sheet to full, 200 scroll the list.
      for (var step = 1; step <= 20; step++) {
        await gesture.moveBy(const Offset(0, -28), timeStamp: Duration(milliseconds: 50 * step));
      }
      // Then a quick flick down while the list is still scrolled.
      for (var step = 1; step <= 3; step++) {
        await gesture.moveBy(const Offset(0, 20), timeStamp: Duration(milliseconds: 1000 + 10 * step));
      }
      await tester.pump();
      expect(_listPosition(tester).pixels, greaterThan(0));
      await gesture.up(timeStamp: const Duration(milliseconds: 1030));
      await tester.pumpAndSettle();

      expect(_sheetTop(tester), _fullTop);
      expect(_listPosition(tester).pixels, 0);
    });

    testWidgets("the keyboard lifts the content and never pushes the sheet over the status bar", (tester) async {
      await _open(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byKey(_inputKey)).dy, _screen.height - 300);
      expect(_sheetTop(tester), _screen.height - 300 - _halfTop);

      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byKey(_inputKey)).dy, _screen.height - 500);
      expect(_sheetTop(tester), _fullTop);
    });

    testWidgets("reduced motion changes height without the spring", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _open(tester);

      await tester.timedDrag(find.byType(PregoSheetGrabber), const Offset(0, -250), const Duration(seconds: 2));
      await tester.pump();

      expect(_sheetTop(tester), _fullTop);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets("with motion, the release springs through the heights in between", (tester) async {
      await _open(tester);

      await tester.timedDrag(find.byType(PregoSheetGrabber), const Offset(0, -250), const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_sheetTop(tester), inExclusiveRange(_fullTop, _halfTop - 250));
      await tester.pumpAndSettle();
      expect(_sheetTop(tester), _fullTop);
    });

    testWidgets("a screen reader expands and collapses the sheet with the same spring", (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      final sheet = find.semantics.byLabel("Bottom Sheet");

      tester.semantics.customAction(sheet, const CustomSemanticsAction(label: "Expand"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheetTop(tester), inExclusiveRange(_fullTop, _halfTop));
      await tester.pumpAndSettle();
      expect(_sheetTop(tester), _fullTop);

      tester.semantics.customAction(sheet, const CustomSemanticsAction(label: "Collapse"));
      await tester.pumpAndSettle();
      expect(_sheetTop(tester), _halfTop);
      semantics.dispose();
    });

    testWidgets("a screen reader gets no height action while the keyboard leaves one height", (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      final sheet = find.semantics.byLabel("Bottom Sheet");
      expect(sheet.evaluate().single.getSemanticsData().customSemanticsActionIds, isNotEmpty);

      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await tester.pumpAndSettle();

      expect(sheet.evaluate().single.getSemanticsData().customSemanticsActionIds, isEmpty);
      semantics.dispose();
    });

    testWidgets("with reduced motion, a screen reader changes height at once", (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _open(tester);

      tester.semantics.customAction(
        find.semantics.byLabel("Bottom Sheet"),
        const CustomSemanticsAction(label: "Expand"),
      );
      // One frame: a spring would still be on its way.
      await tester.pump();

      expect(_sheetTop(tester), _fullTop);
      semantics.dispose();
    });

    testWidgets("keeps the presenting page's theme", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Theme(
            data: ThemeData(extensions: [PregoDesignSystem.dark]),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPregoDetentSheet<void>(context: context, builder: (_, _) => const SizedBox()),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_openLabel));
      await tester.pumpAndSettle();

      final surface = tester.widget<Material>(
        find.ancestor(of: find.byType(PregoSheetGrabber), matching: find.byType(Material)).first,
      );
      expect(surface.color, PregoDesignSystem.dark.colors.bgSecondary);
    });
  });
}
