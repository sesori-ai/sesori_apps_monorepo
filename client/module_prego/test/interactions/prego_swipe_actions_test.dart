import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_prego/module_prego.dart';

/// The default test surface is 800 logical px wide, so the geometry the tests
/// assert against is:
/// - reveal width: 6 (start gap) + 40 (action) + 6 (gap) + 136 (primary) + 16
///   (end inset) = 204, settle-open threshold 102;
/// - commit threshold: 0.6 * 800 = 480.
/// Drags lose ~18px to touch slop before the recognizer reports, so distances
/// keep a margin on their side of each threshold.
const double _surfaceWidth = 800;
const double _revealWidth = 204;
const double _primaryWidth = 136;

class _Counters {
  int contentTaps = 0;
  int actionTaps = 0;
  int primaryTaps = 0;
  int fullSwipes = 0;
}

Widget _row({
  required String label,
  required _Counters counters,
  bool closeOnAction = false,
}) {
  return PregoSwipeActions(
    actionsBuilder: (context, close) => [
      GestureDetector(
        key: ValueKey('action-$label'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          counters.actionTaps++;
          if (closeOnAction) close();
        },
        child: const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.blue)),
      ),
    ],
    primaryActionBuilder: (context, close) => TextButton(
      onPressed: () {
        counters.primaryTaps++;
        if (closeOnAction) close();
      },
      child: Text('Hide $label'),
    ),
    primaryActionWidth: _primaryWidth,
    onFullSwipe: () => counters.fullSwipes++,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => counters.contentTaps++,
      child: SizedBox(
        height: 96,
        child: Center(child: Text('$label content')),
      ),
    ),
  );
}

Widget _harness({
  required List<Widget> rows,
  ScrollController? scrollController,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: ListView(
          controller: scrollController,
          children: [
            ...rows,
            for (var i = 0; i < 10; i++) const SizedBox(height: 96),
          ],
        ),
      ),
    ),
  );
}

/// Drags [label]'s row horizontally by [dx] and lets it settle.
Future<void> _swipe(WidgetTester tester, {required String label, required double dx}) async {
  await tester.drag(find.text('$label content'), Offset(dx, 0));
  await tester.pumpAndSettle();
}

/// The primary action's tappable rect for [label]'s row.
Rect _primaryRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(TextButton, 'Hide $label'));

/// Moves a held gesture in steps, the way a finger streams move events.
///
/// A single big `moveBy` only wins the gesture arena: with the default
/// [DragStartBehavior.start] the accepting event's whole delta is treated as
/// positioning and discarded, so the drag would register as zero movement.
/// [pumpEach] paces the stream — long pauses keep the release velocity under
/// the fling threshold.
Future<void> _moveInSteps(
  WidgetTester tester,
  TestGesture gesture, {
  required Offset total,
  int steps = 8,
  Duration pumpEach = const Duration(milliseconds: 16),
}) async {
  final step = Offset(total.dx / steps, total.dy / steps);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(pumpEach);
  }
}

void main() {
  testWidgets('rests closed: actions off-row, content tappable, none of the callbacks fired', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // The strip is laid out past the row's end edge, clipped out of view.
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await tester.tap(find.text('A content'));
    await tester.pumpAndSettle();
    expect(counters.contentTaps, 1);
    expect(counters.actionTaps, 0);
    expect(counters.primaryTaps, 0);
    expect(counters.fullSwipes, 0);
  });

  testWidgets('while closed the actions are excluded from semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    expect(find.bySemanticsLabel('Hide A'), findsNothing);

    await _swipe(tester, label: 'A', dx: -150);

    expect(find.bySemanticsLabel('Hide A'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a short drag springs back closed', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // ~62px after slop — under the 102px settle-open threshold.
    await _swipe(tester, label: 'A', dx: -80);

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('a drag past half the reveal settles open with the actions in place and tappable', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await _swipe(tester, label: 'A', dx: -150);

    // Open geometry: the primary sits its own width plus the end inset from
    // the row's end; the reveal width was measured, not declared.
    final rect = _primaryRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(_surfaceWidth - 16 - _primaryWidth, epsilon: 1));
    expect(rect.width, moreOrLessEquals(_primaryWidth, epsilon: 1));

    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();
    expect(counters.primaryTaps, 1);

    final actionTarget = tester.getCenter(find.byKey(const ValueKey('action-A')));
    expect(actionTarget.dx, moreOrLessEquals(_surfaceWidth - _revealWidth + 6 + 20, epsilon: 1));
    await tester.tap(find.byKey(const ValueKey('action-A')));
    await tester.pumpAndSettle();
    expect(counters.actionTaps, 1);
    expect(counters.fullSwipes, 0);
  });

  testWidgets('an action can close the row through the builder callback', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters, closeOnAction: true)]));

    await _swipe(tester, label: 'A', dx: -150);
    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();

    expect(counters.primaryTaps, 1);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('tapping the open row closes it without activating the content, which works again after', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await _swipe(tester, label: 'A', dx: -150);
    // The tap intentionally lands on the close-catcher covering the content.
    await tester.tap(find.text('A content'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(counters.contentTaps, 0);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await tester.tap(find.text('A content'));
    await tester.pumpAndSettle();
    expect(counters.contentTaps, 1);
  });

  testWidgets('a tap anywhere outside the open row closes it', (tester) async {
    final counters = _Counters();
    final other = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters), _row(label: 'B', counters: other)]),
    );

    await _swipe(tester, label: 'A', dx: -150);
    await tester.tap(find.text('B content'));
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('opening a second row closes the first', (tester) async {
    final a = _Counters();
    final b = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: a), _row(label: 'B', counters: b)]));

    await _swipe(tester, label: 'A', dx: -150);
    await _swipe(tester, label: 'B', dx: -150);

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
    expect(_primaryRect(tester, 'B').left, lessThan(_surfaceWidth));
  });

  testWidgets('scrolling the enclosing list closes the open row', (tester) async {
    final counters = _Counters();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters)], scrollController: scrollController),
    );

    await _swipe(tester, label: 'A', dx: -150);
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));

    // Programmatic, so the close is attributable to the scroll itself rather
    // than to the pointer-down of a scroll gesture.
    scrollController.jumpTo(40);
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('a full swipe past the commit threshold fires onFullSwipe once and closes', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // ~502px after slop — past the 480px commit threshold.
    await _swipe(tester, label: 'A', dx: -520);

    expect(counters.fullSwipes, 1);
    expect(counters.primaryTaps, 0);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('the primary action stretches during the overdrag, trailing edge pinned to the row end', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // 8 steps of -70; the first step is spent winning the arena, leaving
    // ~490px of extent — past the 480px commit threshold.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(tester, gesture, total: const Offset(-560, 0));

    final rect = _primaryRect(tester, 'A');
    expect(rect.right, moreOrLessEquals(_surfaceWidth - 16, epsilon: 1));
    expect(rect.width, greaterThan(_primaryWidth + 200));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(counters.fullSwipes, 1);
  });

  testWidgets('dragging past the threshold and back before releasing does not commit', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(tester, gesture, total: const Offset(-560, 0));
    // Slow enough on the way back that the release is not a closing fling —
    // a fast fling back is its own cancel path.
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(300, 0),
      steps: 6,
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 0);
    // ~190px extent at release — past half the reveal, so it settles open.
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));
  });

  testWidgets('reveals with a start-edge drag under RTL', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters)], textDirection: TextDirection.rtl),
    );

    // In RTL the actions live past the left edge and a rightward drag reveals.
    expect(_primaryRect(tester, 'A').right, lessThanOrEqualTo(0));

    await _swipe(tester, label: 'A', dx: 150);

    final rect = _primaryRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(16, epsilon: 1));

    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();
    expect(counters.primaryTaps, 1);
  });

  testWidgets('disposing mid-settle does not throw', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await tester.drag(find.text('A content'), const Offset(-150, 0));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
