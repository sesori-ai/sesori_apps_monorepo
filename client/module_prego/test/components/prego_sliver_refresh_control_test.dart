import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// `CupertinoSliverRefreshControl` triggers at 100 logical px by default, so
/// the deep stage arms at 160. Drags keep a margin on their side of each
/// threshold, since a drag loses some distance to touch slop.
const double _softTrigger = 100;
const double _deepTrigger = _softTrigger * 1.6;

void main() {
  group("PregoSliverRefreshControl", () {
    late int softRefreshes;
    late int deepRefreshes;

    setUp(() {
      softRefreshes = 0;
      deepRefreshes = 0;
    });

    Widget harness({required bool withDeepRefresh}) {
      return MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              PregoSliverRefreshControl(
                onRefresh: () async => softRefreshes++,
                deepRefresh: withDeepRefresh
                    ? PregoDeepRefresh(
                        onDeepRefresh: () => deepRefreshes++,
                        pullCaption: "Keep pulling to scan all harnesses",
                        deepCaption: "Scanning for new sessions",
                      )
                    : null,
              ),
              SliverList.list(
                children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
              ),
            ],
          ),
        ),
      );
    }

    Future<void> pullBy(WidgetTester tester, double distance) async {
      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(Offset(0, distance));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets("a pull to the ordinary trigger runs only the soft refresh", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));

      await pullBy(tester, _softTrigger + 40);

      expect(softRefreshes, 1);
      expect(deepRefreshes, 0, reason: "the deep threshold was never reached");
    });

    testWidgets("a pull past the deep threshold runs both", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));

      await pullBy(tester, _deepTrigger + 80);

      expect(softRefreshes, 1);
      expect(deepRefreshes, 1);
    });

    testWidgets("a pull abandoned before the trigger runs neither", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));

      final gesture = await tester.startGesture(const Offset(200, 100));
      // Short of the trigger, then back to rest.
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(softRefreshes, 0);
      expect(deepRefreshes, 0);
    });

    testWidgets("the deep stage cannot fire when no second stage is supplied", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: false));

      await pullBy(tester, _deepTrigger + 80);

      expect(softRefreshes, 1);
      expect(deepRefreshes, 0);
    });

    testWidgets("captions appear only past the ordinary trigger and switch at the deep one", (
      tester,
    ) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));
      final gesture = await tester.startGesture(const Offset(200, 100));

      // Bouncing physics damps overscroll, so the captions are driven by a
      // gradual pull and asserted on their order rather than on a distance.
      final order = <String>[];
      void record() {
        if (find.text("Keep pulling to scan all harnesses").evaluate().isNotEmpty) order.add("pull");
        if (find.text("Scanning for new sessions").evaluate().isNotEmpty) order.add("deep");
      }

      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(find.text("Keep pulling to scan all harnesses"), findsNothing);
      expect(find.text("Scanning for new sessions"), findsNothing);

      for (var step = 0; step < 16; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        record();
      }

      expect(order, contains("pull"), reason: "a pull past the trigger must invite the second stage");
      expect(order, contains("deep"), reason: "and report once the rescan has fired");
      expect(
        order.indexOf("pull"),
        lessThan(order.indexOf("deep")),
        reason: "the invitation comes before the rescan",
      );
      expect(order.last, "deep");

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("the fired caption is visually distinct from the invitation", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));
      final gesture = await tester.startGesture(const Offset(200, 100));

      // Past the ordinary trigger: a quiet, icon-less invitation.
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      expect(find.text("Keep pulling to scan all harnesses"), findsOneWidget);
      expect(find.byIcon(TablerRegular.rotate_clockwise), findsNothing);

      // Past the deep threshold: the label gains its icon.
      for (var step = 0; step < 6; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Scanning for new sessions"), findsOneWidget);
      expect(find.byIcon(TablerRegular.rotate_clockwise), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("one pull rescans once however far it travels", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));

      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 16; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deepRefreshes, 1, reason: "crossing the threshold once must not fire per frame");
    });

    testWidgets("a second pull does not inherit the previous pull's arming", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));

      await pullBy(tester, _deepTrigger + 80);
      expect(deepRefreshes, 1);

      await pullBy(tester, _softTrigger + 40);

      expect(softRefreshes, 2);
      expect(deepRefreshes, 1, reason: "the arming must reset after each release");
    });
  });
}
