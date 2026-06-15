import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/scroll_follow_tracker.dart";

ScrollMetrics _metrics({required double min, required double max, required double pixels}) {
  return FixedScrollMetrics(
    minScrollExtent: min,
    maxScrollExtent: max,
    pixels: pixels,
    viewportDimension: 600,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );
}

void main() {
  group("ScrollFollowTracker", () {
    late ScrollFollowTracker tracker;

    setUp(() => tracker = ScrollFollowTracker(edge: ScrollFollowEdge.min));
    tearDown(() => tracker.dispose());

    // A BuildContext is only needed to construct the notification objects; the
    // tracker never reads it. Capture one from a pumped widget.
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      );
      return captured;
    }

    testWidgets("starts in following mode", (tester) async {
      expect(tracker.following, isTrue);
    });

    testWidgets("a user drag on a scrollable list detaches", (tester) async {
      final context = await pumpContext(tester);
      tracker.handleScrollNotification(
        notification: ScrollStartNotification(
          metrics: _metrics(min: 0, max: 1000, pixels: 0),
          context: context,
          dragDetails: DragStartDetails(),
        ),
      );
      expect(tracker.following, isFalse);
    });

    testWidgets("overscroll on a list with no scrollable range does NOT detach", (tester) async {
      // Content shorter than the viewport: min == max, so any drag is pure
      // overscroll bounce that returns to the edge. Must stay following so the
      // jump-to-latest pill never flashes (regression guard for the
      // always-overscroll physics on the chat list).
      final context = await pumpContext(tester);
      tracker.handleScrollNotification(
        notification: ScrollStartNotification(
          metrics: _metrics(min: 0, max: 0, pixels: 0),
          context: context,
          dragDetails: DragStartDetails(),
        ),
      );
      expect(tracker.following, isTrue);
    });

    testWidgets("a scroll-end on a list with no scrollable range does NOT toggle follow state", (tester) async {
      // A bouncing overscroll on a short transcript can fire ScrollEnd with the
      // pixels still displaced past the tolerance. With no scrollable range the
      // list never left the edge, so _maybeReattach must not flip to detached.
      final context = await pumpContext(tester);
      tracker.handleScrollNotification(
        notification: ScrollEndNotification(
          metrics: _metrics(min: 0, max: 0, pixels: -50),
          context: context,
        ),
      );
      expect(tracker.following, isTrue);
    });

    testWidgets("reattaches when a scroll settles back at the follow edge", (tester) async {
      final context = await pumpContext(tester);
      tracker.handleScrollNotification(
        notification: ScrollStartNotification(
          metrics: _metrics(min: 0, max: 1000, pixels: 200),
          context: context,
          dragDetails: DragStartDetails(),
        ),
      );
      expect(tracker.following, isFalse);

      tracker.handleScrollNotification(
        notification: ScrollEndNotification(
          metrics: _metrics(min: 0, max: 1000, pixels: 0),
          context: context,
        ),
      );
      expect(tracker.following, isTrue);
    });

    testWidgets("stays detached when a scroll settles away from the follow edge", (tester) async {
      final context = await pumpContext(tester);
      tracker.handleScrollNotification(
        notification: ScrollStartNotification(
          metrics: _metrics(min: 0, max: 1000, pixels: 200),
          context: context,
          dragDetails: DragStartDetails(),
        ),
      );
      tracker.handleScrollNotification(
        notification: ScrollEndNotification(
          metrics: _metrics(min: 0, max: 1000, pixels: 500),
          context: context,
        ),
      );
      expect(tracker.following, isFalse);
    });
  });
}
