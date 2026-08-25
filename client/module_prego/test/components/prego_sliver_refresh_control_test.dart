import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoActivityIndicator;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// `CupertinoSliverRefreshControl` triggers at 100 logical px by default, so
/// the deep stage arms at 160. Drags keep a margin on their side of each
/// threshold, since a drag loses some distance to touch slop.
const double _softTrigger = 100;
const double _deepTrigger = _softTrigger * 1.8;

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
                decorate: null,
                onPulledExtentChanged: null,
                deepRefresh: withDeepRefresh
                    ? PregoDeepRefresh(
                        onDeepRefresh: () => deepRefreshes++,
                        pullCaption: "Keep pulling to scan all harnesses",
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

    testWidgets("the invitation appears past the ordinary trigger and is gone once fired", (
      tester,
    ) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));
      final gesture = await tester.startGesture(const Offset(200, 100));

      // Bouncing physics damps overscroll, so the caption is driven by a
      // gradual pull and asserted on its order rather than on a distance.
      var invited = false;

      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(find.text("Keep pulling to scan all harnesses"), findsNothing);

      for (var step = 0; step < 16; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        if (find.text("Keep pulling to scan all harnesses").evaluate().isNotEmpty) invited = true;
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(invited, isTrue, reason: "a pull past the trigger must invite the second stage");
      expect(deepRefreshes, 1);
      // Crossing the threshold hands reporting to the host's own row, so the
      // control says nothing more rather than narrating the same run twice.
      expect(find.text("Keep pulling to scan all harnesses"), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("the control empties itself once the second stage has fired", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));
      final gesture = await tester.startGesture(const Offset(200, 100));

      // Past the ordinary trigger: a quiet, icon-less invitation.
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      expect(find.text("Keep pulling to scan all harnesses"), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsWidgets);

      // Past the deep threshold: caption and spinner both go, because the
      // host's progress row is what reports the run from here.
      for (var step = 0; step < 8; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Keep pulling to scan all harnesses"), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("no caption survives an ordinary refresh once the finger lifts", (tester) async {
      // The control holds a shorter indicator extent while the refresh runs, so
      // a caption keyed on the furthest point reached would sit under the
      // spinner for the whole of an ordinary refresh.
      final completer = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                PregoSliverRefreshControl(
                  onRefresh: () => completer.future,
                  decorate: null,
                  onPulledExtentChanged: null,
                  deepRefresh: PregoDeepRefresh(
                    onDeepRefresh: () => deepRefreshes++,
                    pullCaption: "Keep pulling to scan all harnesses",
                  ),
                ),
                SliverList.list(
                  children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      expect(find.text("Keep pulling to scan all harnesses"), findsOneWidget);

      await gesture.up();
      await tester.pump();
      // Two frames: the first settles the extent, which is what tells the
      // caption to leave; the second runs its fade-out to completion.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text("Keep pulling to scan all harnesses"),
        findsNothing,
        reason: "an ordinary refresh must look exactly as it did before",
      );

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets("the caption stays inside the extent the control reserved", (tester) async {
      await tester.pumpWidget(harness(withDeepRefresh: true));
      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }

      // The first list row must start below the caption, or the caption paints
      // over the list.
      final captionBottom = tester.getRect(find.text("Keep pulling to scan all harnesses")).bottom;
      final firstRowTop = tester.getRect(find.text("row 0")).top;
      expect(
        captionBottom,
        lessThanOrEqualTo(firstRowTop),
        reason: "the caption must not overlap the first row",
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("the fired report gives way as the pull collapses", (tester) async {
      // Once the finger lifts, the control holds an extent far shorter than the
      // trigger; a caption pinned inside it would sit on top of the spinner.
      // The host's progress surface reports the rest of the run.
      final completer = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                PregoSliverRefreshControl(
                  onRefresh: () => completer.future,
                  decorate: null,
                  onPulledExtentChanged: null,
                  deepRefresh: PregoDeepRefresh(
                    onDeepRefresh: () => deepRefreshes++,
                    pullCaption: "Keep pulling to scan all harnesses",
                  ),
                ),
                SliverList.list(
                  children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 11; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(deepRefreshes, 1);
      expect(find.text("Keep pulling to scan all harnesses"), findsNothing);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text("Keep pulling to scan all harnesses"),
        findsNothing,
        reason: "a fired pull leaves nothing behind for the held extent to show",
      );

      completer.complete();
      await tester.pumpAndSettle();
    });

    // The ordinary refresh reaches the same backend the second stage just put
    // to work, so waiting for it holds the list open for as long as the whole
    // scan — with nothing in the held space to explain why.
    testWidgets("a fired pull stops holding the list open for the ordinary refresh", (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                PregoSliverRefreshControl(
                  onRefresh: () => completer.future,
                  decorate: null,
                  onPulledExtentChanged: null,
                  deepRefresh: PregoDeepRefresh(
                    onDeepRefresh: () => deepRefreshes++,
                    pullCaption: "Keep pulling to scan all harnesses",
                  ),
                ),
                SliverList.list(
                  children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                ),
              ],
            ),
          ),
        ),
      );
      final restingTop = tester.getTopLeft(find.text("row 0")).dy;

      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        await tester.pump();
      }
      expect(deepRefreshes, 1);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        completer.isCompleted,
        isFalse,
        reason: "the ordinary refresh is still running, which is the whole point",
      );
      expect(
        tester.getTopLeft(find.text("row 0")).dy,
        restingTop,
        reason: "the list must not stay pushed down for the length of the scan",
      );

      completer.complete();
      await tester.pumpAndSettle();
    });

    // The control only *schedules* its refresh from the builder, so a move fast
    // enough to cross both thresholds in one frame fires the second stage
    // before the refresh exists to be released from.
    testWidgets("a single move across both thresholds still releases the list", (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                PregoSliverRefreshControl(
                  onRefresh: () => completer.future,
                  decorate: null,
                  onPulledExtentChanged: null,
                  deepRefresh: PregoDeepRefresh(
                    onDeepRefresh: () => deepRefreshes++,
                    pullCaption: "Keep pulling to find new sessions",
                  ),
                ),
                SliverList.list(
                  children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                ),
              ],
            ),
          ),
        ),
      );
      final restingTop = tester.getTopLeft(find.text("row 0")).dy;

      // One move, far past both thresholds, rather than the gradual pull the
      // other tests use.
      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 900));
      await tester.pump();
      await tester.pump();
      expect(deepRefreshes, 1);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(completer.isCompleted, isFalse);
      expect(
        tester.getTopLeft(find.text("row 0")).dy,
        restingTop,
        reason: "the release must not depend on the refresh having started first",
      );

      completer.complete();
      await tester.pumpAndSettle();
    });

    // The released refresh has nothing downstream left to observe it, and this
    // package has no logger of its own.
    testWidgets("a released refresh reports its own failure", (tester) async {
      final completer = Completer<void>();
      final reported = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                PregoSliverRefreshControl(
                  onRefresh: () => completer.future,
                  decorate: null,
                  onPulledExtentChanged: null,
                  deepRefresh: PregoDeepRefresh(
                    onDeepRefresh: () => deepRefreshes++,
                    pullCaption: "Keep pulling to find new sessions",
                  ),
                ),
                SliverList.list(
                  children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 900));
      await tester.pump();
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      completer.completeError(StateError("refresh blew up"), StackTrace.current);
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(reported.single, isA<StateError>());
    });

    testWidgets("a long caption truncates rather than overflowing", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: MediaQuery(
            // A large accessibility text scale, which is where an
            // unconstrained label overflows instead of truncating.
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: Scaffold(
              body: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  PregoSliverRefreshControl(
                    onRefresh: () async => softRefreshes++,
                    decorate: null,
                    onPulledExtentChanged: null,
                    deepRefresh: PregoDeepRefresh(
                      onDeepRefresh: () => deepRefreshes++,
                      pullCaption: "Keep pulling to scan every harness for sessions you have not seen",
                    ),
                  ),
                  SliverList.list(
                    children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 100));
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
      }

      expect(tester.takeException(), isNull, reason: "the caption must not overflow its row");

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
